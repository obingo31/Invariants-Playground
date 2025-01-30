// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../Interfaces/IMasterChefGovernance.sol";
import "../Interfaces/IStakeManager.sol";
import "../Interfaces/IWarpMessenger.sol";
import "../Interfaces/IGovernanceNFT.sol";

contract MasterChefGovernance is
    Initializable,
    UUPSUpgradeable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IMasterChefGovernance
{
    struct ConvictionParams {
        uint64 maxConviction;
        uint64 halfLifeSeconds;
        uint64 minStakeTime;
    }

    struct QuadraticParams {
        uint64 baseCredits;
        uint64 creditPrice;
        uint64 maxCreditsPerVoter;
    }

    IStakeManager public stakeManager;
    IWarpMessenger public warpMessenger;
    IGovernanceNFT public governanceNFT;

    uint256 public proposalCount;
    uint256 public minQuorum;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public stakingTimestamp;
    
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, ProposalType indexed proposalType);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint256 weight);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);

    function initialize(
        address _stakeManager,
        address _warpMessenger,
        address _governanceNFT
    ) public initializer {
        __ERC20_init("MasterChef Token", "ML");
        __ERC20Permit_init("MasterChef Token");
        __ERC20Votes_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        stakeManager = IStakeManager(_stakeManager);
        warpMessenger = IWarpMessenger(_warpMessenger);
        governanceNFT = IGovernanceNFT(_governanceNFT);
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(EXECUTOR_ROLE) {}

    function vote(uint256 proposalId, uint256 amount) external {
        require(!hasVoted[msg.sender][proposalId], "Already voted");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime, "Voting period over");
        
        uint256 quadraticVoteWeight = sqrt(amount);
        proposal.totalConviction += uint256(amount);
        proposal.totalQuadraticVotes += uint256(quadraticVoteWeight);
        hasVoted[msg.sender][proposalId] = true;
        
        emit VoteCast(msg.sender, proposalId, quadraticVoteWeight);
    }

    function executeProposal(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp >= proposal.endTime, "Voting period not ended");
        require(proposal.totalConviction >= minQuorum, "Quorum not met");
        
        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }
    
    function sqrt(uint256 x) private pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
