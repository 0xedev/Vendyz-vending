# Smart Contract Deployment README

## Quick Start

```bash
# Install dependencies
npm install

# Compile contracts
npm run compile

# Run tests
npm run test

# Deploy to testnet
npm run deploy:sepolia

# Verify on Etherscan
npm run verify:sepolia
```

## Environment Setup

Create a `.env` file in the contracts directory:

```bash
# Blockchain
PRIVATE_KEY=your_deployer_private_key
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY

# Chainlink VRF (Sepolia)
CHAINLINK_VRF_COORDINATOR=0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
CHAINLINK_SUBSCRIPTION_ID=your_subscription_id
CHAINLINK_KEY_HASH=0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c

# Contract Addresses
USDC_ADDRESS=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
TREASURY_ADDRESS=your_treasury_address

# Etherscan
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Deployment Process

### 1. Testnet Deployment (Sepolia)

```bash
# Deploy all contracts
npm run deploy:sepolia

# This will deploy:
# - RandomnessProvider
# - VendingMachine
# - RaffleManager  
# - SponsorAuction
```

### 2. Post-Deployment Configuration

After deployment, you need to:

1. **Add RandomnessProvider as VRF Consumer**
   - Go to [vrf.chain.link](https://vrf.chain.link)
   - Select your subscription
   - Click "Add Consumer"
   - Enter RandomnessProvider address

2. **Fund VRF Subscription**
   - Ensure subscription has enough LINK tokens
   - Recommended: 10+ LINK for testing

3. **Verify Contracts**
   ```bash
   npm run verify:sepolia
   ```

### 3. Testing on Testnet

Use the test scripts or frontend to:
- Purchase a vending machine tier
- Buy raffle tickets
- Place sponsor auction bids
- Verify randomness fulfillment

### 4. Mainnet Deployment

**⚠️ CRITICAL: Complete security audit before mainnet deployment**

```bash
# Deploy to mainnet
npm run deploy:mainnet

# Verify contracts
npm run verify:mainnet
```

## Contract Addresses

After deployment, contract addresses are saved to `deployments/{network}.json`

Example structure:
```json
{
  "network": "sepolia",
  "timestamp": "2024-01-15T10:30:00Z",
  "deployer": "0x...",
  "contracts": {
    "RandomnessProvider": "0x...",
    "VendingMachine": "0x...",
    "RaffleManager": "0x...",
    "SponsorAuction": "0x..."
  }
}
```

## Testing

```bash
# Run all tests
npm test

# Run with gas reporting
REPORT_GAS=true npm test

# Run with coverage
npm run test:coverage

# Run specific test
npx hardhat test test/VendingMachine.test.js
```

## Troubleshooting

### VRF Fulfillment Fails

**Symptom**: Randomness not fulfilled, purchases stuck

**Solutions**:
1. Check VRF subscription has LINK tokens
2. Verify RandomnessProvider is added as consumer
3. Check callback gas limit is sufficient (default: 500,000)
4. Review Chainlink VRF job status

### Insufficient Gas

**Symptom**: Transactions fail with out-of-gas error

**Solutions**:
1. Increase gas limit in transaction
2. Check gas price is competitive
3. Consider deploying on L2 for lower costs

### USDC Transfer Fails

**Symptom**: Purchase reverts with "Transfer failed"

**Solutions**:
1. Ensure user has enough USDC balance
2. Verify USDC approval is sufficient
3. Check USDC contract address is correct

## Network Information

### Sepolia Testnet

- **Chain ID**: 11155111
- **RPC**: https://sepolia.infura.io/v3/YOUR_KEY
- **VRF Coordinator**: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
- **Key Hash**: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
- **Block Explorer**: https://sepolia.etherscan.io

### Ethereum Mainnet

- **Chain ID**: 1
- **RPC**: https://mainnet.infura.io/v3/YOUR_KEY
- **USDC**: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
- **VRF Coordinator**: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909
- **Key Hash**: Varies by gas lane
- **Block Explorer**: https://etherscan.io

## Additional Resources

- [Chainlink VRF Docs](https://docs.chain.link/vrf/v2/introduction)
- [Hardhat Documentation](https://hardhat.org/docs)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Full Project Documentation](../docs/CONTRACTS.md)
