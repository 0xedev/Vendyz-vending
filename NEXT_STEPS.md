# Vendyz - Next Steps & Deployment Guide

## 📋 Current Status

### ✅ Completed Components

1. **Smart Contracts** (Base Mainnet - Deployed)
   - VendingMachine: `0x12e3390140A4fb3424493F039aE695AA2d7AaE9a`
   - SponsorAuction: `0xf4b0943587Ac61Be0Eaed8Ed0fCd45505F72c049`
   - RaffleManager: `0x3C20Bd88d2E29Ae66829Ced86209B0150A576DBF`
   - TokenTreasury: `0x194A3440A2E11b8eDBCf69d7f14304cA92a75513`

2. **Frontend** (Next.js 15 + React 19)
   - Complete UI for all features
   - Error handling & validation
   - Transaction tracking
   - Loading states & skeletons
   - Analytics dashboard
   - Emergency functions

3. **Backend Service**
   - Event listener (WalletReady)
   - Wallet generation (BIP39)
   - Token selection algorithm (treasury-based)
   - Price oracle (CoinGecko + Moralis)
   - Test suites

### ⏳ Pending Tasks

## 🚀 Phase 1: Backend Authorization & Funding (15 minutes)

### Step 1.1: Generate Backend Wallet

```bash
cd backend
npm install
node -p "require('crypto').randomBytes(32).toString('hex')"
# Output: YOUR_BACKEND_PRIVATE_KEY (save this!)
```

### Step 1.2: Fund Backend Wallet with ETH (Gas)

```bash
# Send 0.05 ETH to backend address for gas fees
# Get address: npm run setup (it will show the address)
```

### Step 1.3: Authorize Backend in TokenTreasury

As TokenTreasury owner:

```solidity
// Connect with owner wallet to Base mainnet
// Call on 0x194A3440A2E11b8eDBCf69d7f14304cA92a75513

TokenTreasury.authorizeBackend("YOUR_BACKEND_ADDRESS")
```

### Step 1.4: Deposit Tokens into TokenTreasury

For each token you want to distribute:

```solidity
// Example: USDC
USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

// 1. Approve
USDC.approve(0x194A3440A2E11b8eDBCf69d7f14304cA92a75513, 10000000000) // 10,000 USDC

// 2. Deposit
TokenTreasury.depositTokens(
  0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // USDC
  10000000000 // 10,000 USDC (6 decimals)
)
```

**Recommended Initial Deposits:**

- USDC: $10,000 (10,000,000,000 with 6 decimals)
- DEGEN: $1,000 worth (~769M DEGEN at current price)
- WETH: $2,000 worth (~0.7 WETH)
- DAI: $2,000 (2,000 \* 10^18)
- Other tokens: Based on preference

### Step 1.5: Configure Backend Environment

```bash
cd backend
cp .env.example .env
nano .env
```

Add these values:

```bash
BASE_RPC_URL=https://mainnet.base.org
BACKEND_PRIVATE_KEY=0x... # From Step 1.1
VENDING_MACHINE_ADDRESS=0x12e3390140A4fb3424493F039aE695AA2d7AaE9a
TOKEN_TREASURY_ADDRESS=0x194A3440A2E11b8eDBCf69d7f14304cA92a75513
SPONSOR_AUCTION_ADDRESS=0xf4b0943587Ac61Be0Eaed8Ed0fCd45505F72c049
USDC_ADDRESS=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
MORALIS_API_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Step 1.6: Verify Setup

```bash
npm run setup
```

Expected output:

```
✅ Backend service initialized
📝 Backend address: 0x...
🔗 Connected to Base mainnet

1️⃣  Backend Address: 0x...
2️⃣  ETH Balance: 0.05 ETH
3️⃣  TokenTreasury Authorization: ✅ Authorized
4️⃣  TokenTreasury Balances:
   ✅ USDC: 10000.0000 tokens
   ✅ DEGEN: 769000000.0000 tokens
   ✅ WETH: 0.7000 tokens
5️⃣  Active Sponsors: 0 tokens

✅ Setup complete! Ready to start service with: npm start
```

---

## 🗄️ Phase 2: Database Integration (1-2 hours)

### Option A: PostgreSQL (Recommended)

#### Install PostgreSQL

```bash
# macOS
brew install postgresql@15
brew services start postgresql@15

# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
```

#### Create Database

```bash
psql postgres
```

```sql
CREATE DATABASE vendyz;
CREATE USER vendyz_user WITH PASSWORD 'secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE vendyz TO vendyz_user;
\c vendyz
GRANT ALL ON SCHEMA public TO vendyz_user;
```

#### Install Node.js Dependencies

```bash
cd backend
npm install pg
```

#### Create Database Schema

Create `backend/src/database.js`:

```javascript
import pg from "pg";
import crypto from "crypto";
import * as dotenv from "dotenv";

dotenv.config();

const { Pool } = pg;

const pool = new Pool({
  connectionString:
    process.env.DATABASE_URL ||
    "postgresql://vendyz_user:secure_password_here@localhost:5432/vendyz",
  ssl:
    process.env.NODE_ENV === "production"
      ? { rejectUnauthorized: false }
      : false,
});

// Encryption
const ENCRYPTION_KEY = Buffer.from(
  process.env.ENCRYPTION_KEY || crypto.randomBytes(32).toString("hex"),
  "hex"
);
const ALGORITHM = "aes-256-cbc";

export function encrypt(text) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGORITHM, ENCRYPTION_KEY, iv);
  let encrypted = cipher.update(text, "utf8", "hex");
  encrypted += cipher.final("hex");
  return iv.toString("hex") + ":" + encrypted;
}

export function decrypt(text) {
  const parts = text.split(":");
  const iv = Buffer.from(parts[0], "hex");
  const encryptedText = parts[1];
  const decipher = crypto.createDecipheriv(ALGORITHM, ENCRYPTION_KEY, iv);
  let decrypted = decipher.update(encryptedText, "hex", "utf8");
  decrypted += decipher.final("utf8");
  return decrypted;
}

// Initialize database tables
export async function initializeDatabase() {
  const client = await pool.connect();

  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS wallets (
        id SERIAL PRIMARY KEY,
        request_id BIGINT UNIQUE NOT NULL,
        buyer_address VARCHAR(42) NOT NULL,
        wallet_address VARCHAR(42) NOT NULL,
        encrypted_private_key TEXT NOT NULL,
        encrypted_mnemonic TEXT NOT NULL,
        tier SMALLINT NOT NULL,
        estimated_value BIGINT NOT NULL,
        actual_value DECIMAL(20, 2),
        tokens_json TEXT,
        created_at TIMESTAMP DEFAULT NOW(),
        retrieved BOOLEAN DEFAULT FALSE,
        retrieved_at TIMESTAMP,
        INDEX idx_request_id (request_id),
        INDEX idx_buyer (buyer_address),
        INDEX idx_created (created_at)
      );
    `);

    console.log("✅ Database tables initialized");
  } catch (error) {
    console.error("❌ Database initialization error:", error);
    throw error;
  } finally {
    client.release();
  }
}

export async function storeWallet(walletData) {
  const client = await pool.connect();

  try {
    const encryptedPrivateKey = encrypt(walletData.privateKey);
    const encryptedMnemonic = encrypt(walletData.mnemonic);

    const result = await client.query(
      `INSERT INTO wallets 
        (request_id, buyer_address, wallet_address, encrypted_private_key, 
         encrypted_mnemonic, tier, estimated_value, actual_value, tokens_json)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id`,
      [
        walletData.requestId,
        walletData.buyer,
        walletData.address,
        encryptedPrivateKey,
        encryptedMnemonic,
        walletData.tier,
        walletData.estimatedValue,
        walletData.actualValue,
        JSON.stringify(walletData.tokens),
      ]
    );

    console.log(`✅ Wallet stored in database (ID: ${result.rows[0].id})`);
    return result.rows[0].id;
  } catch (error) {
    console.error("❌ Database storage error:", error);
    throw error;
  } finally {
    client.release();
  }
}

export async function getWallet(requestId) {
  const client = await pool.connect();

  try {
    const result = await client.query(
      "SELECT * FROM wallets WHERE request_id = $1",
      [requestId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    const wallet = result.rows[0];
    return {
      ...wallet,
      privateKey: decrypt(wallet.encrypted_private_key),
      mnemonic: decrypt(wallet.encrypted_mnemonic),
      tokens: JSON.parse(wallet.tokens_json),
    };
  } catch (error) {
    console.error("❌ Database retrieval error:", error);
    throw error;
  } finally {
    client.release();
  }
}

export async function markWalletRetrieved(requestId) {
  const client = await pool.connect();

  try {
    await client.query(
      "UPDATE wallets SET retrieved = TRUE, retrieved_at = NOW() WHERE request_id = $1",
      [requestId]
    );
    console.log(`✅ Wallet ${requestId} marked as retrieved`);
  } catch (error) {
    console.error("❌ Database update error:", error);
    throw error;
  } finally {
    client.release();
  }
}

export default pool;
```

#### Update index.js to use database

In `backend/src/index.js`, replace the `storeWalletCredentials` function:

```javascript
import { initializeDatabase, storeWallet } from "./database.js";

// Add at startup
(async () => {
  try {
    await initializeDatabase();
    await startEventListener();
  } catch (error) {
    console.error("❌ Failed to start service:", error);
    process.exit(1);
  }
})();

// Replace storeWalletCredentials function
async function storeWalletCredentials(
  requestId,
  buyer,
  walletData,
  tier,
  estimatedValue,
  tokens,
  actualValue
) {
  try {
    await storeWallet({
      requestId: requestId.toString(),
      buyer,
      address: walletData.address,
      privateKey: walletData.privateKey,
      mnemonic: walletData.mnemonic,
      tier,
      estimatedValue: estimatedValue.toString(),
      actualValue,
      tokens: tokens.map((token, i) => ({
        address: token,
        amount: amounts[i].toString(),
      })),
    });
  } catch (error) {
    console.error("❌ Failed to store wallet:", error);
    throw error;
  }
}
```

#### Update .env

```bash
DATABASE_URL=postgresql://vendyz_user:secure_password_here@localhost:5432/vendyz
ENCRYPTION_KEY=your_32_byte_hex_key_here
```

Generate encryption key:

```bash
node -p "require('crypto').randomBytes(32).toString('hex')"
```

---

## 🌐 Phase 3: API Endpoint for Wallet Retrieval (30 minutes)

Create `backend/src/api.js`:

```javascript
import express from "express";
import cors from "cors";
import { getWallet, markWalletRetrieved } from "./database.js";
import { verifyMessage } from "viem";
import rateLimit from "express-rate-limit";

const app = express();
const PORT = process.env.API_PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Retrieve wallet
app.get("/api/wallet/:requestId", async (req, res) => {
  try {
    const { requestId } = req.params;
    const { signature, message } = req.query;

    if (!signature || !message) {
      return res.status(400).json({ error: "Missing signature or message" });
    }

    // Fetch wallet
    const wallet = await getWallet(BigInt(requestId));

    if (!wallet) {
      return res.status(404).json({ error: "Wallet not found" });
    }

    // Verify signature
    const recoveredAddress = await verifyMessage({
      message,
      signature,
    });

    if (recoveredAddress.toLowerCase() !== wallet.buyer_address.toLowerCase()) {
      return res
        .status(403)
        .json({ error: "Unauthorized - signature verification failed" });
    }

    // Mark as retrieved
    await markWalletRetrieved(requestId);

    // Return credentials
    res.json({
      walletAddress: wallet.wallet_address,
      privateKey: wallet.privateKey,
      mnemonic: wallet.mnemonic,
      tier: wallet.tier,
      tokens: wallet.tokens,
      createdAt: wallet.created_at,
    });
  } catch (error) {
    console.error("API error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`✅ API server listening on port ${PORT}`);
});

export default app;
```

Install dependencies:

```bash
npm install express cors express-rate-limit
```

Update `package.json` scripts:

```json
{
  "scripts": {
    "start": "node src/index.js",
    "api": "node src/api.js",
    "dev": "node --watch src/index.js",
    "dev:api": "node --watch src/api.js"
  }
}
```

Run both services:

```bash
# Terminal 1: Event listener
npm start

# Terminal 2: API server
npm run api
```

---

## 🚀 Phase 4: Deployment (1-2 hours)

### Option A: DigitalOcean Droplet (Recommended - $12/month)

#### 1. Create Droplet

- OS: Ubuntu 22.04 LTS
- Plan: Basic - $12/month (2GB RAM)
- Datacenter: Choose closest to users
- Add SSH key

#### 2. SSH into Server

```bash
ssh root@YOUR_SERVER_IP
```

#### 3. Install Dependencies

```bash
# Update system
apt update && apt upgrade -y

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install PostgreSQL
apt install -y postgresql postgresql-contrib

# Install PM2
npm install -g pm2

# Install Nginx (for API proxy)
apt install -y nginx
```

#### 4. Create Database

```bash
sudo -u postgres psql
```

```sql
CREATE DATABASE vendyz;
CREATE USER vendyz_user WITH PASSWORD 'YOUR_SECURE_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE vendyz TO vendyz_user;
\q
```

#### 5. Clone & Setup Project

```bash
cd /opt
git clone https://github.com/YOUR_REPO/vendyz-vending.git
cd vendyz-vending/backend
npm install
```

#### 6. Configure Environment

```bash
nano .env
```

Add all your environment variables (from Phase 1.5)

#### 7. Initialize Database

```bash
node -e "import('./src/database.js').then(db => db.initializeDatabase())"
```

#### 8. Start Services with PM2

```bash
# Start event listener
pm2 start src/index.js --name vendyz-listener

# Start API server
pm2 start src/api.js --name vendyz-api

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
# Run the command it outputs
```

#### 9. Configure Nginx

```bash
nano /etc/nginx/sites-available/vendyz
```

```nginx
server {
    listen 80;
    server_name api.vendyz.xyz;  # Your domain

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/vendyz /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

#### 10. Setup SSL with Let's Encrypt

```bash
apt install -y certbot python3-certbot-nginx
certbot --nginx -d api.vendyz.xyz
```

#### 11. Monitor Services

```bash
# View logs
pm2 logs vendyz-listener
pm2 logs vendyz-api

# Monitor processes
pm2 monit

# View status
pm2 status
```

---

## 📊 Phase 5: Frontend Integration (30 minutes)

Update `vendyz/src/components/WalletRetrieval.tsx`:

```typescript
const BACKEND_API_URL =
  process.env.NEXT_PUBLIC_BACKEND_API_URL || "https://api.vendyz.xyz";

async function retrieveWallet(requestId: bigint) {
  try {
    // 1. Sign message to prove ownership
    const message = `Retrieve wallet for request ${requestId}`;
    const signature = await signMessageAsync({ message });

    // 2. Call backend API
    const response = await fetch(
      `${BACKEND_API_URL}/api/wallet/${requestId}?signature=${signature}&message=${encodeURIComponent(message)}`
    );

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || "Failed to retrieve wallet");
    }

    const data = await response.json();

    // 3. Display credentials to user
    setWalletData({
      address: data.walletAddress,
      privateKey: data.privateKey,
      mnemonic: data.mnemonic,
      tokens: data.tokens,
    });

    toast.success("Wallet retrieved successfully!");
  } catch (error) {
    console.error("Error retrieving wallet:", error);
    toast.error(error.message || "Failed to retrieve wallet");
  }
}
```

Add to `.env.local`:

```bash
NEXT_PUBLIC_BACKEND_API_URL=https://api.vendyz.xyz
```

---

## ✅ Final Checklist

### Before Going Live

- [ ] All contracts deployed and verified on Base
- [ ] Backend authorized in TokenTreasury
- [ ] TokenTreasury funded with tokens ($15,000+ recommended)
- [ ] Backend wallet funded with ETH for gas (0.05+ ETH)
- [ ] Database setup and tested
- [ ] API endpoints tested
- [ ] Backend services running (PM2)
- [ ] Frontend deployed (Vercel/Netlify)
- [ ] SSL certificates installed
- [ ] Monitoring setup (PM2, logs)
- [ ] Test complete flow: Purchase → Fund → Retrieve

### Testing Flow

1. Purchase Tier 1 wallet from frontend ($20)
2. Wait for WalletReady event
3. Backend generates wallet and funds it
4. Check database for stored credentials
5. Retrieve wallet via frontend
6. Verify wallet contains tokens
7. Verify total value matches tier

---

## 🎉 You're Live!

Once all steps are complete:

- Users can purchase wallets
- Backend automatically funds them
- Users can retrieve their credentials
- Monitor via PM2 logs and dashboard

## 📞 Support

Need help? Check:

- Backend logs: `pm2 logs`
- Database: `psql vendyz -c "SELECT * FROM wallets ORDER BY created_at DESC LIMIT 10;"`
- API health: `curl https://api.vendyz.xyz/health`
