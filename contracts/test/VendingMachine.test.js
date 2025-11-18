const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time, loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("VendingMachine", function () {
  // Fixture to deploy contracts
  async function deployVendingMachineFixture() {
    const [owner, treasury, user1, user2] = await ethers.getSigners();

    // Deploy mock USDC
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const usdc = await MockERC20.deploy("USD Coin", "USDC", 6);

    // Deploy mock RandomnessProvider
    const MockRandomnessProvider = await ethers.getContractFactory("MockRandomnessProvider");
    const randomnessProvider = await MockRandomnessProvider.deploy();

    // Deploy VendingMachine
    const VendingMachine = await ethers.getContractFactory("VendingMachine");
    const vendingMachine = await VendingMachine.deploy(
      await usdc.getAddress(),
      await randomnessProvider.getAddress(),
      treasury.address
    );

    // Mint USDC to users
    const mintAmount = ethers.parseUnits("1000", 6); // 1000 USDC
    await usdc.mint(user1.address, mintAmount);
    await usdc.mint(user2.address, mintAmount);

    return {
      vendingMachine,
      usdc,
      randomnessProvider,
      owner,
      treasury,
      user1,
      user2,
    };
  }

  describe("Deployment", function () {
    it("Should set the correct USDC address", async function () {
      const { vendingMachine, usdc } = await loadFixture(deployVendingMachineFixture);
      expect(await vendingMachine.usdc()).to.equal(await usdc.getAddress());
    });

    it("Should set the correct treasury", async function () {
      const { vendingMachine, treasury } = await loadFixture(deployVendingMachineFixture);
      expect(await vendingMachine.treasury()).to.equal(treasury.address);
    });

    it("Should initialize tiers correctly", async function () {
      const { vendingMachine } = await loadFixture(deployVendingMachineFixture);

      const tier1 = await vendingMachine.getTier(1);
      expect(tier1.price).to.equal(ethers.parseUnits("20", 6));
      expect(tier1.minValue).to.equal(ethers.parseUnits("5", 6));
      expect(tier1.maxValue).to.equal(ethers.parseUnits("30", 6));
      expect(tier1.active).to.be.true;

      const tier2 = await vendingMachine.getTier(2);
      expect(tier2.price).to.equal(ethers.parseUnits("50", 6));

      const tier3 = await vendingMachine.getTier(3);
      expect(tier3.price).to.equal(ethers.parseUnits("100", 6));
    });
  });

  describe("Purchases", function () {
    it("Should allow user to purchase tier 1", async function () {
      const { vendingMachine, usdc, user1, treasury } = await loadFixture(
        deployVendingMachineFixture
      );

      const tier = 1;
      const price = ethers.parseUnits("20", 6);

      // Approve USDC
      await usdc.connect(user1).approve(await vendingMachine.getAddress(), price);

      // Purchase
      await expect(vendingMachine.connect(user1).purchase(tier))
        .to.emit(vendingMachine, "PurchaseInitiated")
        .withArgs(user1.address, tier, 1, price);

      // Check treasury received USDC
      expect(await usdc.balanceOf(treasury.address)).to.equal(price);

      // Check user purchase count
      expect(await vendingMachine.getUserPurchaseCount(user1.address)).to.equal(1);
    });

    it("Should revert if tier is invalid", async function () {
      const { vendingMachine, user1 } = await loadFixture(deployVendingMachineFixture);

      await expect(vendingMachine.connect(user1).purchase(0)).to.be.revertedWithCustomError(
        vendingMachine,
        "InvalidTier"
      );

      await expect(vendingMachine.connect(user1).purchase(4)).to.be.revertedWithCustomError(
        vendingMachine,
        "InvalidTier"
      );
    });

    it("Should revert if insufficient USDC approved", async function () {
      const { vendingMachine, usdc, user1 } = await loadFixture(
        deployVendingMachineFixture
      );

      const tier = 1;
      const insufficientAmount = ethers.parseUnits("10", 6);

      await usdc.connect(user1).approve(await vendingMachine.getAddress(), insufficientAmount);

      await expect(vendingMachine.connect(user1).purchase(tier)).to.be.reverted;
    });

    it("Should handle multiple purchases from same user", async function () {
      const { vendingMachine, usdc, user1 } = await loadFixture(
        deployVendingMachineFixture
      );

      const price = ethers.parseUnits("20", 6);
      await usdc.connect(user1).approve(await vendingMachine.getAddress(), price * 3n);

      await vendingMachine.connect(user1).purchase(1);
      await vendingMachine.connect(user1).purchase(1);
      await vendingMachine.connect(user1).purchase(1);

      expect(await vendingMachine.getUserPurchaseCount(user1.address)).to.equal(3);
    });
  });

  describe("Randomness Fulfillment", function () {
    it("Should fulfill randomness and emit WalletReady", async function () {
      const { vendingMachine, usdc, randomnessProvider, user1 } = await loadFixture(
        deployVendingMachineFixture
      );

      const price = ethers.parseUnits("20", 6);
      await usdc.connect(user1).approve(await vendingMachine.getAddress(), price);

      // Purchase
      const tx = await vendingMachine.connect(user1).purchase(1);
      const receipt = await tx.wait();

      // Get requestId from event
      const event = receipt.logs.find((log) => {
        try {
          return vendingMachine.interface.parseLog(log).name === "PurchaseInitiated";
        } catch {
          return false;
        }
      });
      const requestId = vendingMachine.interface.parseLog(event).args.requestId;

      // Fulfill randomness
      const randomWords = [12345n, 67890n, 11111n, 22222n, 33333n];
      await expect(
        randomnessProvider.fulfillRequest(await vendingMachine.getAddress(), requestId, randomWords)
      )
        .to.emit(vendingMachine, "WalletReady")
        .withArgs(requestId, user1.address, 1, ethers.parseUnits("16", 6));

      // Check purchase is fulfilled
      const purchase = await vendingMachine.getPurchase(requestId);
      expect(purchase.fulfilled).to.be.true;
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to update tier parameters", async function () {
      const { vendingMachine, owner } = await loadFixture(deployVendingMachineFixture);

      const newPrice = ethers.parseUnits("25", 6);
      const newMin = ethers.parseUnits("10", 6);
      const newMax = ethers.parseUnits("35", 6);

      await expect(
        vendingMachine.connect(owner).setTierParameters(1, newPrice, newMin, newMax, true)
      )
        .to.emit(vendingMachine, "TierUpdated")
        .withArgs(1, newPrice, newMin, newMax, true);

      const tier = await vendingMachine.getTier(1);
      expect(tier.price).to.equal(newPrice);
      expect(tier.minValue).to.equal(newMin);
      expect(tier.maxValue).to.equal(newMax);
    });

    it("Should allow owner to pause and unpause", async function () {
      const { vendingMachine, usdc, owner, user1 } = await loadFixture(
        deployVendingMachineFixture
      );

      await vendingMachine.connect(owner).pause();

      const price = ethers.parseUnits("20", 6);
      await usdc.connect(user1).approve(await vendingMachine.getAddress(), price);

      await expect(vendingMachine.connect(user1).purchase(1)).to.be.revertedWith(
        "Pausable: paused"
      );

      await vendingMachine.connect(owner).unpause();
      await expect(vendingMachine.connect(user1).purchase(1)).to.not.be.reverted;
    });

    it("Should allow owner to update treasury", async function () {
      const { vendingMachine, owner, user2 } = await loadFixture(
        deployVendingMachineFixture
      );

      await expect(vendingMachine.connect(owner).setTreasury(user2.address))
        .to.emit(vendingMachine, "TreasuryUpdated");

      expect(await vendingMachine.treasury()).to.equal(user2.address);
    });

    it("Should not allow non-owner to call admin functions", async function () {
      const { vendingMachine, user1, user2 } = await loadFixture(
        deployVendingMachineFixture
      );

      await expect(
        vendingMachine
          .connect(user1)
          .setTierParameters(1, 100, 10, 50, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(vendingMachine.connect(user1).setTreasury(user2.address)).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );

      await expect(vendingMachine.connect(user1).pause()).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
    });
  });

  describe("Edge Cases", function () {
    it("Should handle tier deactivation", async function () {
      const { vendingMachine, usdc, owner, user1 } = await loadFixture(
        deployVendingMachineFixture
      );

      // Deactivate tier 1
      await vendingMachine.connect(owner).setTierParameters(
        1,
        ethers.parseUnits("20", 6),
        ethers.parseUnits("5", 6),
        ethers.parseUnits("30", 6),
        false
      );

      const price = ethers.parseUnits("20", 6);
      await usdc.connect(user1).approve(await vendingMachine.getAddress(), price);

      await expect(vendingMachine.connect(user1).purchase(1)).to.be.revertedWithCustomError(
        vendingMachine,
        "TierNotActive"
      );
    });

    it("Should track total revenue correctly", async function () {
      const { vendingMachine, usdc, user1, user2 } = await loadFixture(
        deployVendingMachineFixture
      );

      const price1 = ethers.parseUnits("20", 6);
      const price2 = ethers.parseUnits("50", 6);

      await usdc.connect(user1).approve(await vendingMachine.getAddress(), price1);
      await usdc.connect(user2).approve(await vendingMachine.getAddress(), price2);

      await vendingMachine.connect(user1).purchase(1);
      await vendingMachine.connect(user2).purchase(2);

      expect(await vendingMachine.totalRevenue()).to.equal(price1 + price2);
      expect(await vendingMachine.totalPurchases()).to.equal(2);
    });
  });
});
