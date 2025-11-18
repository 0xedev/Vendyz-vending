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
  const VRF_COORDINATOR = process.env.CHAINLINK_VRF_COORDINATOR || "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625"; // Sepolia
  const SUBSCRIPTION_ID = process.env.CHAINLINK_SUBSCRIPTION_ID || 0;
  const KEY_HASH = process.env.CHAINLINK_KEY_HASH || "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c"; // Sepolia

  console.log("\nDeployment Configuration:");
  console.log("- USDC Address:", USDC_ADDRESS);
  console.log("- Treasury Address:", TREASURY_ADDRESS);
  console.log("- VRF Coordinator:", VRF_COORDINATOR);
  console.log("- Subscription ID:", SUBSCRIPTION_ID);

  // Deploy RandomnessProvider
  console.log("\n1. Deploying RandomnessProvider...");
  const RandomnessProvider = await hre.ethers.getContractFactory("RandomnessProvider");
  const randomnessProvider = await RandomnessProvider.deploy(
    VRF_COORDINATOR,
    SUBSCRIPTION_ID,
    KEY_HASH
  );
  await randomnessProvider.waitForDeployment();
  const randomnessProviderAddress = await randomnessProvider.getAddress();
  console.log("✅ RandomnessProvider deployed to:", randomnessProviderAddress);

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
  console.log("\n5. Authorizing contracts in RandomnessProvider...");
  await randomnessProvider.authorizeContract(vendingMachineAddress);
  console.log("✅ VendingMachine authorized");
  
  await randomnessProvider.authorizeContract(raffleManagerAddress);
  console.log("✅ RaffleManager authorized");

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

  console.log("\nNext Steps:");
  console.log("-------------------");
  console.log("1. Add RandomnessProvider as a consumer in Chainlink VRF subscription");
  console.log("2. Fund the VRF subscription with LINK tokens");
  console.log("3. Verify contracts on Etherscan (run verify script)");
  console.log("4. Update frontend environment variables with contract addresses");
  console.log("5. Test contracts on testnet before mainnet deployment");

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
      subscriptionId: SUBSCRIPTION_ID,
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
