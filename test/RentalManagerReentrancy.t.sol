// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RentalManager.sol";
import "../src/ListingManager.sol";
import "../src/Rentable721.sol";

// Malicious contract to attempt reentrancy
contract MaliciousRenter {
    RentalManager rentalManager;
    address nft;
    uint256 tokenId;
    uint256 start;
    uint256 end;
    bool hasReentered;

    constructor(address _rentalManager) {
        rentalManager = RentalManager(_rentalManager);
    }

    function setParams(address _nft, uint256 _tokenId, uint256 _start, uint256 _end) external {
        nft = _nft;
        tokenId = _tokenId;
        start = _start;
        end = _end;
    }

    // Attempt to re-enter during rent call (e.g. if we had a callback, but we don't.
    // Usually reentrancy happens on ETH transfer.
    // In `rent`, we only transfer ETH *IN*.
    // Refund *OUT* happens at end.
    // We will test if refund triggers reentrancy.)
    function attack(uint256 value) external payable {
        rentalManager.rent{value: value}(nft, tokenId, start, end);
    }

    receive() external payable {
        if (!hasReentered) {
            hasReentered = true;
            // Try to rent again with same params
            // This should hit ReentrancyGuard
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
    address feeRecipient;
    uint256 tokenId = 1;

    function setUp() public {
        owner = makeAddr("owner");
        feeRecipient = makeAddr("feeRecipient");

        vm.deal(address(this), 100 ether);

        vm.prank(owner);
        nft = new Rentable721();
        listingManager = new ListingManager();
        rentalManager = new RentalManager(address(listingManager), feeRecipient, 500);

        vm.prank(owner);
        nft.setMarketplace(address(rentalManager));

        vm.prank(owner);
        nft.mint(owner, tokenId);

        vm.prank(owner);
        nft.setApprovalForAll(address(rentalManager), true);

        vm.prank(owner);
        listingManager.createListing(address(nft), tokenId, uint256(1 ether) / 3600, 3600, 86400, 0.1 ether, bytes32(0));

        maliciousRenter = new MaliciousRenter(address(rentalManager));
    }

    function testReentrancyProtectionInRent() public {
        uint256 start = block.timestamp + 100;
        uint256 end = start + 3600;

        ListingManager.Listing memory listing = listingManager.getListing(address(nft), tokenId);
        uint256 required = (end - start) * listing.pricePerSecond + listing.deposit;
        uint256 overpayment = required + 1 ether; // To trigger refund

        maliciousRenter.setParams(address(nft), tokenId, start, end);
        vm.deal(address(maliciousRenter), overpayment);

        // The attack:
        // 1. Call rent with overpayment
        // 2. Manager sends refund
        // 3. MaliciousRenter.receive() called
        // 4. MaliciousRenter tries to call rent() again
        // 5. Should revert due to ReentrancyGuard

        vm.prank(address(maliciousRenter));
        vm.expectRevert("RentalManager: refund failed");
        maliciousRenter.attack{value: overpayment}(overpayment);
    }
}
