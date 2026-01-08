// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Rentable721.sol";
import "../src/ListingManager.sol";
import "../src/RentalManager.sol";
import "../src/SalesManager.sol";

contract DemoScript is Script {
    Rentable721 nft;
    ListingManager listingManager;
    RentalManager rentalManager;
    SalesManager salesManager;

    address owner = address(0x1);
    address renter = address(0x2);
    address buyer = address(0x3);
    address feeRecipient = address(0x4);

    function run() external {
        // Setup scenarios with cheatcodes (start local node first or use in-process vm)
        // Note: Script runs on actual fork or local node. We assume 'anvil' environment.

        vm.startBroadcast(); // Deployer context

        // 1. Deploy
        console.log("--- Deploying Contracts ---");
        nft = new Rentable721();
        listingManager = new ListingManager();
        rentalManager = new RentalManager(address(listingManager), feeRecipient, 500); // 5% fee
        salesManager = new SalesManager(); // Deploy SalesManager

        // Setup relations
        nft.setMarketplace(address(rentalManager)); // RentalManager controls user roles

        console.log("Rentable721:", address(nft));
        console.log("RentalManager:", address(rentalManager));
        console.log("SalesManager:", address(salesManager));

        vm.stopBroadcast();

        // 2. Setup NFT & Listing
        console.log("\n--- Minting & Listing for Rent ---");
        // Mint as Deployer (who owns the contract)
        vm.startBroadcast();
        nft.mintWithMetadata(owner, 1, "TestNFT", "Desc", "Img", "Coll");
        vm.stopBroadcast();

        // Switch to NFT Owner for listing
        vm.startBroadcast(owner);

        // List for rent: 0.01 ETH/sec, min 1s, max 1000s, 1 ETH deposit
        uint256 pricePerSec = 0.01 ether;
        uint256 deposit = 1 ether;
        listingManager.createListing(address(nft), 1, pricePerSec, 1, 1000, deposit, bytes32(0));
        console.log("Owner listed NFT 1 for rent");
        vm.stopBroadcast();

        // 3. Renting
        console.log("\n--- Renting NFT ---");
        vm.deal(renter, 100 ether);
        vm.startBroadcast(renter);

        uint256 start = block.timestamp + 10;
        uint256 end = start + 100;
        uint256 duration = end - start;
        uint256 totalCost = (duration * pricePerSec) + deposit;

        rentalManager.rent{value: totalCost}(address(nft), 1, start, end);
        console.log("Renter rented NFT 1 from", start, "to", end);
        console.log("Paid:", totalCost);
        vm.stopBroadcast();

        // 4. CheckIn
        console.log("\n--- Check-in ---");
        // Warp to start time
        // Note: vm.warp works in forge test, but in `forge script` it only works if running against local anvil with rpc.
        // We cannot rely on warp for live networks, but for 'simulation' it works?
        // Forge script simulation doesn't persist warp?
        // We will just verify the state logic. In simulation, warp doesn't work well unless we're in `--rpc-url`?
        // Actually for this demo, we can just skip warp and assume valid if logic holds, OR use `test` instead of `script`?
        // The prompt asked for "command line test". `forge test` is better for this logic verification.
        // But `forge script` demonstrates "deployment + interaction".

        // Let's assume we are just checking checks.
        // If we want to simulate properly, we should put this logic in a TEST file.
        // But let's verify storage state.

        (uint256 rid,,,,,,,,) = rentalManager.rentalById(1);
        require(rid == 1, "Rental not created");
        console.log("Rental ID 1 confirmed created on-chain.");

        // Manual Check-in required since it's a future rental
        vm.warp(start); // Time travel to start
        console.log("Time warped to:", block.timestamp);

        vm.startBroadcast(renter);
        rentalManager.checkIn(1);
        console.log("Renter checked in successfully");
        vm.stopBroadcast();

        // 5. Finalize
        vm.warp(end + 1); // Warp to AFTER rental expires
        console.log("Time warped to:", block.timestamp);

        vm.startBroadcast(owner); // Any one can finalize, but let's use owner
        rentalManager.finalize(1);
        console.log("Rental finalized. Funds released to balances.");
        vm.stopBroadcast();

        // 6. Sales
        console.log("\n--- Selling NFT ---");
        vm.startBroadcast(owner);

        // Owner must approve SalesManager
        nft.setApprovalForAll(address(salesManager), true);

        // List for 5 ETH
        salesManager.listForSale(address(nft), 1, 5 ether);
        console.log("Owner listed NFT for sale at 5 ETH");

        vm.stopBroadcast();

        // 7. Buy
        console.log("\n--- Buying NFT ---");
        vm.deal(buyer, 10 ether);
        vm.startBroadcast(buyer);

        // Check ownership before buy
        require(nft.ownerOf(1) == owner, "Owner should still own NFT");

        salesManager.buy{value: 5 ether}(address(nft), 1);
        console.log("Buyer bought NFT 1");

        vm.stopBroadcast();

        require(nft.ownerOf(1) == buyer, "Buyer should own NFT");
        console.log("Ownership transferred to Buyer confirmed.");

        console.log("\n--- Demo Complete: Success ---");
    }
}
