// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./Rentable721.sol";

contract SalesManager is ReentrancyGuard {
    struct Sale {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(address => mapping(uint256 => Sale)) public sales;
    mapping(address => uint256) public balances;

    event ListedForSale(address indexed nft, uint256 indexed tokenId, address indexed seller, uint256 price);
    event SaleCanceled(address indexed nft, uint256 indexed tokenId, address indexed seller);
    event Sold(address indexed nft, uint256 indexed tokenId, address seller, address indexed buyer, uint256 price);
    event Withdrawn(address indexed user, uint256 amount);

    function listForSale(address nft, uint256 tokenId, uint256 price) external {
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "SalesManager: not owner");
        require(price > 0, "SalesManager: invalid price");

        // Ensure no active rental prevents transfer?
        // ERC721 `transferFrom` will fail if blocked, but good to check.
        // Rentable721 blocks transfer if `userOf` != 0.
        // We allow listing even if rented, but selling might fail?
        // Actually, listing is fine. Buying checks transferability.

        sales[nft][tokenId] = Sale({seller: msg.sender, price: price, active: true});

        emit ListedForSale(nft, tokenId, msg.sender, price);
    }

    function cancelSale(address nft, uint256 tokenId) external {
        Sale storage sale = sales[nft][tokenId];
        require(sale.active, "SalesManager: not listed");
        require(sale.seller == msg.sender, "SalesManager: not seller");

        sale.active = false;
        emit SaleCanceled(nft, tokenId, msg.sender);
    }

    function buy(address nft, uint256 tokenId) external payable nonReentrant {
        Sale storage sale = sales[nft][tokenId];
        require(sale.active, "SalesManager: not listed");
        require(IERC721(nft).ownerOf(tokenId) == sale.seller, "SalesManager: seller no longer owner");
        require(msg.value == sale.price, "SalesManager: incorrect price");

        // Mark inactive first
        sale.active = false;

        // Update balance (Pull Payment)
        balances[sale.seller] += msg.value;

        // Transfer NFT
        IERC721(nft).safeTransferFrom(sale.seller, msg.sender, tokenId);

        emit Sold(nft, tokenId, sale.seller, msg.sender, sale.price);
    }

    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "SalesManager: no funds");
        balances[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "SalesManager: transfer failed");

        emit Withdrawn(msg.sender, amount);
    }
}
