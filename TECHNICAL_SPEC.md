# Technical Specification - Vendyz Vending Machine

## System Architecture

### Overview

```
┌─────────────────┐
│   Frontend UI   │
│  (React/Next.js)│
└────────┬────────┘
         │
┌────────┴────────┐
│   Web3 Layer    │
│  (wagmi/viem)   │
└────────┬────────┘
         │
┌────────┴────────────────────────────────┐
│          Smart Contracts                │
│  ┌──────────────────────────────────┐  │
│  │    VendingMachine.sol             │  │
│  │    RaffleManager.sol              │  │
│  │    SponsorAuction.sol             │  │
│  │    RandomnessProvider.sol         │  │
│  └──────────────────────────────────┘  │
└────────┬────────────────────────────────┘
         │
┌────────┴────────────────────────────────┐
│      Backend Services (Node.js)         │
│  ┌──────────────────────────────────┐  │
│  │  Wallet Generation Service        │  │
│  │  Asset Distribution Service       │  │
│  │  Prefunding Service               │  │
│  │  Event Listener Service           │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Smart Contracts

### 1. VendingMachine.sol

**Purpose**: Main contract handling vending machine purchases

**Key Functions**:

```solidity
// Purchase a vending machine tier
function purchase(uint8 tier) external payable
  - Tier 1: 20 USDC
  - Tier 2: 50 USDC
  - Tier 3: 100 USDC
  - Emits PurchaseEvent with request ID
  - Requests randomness from VRF

// Fulfill randomness and mark wallet ready
function fulfillRandomness(uint256 requestId, uint256[] randomWords)
  - Called by Chainlink VRF
  - Determines wallet contents
  - Emits WalletReadyEvent

// Owner functions
function setTierParameters(uint8 tier, uint256 price, uint256 minValue, uint256 maxValue)
function pauseVending() / unpauseVending()
function withdrawFees()
```

**State Variables**:

```solidity
struct Tier {
  uint256 price;
  uint256 minValue;
  uint256 maxValue;
  bool active;
}

struct Purchase {
  address buyer;
  uint8 tier;
  uint256 timestamp;
  bool fulfilled;
  uint256[] randomWords;
}

mapping(uint8 => Tier) public tiers;
mapping(uint256 => Purchase) public purchases; // requestId => Purchase
mapping(address => uint256) public userPurchaseCount;
```

**Events**:

```solidity
event PurchaseInitiated(address indexed buyer, uint8 tier, uint256 requestId);
event WalletReady(uint256 indexed requestId, address buyer, uint8 tier);
event TierUpdated(uint8 tier, uint256 price, uint256 minValue, uint256 maxValue);
```

### 2. RaffleManager.sol

**Purpose**: Manages raffle ticket sales and winner selection

**Key Functions**:

```solidity
// Buy raffle tickets (1-5 per wallet)
function buyTickets(uint256 amount) external
  - Check user hasn't exceeded 5 tickets
  - Transfer USDC
  - Assign ticket numbers
  - If raffle full, request randomness

// Fulfill winner selection
function fulfillRandomness(uint256 requestId, uint256 randomWord)
  - Select winner from ticket holders
  - Emit WinnerSelected event
  - Start new raffle

// View functions
function getCurrentRaffle() external view returns (RaffleInfo)
function getUserTickets(address user) external view returns (uint256[] memory)
function getRaffleHistory() external view returns (RaffleInfo[] memory)
```

**State Variables**:

```solidity
struct Raffle {
  uint256 raffleId;
  uint256 ticketPrice;
  uint256 maxTickets;
  uint256 ticketsSold;
  uint256 prizePool;
  address winner;
  bool completed;
  uint256 timestamp;
}

struct TicketHolder {
  address holder;
  uint256[] ticketNumbers;
}

uint256 public constant TICKET_PRICE = 1e6; // 1 USDC
uint256 public constant MAX_TICKETS_PER_USER = 5;
uint256 public constant HOUSE_FEE_PERCENT = 10;
uint256 public constant HOUSE_FLAT_FEE = 10e6; // 10 USDC

Raffle public currentRaffle;
mapping(uint256 => Raffle) public raffleHistory;
mapping(address => uint256) public userTicketCount;
address[] public ticketHolders;
```

**Events**:

```solidity
event TicketsPurchased(address indexed buyer, uint256 amount, uint256[] ticketNumbers);
event RaffleFilled(uint256 raffleId, uint256 totalTickets);
event WinnerSelected(uint256 indexed raffleId, address indexed winner, uint256 prizePool);
event NewRaffleStarted(uint256 raffleId);
```

### 3. SponsorAuction.sol

**Purpose**: 30-day recurring auctions for sponsored coin placements

**Key Functions**:

```solidity
// Place bid for sponsor placement
function placeBid(address tokenAddress, uint256 bidAmount) external
  - Check auction is active
  - Check bid is higher than current
  - Refund previous bidder
  - Store new bid
  - Emit BidPlaced event

// Finalize auction (called by owner/bot after 30 days)
function finalizeAuction() external
  - Check 30 days passed
  - Select winner(s)
  - Transfer winning bids to treasury
  - Start new auction
  - Emit AuctionFinalized event

// View current auction
function getCurrentAuction() external view returns (AuctionInfo)
function getActiveSponsors() external view returns (address[] memory)
```

**State Variables**:

```solidity
struct Auction {
  uint256 auctionId;
  uint256 startTime;
  uint256 endTime;
  uint256 availableSlots;
  address[] winners;
  bool finalized;
}

struct Bid {
  address bidder;
  address tokenAddress;
  uint256 amount;
  uint256 timestamp;
}

uint256 public constant AUCTION_DURATION = 30 days;
uint256 public constant SPONSOR_SLOTS = 5; // 5 sponsors per cycle

Auction public currentAuction;
mapping(uint256 => Auction) public auctionHistory;
Bid[] public currentBids;
address[] public activeSponsors;
```

**Events**:

```solidity
event BidPlaced(address indexed bidder, address indexed token, uint256 amount);
event BidRefunded(address indexed bidder, uint256 amount);
event AuctionFinalized(uint256 indexed auctionId, address[] winners);
event NewAuctionStarted(uint256 auctionId, uint256 startTime);
```

### 4. RandomnessProvider.sol

**Purpose**: Chainlink VRF integration for provable randomness

**Key Functions**:

```solidity
// Request random words
function requestRandomWords(uint32 numWords) external returns (uint256 requestId)
  - Only callable by vending machine or raffle contracts
  - Requests randomness from Chainlink VRF
  - Returns request ID

// Callback from Chainlink VRF
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override
  - Forwards to requesting contract
```

**State Variables**:

```solidity
VRFCoordinatorV2Interface public COORDINATOR;
uint64 public subscriptionId;
bytes32 public keyHash;
uint32 public callbackGasLimit = 500000;
uint16 public requestConfirmations = 3;

mapping(uint256 => address) public requestToContract; // requestId => requesting contract
```

## Backend Services

### 1. Wallet Generation Service

**Technology**: Node.js + ethers.js

**Responsibilities**:

- Listen for `WalletReady` events from smart contracts
- Generate new Ethereum wallet (private key + address)
- Determine asset allocation based on tier and random seed
- Pre-fund wallet with selected assets
- Encrypt and temporarily store private key for user retrieval
- Delete private key after user retrieval (24-hour timeout)

**API Endpoints**:

```
POST /api/wallet/generate
  - Input: requestId, tier, randomSeed
  - Output: walletAddress, encryptedPrivateKey, expiresAt

GET /api/wallet/retrieve/:requestId
  - Input: requestId, userSignature (proof of ownership)
  - Output: privateKey (ONE TIME ONLY)
  - After retrieval: DELETE from database
```

**Asset Selection Algorithm**:

```javascript
function selectAssets(tier, randomSeed) {
  const budget = calculateBudget(tier, randomSeed); // 5-30 USDC for tier 1
  const assetPool = getAvailableAssets(tier);
  const selectedAssets = [];

  let remainingBudget = budget;

  // Allocate 40-60% to tokens
  const tokenBudget = remainingBudget * random(0.4, 0.6);
  selectedAssets.push(
    ...selectTokens(tokenBudget, assetPool.tokens, randomSeed)
  );

  // Allocate 20-40% to NFTs
  const nftBudget = remainingBudget * random(0.2, 0.4);
  selectedAssets.push(...selectNFTs(nftBudget, assetPool.nfts, randomSeed));

  // Remaining to LP positions
  const lpBudget = remainingBudget - tokenBudget - nftBudget;
  if (lpBudget > 5) {
    selectedAssets.push(
      ...selectLPPositions(lpBudget, assetPool.lps, randomSeed)
    );
  }

  return selectedAssets;
}
```

### 2. Asset Distribution Service

**Technology**: Node.js + ethers.js

**Responsibilities**:

- Maintain hot wallet with asset inventory
- Transfer tokens to newly generated wallets
- Transfer NFTs to newly generated wallets
- Create LP positions on behalf of wallet
- Track asset inventory levels
- Alert when inventory low

**Functions**:

```javascript
async function fundWallet(walletAddress, assetList) {
  for (const asset of assetList) {
    if (asset.type === "ERC20") {
      await transferToken(asset.address, walletAddress, asset.amount);
    } else if (asset.type === "ERC721") {
      await transferNFT(asset.address, walletAddress, asset.tokenId);
    } else if (asset.type === "LP") {
      await createLPPosition(asset.pool, walletAddress, asset.amount);
    }
  }
}
```

### 3. Event Listener Service

**Technology**: Node.js + ethers.js

**Responsibilities**:

- Listen to all contract events
- Trigger wallet generation on `WalletReady` events
- Trigger winner notification on `WinnerSelected` events
- Update database with transaction history
- Send notifications (email, webhook, etc.)

### 4. Sponsor Management Service

**Technology**: Node.js

**Responsibilities**:

- Track active sponsors from auctions
- Ensure sponsored tokens included in X% of wallets
- Generate reports for sponsors (impression tracking)
- Automate auction finalization after 30 days
- Send notifications to bidders

## Frontend Application

### Technology Stack

- **Framework**: Next.js 14 (App Router)
- **Web3**: wagmi + viem
- **Styling**: Tailwind CSS
- **State Management**: Zustand
- **UI Components**: shadcn/ui

### Pages & Components

#### 1. Home/Landing Page

- Explain vending machine concept
- Show recent winners/stats
- CTA buttons for each mode

#### 2. Vending Machine Page

```tsx
<VendingMachinePage>
  <TierSelector> // Select 20/50/100 USDC tier
  <ProbabilityDisplay> // Show odds and potential prizes
  <PurchaseButton> // Connect wallet, approve USDC, purchase
  <WalletDeliveryModal> // ONE-TIME display of private key
</VendingMachinePage>
```

#### 3. Raffle Page

```tsx
<RafflePage>
  <CurrentRaffleInfo> // Tickets sold, prize pool, time remaining
  <TicketPurchase> // Buy 1-5 tickets
  <UserTickets> // Show user's ticket numbers
  <RecentWinners> // Display recent raffle winners
</RafflePage>
```

#### 4. Sponsor Portal

```tsx
<SponsorPortal>
  <CurrentAuction> // Show current bids, time remaining
  <BidForm> // Place bid for coin placement
  <AuctionHistory> // Past auction results
  <SponsorStats> // Analytics for current sponsors
</SponsorPortal>
```

#### 5. Wallet Delivery Component

```tsx
<WalletDelivery>
  - Display private key ONCE (no copy-paste, force manual write-down) - Show QR
  code for import - Countdown timer (5 minutes to save) - Warning messages about
  permanence - Checkbox: "I have saved my private key"
</WalletDelivery>
```

## Database Schema

### PostgreSQL Tables

```sql
-- Purchases
CREATE TABLE purchases (
  id SERIAL PRIMARY KEY,
  request_id VARCHAR(66) UNIQUE NOT NULL,
  buyer_address VARCHAR(42) NOT NULL,
  tier INTEGER NOT NULL,
  price_usdc DECIMAL(18, 6) NOT NULL,
  random_seed VARCHAR(66),
  wallet_address VARCHAR(42),
  wallet_value_usdc DECIMAL(18, 6),
  fulfilled BOOLEAN DEFAULT FALSE,
  retrieved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  fulfilled_at TIMESTAMP,
  retrieved_at TIMESTAMP
);

-- Raffle Tickets
CREATE TABLE raffle_tickets (
  id SERIAL PRIMARY KEY,
  raffle_id INTEGER NOT NULL,
  buyer_address VARCHAR(42) NOT NULL,
  ticket_numbers INTEGER[] NOT NULL,
  purchase_tx VARCHAR(66) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Raffles
CREATE TABLE raffles (
  id SERIAL PRIMARY KEY,
  raffle_id INTEGER UNIQUE NOT NULL,
  total_tickets INTEGER NOT NULL,
  prize_pool_usdc DECIMAL(18, 6) NOT NULL,
  winner_address VARCHAR(42),
  winner_ticket_number INTEGER,
  completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
);

-- Sponsor Auctions
CREATE TABLE sponsor_auctions (
  id SERIAL PRIMARY KEY,
  auction_id INTEGER UNIQUE NOT NULL,
  start_time TIMESTAMP NOT NULL,
  end_time TIMESTAMP NOT NULL,
  finalized BOOLEAN DEFAULT FALSE,
  winners TEXT[], -- Array of winning token addresses
  created_at TIMESTAMP DEFAULT NOW()
);

-- Sponsor Bids
CREATE TABLE sponsor_bids (
  id SERIAL PRIMARY KEY,
  auction_id INTEGER NOT NULL,
  bidder_address VARCHAR(42) NOT NULL,
  token_address VARCHAR(42) NOT NULL,
  bid_amount_usdc DECIMAL(18, 6) NOT NULL,
  refunded BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (auction_id) REFERENCES sponsor_auctions(id)
);

-- Asset Pool
CREATE TABLE asset_pool (
  id SERIAL PRIMARY KEY,
  asset_type VARCHAR(20) NOT NULL, -- 'ERC20', 'ERC721', 'LP'
  contract_address VARCHAR(42) NOT NULL,
  token_id VARCHAR(78), -- For NFTs
  quantity DECIMAL(18, 6), -- For tokens/LP
  estimated_value_usdc DECIMAL(18, 6) NOT NULL,
  tier_eligibility INTEGER[], -- Which tiers can receive this
  is_sponsored BOOLEAN DEFAULT FALSE,
  sponsor_address VARCHAR(42),
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Wallet Keys (temporary storage)
CREATE TABLE wallet_keys (
  id SERIAL PRIMARY KEY,
  request_id VARCHAR(66) UNIQUE NOT NULL,
  wallet_address VARCHAR(42) NOT NULL,
  encrypted_private_key TEXT NOT NULL,
  retrieved BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  retrieved_at TIMESTAMP
);
```

## Security Considerations

### Smart Contract Security

- Use OpenZeppelin libraries for standards
- Implement ReentrancyGuard on payable functions
- Add pause functionality for emergencies
- Multi-sig wallet for admin functions
- Time-locks for parameter changes

### Private Key Security

- Never store unencrypted private keys
- Use AES-256 encryption with user-derived key
- Auto-delete after retrieval or 24-hour timeout
- No backup mechanism (by design)
- Log deletion events for audit

### Randomness Security

- Use Chainlink VRF for verifiable randomness
- Never allow client-side randomness
- Commit-reveal for additional security
- Monitor VRF fulfillment times

### Access Control

- Role-based permissions (Owner, Operator, Bot)
- Rate limiting on frontend
- Wallet address verification
- Transaction replay protection

## Testing Strategy

### Smart Contract Tests

```
- Unit tests for each function
- Integration tests for full flows
- Fuzz testing for edge cases
- Gas optimization tests
- Upgrade simulation tests
```

### Backend Tests

```
- API endpoint tests
- Event listener reliability tests
- Wallet generation security tests
- Asset distribution accuracy tests
- Stress tests (concurrent users)
```

### Frontend Tests

```
- Component unit tests
- E2E tests with wallet connection
- Mobile responsiveness tests
- Browser compatibility tests
```

## Deployment Pipeline

### Testnet Deployment

1. Deploy contracts to Sepolia/Goerli
2. Set up backend services on staging
3. Configure Chainlink VRF testnet
4. Deploy frontend to Vercel preview
5. Internal testing (1-2 weeks)
6. Public beta (invite-only)

### Mainnet Deployment

1. Smart contract audit (CertiK, OpenZeppelin, etc.)
2. Deploy contracts to mainnet
3. Initialize with small asset pool
4. Deploy backend to production infrastructure
5. Deploy frontend to production
6. Gradual rollout (whitelist → public)

## Monitoring & Analytics

### Metrics to Track

- Total vending machine sales (by tier)
- Average wallet value vs. price paid
- House edge realization (actual vs. expected)
- Raffle participation rate
- Sponsor auction bid amounts
- User retention rate
- Asset inventory levels
- Transaction success rate

### Alerts

- Low asset inventory
- VRF fulfillment delays
- Unusual betting patterns
- Smart contract errors
- Backend service downtime

## Cost Estimation

### Smart Contract Deployment

- VendingMachine: ~$500-1000 gas
- RaffleManager: ~$400-800 gas
- SponsorAuction: ~$300-600 gas
- RandomnessProvider: ~$200-400 gas

### Operational Costs

- Chainlink VRF: ~$0.50-2 per request
- Backend hosting: ~$100-300/month
- Database: ~$50-100/month
- Frontend hosting: ~$20-50/month
- Asset inventory: Varies (initial capital)

### Revenue Projections

**Example Month 1:**

- 1000 vending machine purchases × 20 USDC × 10% = 2,000 USDC
- 50 raffles × 100 tickets × 1 USDC × 10% = 500 USDC
- 5 sponsor auctions × 1,000 USDC = 5,000 USDC
- **Total**: ~7,500 USDC/month

## Future Enhancements

1. **Mobile App**: Native iOS/Android app
2. **Additional Chains**: Deploy to Polygon, Base, Arbitrum
3. **Referral System**: Earn % for referring users
4. **Loyalty Program**: Rewards for frequent players
5. **Custom Wallets**: User-selectable asset preferences
6. **Social Features**: Share wins, leaderboards
7. **Advanced LP Strategies**: Auto-compounding positions
8. **DAO Governance**: Community voting on asset pool

## Conclusion

This technical specification provides a comprehensive foundation for building the Vendyz Vending Machine platform. The architecture balances security, scalability, and user experience while maintaining the core value proposition: anonymous, pre-funded wallets with gamified randomness.
