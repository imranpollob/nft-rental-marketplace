// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RentalManager.sol";
import "../src/ListingManager.sol";
import "../src/Rentable721.sol";

contract RentalManagerTest is Test {
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
        vm.deal(renter, 2 ether);
        vm.deal(other, 2 ether);
        vm.prank(owner);
        nft = new Rentable721();
        listingManager = new ListingManager();
        rentalManager = new RentalManager(address(listingManager), feeRecipient, 500); // 5% fee

        vm.prank(owner);
        nft.setMarketplace(address(rentalManager));

        vm.prank(owner);
        nft.mint(owner, tokenId);

        vm.prank(owner);
        nft.setApprovalForAll(address(rentalManager), true);

        vm.prank(owner);
        listingManager.createListing(address(nft), tokenId, uint256(1 ether) / 3600, 3600, 86400, 0.1 ether, bytes32(0)); // 1 eth/hour, min 1h, max 1d, deposit 0.1

        // Check that the listing is active
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        assertTrue(listing.active, "Listing should be active after creation");
    }

    function testRent() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 expectedCost = (end - start) * listing.pricePerSecond;
        uint256 expectedDeposit = listing.deposit;

        uint256 renterBalanceBefore = renter.balance;

        vm.prank(renter);
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, start, end);

        RentalManager.Rental[] memory rs = rentalManager.getRentals(address(nft), tokenId);
        assertEq(rs.length, 1);
        assertEq(rs[0].renter, renter);
        assertEq(rs[0].start, start);
        assertEq(rs[0].end, end);
        assertEq(rs[0].amount, expectedCost);
        assertEq(rs[0].deposit, expectedDeposit);
        assertFalse(rs[0].finalized);

        assertEq(nft.userOf(tokenId), renter);
        assertEq(address(rentalManager.escrow()).balance, expectedCost + expectedDeposit);

        assertEq(renter.balance, renterBalanceBefore - (expectedCost + expectedDeposit));
    }

    function testRentOverlap() public {
        uint256 start1 = block.timestamp + 100;
        uint256 end1 = start1 + 3600;
        vm.deal(renter, 2 ether);
        vm.prank(renter);
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, start1, end1);

        // Overlapping
        uint256 start2 = start1 + 1800;
        uint256 end2 = end1 + 1800;
        vm.prank(other);
        vm.deal(other, 2 ether);
        vm.expectRevert("RentalManager: time conflict");
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, start2, end2);
    }

    function testRentNoOverlap() public {
        uint256 start1 = block.timestamp + 100;
        uint256 end1 = start1 + 3600;
        vm.deal(renter, 2 ether);
        vm.prank(renter);
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, start1, end1);

        // Non-overlapping
        uint256 start2 = end1 + 100;
        uint256 end2 = start2 + 3600;
        vm.prank(other);
        vm.deal(other, 2 ether);
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, start2, end2);

        RentalManager.Rental[] memory rs = rentalManager.getRentals(address(nft), tokenId);
        assertEq(rs.length, 2);
    }

    function testFinalize() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        vm.prank(renter);
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, start, end);

        vm.warp(end + 1);

        uint256 ownerBalanceBefore = owner.balance;
        uint256 feeBalanceBefore = feeRecipient.balance;
        uint256 renterBalanceBefore = renter.balance;

        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 cost = (end - start) * listing.pricePerSecond;
        uint256 fee = cost * rentalManager.protocolFeeBps() / 10_000;
        uint256 ownerShare = cost - fee;

        vm.prank(other); // anyone can finalize
        rentalManager.finalize(1, address(nft), tokenId);

        RentalManager.Rental[] memory rs = rentalManager.getRentals(address(nft), tokenId);
        assertTrue(rs[0].finalized);

        // Payouts: rent minus fee to owner, fee to protocol, deposit back to renter
        assertEq(owner.balance, ownerBalanceBefore + ownerShare);
        assertEq(feeRecipient.balance, feeBalanceBefore + fee);
        assertEq(renter.balance, renterBalanceBefore + listing.deposit);

        // User expired
        assertEq(nft.userOf(tokenId), address(0));
        assertEq(address(rentalManager.escrow()).balance, 0);
    }

    function testRentInsufficientPayment() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        vm.deal(renter, 1 ether);
        vm.prank(renter);
        vm.expectRevert("RentalManager: insufficient payment");
        rentalManager.rent{value: 1 ether}(address(nft), tokenId, start, end);
    }

    function testRentInvalidTimes() public {
        vm.deal(renter, 2 ether);
        vm.prank(renter);
        vm.expectRevert("RentalManager: invalid times");
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, block.timestamp + 200, block.timestamp + 100);
    }

    function testFinalizeBeforeExpiry() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        vm.deal(renter, 2 ether);
        vm.prank(renter);
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, start, end);

        vm.prank(other);
        vm.expectRevert("RentalManager: not expired");
        rentalManager.finalize(1, address(nft), tokenId);
    }

    function testRentDurationOutOfRange() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 1800; // 30 min, below min 1h
        vm.deal(renter, 2 ether);
        vm.prank(renter);
        vm.expectRevert("RentalManager: duration out of range");
        rentalManager.rent{value: 0.6 ether}(address(nft), tokenId, start, end);
    }
    
    function testRentAtCurrentTimestamp() public {
        uint256 start = block.timestamp; // Rent starting at current time
        uint256 end = start + 3600; // 1 hour
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 total = 3600 * listing.pricePerSecond + listing.deposit;

        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start, end);

        RentalManager.Rental[] memory rs = rentalManager.getRentals(address(nft), tokenId);
        assertEq(rs.length, 1);
        assertEq(rs[0].start, start);
        assertEq(rs[0].end, end);
    }
    
    function testRentStartTimeInPast() public {
        // Warp to ensure we have a reasonable timestamp
        vm.warp(1000000); // Set a reasonable timestamp value
        vm.deal(renter, 2 ether);
        // Test start time in the past - this should fail with "invalid times" because start >= block.timestamp
        vm.expectRevert("RentalManager: invalid times");
        vm.prank(renter);
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, 999900, 1000100); // Past start time
    }
    
    function testRentEndBeforeStart() public {
        vm.warp(1000000); // Ensure we have a reasonable timestamp
        vm.deal(renter, 2 ether);
        // Test end before start - this should fail with "invalid times" because start < end
        vm.expectRevert("RentalManager: invalid times");
        vm.prank(renter);
        rentalManager.rent{value: 1.1 ether}(address(nft), tokenId, 1000200, 1000100); // end < start
    }
    
    function testRentBoundaryOverlapStart() public {
        // Test when new rental starts exactly when existing rental ends (should not conflict)
        uint256 start1 = 1000000;
        uint256 end1 = 1003600; // 1 hour later (minimum duration)
        vm.warp(start1 - 500);
        vm.deal(renter, 2 ether);
        vm.deal(other, 2 ether);
        
        // Get listing to calculate proper payment
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 cost1 = (end1 - start1) * listing.pricePerSecond; // 1 hour cost = 1 ether
        uint256 total1 = cost1 + listing.deposit; // 1.1 ether total
        
        // Create first rental
        vm.prank(renter);
        rentalManager.rent{value: total1}(address(nft), tokenId, start1, end1);
        
        // Second rental starts exactly when first ends (should succeed)
        uint256 start2 = end1;
        uint256 end2 = end1 + 3600; // Another 1 hour
        uint256 cost2 = (end2 - start2) * listing.pricePerSecond; // 1 hour cost = 1 ether
        uint256 total2 = cost2 + listing.deposit; // 1.1 ether total
        
        vm.prank(other);
        rentalManager.rent{value: total2}(address(nft), tokenId, start2, end2);
        
        RentalManager.Rental[] memory rs = rentalManager.getRentals(address(nft), tokenId);
        assertEq(rs.length, 2);
    }
    
    function testRentCompleteOverlap() public {
        // Test when one rental completely encompasses another
        uint256 start1 = 1000000;
        uint256 end1 = 1010800; // 3 hours (within max duration)
        uint256 start2 = 1003600;  // Starts 1 hour after first rental starts (during first rental)
        uint256 end2 = 1007200;    // Ends 2 hours after first rental starts (during first rental, 1 hour duration)
        vm.warp(999500);
        vm.deal(renter, 4 ether);
        vm.deal(other, 2 ether);
        
        // Create first rental (3 hours = 3 ether cost + 0.1 deposit = 3.1 total)
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 cost1 = (end1 - start1) * listing.pricePerSecond; // 3 hours cost = 3 ether
        uint256 total1 = cost1 + listing.deposit; // 3.1 ether total
        
        vm.prank(renter);
        rentalManager.rent{value: total1}(address(nft), tokenId, start1, end1);
        
        // Try to create rental that's completely within the first one (should fail due to conflict)
        uint256 cost2 = (end2 - start2) * listing.pricePerSecond; // 1 hour cost = 1 ether
        uint256 total2 = cost2 + listing.deposit; // 1.1 ether total
        
        vm.expectRevert("RentalManager: time conflict");
        vm.prank(other);
        rentalManager.rent{value: total2}(address(nft), tokenId, start2, end2);
    }
    
    function testRentMultipleOverlaps() public {
        // Test creating multiple rentals and then trying to book overlapping with all
        uint256 start1 = 1000000;
        uint256 end1 = 1003600; // 1 hour
        uint256 start2 = 1007200; // Start after first ends
        uint256 end2 = 1010800; // 1 hour
        uint256 start3 = 1014400;  // Start after second ends
        uint256 end3 = 1018000; // 1 hour
        vm.warp(999500);
        vm.deal(renter, 4 ether);
        vm.deal(other, 2 ether);
        
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        
        // Create multiple non-overlapping rentals (1 hour each = 1.1 ether each)
        uint256 cost = 3600 * listing.pricePerSecond; // 1 hour cost = 1 ether
        uint256 total = cost + listing.deposit; // 1.1 ether total
        
        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start1, end1);
        
        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start2, end2);
        
        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start3, end3);
        
        // Try to create one that overlaps with the second rental (should fail)
        uint256 overlapStart = start2 + 1800; // 30 min into second rental
        uint256 overlapEnd = end2 + 1800; // Extends past second rental end
        uint256 overlapCost = (overlapEnd - overlapStart) * listing.pricePerSecond; // 1.5 hours = 1.5 ether
        uint256 overlapTotal = overlapCost + listing.deposit; // 1.6 ether total
        
        vm.expectRevert("RentalManager: time conflict");
        vm.prank(other);
        rentalManager.rent{value: overlapTotal}(address(nft), tokenId, overlapStart, overlapEnd);
        
        // Verify all original rentals still exist
        RentalManager.Rental[] memory rs = rentalManager.getRentals(address(nft), tokenId);
        assertEq(rs.length, 3);
    }
}