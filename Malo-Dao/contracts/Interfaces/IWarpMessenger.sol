// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWarpMessenger {
    function sendMessage(uint256 warpChainId, bytes calldata message) external;

    event MessageSent(uint256 indexed warpChainId, bytes message);
    event MessageReceived(uint256 indexed warpChainId, bytes message);
    
    function receiveMessage(uint256 warpChainId, bytes calldata message) external;
    function getMessageStatus(uint256 messageId) external view returns (bool);
    function acknowledgeMessage(uint256 messageId) external;
}
