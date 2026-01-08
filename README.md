# NFT Rental & Sales Protocol

A robust, secure, and gas-optimized EVM protocol for renting and selling ERC-721 assets. This system enables time-based access rights (via ERC-4907), secure escrow management, and atomic buy/sell operations, designed for high-scalability and security.

## 🚀 Key Features

### ⏳ Time-Based Rentals
- **Precise Duration**: Rent NFTs for specific time windows with exact start/end timestamps.
- **ERC-4907 Compliance**: Standardized user assignment (`userOf`) allows active renters to utilize assets (e.g., in games or gated communities) without ownership transfer.
- **Append-Only Scheduling**: Optimized O(1) scheduling algorithm prevents gas limit issues (DoS) regardless of historical rental volume.

### 💰 Sales & Marketplace
- **Fixed-Price Listing**: Sell NFTs atomically with `SalesManager`.
- **Rental Protection**: Active rentals block ownership transfers, ensuring renters retain access for their paid duration.
- **Atomic Swaps**: Secure exchange of assets and Rentable721 tokens.

### 🔒 Security First
- **Pull-Payment Pattern**: All fund withdrawals use the "Pull" pattern to prevent reentrancy and locking attacks.
- **Reentrancy Protection**: Critical financial functions are guarded with `ReentrancyGuard`.
- **DoS Prevention**: Unbounded loops have been removed in favor of O(1) mappings and state tracking.

### ⚙️ Protocol Management
- **Configurable Fees**: Protocol admins can adjust fee rates (basis points) and recipients.
- **Royalty Support**: ERC-2981 compatibility ensures creators earn from secondary market activity.

---

## �️ Architecture

### Core Contracts

1.  **`Rentable721.sol`**
    -   An ERC-721 token implementing ERC-4907.
    -   Manages `userOf` roles for renters.
    -   Enforces transfer restrictions during active rental periods.

2.  **`RentalManager.sol`**
    -   The core engine for rental logic.
    -   Handles `rent()`, `checkIn()`, and `finalize()` operations.
    -   Uses an `Escrow` contract to hold funds securely until rental completion.

3.  **`SalesManager.sol`**
    -   Facilitates buy/sell operations.
    -   Ensures sales respect active rental constraints.

4.  **`Escrow.sol`**
    -   Holds rental deposits and payments.
    -   Distributes payouts to owners, protocol, and renters (refunds) upon finalization.
    -   Implements `withdraw()` for users to claim earnings.

5.  **`ListingManager.sol`**
    -   Stores listing parameters (price, min/max duration, deposits).

---

## 🛠️ Development & Usage

### Prerequisites
-   [Foundry](https://book.getfoundry.sh/getting-started/installation) (Forge, Anvil, Cast)

### Build
Compile the smart contracts:
```bash
forge build
```

### Test
Run the comprehensive test suite (Unit + Integration):
```bash
forge test
```
*Current Status: 47/47 Tests Passed*

### CLI Demonstration
Simulate a full lifecycle (Mint -> List -> Rent -> CheckIn -> Finalize -> Sell -> Buy) on a local Anvil chain:
```bash
forge script script/Demo.s.sol
```

### Deployment
To deploy to a live network (e.g., Base Sepolia), use `forge script` with your RPC URL and Private Key:
```bash
forge script script/Demo.s.sol --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
```

---

## 📄 License
MIT