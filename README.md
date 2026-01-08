# NFT Rental & Sales Protocol

An EVM protocol for renting and selling ERC-721 assets. This system implements time-based access rights via ERC-4907, escrow management, and atomic buy/sell operations.

## Features

### Time-Based Rentals
- **Fixed Duration**: Rentals have explicit start and end timestamps.
- **ERC-4907 Implementation**: Uses the `userOf` standard to assign usage rights without transferring ownership.
- **O(1) Scheduling**: Uses mapping-based lookups to prevent gas loops during rental checks.

### Sales & Marketplace
- **Atomic Sales**: `SalesManager` enables fixed-price NFT sales.
- **Rental Constraints**: Active rentals prevent ownership transfers until the rental period expires.
- **Pull Payments**: All value transfers use a withdraw pattern.

### Security Architecture
- **Pull-Payment Pattern**: Funds are stored in `Escrow` and only moved upon explicit user withdrawal.
- **Reentrancy Protection**: `ReentrancyGuard` is applied to all state-changing financial functions.
- **State Limits**: Array iterations are replaced with constant-time operations to avoid Denial of Service.

### Protocol Management
- **Protocol Fees**: Admin-configurable fee basis points on rental transactions.
- **Royalties**: Supports ERC-2981 for secondary sale royalties.

---

## Architecture

### Contracts

1.  **`Rentable721.sol`**
    -   ERC-721 token with ERC-4907 extension.
    -   Overrides `transferFrom` to block transfers of rented assets.

2.  **`RentalManager.sol`**
    -   Entry point for `rent` and `checkIn` transactions.
    -   Validates availability and calculates costs.
    -   Routes funds to `Escrow`.

3.  **`SalesManager.sol`**
    -   Entry point for `list` and `buy` transaction.
    -   Validates ownership and rental status before execution.

4.  **`Escrow.sol`**
    -   Custody contract for ETH.
    -   Maps user balances for withdrawal.

5.  **`ListingManager.sol`**
    -   Data storage for listing configurations (price, duration limits).

---

## Usage

### Prerequisites
-   Foundry

### Build
```bash
forge build
```

### Test
```bash
forge test
```

### Simulation
Run the local deployment script to verify the lifecycle (Mint -> Rent -> Sell):
```bash
forge script script/Demo.s.sol
```

### Deployment
```bash
forge script script/Demo.s.sol --rpc-url <RPC_URL> --private-key <KEY> --broadcast
```

## License
MIT
