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
        vm.deal(renter, 100 ether);
        vm.deal(other, 100 ether);

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
        listingManager.createListing(address(nft), tokenId, uint256(1 ether) / 3600, 3600, 86400, 0.1 ether, bytes32(0));
    }

    function _getRental(uint256 id) internal view returns (RentalManager.Rental memory) {
        (
            uint256 _id,
            address _nft,
            uint256 _tokenId,
            address _renter,
            uint256 _start,
            uint256 _end,
            uint256 _amount,
            uint256 _deposit,
            bool _finalized
        ) = rentalManager.rentalById(id);
        return RentalManager.Rental(_id, _nft, _tokenId, _renter, _start, _end, _amount, _deposit, _finalized);
    }

    function testRent() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 expectedCost = (end - start) * listing.pricePerSecond;
        uint256 expectedDeposit = listing.deposit;
        uint256 total = expectedCost + expectedDeposit;

        uint256 renterBalanceBefore = renter.balance;

        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start, end);

        RentalManager.Rental memory r = _getRental(1);
        assertEq(r.renter, renter);
        assertEq(r.start, start);
        assertEq(r.end, end);
        assertEq(r.amount, expectedCost);
        assertEq(r.deposit, expectedDeposit);
        assertFalse(r.finalized);

        // Check Escrow Balance (not direct balance since it's properly accounted now)
        assertEq(rentalManager.escrow().rentalDeposits(1), total);
    }

    function testRentOverlap() public {
        uint256 start1 = block.timestamp + 100;
        uint256 end1 = start1 + 3600;
        vm.prank(renter);
        rentalManager.rent{value: 2 ether}(address(nft), tokenId, start1, end1);

        // Overlapping (Start before previous end)
        uint256 start2 = start1 + 1800;
        uint256 end2 = end1 + 1800;

        vm.prank(other);
        vm.expectRevert("RentalManager: time conflict - must book after last rental");
        rentalManager.rent{value: 2 ether}(address(nft), tokenId, start2, end2);
    }

    function testRentNoOverlap() public {
        uint256 start1 = block.timestamp + 100;
        uint256 end1 = start1 + 3600;
        vm.prank(renter);
        rentalManager.rent{value: 2 ether}(address(nft), tokenId, start1, end1);

        // Non-overlapping (Start after previous end)
        uint256 start2 = end1; // Can begin exactly when last ends
        uint256 end2 = start2 + 3600;

        vm.prank(other);
        rentalManager.rent{value: 2 ether}(address(nft), tokenId, start2, end2);

        RentalManager.Rental memory r2 = _getRental(2);
        assertEq(r2.id, 2);
    }

    function testFinalize() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 cost = (end - start) * listing.pricePerSecond;
        uint256 total = cost + listing.deposit;

        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start, end);

        vm.warp(end + 1);

        vm.prank(other);
        rentalManager.finalize(1);

        RentalManager.Rental memory r = _getRental(1);
        assertTrue(r.finalized);

        // Check Balances in Escrow (Pull Payment)
        uint256 fee = cost * rentalManager.protocolFeeBps() / 10000;
        uint256 ownerShare = cost - fee;

        assertEq(rentalManager.escrow().userBalances(owner), ownerShare);
        assertEq(rentalManager.escrow().userBalances(feeRecipient), fee);
        assertEq(rentalManager.escrow().userBalances(renter), listing.deposit);
    }

    function testRentInsufficientPayment() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        vm.prank(renter);
        vm.expectRevert("RentalManager: insufficient payment");
        rentalManager.rent{value: 0.1 ether}(address(nft), tokenId, start, end);
    }

    function testRentInvalidTimes() public {
        vm.prank(renter);
        vm.expectRevert("RentalManager: invalid times");
        rentalManager.rent{value: 2 ether}(address(nft), tokenId, block.timestamp + 200, block.timestamp + 100);
    }

    function testFinalizeBeforeExpiry() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        vm.prank(renter);
        rentalManager.rent{value: 2 ether}(address(nft), tokenId, start, end);

        vm.prank(other);
        vm.expectRevert("RentalManager: not expired");
        rentalManager.finalize(1);
    }

    function testRentDurationOutOfRange() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 1800; // 30 min, below min 1h
        vm.prank(renter);
        vm.expectRevert("RentalManager: duration out of range");
        rentalManager.rent{value: 2 ether}(address(nft), tokenId, start, end);
    }

    function testCheckIn() public {
        uint256 start = block.timestamp + 1000;
        uint256 end = start + 3600;

        vm.prank(renter);
        rentalManager.rent{value: 2 ether}(address(nft), tokenId, start, end);

        // Try checkin too early
        vm.prank(renter);
        vm.expectRevert("RentalManager: too early");
        rentalManager.checkIn(1);

        // Warp to start
        vm.warp(start);
        vm.prank(renter);
        rentalManager.checkIn(1);

        assertEq(nft.userOf(tokenId), renter);
    }
}
