# Vendyz Vending Machine - Anonymous Wallet Vending Platform

## Core Concept

A blockchain-based vending machine that dispenses pre-funded anonymous Ethereum wallets containing a random assortment of coins, NFTs, and liquidity positions. Users pay a fixed price and receive an anonymous wallet they're not directly linked to, enabling private trading while gambling on the contents.

## Key Features

### 1. Vending Machine Mode (Gacha)

Fixed-price tiers where users receive random anonymous wallets:

#### Tier 1: 20 USDC

- **Output Range**: 5-30 USDC worth of assets
- **Expected Return**: ~18 USDC (90% of input)
- **House Edge**: 10%

#### Tier 2: 50 USDC

- **Output Range**: 5-75 USDC worth of assets
- **Expected Return**: ~45 USDC (90% of input)
- **House Edge**: 10%

#### Tier 3: 100 USDC

- **Output Range**: 10-150 USDC worth of assets
- **Expected Return**: ~90 USDC (90% of input)
- **House Edge**: 10%

**Assets Included:**

- ERC-20 tokens (random selection)
- NFTs (random rarity)
- Liquidity Position NFTs (Uniswap V3, etc.)

### 2. Raffle Mode

Community-driven lottery system:

- **Entry Fee**: 1 USDC per ticket
- **Max Tickets**: 5 per wallet address
- **Prize Pool**: 90% of total entries (in USDC worth of assets)
- **House Edge**: 10% + 10 USDC flat fee
- **Trigger**: Automatically draws winner once all tickets sold
- **Example**: 100 tickets × 1 USDC = 100 USDC collected → Winner gets wallet with 90 USDC worth of assets

### 3. Sponsor Auction System

Revenue diversification through sponsored coin placements:

- **Auction Frequency**: Every 30 days
- **Auction Item**: Guaranteed placement in vending machine wallets
- **Bidding**: Projects bid for spots in the next cycle
- **Integration**: Sponsored tokens guaranteed in X% of wallets

## Core Mechanics

### Anonymous Wallet Generation

1. Platform generates new Ethereum wallet (private key)
2. Wallet is pre-funded with random assets
3. Private key/seed phrase delivered ONLY to user
4. Platform has ZERO access to wallet after delivery
5. User receives anonymous wallet not linked to their purchasing wallet

### Randomization & House Edge

- Provably fair random selection (Chainlink VRF recommended)
- 90% average return rate ensures long-term profitability
- Random asset selection from curated pool
- Rarity tiers for NFTs and tokens
- Value ranges ensure excitement while maintaining edge

### Asset Pool Management

- Curated list of tokens/NFTs for inclusion
- Regular rebalancing of asset pools
- Sponsor-paid placements
- Liquidity position management
- Quality control for included assets

## Technical Architecture

### Smart Contracts

1. **VendingMachine.sol** - Main contract for vending machine tiers
2. **RaffleManager.sol** - Handles raffle ticket sales and winner selection
3. **SponsorAuction.sol** - Manages 30-day sponsor auctions
4. **RandomnessProvider.sol** - Chainlink VRF integration
5. **WalletPrefunder.sol** - Handles pre-funding logic

### Backend Services

1. **Wallet Generation Service** - Creates new anonymous wallets
2. **Asset Distribution Service** - Randomly selects and sends assets
3. **Prefunding Service** - Pre-funds wallets before delivery
4. **Sponsor Management** - Tracks auction winners and placements
5. **Analytics Service** - Tracks metrics and probabilities

### Frontend

1. **Vending Machine Interface** - Select tier, pay, receive wallet
2. **Raffle Dashboard** - Buy tickets, view entries, see winners
3. **Sponsor Portal** - Auction bidding for projects
4. **Wallet Delivery** - Secure private key/seed phrase display
5. **Analytics Dashboard** - Show odds, recent wins, stats

## User Flows

### Vending Machine Purchase

```
1. User connects wallet
2. Selects tier (20/50/100 USDC)
3. Approves USDC payment
4. Platform generates anonymous wallet
5. Platform pre-funds wallet with random assets
6. User receives private key/seed phrase (ONE TIME DISPLAY)
7. User imports wallet to trade anonymously
```

### Raffle Entry

```
1. User connects wallet
2. Purchases 1-5 tickets (1 USDC each)
3. Raffle fills up (e.g., 100 tickets)
4. Winner randomly selected (Chainlink VRF)
5. Winner receives pre-funded anonymous wallet
6. New raffle begins
```

### Sponsor Auction

```
1. Project connects wallet
2. Views current auction status
3. Places bid for coin placement
4. Auction ends after 30 days
5. Winner's token included in next cycle
6. Next auction begins
```

## Security & Trust

### Anonymity Guarantees

- Platform never stores private keys
- Wallet generation happens on-demand
- Private key shown ONCE to user
- No link between purchasing wallet and anonymous wallet

### Fairness

- Chainlink VRF for provable randomness
- Open-source smart contracts
- On-chain verification of odds
- Transparent house edge

### Asset Safety

- Only vetted tokens/NFTs included
- Regular security audits
- Multi-sig for treasury management
- Emergency pause functionality

## Revenue Model

1. **House Edge**: 10% on all vending machine sales
2. **Raffle Fees**: 10% + 10 USDC per raffle
3. **Sponsor Auctions**: 30-day recurring revenue
4. **Volume Incentives**: More plays = more revenue

## Competitive Advantages

1. **Anonymity First**: Not just gambling, but privacy tool
2. **Asset Diversity**: Coins + NFTs + LP positions
3. **Sponsored Content**: Sustainable revenue beyond gambling
4. **Raffle Mode**: Community engagement and fairness
5. **Pre-funded Wallets**: Instant access, no waiting

## Legal Considerations

- Gambling regulations vary by jurisdiction
- May need licensing in certain regions
- Anonymous wallets may face AML concerns
- Consult legal counsel before launch
- Consider geo-blocking restricted regions

## Next Steps

1. [ ] Finalize tokenomics and odds tables
2. [ ] Design and audit smart contracts
3. [ ] Build wallet generation infrastructure
4. [ ] Create frontend interface
5. [ ] Establish asset partnerships
6. [ ] Run testnet pilot
7. [ ] Legal review and compliance
8. [ ] Mainnet launch

## Open Questions

- Which blockchain? (Ethereum mainnet, Polygon, Base, Arbitrum?)
- Minimum asset pool size before launch?
- Raffle ticket caps (total tickets per round)?
- Sponsor auction starting bids?
- KYC requirements (if any)?
- Asset curation criteria?
