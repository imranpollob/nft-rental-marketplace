// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SalesManager.sol";
import "../src/Rentable721.sol";

contract SalesManagerTest is Test {
    SalesManager salesManager;
    Rentable721 nft;
    address owner;
    address buyer;
    uint256 tokenId = 1;

    function setUp() public {
        owner = makeAddr("owner");
        buyer = makeAddr("buyer");
        
        vm.prank(owner);
        nft = new Rentable721();
        salesManager = new SalesManager();

        vm.prank(owner);
        nft.mint(owner, tokenId);
    }

    function testListAndBuy() public {
        vm.prank(owner);
        nft.setApprovalForAll(address(salesManager), true);

        vm.prank(owner);
        salesManager.listForSale(address(nft), tokenId, 1 ether);

        (address seller, uint256 price, bool active) = salesManager.sales(address(nft), tokenId);
        assertEq(seller, owner);
        assertEq(price, 1 ether);
        assertTrue(active);

        vm.deal(buyer, 2 ether);
        vm.prank(buyer);
        salesManager.buy{value: 1 ether}(address(nft), tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
        
        // check balance of seller
        assertEq(salesManager.balances(owner), 1 ether);
    }

    function testWithdraw() public {
        testListAndBuy(); // Sets up a sale and balance
        
        uint256 preBalance = owner.balance;
        vm.prank(owner);
        salesManager.withdraw();
        
        assertEq(owner.balance, preBalance + 1 ether);
        assertEq(salesManager.balances(owner), 0);
    }

    function testCancelSale() public {
        vm.prank(owner);
        salesManager.listForSale(address(nft), tokenId, 1 ether);
        
        vm.prank(owner);
        salesManager.cancelSale(address(nft), tokenId);
        
        (,, bool active) = salesManager.sales(address(nft), tokenId);
        assertFalse(active);
    }
}
