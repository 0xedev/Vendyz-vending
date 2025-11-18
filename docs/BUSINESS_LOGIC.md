# Business Logic & User Flows

## Core Business Model

### Revenue Streams

1. **Vending Machine (Primary)**
   - 10% house edge on all purchases
   - Expected revenue: $2 per $20 purchase
   - Volume-dependent profitability

2. **Raffle System**
   - 10% of total ticket sales + 10 USDC flat fee
   - Example: 100 tickets × 1 USDC = 10 USDC + 10 USDC = 20 USDC revenue
   - Lower risk, community-driven

3. **Sponsor Auctions**
   - Recurring 30-day auctions
   - 100% revenue (no refunds)
   - Predictable income stream

### House Edge Mathematics

**Tier 1 Example (20 USDC):**
- User pays: 20 USDC
- Expected return: 18 USDC (90%)
- House keeps: 2 USDC (10%)
- Wallet value range: 5-30 USDC
- Distribution ensures 18 USDC average

**How it works:**
- 30% chance: 5-10 USDC (lose)
- 50% chance: 15-20 USDC (break even)
- 20% chance: 25-30 USDC (win)
- Weighted average: ~18 USDC

## User Flows

### Flow 1: Vending Machine Purchase

```
┌──────────────────────────────────────────────────┐
│ 1. User lands on website                         │
│    - Sees tier options (20/50/100 USDC)         │
│    - Views recent winners                        │
│    - Checks probability calculator               │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 2. User selects tier                             │
│    - Reviews tier details                        │
│    - Sees potential prize range                  │
│    - Understands 90% return rate                 │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 3. User connects wallet                          │
│    - MetaMask/WalletConnect                      │
│    - Signs connection message                    │
│    - Wallet address displayed                    │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 4. User approves USDC                            │
│    - Transaction 1: Approve VendingMachine       │
│    - Confirms in wallet                          │
│    - Wait for confirmation                       │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 5. User purchases tier                           │
│    - Transaction 2: Call purchase()              │
│    - USDC transferred to treasury                │
│    - VRF randomness requested                    │
│    - Request ID generated                        │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 6. Wait for wallet generation (30-60 sec)        │
│    - Loading screen with animations              │
│    - "Generating your anonymous wallet..."       │
│    - "Selecting random assets..."                │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 7. Wallet ready notification                     │
│    - Backend receives VRF callback               │
│    - Wallet generated with private key           │
│    - Assets transferred to wallet                │
│    - User notified                               │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 8. Private key delivery (CRITICAL)               │
│    - ONE-TIME display modal                      │
│    - Large warning messages                      │
│    - Private key shown in plain text             │
│    - QR code for easy import                     │
│    - 5-minute countdown timer                    │
│    - "Have you saved your key?" checkbox         │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 9. User saves private key                        │
│    - Writes down on paper (recommended)          │
│    - Takes screenshot (not recommended)          │
│    - Scans QR code to mobile wallet              │
│    - Confirms save checkbox                      │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 10. User closes modal                            │
│     - Private key deleted from database          │
│     - Cannot be recovered                        │
│     - Permanent deletion logged                  │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 11. User imports wallet                          │
│     - Opens MetaMask/other wallet                │
│     - Imports private key                        │
│     - Sees wallet balance and assets             │
│     - Can now trade anonymously                  │
└──────────────────────────────────────────────────┘
```

### Flow 2: Raffle Entry

```
┌──────────────────────────────────────────────────┐
│ 1. User navigates to Raffle page                 │
│    - Sees current raffle progress                │
│    - Tickets sold: 45/100                        │
│    - Current prize pool: 45 USDC → 35.5 winner  │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 2. User selects ticket quantity                  │
│    - Slider: 1-5 tickets                         │
│    - Shows total cost (e.g., 3 tickets = 3 USDC)│
│    - Shows max tickets already bought (if any)   │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 3. User connects wallet & approves               │
│    - Same as vending machine flow                │
│    - Approves USDC transfer                      │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 4. User buys tickets                             │
│    - Transaction: buyTickets(3)                  │
│    - Receives ticket numbers: #45, #46, #47      │
│    - Ticket numbers displayed prominently        │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 5. User waits for raffle to fill                 │
│    - Live progress bar                           │
│    - "55 tickets remaining"                      │
│    - Estimated fill time                         │
│    - Can leave page and return                   │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 6. Raffle fills (100/100 tickets sold)           │
│    - Automatic VRF request triggered             │
│    - "Drawing winner..." animation               │
│    - All participants notified                   │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 7. Winner selected                               │
│    - Winning ticket number revealed              │
│    - Winner address displayed                    │
│    - Prize pool amount shown                     │
└─────────────────┬────────────────────────────────┘
                  │
          ┌───────┴───────┐
          │               │
┌─────────▼─────┐  ┌──────▼──────────────┐
│ 8a. I WON!    │  │ 8b. I lost :(       │
│                │  │                     │
│ - Big winner  │  │ - "Better luck next │
│   animation   │  │   time!" message    │
│ - Confetti    │  │ - "Enter new raffle"│
│ - Wallet      │  │   CTA               │
│   delivery    │  │ - See next raffle   │
│   (same as    │  │   details           │
│   vending)    │  │                     │
└───────────────┘  └─────────────────────┘
```

### Flow 3: Sponsor Auction

```
┌──────────────────────────────────────────────────┐
│ 1. Project team visits Sponsor Portal            │
│    - Sees current auction status                 │
│    - Days remaining: 15/30                       │
│    - Current bids displayed                      │
│    - Available slots: 2/5                        │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 2. Project decides to bid                        │
│    - Reviews benefits:                           │
│      * Token included in X% of wallets           │
│      * Logo on website                           │
│      * Analytics dashboard                       │
│      * 30-day placement                          │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 3. Project places bid                            │
│    - Enters token contract address               │
│    - Enters bid amount (e.g., 1,500 USDC)       │
│    - Minimum bid shown                           │
│    - Must beat current lowest winning bid        │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 4. Bid submitted                                 │
│    - USDC held in contract                       │
│    - Bid publicly visible                        │
│    - Email notification sent                     │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 5. Auction progresses                            │
│    - Other projects may outbid                   │
│    - If outbid, USDC auto-refunded               │
│    - Can re-bid if desired                       │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 6. Auction ends (after 30 days)                  │
│    - Top 5 bidders win                           │
│    - Winners' USDC transferred to treasury       │
│    - Losers' USDC refunded automatically         │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 7. Winners announced                             │
│    - Email notification to winners               │
│    - Token added to asset pool                   │
│    - Sponsor logo added to website               │
│    - Analytics dashboard access granted          │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 8. 30-day sponsorship period                     │
│    - Token included in wallets                   │
│    - Track impressions                           │
│    - View analytics                              │
│    - Download reports                            │
└─────────────────┬────────────────────────────────┘
                  │
┌─────────────────▼────────────────────────────────┐
│ 9. Sponsorship ends                              │
│    - Final report delivered                      │
│    - Token removed from pool                     │
│    - Invited to bid in next auction              │
└──────────────────────────────────────────────────┘
```

## Asset Selection Algorithm

### How Assets Are Chosen

```javascript
function selectAssetsForWallet(tier, randomSeed) {
  // Step 1: Calculate total budget for this wallet
  const tierConfig = TIER_CONFIGS[tier];
  const randomValue = seededRandom(randomSeed, 0);
  const budget = lerp(
    tierConfig.minValue, 
    tierConfig.maxValue, 
    randomValue
  );
  // Example: Tier 1, budget = 18 USDC

  // Step 2: Determine allocation percentages
  const tokenPercent = seededRandom(randomSeed, 1) * 0.3 + 0.4; // 40-70%
  const nftPercent = seededRandom(randomSeed, 2) * 0.2 + 0.15;  // 15-35%
  const lpPercent = 1 - tokenPercent - nftPercent;              // remainder

  // Step 3: Calculate budgets for each category
  const tokenBudget = budget * tokenPercent;  // e.g., 10.8 USDC
  const nftBudget = budget * nftPercent;      // e.g., 3.6 USDC
  const lpBudget = budget * lpPercent;        // e.g., 3.6 USDC

  // Step 4: Select tokens
  const tokens = selectTokens(tokenBudget, randomSeed);
  // Example output:
  // - 5 USDC worth of $PEPE
  // - 3 USDC worth of $WOJAK
  // - 2.8 USDC worth of $MEME

  // Step 5: Select NFTs
  const nfts = selectNFTs(nftBudget, randomSeed);
  // Example output:
  // - 1 Pudgy Penguin (floor: 2 USDC)
  // - 1 Milady (floor: 1.6 USDC)

  // Step 6: Select LP positions
  const lps = selectLPPositions(lpBudget, randomSeed);
  // Example output:
  // - USDC/ETH LP (3.6 USDC deposited)

  return {
    budget,
    tokens,
    nfts,
    lps,
    total: tokenBudget + nftBudget + lpBudget
  };
}
```

### Token Selection

```javascript
function selectTokens(budget, seed) {
  const availableTokens = getEligibleTokens();
  const numTokens = Math.floor(seededRandom(seed, 3) * 3) + 2; // 2-5 tokens
  const selected = [];
  
  let remainingBudget = budget;
  
  for (let i = 0; i < numTokens; i++) {
    // Weighted random selection (considers sponsor boost)
    const token = weightedRandomToken(availableTokens, seed, i);
    
    // Allocate portion of budget
    const allocation = remainingBudget / (numTokens - i);
    const amount = calculateTokenAmount(token, allocation);
    
    selected.push({
      address: token.address,
      symbol: token.symbol,
      amount: amount,
      valueUSD: allocation
    });
    
    remainingBudget -= allocation;
  }
  
  return selected;
}
```

### Sponsor Boost

Sponsored tokens get 3x weight in selection:

```javascript
function weightedRandomToken(tokens, seed, index) {
  const weights = tokens.map(t => t.isSponsored ? 3 : 1);
  const totalWeight = weights.reduce((a, b) => a + b, 0);
  
  let random = seededRandom(seed, index + 10) * totalWeight;
  
  for (let i = 0; i < tokens.length; i++) {
    random -= weights[i];
    if (random <= 0) return tokens[i];
  }
  
  return tokens[tokens.length - 1];
}
```

## Wallet Pre-funding Process

### Backend Workflow

```
1. Event Listener detects WalletReady event
   └─> Extracts: requestId, buyer, tier, randomSeed

2. Wallet Generation Service triggered
   ├─> Generate new Ethereum keypair
   ├─> Derive address from private key
   └─> Store encrypted private key (24hr TTL)

3. Asset Selection Service
   ├─> Run selection algorithm with randomSeed
   ├─> Determine exact tokens, NFTs, LPs
   └─> Validate total value within tier range

4. Asset Distribution Service
   ├─> Transfer tokens from hot wallet
   ├─> Transfer NFTs from hot wallet
   ├─> Create LP positions (if applicable)
   └─> Verify all transfers succeeded

5. Notification Service
   ├─> Update database: wallet ready
   ├─> Send email to user (optional)
   └─> Emit webhook for frontend

6. Frontend receives notification
   └─> Display private key delivery modal
```

## Security & Trust

### Private Key Handling

**CRITICAL RULES:**
1. Private key generated ONLY after payment confirmed
2. Private key stored encrypted with user-derived key
3. Private key shown ONLY ONCE to user
4. Private key deleted after retrieval OR 24-hour timeout
5. No backup, no recovery, no exceptions

### Anonymity Guarantees

**Wallet generation:**
- New wallet has no on-chain history
- Not linked to purchasing wallet
- No KYC, no email required
- Platform cannot access wallet after delivery

**Asset transfers:**
- All transfers from hot wallet
- Hot wallet refilled regularly
- No direct link between user and anonymous wallet

## Economics Deep Dive

### House Edge Over Time

**Scenario: 1000 users play Tier 1 (20 USDC)**

| Metric | Value |
|--------|-------|
| Total revenue | 20,000 USDC |
| Total paid out | 18,000 USDC |
| House profit | 2,000 USDC |
| House edge | 10% |

**Distribution of outcomes:**
- 200 users get 25-30 USDC (win big)
- 500 users get 15-20 USDC (break even)
- 300 users get 5-10 USDC (lose)

Average: 18 USDC per user (90% return)

### Raffle Economics

**Example: 100-ticket raffle**

| Item | Amount |
|------|--------|
| Ticket price | 1 USDC |
| Tickets sold | 100 |
| Total collected | 100 USDC |
| House fee (10%) | 10 USDC |
| House flat fee | 10 USDC |
| Prize pool | 80 USDC |
| Effective return | 80% |

Winner receives wallet with ~80 USDC worth of assets.

### Sponsor Auction Value

**For platform:**
- 5 sponsors × 1,000 USDC = 5,000 USDC/month
- Recurring revenue stream
- Predictable income

**For sponsors:**
- Guaranteed placement in wallets
- Estimated 10,000 impressions/month
- Cost per impression: $0.10
- Comparable to traditional advertising

## Risk Management

### Inventory Management

Platform must maintain:
- Hot wallet with diverse assets
- USDC reserve for LP positions
- NFT collection for distribution
- Rebalancing strategy

**Warning thresholds:**
- Alert if token inventory < 7 days
- Alert if USDC reserve < 50% target
- Alert if NFT inventory < 20 units

### Smart Contract Risks

**Mitigation strategies:**
- Pausable contracts for emergencies
- Multi-sig for admin functions
- Time-locks for parameter changes
- Regular audits
- Bug bounty program

### Regulatory Risks

**Considerations:**
- Gambling laws vary by jurisdiction
- May need operating license
- AML/KYC requirements unclear
- Consult legal counsel

**Recommended approach:**
- Geo-block restricted regions
- Display disclaimers
- Track regulatory changes
- Maintain legal reserve fund

## Future Enhancements

1. **Dynamic Pricing**: Adjust tiers based on demand
2. **Loyalty Program**: Rewards for repeat users
3. **Referral System**: Earn % of referred purchases
4. **Custom Wallets**: User-selectable asset preferences
5. **Social Features**: Share wins, leaderboards
6. **Mobile App**: Native iOS/Android experience
7. **Multi-chain**: Deploy to L2s for lower fees
8. **DAO Governance**: Community votes on asset pool
