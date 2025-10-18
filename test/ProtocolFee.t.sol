// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RentalManager.sol";
import "../src/ListingManager.sol";
import "../src/Rentable721.sol";

contract ProtocolFeeTest is Test {
    RentalManager rentalManager;
    ListingManager listingManager;
    Rentable721 nft;
    address owner;
    address renter;
    address feeRecipient;
    address other;
    uint256 tokenId = 1;

    function setUp() public {
        owner = makeAddr("owner");
        renter = makeAddr("renter");
        feeRecipient = makeAddr("feeRecipient");
        other = makeAddr("other");
        vm.deal(address(this), 100 ether);
        vm.deal(renter, 100 ether);
        vm.deal(other, 100 ether);
        
        vm.prank(owner);
        nft = new Rentable721();
        listingManager = new ListingManager();
        
        vm.prank(owner);
        nft.setMarketplace(address(rentalManager)); // This will be set after rentalManager is created
    }

    function testProtocolFeeWith10Percent() public {
        // Create RentalManager with 10% fee (1000 basis points)
        RentalManager tenPercentManager = new RentalManager(address(listingManager), feeRecipient, 1000); // 10% fee
        
        vm.prank(owner);
        nft.setMarketplace(address(tenPercentManager));

        vm.prank(owner);
        nft.mint(owner, tokenId);

        vm.prank(owner);
        nft.setApprovalForAll(address(tenPercentManager), true);

        vm.prank(owner);
        listingManager.createListing(address(nft), tokenId, uint256(1 ether) / 3600, 3600, 86400, 0.1 ether, bytes32(0)); // 1 eth/hour

        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600; // 1 hour rental
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 cost = 3600 * listing.pricePerSecond; // 1 ether for 1 hour
        uint256 total = cost + listing.deposit;

        // Record balances before
        uint256 ownerBalanceBefore = owner.balance;
        uint256 feeRecipientBalanceBefore = feeRecipient.balance;

        vm.prank(renter);
        tenPercentManager.rent{value: total}(address(nft), tokenId, start, end);

        // Warp to after rental expires
        vm.warp(end + 1);

        vm.prank(renter);
        tenPercentManager.finalize(1, address(nft), tokenId);

        // Check that 10% went to fee recipient and 90% to owner
        uint256 expectedFee = cost * 1000 / 10000; // 10% fee
        uint256 expectedOwnerAmount = cost - expectedFee;
        
        assertEq(owner.balance, ownerBalanceBefore + expectedOwnerAmount);
        assertEq(feeRecipient.balance, feeRecipientBalanceBefore + expectedFee);
    }
    
    function testProtocolFeeWith0Percent() public {
        // Create RentalManager with 0% fee (0 basis points)
        address zeroFeeRecipient = makeAddr("zeroFeeRecipient");
        RentalManager zeroPercentManager = new RentalManager(address(listingManager), zeroFeeRecipient, 0); // 0% fee
        
        vm.prank(owner);
        nft.setMarketplace(address(zeroPercentManager));

        vm.prank(owner);
        nft.mint(owner, 2); // Use different tokenId

        vm.prank(owner);
        nft.setApprovalForAll(address(zeroPercentManager), true);

        vm.prank(owner);
        listingManager.createListing(address(nft), 2, uint256(1 ether) / 3600, 3600, 86400, 0.1 ether, bytes32(0)); // 1 eth/hour

        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600; // 1 hour rental
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), 2);
        uint256 cost = 3600 * listing.pricePerSecond; // 1 ether for 1 hour
        uint256 total = cost + listing.deposit;

        // Record balances before
        uint256 ownerBalanceBefore = owner.balance;
        uint256 zeroFeeRecipientBalanceBefore = zeroFeeRecipient.balance;

        vm.prank(renter);
        zeroPercentManager.rent{value: total}(address(nft), 2, start, end);

        // Warp to after rental expires
        vm.warp(end + 1);

        vm.prank(renter);
        zeroPercentManager.finalize(1, address(nft), 2);

        // Check that 0% went to fee recipient and 100% to owner
        uint256 expectedFee = cost * 0 / 10000; // 0% fee
        uint256 expectedOwnerAmount = cost - expectedFee;
        
        assertEq(owner.balance, ownerBalanceBefore + expectedOwnerAmount); // Should receive full amount
        assertEq(zeroFeeRecipient.balance, zeroFeeRecipientBalanceBefore + expectedFee); // Should receive nothing
    }
    
    function testProtocolFeeWith25Percent() public {
        // Create RentalManager with 25% fee (2500 basis points)
        address highFeeRecipient = makeAddr("highFeeRecipient");
        RentalManager twentyFivePercentManager = new RentalManager(address(listingManager), highFeeRecipient, 2500); // 25% fee
        
        vm.prank(owner);
        nft.setMarketplace(address(twentyFivePercentManager));

        vm.prank(owner);
        nft.mint(owner, 3); // Use different tokenId

        vm.prank(owner);
        nft.setApprovalForAll(address(twentyFivePercentManager), true);

        vm.prank(owner);
        listingManager.createListing(address(nft), 3, uint256(1 ether) / 3600, 3600, 86400, 0.1 ether, bytes32(0)); // 1 eth/hour

        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600; // 1 hour rental
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), 3);
        uint256 cost = 3600 * listing.pricePerSecond; // 1 ether for 1 hour
        uint256 total = cost + listing.deposit;

        // Record balances before
        uint256 ownerBalanceBefore = owner.balance;
        uint256 highFeeRecipientBalanceBefore = highFeeRecipient.balance;

        vm.prank(renter);
        twentyFivePercentManager.rent{value: total}(address(nft), 3, start, end);

        // Warp to after rental expires
        vm.warp(end + 1);

        vm.prank(renter);
        twentyFivePercentManager.finalize(1, address(nft), 3);

        // Check that 25% went to fee recipient and 75% to owner
        uint256 expectedFee = cost * 2500 / 10000; // 25% fee
        uint256 expectedOwnerAmount = cost - expectedFee;
        
        assertEq(owner.balance, ownerBalanceBefore + expectedOwnerAmount);
        assertEq(highFeeRecipient.balance, highFeeRecipientBalanceBefore + expectedFee);
    }
    

}