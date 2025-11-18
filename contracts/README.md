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
### Environment Variables

```bash
# Blockchain
PRIVATE_KEY=your_deployer_private_key
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
CHAINLINK_VRF_COORDINATOR=0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
CHAINLINK_KEY_HASH=0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae
INITIAL_VRF_FUNDING=0.5  # ETH to fund RandomnessProvider

# Backend
DATABASE_URL=postgresql://user:pass@localhost:5432/hammy
HOT_WALLET_PRIVATE_KEY=your_hot_wallet_key
ASSET_POOL_ADDRESS=0x...
```

## Deployment Process

### 1. Testnet Deployment (Sepolia)

```bash
# Deploy all contracts
npm run deploy:sepolia

# This will deploy:
# - RandomnessProvider (VRF 2.5 Direct Funding)
# - VendingMachine
# - RaffleManager  
# - SponsorAuction
```

**Note**: The deployment script automatically funds RandomnessProvider with 0.5 ETH for VRF requests.

### 2. Post-Deployment Configuration

After deployment, you need to:

1. **Verify Contracts**
   ```bash
   npm run verify:sepolia
   ```

2. **Monitor RandomnessProvider ETH Balance**
   - Check balance regularly
   - Top up when running low (< 0.1 ETH)
   - No LINK tokens or subscriptions needed!

3. **Top Up When Needed**
   ```bash
   # Send ETH directly to RandomnessProvider
   cast send $RANDOMNESS_PROVIDER_ADDRESS --value 0.5ether
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
1. Check RandomnessProvider has enough ETH balance
2. Top up with ETH: `cast send $ADDRESS --value 0.5ether`
3. Check callback gas limit is sufficient (default: 500,000)
4. Verify correct VRF Coordinator address for your network
5. Review Chainlink VRF job status

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
- **VRF Coordinator (2.5)**: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
- **Key Hash (500 gwei)**: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae
- **Block Explorer**: https://sepolia.etherscan.io

### Ethereum Mainnet

- **Chain ID**: 1
- **RPC**: https://mainnet.infura.io/v3/YOUR_KEY
- **USDC**: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
- **VRF Coordinator (2.5)**: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a
- **Key Hash (500 gwei)**: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9
- **Block Explorer**: https://etherscan.io

## Additional Resources

- [Chainlink VRF 2.5 Docs](https://docs.chain.link/vrf/v2-5/overview)
- [VRF Direct Funding Guide](../docs/VRF_DIRECT_FUNDING.md)
- [Hardhat Documentation](https://hardhat.org/docs)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Full Project Documentation](../docs/CONTRACTS.md)
