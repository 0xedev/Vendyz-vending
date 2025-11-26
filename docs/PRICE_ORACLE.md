# Price Oracle Integration

## Overview

The price oracle system fetches real-time token prices using a dual-source strategy:
1. **CoinGecko** (Primary) - Free, no API key required
2. **Moralis** (Fallback) - Reliable backup when CoinGecko fails

## Architecture

```
┌─────────────────────────────────────────────┐
│  Frontend (WalletRetrieval, Analytics)     │
│  Uses: /lib/priceOracle.ts                 │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  Next.js API Route: /api/prices            │
│  - Proxies requests to avoid CORS          │
│  - Server-side caching (5 min)             │
└────────────────┬────────────────────────────┘
                 │
                 ├─────────────┬──────────────┐
                 ▼             ▼              ▼
         ┌──────────┐  ┌──────────┐  ┌──────────┐
         │CoinGecko │  │ Moralis  │  │  Cache   │
         │   API    │  │   API    │  │ (5 min)  │
         └──────────┘  └──────────┘  └──────────┘


┌─────────────────────────────────────────────┐
│  Backend (Wallet Funding Service)          │
│  Uses: /src/priceOracle.js                 │
│  - Token selection algorithm               │
│  - Calculate wallet values                 │
└─────────────────────────────────────────────┘
```

## Features

✅ **Dual-Source Strategy** - CoinGecko primary, Moralis fallback  
✅ **5-Minute Caching** - Reduces API calls and rate limits  
✅ **Batch Requests** - Fetch multiple token prices efficiently  
✅ **Rate Limiting** - Automatic throttling to respect API limits  
✅ **Error Handling** - Graceful degradation if prices unavailable  
✅ **Base Network Support** - Optimized for Base mainnet tokens  

## Backend Integration

### Installation

```bash
cd backend
npm install
```

### Usage

```javascript
import { getTokenPrice, getTokenPrices, calculateWalletValue } from './priceOracle.js';

// Single token
const price = await getTokenPrice('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913');
console.log(`USDC: $${price.price}`);

// Multiple tokens (batch)
const prices = await getTokenPrices([
  '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', // USDC
  '0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed', // DEGEN
]);

// Calculate wallet value
const wallet = await calculateWalletValue([
  { address: '0x833...', symbol: 'USDC', amount: '1000000', decimals: 6 },
  { address: '0x4ed4...', symbol: 'DEGEN', amount: '1000000000000000000', decimals: 18 },
]);
console.log(`Total: $${wallet.totalValue}`);
```

### Testing

```bash
npm run test:oracle
```

## Frontend Integration

### API Routes

**GET /api/prices?token=0x...**
```typescript
// Fetch single token price
const response = await fetch('/api/prices?token=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913');
const data = await response.json();
// { price: 1.00, source: 'coingecko', cached: false }
```

**POST /api/prices**
```typescript
// Fetch multiple token prices
const response = await fetch('/api/prices', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    tokens: ['0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', '0x4ed4...']
  }),
});
const data = await response.json();
// { prices: { '0x833...': { price: 1.00, source: 'coingecko' }, ... } }
```

### Client-Side Usage

```typescript
import { getTokenPrice, calculateWalletValue, formatUSD } from '~/lib/priceOracle';

// In your component
const [totalValue, setTotalValue] = useState(0);

useEffect(() => {
  async function fetchValue() {
    const result = await calculateWalletValue([
      { address: '0x...', symbol: 'USDC', amount: '1000000', decimals: 6 },
    ]);
    setTotalValue(result.totalValue);
  }
  fetchValue();
}, []);

return <div>Total Value: {formatUSD(totalValue)}</div>;
```

## API Details

### CoinGecko (Primary)

**Endpoint:** `https://api.coingecko.com/api/v3/simple/token_price/base`

**Features:**
- Supports Base network
- Batch requests (up to 250 tokens)
- Free tier: 10-50 calls/minute
- No API key required

**Rate Limits:**
- 1.2 seconds between calls
- ~50 requests per minute

### Moralis (Fallback)

**Endpoint:** `https://deep-index.moralis.io/api/v2.2/erc20/{address}/price?chain=base`

**Features:**
- Real-time DEX prices
- Base network support
- API key included

**Rate Limits:**
- 0.5 seconds between calls
- API key: Free tier (25 requests/second)

## Caching Strategy

### TTL: 5 Minutes

**Why 5 minutes?**
- Token prices don't change significantly in short periods
- Reduces API calls by ~90%
- Stays within rate limits
- Fresh enough for UX

### Cache Invalidation

```javascript
import { clearPriceCache, getCacheStats } from './priceOracle.js';

// Clear all cached prices
clearPriceCache();

// Get cache statistics
const stats = getCacheStats();
console.log(`Cache: ${stats.valid} valid, ${stats.expired} expired`);
```

## Error Handling

### Fallback Chain

1. **Check Cache** - Return if fresh (< 5 min)
2. **Try CoinGecko** - Primary source
3. **Try Moralis** - Fallback if CoinGecko fails
4. **Return 0** - If both fail, return $0 with error flag

### Error States

```typescript
{
  price: 0,
  cached: false,
  source: 'none',
  error: 'All sources failed'
}
```

## Rate Limiting

### Automatic Throttling

Both sources implement automatic rate limiting:

```javascript
// CoinGecko: 1.2s between calls
const timeSinceLastCall = Date.now() - lastCoinGeckoCall;
if (timeSinceLastCall < 1200) {
  await sleep(1200 - timeSinceLastCall);
}

// Moralis: 0.5s between calls
const timeSinceLastCall = Date.now() - lastMoralisCall;
if (timeSinceLastCall < 500) {
  await sleep(500 - timeSinceLastCall);
}
```

## Environment Variables

### Backend (.env)

```bash
# Optional: Custom Moralis API key
MORALIS_API_KEY=your_api_key_here
```

### Frontend (.env.local)

```bash
# Optional: Custom Moralis API key for Next.js API route
MORALIS_API_KEY=your_api_key_here
```

**Note:** A default Moralis API key is included in the code.

## Performance

### Typical Response Times

- **Cached:** < 1ms
- **CoinGecko:** 200-500ms
- **Moralis:** 300-700ms
- **Batch (10 tokens):** 500-1000ms

### Cache Hit Rate

With 5-minute TTL:
- Expected: 85-95% cache hit rate
- Reduces API calls by 90%+

## Integration Examples

### Example 1: WalletRetrieval Component

```typescript
import { calculateWalletValue, formatUSD } from '~/lib/priceOracle';

export function WalletRetrieval({ requestId }: { requestId: bigint }) {
  const [walletValue, setWalletValue] = useState(0);
  const [tokens, setTokens] = useState([]);

  useEffect(() => {
    async function loadValue() {
      // Fetch wallet tokens from contract or API
      const walletTokens = await getWalletTokens(requestId);
      
      // Calculate total value
      const result = await calculateWalletValue(walletTokens);
      setWalletValue(result.totalValue);
      setTokens(result.tokens);
    }
    loadValue();
  }, [requestId]);

  return (
    <div>
      <h3>Total Value: {formatUSD(walletValue)}</h3>
      {tokens.map(token => (
        <div key={token.address}>
          {token.symbol}: {token.amount} × {formatUSD(token.price)} = {formatUSD(token.value)}
        </div>
      ))}
    </div>
  );
}
```

### Example 2: Backend Token Selection

```javascript
import { getTokenPrices } from './priceOracle.js';

async function selectTokensForTier(tier, targetValue) {
  // Get sponsor tokens from SponsorAuction
  const sponsors = await getActiveSponsors();
  
  // Get random token list
  const randomTokens = getRandomTokens();
  
  // Mix 50/50
  const selectedTokens = [
    ...sponsors.slice(0, 3),
    ...randomTokens.slice(0, 3),
  ];
  
  // Fetch current prices
  const prices = await getTokenPrices(selectedTokens.map(t => t.address));
  
  // Calculate amounts to match target value
  const distribution = [];
  const valuePerToken = targetValue / selectedTokens.length;
  
  for (const token of selectedTokens) {
    const price = prices[token.address.toLowerCase()].price;
    const amount = Math.floor((valuePerToken / price) * Math.pow(10, token.decimals));
    distribution.push({ token, amount });
  }
  
  return distribution;
}
```

## Troubleshooting

### Issue: "All sources failed"

**Solutions:**
1. Check internet connection
2. Verify token address is valid Base mainnet contract
3. Check if token exists on CoinGecko/Moralis
4. Clear cache and retry

### Issue: Rate limit exceeded

**Solutions:**
1. Cache is working correctly - prices reuse cached values
2. Reduce frequency of price fetches
3. Use batch requests instead of individual calls

### Issue: Prices seem outdated

**Solutions:**
1. Prices cached for 5 minutes - this is intentional
2. Call `clearPriceCache()` to force refresh (testing only)
3. Adjust `CACHE_TTL` if needed

## Future Enhancements

- [ ] Add DeFiLlama as tertiary fallback
- [ ] Implement WebSocket for real-time prices
- [ ] Add price change percentage (24h)
- [ ] Support for multiple chains
- [ ] Historical price data
- [ ] Price alerts/notifications

## Support

For issues or questions about the price oracle:
1. Check logs for API errors
2. Test with `npm run test:oracle`
3. Verify API keys are set correctly
4. Check rate limits haven't been exceeded
