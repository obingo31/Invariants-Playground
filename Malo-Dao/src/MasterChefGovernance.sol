// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IStakeManager.sol";
import "./IMasterChefGovernance.sol";
import "./IProposalExecutor.sol";
import "./IWarpMessenger.sol";
import "./IGovernanceNFT.sol";

contract MasterChefGovernance is Initializable, UUPSUpgradeable, ERC20, ERC20Permit, ERC20Votes, ERC20Capped, AccessControl, Pausable, ReentrancyGuard, IMasterChefGovernance {
    IStakeManager public stakeManager;
    IWarpMessenger public warpMessenger;
    IGovernanceNFT public governanceNFT;

    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        uint64 startTime;
        uint64 endTime;
        uint64 convictionGrowthRate;
        uint64 totalConviction;
        uint64 totalQuadraticVotes;
        bool executed;
        string ipfsHash;
    }

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

    uint256 public proposalCount;
    uint256 public stakingPool;
    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public stakingTimestamp;
    mapping(address => uint256) public voterRewards;
    mapping(address => bool) public trustedBridges;
    mapping(bytes32 => bool) public executedCrossChainProposals;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => address) public trustedWarpChains;
    mapping(address => bool) public rewardNFTs;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, ProposalType indexed proposalType);
    event ProposalExecuted(uint256 indexed proposalId);
    event CrossChainProposalReceived(bytes32 indexed proposalHash, address indexed sourceBridge);
    event WarpMessageReceived(uint256 indexed warpChainId, uint256 indexed proposalId);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event GovernanceNFTMinted(address indexed user, uint256 indexed proposalId);
    event ContractUpgraded(address indexed newImplementation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _stakeManager, address _warpMessenger, address _governanceNFT) public initializer {
        __ERC20_init("MasterChef Token", "ML");
        __ERC20Permit_init("MasterChef Token");
        __ERC20Capped_init(100_000_000 * 10**18);
        __UUPSUpgradeable_init();

        stakeManager = IStakeManager(_stakeManager);
        warpMessenger = IWarpMessenger(_warpMessenger);
        governanceNFT = IGovernanceNFT(_governanceNFT);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(EXECUTOR_ROLE, msg.sender);
        _setupRole(REWARD_DISTRIBUTOR_ROLE, msg.sender);
        _setupInitialGovernance();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
        emit ContractUpgraded(newImplementation);
    }

    function _setupInitialGovernance() private {
        convictionParams = ConvictionParams({
            maxConviction: 10000,
            halfLifeSeconds: 7 days,
            minStakeTime: 2 days
        });

        quadraticParams = QuadraticParams({
            baseCredits: 100,
            creditPrice: 1 * 10**18,
            maxCreditsPerVoter: 10000
        });
    }

    function receiveWarpMessage(uint256 warpChainId, uint256 proposalId, bytes calldata proposalData) external whenNotPaused {
        require(trustedWarpChains[warpChainId] != address(0), "Untrusted Warp chain");

        (address proposer, ProposalType proposalType, string memory ipfsHash) = abi.decode(proposalData, (address, ProposalType, string));

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: proposer,
            proposalType: proposalType,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + 7 days),
            convictionGrowthRate: 1000,
            totalConviction: 0,
            totalQuadraticVotes: 0,
            executed: false,
            ipfsHash: ipfsHash
        });

        emit WarpMessageReceived(warpChainId, proposalId);
        emit ProposalCreated(proposalId, proposer, proposalType);
    }

    function sendWarpMessage(uint256 warpChainId, uint256 proposalId) external onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");

        bytes memory message = abi.encode(proposal.proposer, proposal.proposalType, proposal.ipfsHash);
        warpMessenger.sendMessage(warpChainId, message);
    }

    function mintGovernanceNFT(address user, uint256 proposalId) external onlyRole(REWARD_DISTRIBUTOR_ROLE) {
        require(!rewardNFTs[user], "NFT already claimed");

        governanceNFT.mint(user, proposalId);
        rewardNFTs[user] = true;

        emit GovernanceNFTMinted(user, proposalId);
    }

    function setTrustedWarpChain(uint256 warpChainId, address executor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        trustedWarpChains[warpChainId] = executor;
    }
}
