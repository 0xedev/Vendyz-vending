# 🎰 Vendyz Vending Machine

> Anonymous wallet vending machine with gamified randomness

## What is This?

Vendyz is a blockchain-based vending machine that dispenses **pre-funded anonymous Ethereum wallets**. You pay a fixed price (20, 50, or 100 USDC) and receive a random wallet containing coins, NFTs, and liquidity positions. The wallet is completely anonymous and not linked to your purchasing address.

**It's gambling meets privacy tech.**

## 🎯 Three Modes

### 1. 🎰 Vending Machine Mode (Gacha)

Pay a fixed price, get a random anonymous wallet:

| Tier   | Cost     | Output Range      | Expected Value |
| ------ | -------- | ----------------- | -------------- |
| Bronze | 20 USDC  | 5-30 USDC worth   | ~18 USDC       |
| Silver | 50 USDC  | 5-75 USDC worth   | ~45 USDC       |
| Gold   | 100 USDC | 10-150 USDC worth | ~90 USDC       |

**Contents**: Random mix of ERC-20 tokens, NFTs, and Uniswap V3 LP positions

### 2. 🎫 Raffle Mode

Community lottery with better odds:

- **Entry**: 1 USDC per ticket (max 5 per wallet)
- **Prize**: Winner gets wallet with 90% of total pot
- **Example**: 100 tickets sold → Winner gets wallet with 90 USDC worth of assets

### 3. 💰 Sponsor Auctions

Projects can bid to have their tokens included:

- **Frequency**: Every 30 days
- **Format**: Highest bidders get guaranteed placement
- **Benefit**: Exposure to all vending machine users

## 🔒 Privacy & Anonymity

- **No KYC**: Just connect wallet and pay
- **No Tracking**: Anonymous wallet not linked to you
- **No Access**: Platform never stores your private key
- **One-Time Display**: Private key shown once, then deleted forever

## 🎲 House Edge

- **10% average edge** across all modes
- Users win back ~90% on average
- Some wallets contain more, some contain less
- Provably fair randomness via Chainlink VRF

## 🏗️ Project Structure

```
Vendyz-vending/
├── contracts/          # Solidity smart contracts
│   ├── VendingMachine.sol
│   ├── RaffleManager.sol
│   ├── SponsorAuction.sol
│   └── RandomnessProvider.sol
├── backend/           # Node.js services
│   ├── wallet-service/
│   ├── asset-service/
│   └── event-listener/
├── frontend/          # Next.js web app
│   ├── app/
│   ├── components/
│   └── lib/
├── docs/             # Documentation
├── scripts/          # Deployment scripts
└── tests/           # Test suites
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- pnpm or npm
- Hardhat
- MetaMask or similar wallet

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/Vendyz-vending.git
cd Vendyz-vending

# Install dependencies for all packages
pnpm install

# Set up environment variables
cp .env.example .env
# Edit .env with your values

# Compile smart contracts
pnpm contracts:compile

# Run tests
pnpm contracts:test

# Deploy to testnet
pnpm contracts:deploy:testnet

# Start backend services
pnpm backend:dev

# Start frontend
pnpm frontend:dev
```

### Environment Variables

```bash
# Blockchain
PRIVATE_KEY=your_deployer_private_key
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
CHAINLINK_VRF_COORDINATOR=0x...
CHAINLINK_SUBSCRIPTION_ID=123

# Backend
DATABASE_URL=postgresql://user:pass@localhost:5432/Vendyz
HOT_WALLET_PRIVATE_KEY=your_hot_wallet_key
ASSET_POOL_ADDRESS=0x...

# Frontend
NEXT_PUBLIC_CONTRACT_ADDRESS=0x...
NEXT_PUBLIC_CHAIN_ID=1
```

## 📚 Documentation

- [Project Overview](./PROJECT_OVERVIEW.md) - High-level concept and features
- [Technical Specification](./TECHNICAL_SPEC.md) - Detailed architecture and implementation
- [Smart Contract Docs](./docs/contracts.md) - Contract interfaces and usage
- [API Documentation](./docs/api.md) - Backend API endpoints
- [User Guide](./docs/user-guide.md) - How to use the platform

## 🛠️ Development

### Smart Contracts

```bash
cd contracts

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy locally
npx hardhat node
npx hardhat run scripts/deploy.js --network localhost

# Verify on Etherscan
npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS
```

### Backend Services

```bash
cd backend

# Run in development
npm run dev

# Run tests
npm test

# Build for production
npm run build

# Start production server
npm start
```

### Frontend

```bash
cd frontend

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start

# Run tests
npm test
```

## 🧪 Testing

```bash
# Run all tests
pnpm test

# Run contract tests only
pnpm contracts:test

# Run backend tests
pnpm backend:test

# Run frontend tests
pnpm frontend:test

# Run with coverage
pnpm test:coverage
```

## 🔐 Security

- Smart contracts audited by [Audit Firm]
- Chainlink VRF for provable randomness
- Multi-sig treasury management
- Private keys never stored unencrypted
- Auto-delete mechanism for sensitive data

**Bug Bounty**: Report vulnerabilities to security@Vendyz.vending

## 📊 Analytics Dashboard

Track platform metrics:

- Total volume traded
- House edge realization
- User retention
- Asset pool performance
- Raffle participation
- Sponsor ROI

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## ⚖️ Legal & Compliance

**Warning**: This platform involves gambling and may not be legal in all jurisdictions.

- Consult local laws before using
- Platform may geo-block restricted regions
- No guarantees on returns
- Use at your own risk
- May require gambling license to operate

## 📝 License

This project is licensed under the MIT License - see [LICENSE.md](./LICENSE.md) for details.

## 🔗 Links

- **Website**: [Vendyz.vending](https://Vendyz.vending)
- **Twitter**: [@VendyzVending](https://twitter.com/VendyzVending)
- **Discord**: [Join Community](https://discord.gg/Vendyz)
- **Docs**: [docs.Vendyz.vending](https://docs.Vendyz.vending)
- **Audit**: [View Audit Report](./audits/report.pdf)

## 🙏 Acknowledgments

- [Chainlink VRF](https://chain.link/vrf) for provable randomness
- [OpenZeppelin](https://openzeppelin.com/) for secure contract templates
- [Uniswap](https://uniswap.org/) for LP position integration
- Community testers and early adopters

## 📈 Roadmap

### Phase 1: MVP (Q1 2024)

- [x] Core vending machine functionality
- [x] Raffle system
- [x] Basic UI/UX
- [ ] Testnet deployment
- [ ] Internal testing

### Phase 2: Launch (Q2 2024)

- [ ] Smart contract audit
- [ ] Mainnet deployment
- [ ] Marketing campaign
- [ ] Sponsor auction system

### Phase 3: Expansion (Q3 2024)

- [ ] Multi-chain support (Polygon, Base, Arbitrum)
- [ ] Mobile app
- [ ] Advanced analytics
- [ ] Referral system

### Phase 4: DAO (Q4 2024)

- [ ] Governance token launch
- [ ] DAO formation
- [ ] Community-driven asset selection
- [ ] Revenue sharing mechanism

## 💬 Support

Need help?

- **Discord**: [Join our server](https://discord.gg/Vendyz)
- **Email**: support@Vendyz.vending
- **Twitter**: [@VendyzVending](https://twitter.com/VendyzVending)
- **Documentation**: [docs.Vendyz.vending](https://docs.Vendyz.vending)

---

**Disclaimer**: Gambling involves risk. Never gamble more than you can afford to lose. This platform is for entertainment purposes. No guarantees are made regarding returns.

Made with 🎰 by the Vendyz team

# Vendyz-vending
