// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    address public rentalManager;
    mapping(address => uint256) public userBalances;
    mapping(uint256 => uint256) public rentalDeposits;

    event FundsDeposited(uint256 indexed rentalId, uint256 amount);
    event FundsReleased(uint256 indexed rentalId, address indexed to, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _rentalManager) {
        rentalManager = _rentalManager;
    }

    modifier onlyRentalManager() {
        require(msg.sender == rentalManager, "Escrow: only rental manager");
        _;
    }

    // RentalManager deposits funds for a specific rental
    function deposit(uint256 rentalId) external payable {
        rentalDeposits[rentalId] += msg.value;
        emit FundsDeposited(rentalId, msg.value);
    }

    // RentalManager releases funds from a rental to a user's balance
    function release(uint256 rentalId, address to, uint256 amount) external onlyRentalManager {
        require(rentalDeposits[rentalId] >= amount, "Escrow: insufficient rental balance");
        rentalDeposits[rentalId] -= amount;
        userBalances[to] += amount;
        emit FundsReleased(rentalId, to, amount);
    }

    // User withdraws their available balance
    function withdraw() external nonReentrant {
        uint256 amount = userBalances[msg.sender];
        require(amount > 0, "Escrow: no funds to withdraw");

        userBalances[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Escrow: transfer failed");

        emit Withdrawn(msg.sender, amount);
    }
}
