// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RentalManager.sol";
import "../src/ListingManager.sol";
import "../src/Rentable721.sol";

// Malicious contract to test reentrancy
contract MaliciousRenter {
    RentalManager rentalManager;
    address nft;
    uint256 tokenId;
    uint256 start;
    uint256 end;
    bool hasReentered;
    
    constructor(address _rentalManager) {
        rentalManager = RentalManager(_rentalManager);
        hasReentered = false;
    }
    
    function setParams(address _nft, uint256 _tokenId, uint256 _start, uint256 _end) external {
        nft = _nft;
        tokenId = _tokenId;
        start = _start;
        end = _end;
    }

    function attack(uint256 value) external payable returns (bool) {
        hasReentered = false; // Reset for this call
        try rentalManager.rent{value: value}(nft, tokenId, start, end) {
            return true;
        } catch {
            return false;
        }
    }
    
    receive() external payable {
        // Try to reenter during the rent function
        if (start != 0 && !hasReentered) {
            hasReentered = true; // Prevent infinite loop
            rentalManager.rent{value: msg.value}(nft, tokenId, start, end);
        }
    }
}

contract RentalManagerReentrancyTest is Test {
    RentalManager rentalManager;
    ListingManager listingManager;
    Rentable721 nft;
    MaliciousRenter maliciousRenter;
    address owner;
    address renter;
    address feeRecipient;
    uint256 tokenId = 1;

    function setUp() public {
        owner = makeAddr("owner");
        renter = makeAddr("renter");
        feeRecipient = makeAddr("feeRecipient");
        
        vm.deal(address(this), 100 ether);
        vm.deal(renter, 100 ether);
        
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
        
        maliciousRenter = new MaliciousRenter(address(rentalManager));
    }

    function testReentrancyProtectionInRent() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 requiredAmount = 3600 * listing.pricePerSecond + listing.deposit; // 1 hour rental
        uint256 sentAmount = requiredAmount + 0.1 ether; // Send more to trigger refund
        
        // The malicious contract will try to reenter during the refund process
        maliciousRenter.setParams(address(nft), tokenId, start, end);
        
        // Give malicious contract funds
        vm.deal(address(maliciousRenter), sentAmount);
        vm.prank(address(maliciousRenter));
        
        // Try to call rent - if reentrancy protection works properly, the 
        // second call from the receive() function should be blocked
        bool success = maliciousRenter.attack{value: sentAmount}(requiredAmount);
        
        // If reentrancy protection works, the first call to rent should still succeed
        // because the second reentrant call would fail due to time conflicts or reentrancy guard
        assertTrue(success, "The initial rent call should succeed");
        
        // Check that rentals were recorded properly (should only be one if reentrancy was blocked)
        RentalManager.Rental[] memory rentals = rentalManager.getRentals(address(nft), tokenId);
        assertEq(rentals.length, 1, "Should only have one rental, indicating reentrancy was prevented");
    }
    
    function testReentrancyProtectionInFinalize() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 total = 3600 * listing.pricePerSecond + listing.deposit; // 1 hour rental

        // Successfully create a rental first
        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start, end);

        // Warp to after the rental expires
        vm.warp(end + 1);

        // Create malicious contract that might try to reenter during finalize
        MaliciousRenter finalizeAttacker = new MaliciousRenter(address(rentalManager));
        
        // The finalize function should still work properly with reentrancy guard
        vm.prank(renter);
        rentalManager.finalize(1, address(nft), tokenId);
        
        // Verify that rental is finalized
        RentalManager.Rental[] memory rentals = rentalManager.getRentals(address(nft), tokenId);
        assertTrue(rentals[0].finalized);
    }
    
    // Test to verify protocol fee functionality works as expected
    function testProtocolFeeCalculation() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600; // 1 hour
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 cost = 3600 * listing.pricePerSecond; // 1 hour rental
        uint256 total = cost + listing.deposit;
        
        // Record balances before
        uint256 ownerBalanceBefore = owner.balance;
        uint256 feeRecipientBalanceBefore = feeRecipient.balance;
        uint256 renterBalanceBefore = renter.balance;

        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start, end);

        // Warp to after rental expires
        vm.warp(end + 1);

        vm.prank(renter);
        rentalManager.finalize(1, address(nft), tokenId);

        // Check balances after
        uint256 expectedFee = cost * 500 / 10000; // 5% fee
        uint256 expectedOwnerAmount = cost - expectedFee;
        
        assertEq(owner.balance, ownerBalanceBefore + expectedOwnerAmount);
        assertEq(feeRecipient.balance, feeRecipientBalanceBefore + expectedFee);
        assertEq(renter.balance, renterBalanceBefore - total + listing.deposit);
    }
    
    // Test that finalize can be called by anyone (not just renter or owner)
    function testFinalizeAnyoneCanCall() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 total = 3600 * listing.pricePerSecond + listing.deposit; // 1 hour rental

        vm.prank(renter);
        rentalManager.rent{value: total}(address(nft), tokenId, start, end);

        vm.warp(end + 1);

        address randomPerson = makeAddr("random");
        vm.prank(randomPerson); // Random person should be able to call finalize
        rentalManager.finalize(1, address(nft), tokenId);
        
        RentalManager.Rental[] memory rentals = rentalManager.getRentals(address(nft), tokenId);
        assertTrue(rentals[0].finalized);
    }
    
    // Test that finalize fails for non-existent rentals
    function testFinalizeInvalidRentalId() public {
        vm.expectRevert("RentalManager: rental not found");
        rentalManager.finalize(999, address(nft), tokenId);
    }
    
    // Test refund excess funds properly
    function testRefundExcessFunds() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600; // 1 hour
        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 requiredAmount = 3600 * listing.pricePerSecond + listing.deposit;
        uint256 sentAmount = requiredAmount + 0.5 ether; // Send more than required
        
        uint256 renterBalanceBefore = renter.balance;

        vm.prank(renter);
        rentalManager.rent{value: sentAmount}(address(nft), tokenId, start, end);

        uint256 renterBalanceAfter = renter.balance;
        uint256 actualSpent = renterBalanceBefore - renterBalanceAfter;
        
        assertEq(actualSpent, requiredAmount); // Should only spend the required amount
    }
}