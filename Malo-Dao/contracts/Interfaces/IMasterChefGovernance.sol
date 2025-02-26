// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMasterChefGovernance {
    enum ProposalType { Simple, Conviction, Quadratic }

    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        uint64 startTime;
        uint64 endTime;
        uint64 convictionGrowthRate;
        uint256 totalConviction;
        uint256 totalQuadraticVotes;
        bool executed;
        string ipfsHash;
    }

   
}
