# NFT Rentals and Sales Protocol

A secure, decentralized protocol for time-based NFT rentals and atomic sales built on the Ethereum Virtual Machine (EVM) using Solidity and Foundry.

## Overview

This protocol enables NFT owners to monetize their digital assets through time-based rentals while maintaining ownership, or sell them outright through a secure marketplace. The system implements the ERC-4907 rentable NFT standard and provides a comprehensive infrastructure for managing rental listings, escrow, and sales.

## Core Features

### 🔐 **ERC-4907 Rentable NFTs**
- Implements the ERC-4907 standard for rentable NFTs
- Separates ownership from usage rights
- Automatic expiration of rental periods
- Transfer protection during active rentals
- Built-in ERC-2981 royalty support (5% to owner)

### 📋 **Flexible Listing Management**
- Create rental listings with customizable parameters:
  - Price per second for granular pricing
  - Minimum and maximum rental durations
  - Optional security deposits
  - Availability scheduling via hash-based system
- Update or cancel listings at any time
- Nonce-based versioning for listing updates

### ⏰ **Time-Based Rental System**
- Book rentals for specific time periods
- Conflict-free scheduling with append-only reservation system (O(1) complexity)
- Automatic check-in functionality for immediate rentals
- Manual check-in option for future reservations
- Secure deposit handling through escrow

### 💰 **Secure Escrow Mechanism**
- Isolated escrow contract for fund management
- Separate balance tracking per user
- Protected deposits for each rental
- Reentrancy protection on all withdrawals
- Release funds after rental completion

### 💸 **Protocol Fees**
- Configurable protocol fee (in basis points)
- Automated fee distribution to protocol treasury
- Owner receives rental payments minus protocol fees
- Renters receive deposit refunds after finalization

### 🛒 **NFT Sales Marketplace**
- List NFTs for direct sale
- Pull payment pattern for security
- Atomic transfers with payment
- Cancel listings at any time
- Reentrancy-protected transactions

### 🔒 **Security Features**
- ReentrancyGuard on all critical functions
- Ownership verification at every step
- Time validation for rental periods
- Conflict prevention for overlapping bookings
- Safe fund withdrawal mechanisms

## Smart Contracts

| Contract             | Description                                                         |
| -------------------- | ------------------------------------------------------------------- |
| `Rentable721.sol`    | ERC-721 NFT with ERC-4907 rental functionality and metadata support |
| `ListingManager.sol` | Manages rental listing creation, updates, and cancellations         |
| `RentalManager.sol`  | Handles rental bookings, check-ins, and finalization                |
| `Escrow.sol`         | Secure fund management for rental deposits and payments             |
| `SalesManager.sol`   | NFT marketplace for buying and selling tokens                       |

## Technical Stack

- **Language**: Solidity ^0.8.20
- **Framework**: Foundry
- **Standards**: ERC-721, ERC-4907, ERC-2981
- **Dependencies**: OpenZeppelin Contracts

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd nft-rentals-and-sales

# Install dependencies
forge install
```

## Testing

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/RentalManager.t.sol
```

## Build

```bash
# Compile contracts
forge build
```

## Deployment

```bash
# Deploy to local network
npm run deploy:local

# Or use forge script directly
forge script script/Deploy.s.sol --rpc-url <your-rpc-url> --broadcast --verify
```

## Usage Flow

### Renting an NFT

1. **List for Rent**: NFT owner creates a listing with rental terms
2. **Book Rental**: Renter pays for desired time period + deposit
3. **Check-in**: Rental activates (automatic or manual)
4. **Usage Period**: Renter has usage rights for the duration
5. **Finalize**: After expiration, funds are distributed and deposit refunded

### Selling an NFT

1. **List for Sale**: NFT owner sets a fixed price
2. **Purchase**: Buyer pays the exact price
3. **Transfer**: NFT is atomically transferred to buyer
4. **Withdraw**: Seller withdraws funds from balance

## Project Structure

```
├── src/
│   ├── Rentable721.sol          # Rentable NFT implementation
│   ├── ListingManager.sol       # Listing management
│   ├── RentalManager.sol        # Rental operations
│   ├── Escrow.sol              # Fund escrow
│   └── SalesManager.sol        # Sales marketplace
├── test/
│   ├── Integration.t.sol        # Integration tests
│   ├── RentalManager.t.sol     # Rental tests
│   ├── SalesManager.t.sol      # Sales tests
│   └── ...                     # Additional tests
├── script/
│   ├── Deploy.s.sol            # Deployment script
│   └── Demo.s.sol              # Demo script
└── lib/
    ├── forge-std/              # Forge standard library
    └── openzeppelin-contracts/ # OpenZeppelin contracts
```

## License

MIT

## Security Considerations

- Always verify NFT ownership before transactions
- Rentals cannot overlap due to append-only scheduling
- All fund transfers use reentrancy protection
- NFTs are locked during active rentals
- Pull payment pattern prevents failed transfers from blocking operations

---

Built with ❤️ using Foundry and OpenZeppelin
