# Smart Contracts Documentation

## Overview

The Hammy Vending Machine platform consists of four main smart contracts:

1. **VendingMachine.sol** - Core vending machine functionality
2. **RaffleManager.sol** - Raffle ticket sales and winner selection
3. **SponsorAuction.sol** - 30-day recurring sponsor auctions
4. **RandomnessProvider.sol** - Chainlink VRF integration

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                        │
└──────────────────┬──────────────────┬───────────────────┘
                   │                  │
         ┌─────────▼─────────┐  ┌────▼──────────────┐
         │  VendingMachine   │  │  RaffleManager    │
         └─────────┬─────────┘  └────┬──────────────┘
                   │                  │
                   │    ┌────────────┐│
                   └────►  Randomness ◄┘
                        │  Provider  │
                        └────────────┘
         ┌──────────────────────────┐
         │   SponsorAuction         │
         └──────────────────────────┘
```

## Contract Details

### 1. VendingMachine.sol

**Purpose**: Main contract for purchasing pre-funded anonymous wallets.

#### Key Features
- 3 tiers: 20, 50, 100 USDC
- Configurable value ranges per tier
- Chainlink VRF for randomness
- Pausable for emergencies
- Owner-controlled parameters

#### Main Functions

```solidity
// User functions
function purchase(uint8 tier) external nonReentrant whenNotPaused returns (uint256 requestId)

// View functions
function getTier(uint8 tier) external view returns (Tier memory)
function getPurchase(uint256 requestId) external view returns (Purchase memory)
function getUserPurchaseCount(address user) external view returns (uint256)

// Admin functions
function setTierParameters(uint8 tier, uint256 price, uint256 minValue, uint256 maxValue, bool active) external onlyOwner
function setTreasury(address newTreasury) external onlyOwner
function pause() external onlyOwner
function unpause() external onlyOwner
```

#### Events

```solidity
event PurchaseInitiated(address indexed buyer, uint8 indexed tier, uint256 requestId, uint256 price)
event WalletReady(uint256 indexed requestId, address indexed buyer, uint8 tier, uint256 estimatedValue)
event TierUpdated(uint8 indexed tier, uint256 price, uint256 minValue, uint256 maxValue, bool active)
```

#### Default Tiers

| Tier | Price | Min Value | Max Value |
|------|-------|-----------|-----------|
| 1    | 20 USDC | 5 USDC  | 30 USDC   |
| 2    | 50 USDC | 5 USDC  | 75 USDC   |
| 3    | 100 USDC | 10 USDC | 150 USDC  |

---

### 2. RaffleManager.sol

**Purpose**: Community-driven lottery system with ticket sales.

#### Key Features
- 1 USDC per ticket
- Max 5 tickets per wallet
- 90% prize pool (10% + 10 USDC house fee)
- Automatic winner selection when filled
- Continuous raffle cycle

#### Main Functions

```solidity
// User functions
function buyTickets(uint256 amount) external nonReentrant whenNotPaused returns (uint256[] memory ticketNumbers)

// View functions
function getCurrentRaffle() external view returns (Raffle memory)
function getUserTickets(address user) external view returns (uint256[] memory)
function getRaffle(uint256 raffleId) external view returns (Raffle memory)

// Admin functions
function setDefaultMaxTickets(uint256 _maxTickets) external onlyOwner
function setTreasury(address newTreasury) external onlyOwner
```

#### Events

```solidity
event RaffleStarted(uint256 indexed raffleId, uint256 maxTickets, uint256 ticketPrice)
event TicketsPurchased(uint256 indexed raffleId, address indexed buyer, uint256 amount, uint256[] ticketNumbers)
event RaffleFilled(uint256 indexed raffleId, uint256 totalTickets)
event WinnerSelected(uint256 indexed raffleId, address indexed winner, uint256 winningTicket, uint256 prizePool)
```

#### Raffle Economics

**100-ticket raffle example:**
- Tickets sold: 100 × 1 USDC = 100 USDC
- House fee: 10 USDC (10%)
- Flat fee: 10 USDC
- Winner receives: 80 USDC worth of assets

---

### 3. SponsorAuction.sol

**Purpose**: Recurring 30-day auctions for token placement in wallets.

#### Key Features
- 30-day auction cycles
- 5 sponsor slots per cycle
- 100 USDC minimum bid
- Auto-refund for losers
- Active sponsor tracking

#### Main Functions

```solidity
// User functions
function placeBid(address tokenAddress, uint256 bidAmount) external nonReentrant whenNotPaused
function finalizeAuction() external nonReentrant

// View functions
function getCurrentAuction() external view returns (Auction memory)
function getCurrentBids() external view returns (Bid[] memory)
function getActiveSponsors() external view returns (address[] memory)
function isTokenSponsored(address tokenAddress) external view returns (bool)
function getTimeRemaining() external view returns (uint256)

// Admin functions
function addManualSponsor(address tokenAddress, uint256 duration) external onlyOwner
function removeSponsor(address tokenAddress) external onlyOwner
```

#### Events

```solidity
event AuctionStarted(uint256 indexed auctionId, uint256 startTime, uint256 endTime)
event BidPlaced(uint256 indexed auctionId, address indexed bidder, address indexed tokenAddress, uint256 amount)
event BidUpdated(uint256 indexed auctionId, address indexed bidder, uint256 oldAmount, uint256 newAmount)
event AuctionFinalized(uint256 indexed auctionId, address[] winners, uint256[] winningBids)
event SponsorAdded(address indexed tokenAddress, uint256 endTime)
```

#### Auction Process

1. Auction starts automatically (30-day duration)
2. Projects place bids (min 100 USDC)
3. Can update bid by adding more USDC
4. After 30 days, anyone can call `finalizeAuction()`
5. Top 5 bidders become sponsors
6. Losers receive automatic refunds
7. New auction starts immediately

---

### 4. RandomnessProvider.sol

**Purpose**: Chainlink VRF integration for provably fair randomness.

#### Key Features
- VRF v2 integration
- Multiple consumer support
- Configurable gas limits
- Authorization system

#### Main Functions

```solidity
// Authorized contract functions
function requestRandomWords(uint32 numWords) external returns (uint256 requestId)

// View functions
function getRequestStatus(uint256 requestId) external view returns (address requester)
function isAuthorized(address contractAddress) external view returns (bool)

// Admin functions
function authorizeContract(address contractAddress) external onlyOwner
function revokeContract(address contractAddress) external onlyOwner
function updateConfig(uint64 _subscriptionId, bytes32 _keyHash, uint32 _callbackGasLimit, uint16 _requestConfirmations) external onlyOwner
```

#### Events

```solidity
event RandomnessRequested(uint256 indexed requestId, address indexed requester, uint32 numWords)
event RandomnessFulfilled(uint256 indexed requestId, uint256[] randomWords)
event ContractAuthorized(address indexed contractAddress)
event ContractRevoked(address indexed contractAddress)
```

---

## Deployment Guide

### Prerequisites

1. **Chainlink VRF Subscription**
   - Create subscription at [vrf.chain.link](https://vrf.chain.link)
   - Fund with LINK tokens
   - Note subscription ID

2. **USDC Contract Address**
   - Mainnet: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
   - Sepolia: Deploy mock or use existing testnet USDC

3. **Treasury Wallet**
   - Multi-sig recommended for mainnet
   - Regular wallet acceptable for testnet

### Deployment Steps

```bash
# 1. Install dependencies
cd contracts
npm install

# 2. Set up environment variables
cp ../.env.example .env
# Edit .env with your values

# 3. Compile contracts
npm run compile

# 4. Run tests
npm run test

# 5. Deploy to testnet
npm run deploy:sepolia

# 6. Verify contracts
npm run verify:sepolia

# 7. Configure RandomnessProvider
# - Add as consumer in Chainlink VRF subscription
# - Fund subscription with LINK

# 8. Test on testnet
# - Use frontend or scripts to test purchases
# - Verify randomness fulfillment
# - Check all flows

# 9. Deploy to mainnet (after audit)
npm run deploy:mainnet
npm run verify:mainnet
```

### Post-Deployment Checklist

- [ ] RandomnessProvider added as VRF consumer
- [ ] VRF subscription funded with LINK
- [ ] VendingMachine authorized in RandomnessProvider
- [ ] RaffleManager authorized in RandomnessProvider
- [ ] Test purchase on each tier
- [ ] Test raffle ticket purchase
- [ ] Test sponsor auction bid
- [ ] Verify all events emitted correctly
- [ ] Update frontend with contract addresses
- [ ] Monitor gas costs and optimize if needed

---

## Security Considerations

### Access Control

- **Owner**: Can update parameters, pause contracts, emergency withdraw
- **Treasury**: Receives all revenue
- **Authorized Contracts**: Can request randomness

### Safety Features

1. **ReentrancyGuard**: Prevents reentrancy attacks
2. **Pausable**: Emergency stop functionality
3. **Input Validation**: All parameters validated
4. **Safe Math**: Solidity 0.8+ overflow protection

### Best Practices

- Multi-sig for owner on mainnet
- Time-locks for parameter changes
- Regular security audits
- Bug bounty program
- Monitor for unusual activity

---

## Gas Optimization

### Estimated Gas Costs (Ethereum Mainnet)

| Operation | Gas | Cost @ 50 gwei |
|-----------|-----|----------------|
| Purchase Tier 1 | ~120,000 | ~$6 |
| Buy Raffle Tickets | ~80,000 | ~$4 |
| Place Sponsor Bid | ~100,000 | ~$5 |
| VRF Callback | ~200,000 | ~$10 |

### Optimization Tips

1. Use L2 networks (Polygon, Arbitrum, Base) for lower fees
2. Batch operations when possible
3. Optimize storage layout
4. Use events instead of storage where appropriate

---

## Testing

### Run Tests

```bash
# All tests
npm test

# With coverage
npm run test:coverage

# Specific test file
npx hardhat test test/VendingMachine.test.js

# With gas reporting
REPORT_GAS=true npm test
```

### Test Coverage Goals

- **Unit Tests**: 100% function coverage
- **Integration Tests**: End-to-end flows
- **Edge Cases**: Boundary conditions
- **Failure Cases**: Reverts and errors

---

## Upgradeability

Contracts are **not upgradeable** by design for:
- Transparency
- Immutability
- Trust

To update:
1. Deploy new contract versions
2. Migrate liquidity/state
3. Update frontend
4. Announce deprecation timeline

---

## Support

For contract-related questions:
- GitHub Issues: [repository link]
- Discord: #dev-support
- Email: dev@hammy.vending
