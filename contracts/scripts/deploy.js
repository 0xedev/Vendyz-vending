const hre = require("hardhat");

async function main() {
  console.log("Starting deployment...");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  // Contract addresses (update these for your network)
  const USDC_ADDRESS = process.env.USDC_ADDRESS || "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // Mainnet USDC
  const TREASURY_ADDRESS = process.env.TREASURY_ADDRESS || deployer.address;
  const VRF_WRAPPER = process.env.CHAINLINK_VRF_WRAPPER || "0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1"; // Sepolia VRF 2.5 Wrapper
  const INITIAL_VRF_FUNDING = process.env.INITIAL_VRF_FUNDING || hre.ethers.parseEther("0.5"); // 0.5 ETH for VRF

  console.log("\nDeployment Configuration:");
  console.log("- USDC Address:", USDC_ADDRESS);
  console.log("- Treasury Address:", TREASURY_ADDRESS);
  console.log("- VRF Wrapper:", VRF_WRAPPER);
  console.log("- Initial VRF Funding:", hre.ethers.formatEther(INITIAL_VRF_FUNDING), "ETH");

  // Deploy RandomnessProvider with direct funding
  console.log("\n1. Deploying RandomnessProvider (VRF 2.5 Direct Funding)...");
  const RandomnessProvider = await hre.ethers.getContractFactory("RandomnessProvider");
  const randomnessProvider = await RandomnessProvider.deploy(
    VRF_WRAPPER
  );
  await randomnessProvider.waitForDeployment();
  const randomnessProviderAddress = await randomnessProvider.getAddress();
  console.log("✅ RandomnessProvider deployed to:", randomnessProviderAddress);

  // Fund RandomnessProvider with ETH for VRF requests
  console.log("\n2. Funding RandomnessProvider with ETH for VRF requests...");
  const fundTx = await deployer.sendTransaction({
    to: randomnessProviderAddress,
    value: INITIAL_VRF_FUNDING
  });
  await fundTx.wait();
  console.log("✅ Funded with", hre.ethers.formatEther(INITIAL_VRF_FUNDING), "ETH");

  // Deploy VendingMachine
  console.log("\n2. Deploying VendingMachine...");
  const VendingMachine = await hre.ethers.getContractFactory("VendingMachine");
  const vendingMachine = await VendingMachine.deploy(
    USDC_ADDRESS,
    randomnessProviderAddress,
    TREASURY_ADDRESS
  );
  await vendingMachine.waitForDeployment();
  const vendingMachineAddress = await vendingMachine.getAddress();
  console.log("✅ VendingMachine deployed to:", vendingMachineAddress);

  // Deploy RaffleManager
  console.log("\n3. Deploying RaffleManager...");
  const RaffleManager = await hre.ethers.getContractFactory("RaffleManager");
  const raffleManager = await RaffleManager.deploy(
    USDC_ADDRESS,
    randomnessProviderAddress,
    TREASURY_ADDRESS
  );
  await raffleManager.waitForDeployment();
  const raffleManagerAddress = await raffleManager.getAddress();
  console.log("✅ RaffleManager deployed to:", raffleManagerAddress);

  // Deploy SponsorAuction
  console.log("\n4. Deploying SponsorAuction...");
  const SponsorAuction = await hre.ethers.getContractFactory("SponsorAuction");
  const sponsorAuction = await SponsorAuction.deploy(
    USDC_ADDRESS,
    TREASURY_ADDRESS
  );
  await sponsorAuction.waitForDeployment();
  const sponsorAuctionAddress = await sponsorAuction.getAddress();
  console.log("✅ SponsorAuction deployed to:", sponsorAuctionAddress);

  // Authorize contracts in RandomnessProvider
  console.log("\n6. Authorizing contracts in RandomnessProvider...");
  await randomnessProvider.authorizeContract(vendingMachineAddress);
  console.log("✅ VendingMachine authorized");
  
  await randomnessProvider.authorizeContract(raffleManagerAddress);
  console.log("✅ RaffleManager authorized");

  // Check VRF balance
  const vrfBalance = await hre.ethers.provider.getBalance(randomnessProviderAddress);
  console.log("\n7. RandomnessProvider ETH balance:", hre.ethers.formatEther(vrfBalance), "ETH");

  // Display deployment summary
  console.log("\n" + "=".repeat(60));
  console.log("DEPLOYMENT SUMMARY");
  console.log("=".repeat(60));
  console.log("\nContract Addresses:");
  console.log("-------------------");
  console.log("RandomnessProvider:", randomnessProviderAddress);
  console.log("VendingMachine:    ", vendingMachineAddress);
  console.log("RaffleManager:     ", raffleManagerAddress);
  console.log("SponsorAuction:    ", sponsorAuctionAddress);

  console.log("\nConfiguration:");
  console.log("-------------------");
  console.log("USDC:              ", USDC_ADDRESS);
  console.log("Treasury:          ", TREASURY_ADDRESS);
  console.log("VRF Coordinator:   ", VRF_COORDINATOR);
  console.log("VRF Funding:       ", hre.ethers.formatEther(vrfBalance), "ETH");

  console.log("\nNext Steps:");
  console.log("-------------------");
  console.log("1. Verify contracts on Etherscan (run verify script)");
  console.log("2. Monitor RandomnessProvider ETH balance for VRF payments");
  console.log("3. Top up RandomnessProvider with more ETH as needed");
  console.log("4. Update frontend environment variables with contract addresses");
  console.log("5. Test contracts on testnet before mainnet deployment");
  console.log("\nNote: VRF 2.5 uses direct funding - no subscription needed!");

  // Save deployment addresses
  const fs = require("fs");
  const deploymentInfo = {
    network: hre.network.name,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      RandomnessProvider: randomnessProviderAddress,
      VendingMachine: vendingMachineAddress,
      RaffleManager: raffleManagerAddress,
      SponsorAuction: sponsorAuctionAddress,
    },
    config: {
      usdc: USDC_ADDRESS,
      treasury: TREASURY_ADDRESS,
      vrfCoordinator: VRF_COORDINATOR,
      keyHash: KEY_HASH,
      initialVrfFunding: INITIAL_VRF_FUNDING.toString(),
    },
  };

  const deploymentPath = `./deployments/${hre.network.name}.json`;
  fs.mkdirSync("./deployments", { recursive: true });
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\n✅ Deployment info saved to ${deploymentPath}`);

  console.log("\n" + "=".repeat(60));
  console.log("Deployment completed successfully! 🎉");
  console.log("=".repeat(60) + "\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
