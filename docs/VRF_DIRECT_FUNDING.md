# Chainlink VRF 2.5 Direct Funding Guide

## Overview

The RandomnessProvider contract now uses **Chainlink VRF 2.5 with Direct Funding**. This method is simpler than the subscription model:

- ✅ No subscription management needed
- ✅ Pay per request in native token (ETH)
- ✅ No LINK token required
- ✅ Simpler setup process

## Key Differences from VRF 2.0

| Feature | VRF 2.0 (Subscription) | VRF 2.5 (Direct Funding) |
|---------|----------------------|--------------------------|
| Payment Method | LINK token subscription | Native token (ETH) per request |
| Setup Complexity | Create subscription, add consumers, fund with LINK | Deploy contract, fund with ETH |
| Management | Manage subscription balance | Monitor contract ETH balance |
| Refunds | Unused LINK can be withdrawn from subscription | Unused ETH stays in contract |

## Network Configurations

### Ethereum Sepolia Testnet

```bash
VRF_COORDINATOR=0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
KEY_HASH=0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae # 500 gwei
```

### Ethereum Mainnet

```bash
VRF_COORDINATOR=0xD7f86b4b8Cae7D942340FF628F82735b7a20893a
KEY_HASH=0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9 # 500 gwei
```

### Other Networks

See [Chainlink VRF 2.5 Supported Networks](https://docs.chain.link/vrf/v2-5/supported-networks)

## Deployment Steps

### 1. Set Environment Variables

```bash
# .env file
CHAINLINK_VRF_COORDINATOR=0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
CHAINLINK_KEY_HASH=0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae
INITIAL_VRF_FUNDING=0.5  # ETH to fund contract with
```

### 2. Deploy Contracts

```bash
cd contracts
npm run deploy:sepolia
```

The deployment script will:
1. Deploy RandomnessProvider
2. Automatically fund it with ETH (default 0.5 ETH)
3. Deploy other contracts
4. Authorize VendingMachine and RaffleManager

### 3. Monitor ETH Balance

Check the contract's ETH balance:

```bash
# Using ethers.js
const provider = new ethers.JsonRpcProvider(RPC_URL);
const balance = await provider.getBalance(RANDOMNESS_PROVIDER_ADDRESS);
console.log("Balance:", ethers.formatEther(balance), "ETH");
```

Or call the contract directly:

```solidity
uint256 balance = randomnessProvider.getNativeBalance();
```

### 4. Top Up When Needed

Send more ETH to the RandomnessProvider contract:

```bash
# Using cast (Foundry)
cast send $RANDOMNESS_PROVIDER_ADDRESS --value 0.5ether

# Or using ethers.js
await signer.sendTransaction({
  to: randomnessProviderAddress,
  value: ethers.parseEther("0.5")
});
```

Or use the contract's deposit function:

```solidity
randomnessProvider.depositNativeFunds{value: 0.5 ether}();
```

## Cost Estimation

### Per Request Cost

**Sepolia Testnet:**
- Base fee: ~0.001 ETH
- Callback gas: ~200,000 gas
- At 50 gwei: ~0.01 ETH per request
- **Total: ~0.011 ETH per request**

**Ethereum Mainnet:**
- Varies with gas prices
- At 30 gwei: ~0.006 ETH per request
- At 100 gwei: ~0.02 ETH per request

### Funding Recommendations

| Usage Level | Testnet | Mainnet |
|-------------|---------|---------|
| Light (10-50 requests/day) | 0.5 ETH | 1-2 ETH |
| Medium (50-200 requests/day) | 1 ETH | 5-10 ETH |
| Heavy (200+ requests/day) | 2+ ETH | 20+ ETH |

## Contract Functions

### User Functions (Authorized Contracts Only)

```solidity
// Request random words
function requestRandomWords(uint32 numWords) external returns (uint256 requestId)
```

### Admin Functions

```solidity
// Deposit ETH for VRF payments
function depositNativeFunds() external payable

// Withdraw unused ETH (owner only)
function withdrawNativeFunds(uint256 amount) external onlyOwner

// Check balance
function getNativeBalance() external view returns (uint256)

// Update VRF configuration
function updateConfig(
    bytes32 _keyHash,
    uint32 _callbackGasLimit,
    uint16 _requestConfirmations
) external onlyOwner

// Authorize contracts
function authorizeContract(address contractAddress) external onlyOwner
function revokeContract(address contractAddress) external onlyOwner
```

## Monitoring & Maintenance

### Set Up Balance Alerts

Monitor the RandomnessProvider ETH balance and alert when low:

```javascript
const WARNING_THRESHOLD = ethers.parseEther("0.1"); // 0.1 ETH
const CRITICAL_THRESHOLD = ethers.parseEther("0.05"); // 0.05 ETH

async function checkBalance() {
  const balance = await randomnessProvider.getNativeBalance();
  
  if (balance < CRITICAL_THRESHOLD) {
    console.error("🚨 CRITICAL: VRF balance very low!");
    // Send alert
  } else if (balance < WARNING_THRESHOLD) {
    console.warn("⚠️  WARNING: VRF balance running low");
    // Send notification
  }
}

// Run every hour
setInterval(checkBalance, 3600000);
```

### Auto-Refill Script

Automatically top up when balance is low:

```javascript
async function autoRefill() {
  const balance = await randomnessProvider.getNativeBalance();
  const threshold = ethers.parseEther("0.1");
  const refillAmount = ethers.parseEther("0.5");
  
  if (balance < threshold) {
    console.log("Balance low, refilling...");
    const tx = await signer.sendTransaction({
      to: randomnessProviderAddress,
      value: refillAmount
    });
    await tx.wait();
    console.log("✅ Refilled with", ethers.formatEther(refillAmount), "ETH");
  }
}
```

## Troubleshooting

### Request Fails with "Insufficient Balance"

**Problem**: RandomnessProvider doesn't have enough ETH to pay for VRF request.

**Solution**: 
```bash
# Send ETH to the contract
cast send $RANDOMNESS_PROVIDER_ADDRESS --value 0.5ether
```

### Callback Gas Limit Too Low

**Problem**: VRF callback runs out of gas.

**Solution**: Increase callback gas limit:
```solidity
randomnessProvider.updateConfig(
    keyHash,
    750000, // Increased from 500000
    3
);
```

### Wrong VRF Coordinator Address

**Problem**: Requests aren't being fulfilled.

**Solution**: Verify you're using the correct coordinator for your network. See [Chainlink docs](https://docs.chain.link/vrf/v2-5/supported-networks).

## Gas Lane Selection

Different key hashes = different gas prices = different speeds:

| Gas Lane | Speed | Key Hash (Sepolia) |
|----------|-------|-------------------|
| 500 gwei | Fast | 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae |
| 150 gwei | Medium | 0x3fd2fec10d06ee8f65e7f2e95e5e3f2e88d8ab6f9d7e8c5b4a3d2e1f0c9b8a7d6 |
| 50 gwei | Slow | 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c |

Choose based on your needs:
- **Vending Machine**: Fast (users waiting)
- **Raffle**: Medium (less urgent)
- **Sponsor Auction**: Slow (end of 30-day period)

## Migration from VRF 2.0

If you were using VRF 2.0 with subscriptions:

1. **Deploy new RandomnessProvider** with VRF 2.5
2. **Withdraw LINK** from old subscription
3. **Fund new contract** with ETH
4. **Update contract addresses** in VendingMachine and RaffleManager
5. **Authorize contracts** in new RandomnessProvider
6. **Test thoroughly** before switching

## Benefits of Direct Funding

✅ **Simpler**: No subscription management  
✅ **Flexible**: Pay as you go  
✅ **Transparent**: ETH balance = available funds  
✅ **No LINK**: Use native token  
✅ **Better UX**: Fewer steps for deployment

## Additional Resources

- [Chainlink VRF 2.5 Docs](https://docs.chain.link/vrf/v2-5/overview)
- [Direct Funding Guide](https://docs.chain.link/vrf/v2-5/overview/direct-funding)
- [Supported Networks](https://docs.chain.link/vrf/v2-5/supported-networks)
- [Best Practices](https://docs.chain.link/vrf/v2-5/best-practices)
