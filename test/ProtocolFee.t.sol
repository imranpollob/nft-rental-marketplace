// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RentalManager.sol";
import "../src/ListingManager.sol";
import "../src/Rentable721.sol";
import "../src/Escrow.sol";

contract ProtocolFeeTest is Test {
    RentalManager tenPercentManager;
    RentalManager zeroPercentManager;
    RentalManager twentyFivePercentManager;
    ListingManager listingManager;
    Rentable721 nft;
    Escrow escrow;

    address owner = makeAddr("owner");
    address renter = makeAddr("renter");
    address feeRecipient = makeAddr("feeRecipient");
    uint256 tokenId = 1;

    function setUp() public {
        vm.deal(address(this), 100 ether);
        vm.deal(renter, 100 ether);

        vm.prank(owner);
        listingManager = new ListingManager();

        vm.prank(owner);
        tenPercentManager = new RentalManager(address(listingManager), feeRecipient, 1000); // 10%
        vm.prank(owner);
        zeroPercentManager = new RentalManager(address(listingManager), feeRecipient, 0); // 0%
        vm.prank(owner);
        twentyFivePercentManager = new RentalManager(address(listingManager), feeRecipient, 2500); // 25%

        vm.prank(owner);
        nft = new Rentable721();

        vm.prank(owner);
        nft.mint(owner, 1);
        vm.prank(owner);
        nft.mint(owner, 2);
        vm.prank(owner);
        nft.mint(owner, 3);
        
        // Approvals
        vm.prank(owner);
        nft.setApprovalForAll(address(tenPercentManager), true);
        vm.prank(owner);
        nft.setApprovalForAll(address(zeroPercentManager), true);
        vm.prank(owner);
        nft.setApprovalForAll(address(twentyFivePercentManager), true);

        // We have to set marketplace one by one or allow multiple?
        // Rentable721 has single `marketplace` address that can `setUser`.
        // This test deployment strategy is flawed if we want to test multiple managers against SAME nft contract...
        // But the failing tests were just about balances.
        // Actually `rent` calls `nft.setUser`. If `nft.marketplace` is not the specific manager calling `rent`, it will REVERT.
        // The previous tests probably set marketplace before each test or used one marketplace?
        // Ah, `Rentable721` only allows ONE marketplace address.
        // So for these tests we might need separate NFT contracts or re-set marketplace in each test function?
        // Or just set it to the one we are testing.
        
        vm.prank(owner);
        listingManager.createListing(address(nft), 1, 1 gwei, 3600, 86400, 0.1 ether, bytes32(0));
        vm.prank(owner);
        listingManager.createListing(address(nft), 2, 1 gwei, 3600, 86400, 0.1 ether, bytes32(0));
        vm.prank(owner);
        listingManager.createListing(address(nft), 3, 1 gwei, 3600, 86400, 0.1 ether, bytes32(0));
    }

    function testProtocolFeeWith10Percent() public {
        vm.prank(owner);
        nft.setMarketplace(address(tenPercentManager));

        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        uint256 cost = 3600 * 1 gwei; 
        uint256 total = cost + 0.1 ether;

        vm.prank(renter);
        tenPercentManager.rent{value: total}(address(nft), 1, start, end);

        vm.warp(end + 1);

        vm.prank(renter);
        tenPercentManager.finalize(1);

        // Check balances in Escrow
        // 10% fee
        uint256 expectedFee = cost * 1000 / 10000; 
        uint256 expectedOwnerAmount = cost - expectedFee;

        Escrow esc = tenPercentManager.escrow();

        assertEq(esc.userBalances(owner), expectedOwnerAmount);
        assertEq(esc.userBalances(feeRecipient), expectedFee);
        
        assertEq(esc.userBalances(renter), 0.1 ether);
    }

    function testProtocolFeeWith0Percent() public {
        vm.prank(owner);
        nft.setMarketplace(address(zeroPercentManager));

        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        uint256 cost = 3600 * 1 gwei; 
        uint256 total = cost + 0.1 ether;

        vm.prank(renter);
        zeroPercentManager.rent{value: total}(address(nft), 2, start, end);

        vm.warp(end + 1);

        vm.prank(renter);
        zeroPercentManager.finalize(1);

        uint256 expectedFee = 0;
        uint256 expectedOwnerAmount = cost;

        Escrow esc = zeroPercentManager.escrow();

        assertEq(esc.userBalances(owner), expectedOwnerAmount);
        assertEq(esc.userBalances(feeRecipient), expectedFee);
    }

    function testProtocolFeeWith25Percent() public {
        vm.prank(owner);
        nft.setMarketplace(address(twentyFivePercentManager));

        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        uint256 cost = 3600 * 1 gwei; 
        uint256 total = cost + 0.1 ether;

        vm.prank(renter);
        twentyFivePercentManager.rent{value: total}(address(nft), 3, start, end);

        vm.warp(end + 1);

        vm.prank(renter);
        twentyFivePercentManager.finalize(1);

        uint256 expectedFee = cost * 2500 / 10000; 
        uint256 expectedOwnerAmount = cost - expectedFee;

        Escrow esc = twentyFivePercentManager.escrow();

        assertEq(esc.userBalances(owner), expectedOwnerAmount);
        assertEq(esc.userBalances(feeRecipient), expectedFee);
    }
}