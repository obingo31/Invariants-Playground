// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakeManager {
    function stake(address user, uint256 amount) external;
    function unstake(address user, uint256 amount) external;
    function getStakedBalance(address user) external view returns (uint256);
}
