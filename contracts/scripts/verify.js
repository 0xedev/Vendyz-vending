const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const network = hre.network.name;
  console.log(`Verifying contracts on ${network}...`);

  // Load deployment info
  const deploymentPath = `./deployments/${network}.json`;
  if (!fs.existsSync(deploymentPath)) {
    console.error(`Deployment file not found: ${deploymentPath}`);
    console.error("Please deploy contracts first.");
    process.exit(1);
  }

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
  const { contracts, config } = deployment;

  console.log("\nVerifying contracts...\n");

  // Verify RandomnessProvider
  console.log("1. Verifying RandomnessProvider...");
  try {
    await hre.run("verify:verify", {
      address: contracts.RandomnessProvider,
      constructorArguments: [
        config.vrfCoordinator,
        config.subscriptionId,
        process.env.CHAINLINK_KEY_HASH,
      ],
    });
    console.log("✅ RandomnessProvider verified");
  } catch (error) {
    console.log("⚠️  RandomnessProvider verification failed:", error.message);
  }

  // Verify VendingMachine
  console.log("\n2. Verifying VendingMachine...");
  try {
    await hre.run("verify:verify", {
      address: contracts.VendingMachine,
      constructorArguments: [
        config.usdc,
        contracts.RandomnessProvider,
        config.treasury,
      ],
    });
    console.log("✅ VendingMachine verified");
  } catch (error) {
    console.log("⚠️  VendingMachine verification failed:", error.message);
  }

  // Verify RaffleManager
  console.log("\n3. Verifying RaffleManager...");
  try {
    await hre.run("verify:verify", {
      address: contracts.RaffleManager,
      constructorArguments: [
        config.usdc,
        contracts.RandomnessProvider,
        config.treasury,
      ],
    });
    console.log("✅ RaffleManager verified");
  } catch (error) {
    console.log("⚠️  RaffleManager verification failed:", error.message);
  }

  // Verify SponsorAuction
  console.log("\n4. Verifying SponsorAuction...");
  try {
    await hre.run("verify:verify", {
      address: contracts.SponsorAuction,
      constructorArguments: [config.usdc, config.treasury],
    });
    console.log("✅ SponsorAuction verified");
  } catch (error) {
    console.log("⚠️  SponsorAuction verification failed:", error.message);
  }

  console.log("\n" + "=".repeat(60));
  console.log("Verification completed! 🎉");
  console.log("=".repeat(60) + "\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
