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
import "../Interfaces/IStakeManager.sol";
import "../Interfaces/IMasterChefGovernance.sol";
import "../Interfaces/IProposalExecutor.sol";
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
    // Struct Definitions
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

    // State Variables
    IStakeManager public stakeManager;
    IWarpMessenger public warpMessenger;
    IGovernanceNFT public governanceNFT;

    uint256 public proposalCount;
    uint256 public stakingPool;
    mapping(address => uint256) public stakingBalance;
    mapping(address => uint256) public stakingTimestamp;
    mapping(address => uint256) public voterRewards;
    mapping(bytes32 => bool) public executedCrossChainProposals;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => address) public trustedWarpChains;
    mapping(address => bool) public rewardNFTs;
    mapping(address => mapping(uint256 => bool)) public hasVoted;

    ConvictionParams public convictionParams;
    QuadraticParams public quadraticParams;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");

    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, ProposalType indexed proposalType);
    event ProposalExecuted(uint256 indexed proposalId);
    event WarpMessageReceived(uint256 indexed warpChainId, uint256 indexed proposalId);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event GovernanceNFTMinted(address indexed user, uint256 indexed proposalId);
    event ContractUpgraded(address indexed newImplementation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

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

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, msg.sender);

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

    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _transfer(msg.sender, address(this), amount);
        stakingBalance[msg.sender] += amount;
        stakingTimestamp[msg.sender] = block.timestamp;
        stakingPool += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake() external nonReentrant whenNotPaused {
        uint256 stakedAmount = stakingBalance[msg.sender];
        require(stakedAmount > 0, "No staked balance");

        uint256 stakedTime = block.timestamp - stakingTimestamp[msg.sender];
        require(stakedTime >= convictionParams.minStakeTime, "Stake not mature");

        uint256 rewards = calculateRewards(msg.sender);
        stakingBalance[msg.sender] = 0;
        stakingTimestamp[msg.sender] = 0;
        stakingPool -= stakedAmount;

        _transfer(address(this), msg.sender, stakedAmount + rewards);

        emit Unstaked(msg.sender, stakedAmount, rewards);
    }

    function calculateRewards(address user) public view returns (uint256) {
        uint256 stakedTime = block.timestamp - stakingTimestamp[user];
        return (stakingBalance[user] * stakedTime) / 1 days;
    }

    function createProposal(ProposalType proposalType, string calldata ipfsHash) external {
        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            proposalType: proposalType,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + 7 days),
            convictionGrowthRate: 1000,
            totalConviction: 0,
            totalQuadraticVotes: 0,
            executed: false,
            ipfsHash: ipfsHash
        });

        emit ProposalCreated(proposalCount, msg.sender, proposalType);
    }

    function executeProposal(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Invalid proposal");
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp >= proposal.endTime, "Voting period not ended");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function vote(uint256 proposalId, uint256 amount) external {
        require(stakingBalance[msg.sender] >= amount, "Insufficient staked balance");
        require(!hasVoted[msg.sender][proposalId], "Already voted");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime, "Voting period over");

        proposal.totalConviction += uint64(amount);
        hasVoted[msg.sender][proposalId] = true;
    }

    function sendWarpMessage(uint256 warpChainId, uint256 proposalId) external onlyRole(EXECUTOR_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Invalid proposal");
        require(!proposal.executed, "Proposal already executed");

        bytes memory message = abi.encode(proposal.proposer, proposal.proposalType, proposal.ipfsHash);
        warpMessenger.sendMessage(warpChainId, message);
    }

    function mintGovernanceNFT(address user, uint256 proposalId) external onlyRole(REWARD_DISTRIBUTOR_ROLE) {
        require(!rewardNFTs[user], "NFT already claimed");
        require(hasVoted[user][proposalId], "User did not vote");

        governanceNFT.mint(user, proposalId);
        rewardNFTs[user] = true;

        emit GovernanceNFTMinted(user, proposalId);
    }
}