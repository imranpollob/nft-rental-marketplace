# NFT Rental Marketplace

A comprehensive full-stack NFT rental marketplace built with Solidity, Foundry, Next.js, and TypeScript. This platform enables NFT owners to list their assets for time-based rentals while providing renters with temporary access to exclusive digital assets.

---

## 🚀 Features

### Core Rental System
- **Time-based Rentals**: Rent NFTs for specific durations with precise start/end times
- **Conflict Prevention**: Advanced overlap detection prevents double-booking
- **Secure Escrow**: Funds are held safely until rental completion
- **Protocol Fees**: Configurable fee structure with automatic distribution

### Royalty Support
- **ERC-2981 Compatible**: Standard royalty implementation for secondary sales
- **Configurable Rates**: Default 5% royalty to original creators

### Advanced Security
- **Transfer Protection**: Prevents unauthorized transfers during active rentals
- **Role-based Access**: Marketplace-controlled user assignment for rentals
- **Reentrancy Guards**: Protection against common smart contract vulnerabilities
- **Ownership Validation**: Race condition prevention for listing changes

---

## 🎨 Frontend Experiences

#### Public Browsing (No Wallet Required)
- **Browse Homepage**: View featured listings, marketplace stats, and "How It Works" guide
- **Explore Listings**: Filter by collection, price range, and search for specific NFTs
- **View NFT Details**: See metadata, pricing, availability, and rental terms for any NFT

#### Wallet Integration
- **Multi-Wallet Support**: MetaMask, WalletConnect, Coinbase Wallet, and more
- **Network Switching**: Switch between Base and Polygon networks
- **Account Management**: View connected address and network status

#### NFT Owners (Asset Management)
- **Create Listings**: List NFTs for rental with custom pricing, duration limits, and deposits
- **Manage Listings**: View all owned listings with status (active/inactive)
- **Edit Listings**: Update pricing, durations, and terms for existing listings
- **Cancel Listings**: Remove listings from the marketplace
- **Track Earnings**: View rental income and transaction history
- **Approve NFTs**: Grant marketplace permission to manage NFT rentals

#### NFT Renters (Rental Experience)
- **Browse Available NFTs**: Discover rentable assets across collections
- **Calculate Costs**: Real-time pricing with duration selection and cost breakdown
- **Rent NFTs**: Secure rental transactions with automatic escrow
- **View Active Rentals**: Track current rentals with live countdown timers
- **Rental History**: View past rentals with transaction receipts and links
- **Conflict Prevention**: Automatic prevention of double-bookings

#### Dashboard & Analytics
- **Owner Dashboard**: Comprehensive view of listings, earnings, and management tools
- **Renter Dashboard**: Active rentals and complete transaction history
- **Account Overview**: Connected wallet and network status
- **Transaction Tracking**: Links to blockchain explorers for all transactions

#### Real-time Features
- **Live Cost Calculation**: Instant pricing updates as users adjust rental periods
- **Countdown Timers**: Real-time countdown for active rentals
- **Status Updates**: Immediate reflection of rental status changes
- **Network Awareness**: Automatic adaptation to connected blockchain network

#### User Interface
- **Responsive Design**: Works perfectly on desktop, tablet, and mobile
- **Loading States**: Smooth loading indicators and skeleton screens
- **Error Boundaries**: Graceful error handling with retry options
- **Toast Notifications**: Real-time feedback for all user actions
- **Optimistic Updates**: UI updates immediately after successful transactions

---

## 🏗️ Architecture

### Core Contracts

#### Rentable721.sol
- ERC-721 compliant NFT with rental extensions
- ERC-4907 interface for user assignment
- Transfer guards during active rentals
- Royalty support via ERC-2981

#### ListingManager.sol
- Manages NFT listings with pricing and availability
- Owner validation and listing lifecycle
- Availability hash for external scheduling

#### RentalManager.sol
- Orchestrates rental transactions
- Conflict checking and fund management
- Integration with escrow system
- Event emission for transparency

#### Escrow.sol
- Secure fund holding during rentals
- Protocol fee calculation and distribution
- Release mechanisms for owners and renters

---

### 🚀 Quick Development Setup

For a **new computer** or **fresh environment**, run the automated setup script:

```bash
# This will start Anvil, deploy all contracts, and configure the frontend
./setup-dev.sh
```

This script will:
- ✅ Check all dependencies (Foundry, Node.js, npm)
- ✅ Start Anvil local Ethereum node
- ✅ Deploy all smart contracts
- ✅ Auto-generate `.env.local` with deployed addresses
- ✅ Install frontend dependencies
- ✅ Test the build

### 🔄 Redeploy Contracts

If you already have the environment set up and just want to redeploy contracts:

```bash
# Make sure Anvil is running
anvil

# In another terminal, redeploy contracts
./redeploy.sh
```

### 📦 NPM Scripts

The project includes convenient npm scripts for common tasks:

```bash
npm run setup        # Run the full development setup
npm run redeploy     # Redeploy contracts only
npm run test         # Run smart contract tests
npm run build        # Build smart contracts
npm run frontend:dev # Start frontend development server
npm run frontend:build # Build frontend for production
npm run frontend:install # Install frontend dependencies
```


## 🧪 Testing

### Smart Contracts
Run the comprehensive test suite:
```bash
forge test
```

**Test Coverage:**
- Unit tests for individual components
- Integration tests for cross-contract interactions
- Rental conflict prevention
- Transfer safety mechanisms
- Royalty calculations
- Access control validation

### Frontend Application
Run the development server:
```bash
cd frontend
npm run dev
```

Build for production:
```bash
npm run build
```

## 📖 Usage

### Local Development

#### Option 1: Automated Setup (Recommended)
```bash
./setup-dev.sh
```

#### Option 2: Manual Setup
Start a local Ethereum node:
```bash
anvil
```

Deploy contracts and update environment:
```bash
./redeploy.sh
```

Start the frontend development server:
```bash
cd frontend
npm run dev
```

### Environment Configuration

The deployment scripts automatically create/update `frontend/.env.local` with deployed contract addresses. For full functionality, add these additional variables:

```bash
# WalletConnect Project ID (get from https://cloud.walletconnect.com/)
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id_here

# Default chain (base or polygon)
NEXT_PUBLIC_DEFAULT_CHAIN=base

# RPC URLs
NEXT_PUBLIC_BASE_RPC_URL=https://mainnet.base.org
NEXT_PUBLIC_POLYGON_RPC_URL=https://polygon-rpc.com

# Contract Addresses (Auto-generated by deployment script)
NEXT_PUBLIC_RENTABLE_721_BASE=0x5fbdb2315678afecb367f032d93f642f64180aa3
NEXT_PUBLIC_LISTING_MANAGER_BASE=0xe7f1725e7734ce288f8367e1bb143e90bb3f0512
NEXT_PUBLIC_RENTAL_MANAGER_BASE=0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0
NEXT_PUBLIC_ESCROW_BASE=0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9
```


#### User Flows

**For NFT Owners:**
1. Connect wallet and navigate to `/owner`
2. Approve NFT for marketplace
3. Create listing with pricing and duration constraints
4. Manage active listings and view earnings

**For NFT Renters:**
1. Connect wallet and browse `/listings`
2. View NFT details and select rental duration
3. Complete rental transaction with secure escrow
4. Access rented NFT during rental period
5. View rental history in `/me`