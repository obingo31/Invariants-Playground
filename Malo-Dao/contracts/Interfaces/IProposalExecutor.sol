// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProposalExecutor {
    function executeProposal(uint256 proposalId, bytes calldata data) external;
}


