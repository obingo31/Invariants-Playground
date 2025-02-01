// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract WrappedToken is ERC20, ReentrancyGuard {
    address public nativeTokenHolder;
    
    event DepositMade(address indexed user, uint256 amount);
    event WithdrawalMade(address indexed user, uint256 amount);

    constructor() ERC20("Wrapped Token", "WTKN") {}

    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Cannot deposit zero ETH");
        require(msg.value <= type(uint256).max, "Amount too large");
        
        _mint(msg.sender, msg.value);
        nativeTokenHolder = msg.sender;
        
        emit DepositMade(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot withdraw zero amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        // Burn tokens first (checks-effects-interactions pattern)
        _burn(msg.sender, amount);
        
        // Transfer ETH last
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit WithdrawalMade(msg.sender, amount);
    }

    // Prevent accidental ETH transfers
    receive() external payable {
        revert("Use deposit() to send ETH");
    }

    fallback() external payable {
        revert("Use deposit() to send ETH");
    }
}