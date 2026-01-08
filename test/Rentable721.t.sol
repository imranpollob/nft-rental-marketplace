// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Rentable721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract Rentable721Test is Test {
    Rentable721 rentable;
    address owner = address(1);
    address user = address(2);
    address other = address(3);
    uint256 tokenId = 1;

    function setUp() public {
        vm.prank(owner);
        rentable = new Rentable721();
        vm.prank(owner);
        rentable.mint(owner, tokenId);
        vm.prank(owner);
        rentable.setMarketplace(owner); // For testing, set owner as marketplace
    }

    function testSetUser() public {
        uint64 expires = uint64(block.timestamp + 100);
        vm.prank(owner);
        rentable.setUser(tokenId, user, expires);
        assertEq(rentable.userOf(tokenId), user);
        assertEq(rentable.userExpires(tokenId), expires);
    }

    function testAutoExpire() public {
        uint64 expires = uint64(block.timestamp + 100);
        vm.prank(owner);
        rentable.setUser(tokenId, user, expires);
        assertEq(rentable.userOf(tokenId), user);
        vm.warp(block.timestamp + 101);
        assertEq(rentable.userOf(tokenId), address(0));
    }

    function testClearUser() public {
        uint64 expires = uint64(block.timestamp + 100);
        vm.prank(owner);
        rentable.setUser(tokenId, user, expires);
        vm.prank(owner);
        rentable.setUser(tokenId, address(0), 0);
        assertEq(rentable.userOf(tokenId), address(0));
        assertEq(rentable.userExpires(tokenId), 0);
    }

    function testOnlyMarketplaceCanSetUser() public {
        uint64 expires = uint64(block.timestamp + 100);
        vm.prank(other);
        vm.expectRevert("Rentable721: only marketplace can set user");
        rentable.setUser(tokenId, user, expires);
    }

    function testTransferBlockedWhileRented() public {
        uint64 expires = uint64(block.timestamp + 100);
        vm.prank(owner);
        rentable.setUser(tokenId, user, expires);
        vm.prank(owner);
        vm.expectRevert("Rentable721: cannot transfer while rented");
        rentable.transferFrom(owner, other, tokenId);
    }

    function testTransferAllowedAfterExpiry() public {
        uint64 expires = uint64(block.timestamp + 100);
        vm.prank(owner);
        rentable.setUser(tokenId, user, expires);
        vm.warp(block.timestamp + 101);
        vm.prank(owner);
        rentable.transferFrom(owner, other, tokenId);
        assertEq(rentable.ownerOf(tokenId), other);
    }

    function testSetUserExpiresInPast() public {
        uint64 expires = uint64(block.timestamp - 1);
        vm.prank(owner);
        vm.expectRevert("Rentable721: expires must be in the future");
        rentable.setUser(tokenId, user, expires);
    }

    function testRoyaltyInfo() public view {
        uint256 salePrice = 10000;
        (address receiver, uint256 royaltyAmount) = rentable.royaltyInfo(tokenId, salePrice);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 500); // 5% of 10000
    }

    function testSupportsInterface() public view {
        assertTrue(rentable.supportsInterface(type(IERC2981).interfaceId));
    }

    function testRoyaltyDifferentAmounts() public view {
        // Test different sale prices result in correct royalty calculations
        uint256 salePrice1 = 1000; // Should result in 50 (5%)
        uint256 salePrice2 = 20000; // Should result in 1000 (5%)
        uint256 salePrice3 = 100000; // Should result in 5000 (5%)

        (address receiver1, uint256 royaltyAmount1) = rentable.royaltyInfo(tokenId, salePrice1);
        (address receiver2, uint256 royaltyAmount2) = rentable.royaltyInfo(tokenId, salePrice2);
        (address receiver3, uint256 royaltyAmount3) = rentable.royaltyInfo(tokenId, salePrice3);

        assertEq(receiver1, owner);
        assertEq(royaltyAmount1, salePrice1 * 500 / 10000); // 5%
        assertEq(receiver2, owner);
        assertEq(royaltyAmount2, salePrice2 * 500 / 10000); // 5%
        assertEq(receiver3, owner);
        assertEq(royaltyAmount3, salePrice3 * 500 / 10000); // 5%
    }

    function testRoyaltyForNonexistentToken() public {
        // Test what happens when calling royaltyInfo for nonexistent token
        vm.expectRevert("Rentable721: token does not exist");
        rentable.royaltyInfo(999999, 10000); // Non-existent token
    }

    function testRoyaltyChangesAfterTransfer() public {
        // Test that royalty receiver changes after token transfer
        vm.prank(owner);
        rentable.transferFrom(owner, other, tokenId);

        uint256 salePrice = 10000;
        (address receiver, uint256 royaltyAmount) = rentable.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, other); // New owner should receive royalties
        assertEq(royaltyAmount, 500); // 5% of 10000
    }

    function testRoyaltyWithZeroSalePrice() public view {
        // Test royalty calculation with 0 sale price
        (address receiver, uint256 royaltyAmount) = rentable.royaltyInfo(tokenId, 0);

        assertEq(receiver, owner);
        assertEq(royaltyAmount, 0); // 5% of 0 should be 0
    }
}
