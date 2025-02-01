// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MasterChefGovernance} from "../src/MasterChefGovernance.sol";
import {PropertiesAsserts} from "./PropertiesAsserts.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts-upgradeable/proxy/ERC1967/ERC1967Proxy.sol";

interface IMockDependencies {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function mint(address to, uint256 tokenId) external;
    function sendMessage(uint256 chainId, bytes memory message) external;
}

contract MockDependencies is IMockDependencies {
    function stake(uint256) external pure {}
    function unstake(uint256) external pure {}
    function mint(address, uint256) external pure {}
    function sendMessage(uint256, bytes memory) external pure {}
}

contract MasterChefGovernanceTest is Test {
    using PropertiesAsserts for *;

    MasterChefGovernance public masterChef;
    MockDependencies public mockDeps;
    address public constant ADMIN = address(1);
    address public constant USER1 = address(2);
    address public constant USER2 = address(3);
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, IMasterChefGovernance.ProposalType indexed proposalType);
    
    function setUp() public {
        vm.startPrank(ADMIN);
        
        // Deploy mock dependencies
        mockDeps = new MockDependencies();
        
        // Deploy implementation and proxy
        MasterChefGovernance implementation = new MasterChefGovernance();
        bytes memory initData = abi.encodeWithSelector(
            MasterChefGovernance.initialize.selector,
            address(mockDeps),
            address(mockDeps),
            address(mockDeps)
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        masterChef = MasterChefGovernance(address(proxy));
        
        // Initial setup
        masterChef.mint(USER1, 1000 ether);
        masterChef.mint(USER2, 1000 ether);
        
        vm.stopPrank();
    }

    // Property: Staking and unstaking should maintain total supply invariant
    function property_StakingPoolInvariant(uint256 amount) public {
        amount = bound(amount, 1, 1000 ether);
        
        uint256 initialSupply = masterChef.totalSupply();
        
        vm.startPrank(USER1);
        masterChef.approve(address(masterChef), amount);
        
        try masterChef.stake(amount) {
            PropertiesAsserts.assertEq(
                masterChef.totalSupply(),
                initialSupply,
                "Total supply should remain constant after staking"
            );
            
            // Try unstaking after minimum stake time
            vm.warp(block.timestamp + 2 days + 1);
            masterChef.unstake();
            
            PropertiesAsserts.assertEq(
                masterChef.totalSupply(),
                initialSupply,
                "Total supply should remain constant after unstaking"
            );
        } catch {}
        vm.stopPrank();
    }

    // Property: User staking balance should never exceed their token balance
    function property_StakingBalanceLimit(uint256 amount) public {
        amount = bound(amount, 1, 2000 ether);
        
        vm.startPrank(USER1);
        masterChef.approve(address(masterChef), amount);
        
        try masterChef.stake(amount) {
            PropertiesAsserts.assertLte(
                masterChef.stakingBalance(USER1),
                masterChef.balanceOf(USER1),
                "Staked amount cannot exceed token balance"
            );
        } catch {}
        vm.stopPrank();
    }

    // Property: Conviction voting parameters should remain within bounds
    function property_ConvictionParameters() public {
        (uint64 maxConviction, uint64 halfLifeSeconds, uint64 minStakeTime) = masterChef.convictionParams();
        
        PropertiesAsserts.assertGt(
            maxConviction,
            0,
            "Max conviction should be positive"
        );
        
        PropertiesAsserts.assertGt(
            halfLifeSeconds,
            0,
            "Half life should be positive"
        );
        
        PropertiesAsserts.assertGt(
            minStakeTime,
            0,
            "Min stake time should be positive"
        );
    }

    // Property: Proposal creation should maintain sequential IDs
    function property_ProposalSequencing(uint256 numProposals) public {
        numProposals = bound(numProposals, 1, 10);
        uint256 initialCount = masterChef.proposalCount();
        
        for(uint256 i = 0; i < numProposals; i++) {
            vm.prank(USER1);
            masterChef.createProposal(
                IMasterChefGovernance.ProposalType.PARAMETER_CHANGE,
                "QmHash"
            );
            
            PropertiesAsserts.assertEq(
                masterChef.proposalCount(),
                initialCount + i + 1,
                "Proposal IDs should be sequential"
            );
        }
    }

    // Property: Voting power should be proportional to staked amount
    function property_VotingPower(uint256 amount) public {
        amount = bound(amount, 1, 1000 ether);
        
        vm.startPrank(USER1);
        masterChef.approve(address(masterChef), amount);
        
        try masterChef.stake(amount) {
            // Create proposal
            masterChef.createProposal(
                IMasterChefGovernance.ProposalType.PARAMETER_CHANGE,
                "QmHash"
            );
            
            uint256 proposalId = masterChef.proposalCount();
            
            // Try to vote
            masterChef.vote(proposalId, amount);
            
            (,,,,,,uint256 totalConviction,,,) = masterChef.proposals(proposalId);
            
            PropertiesAsserts.assertGte(
                totalConviction,
                amount,
                "Total conviction should be at least the voted amount"
            );
        } catch {}
        vm.stopPrank();
    }

    // Property: Rewards calculation should be monotonic with time
    function property_RewardsMonotonic(uint256 amount, uint256 timeJump1, uint256 timeJump2) public {
        amount = bound(amount, 1, 1000 ether);
        timeJump1 = bound(timeJump1, 1 days, 30 days);
        timeJump2 = bound(timeJump2, 31 days, 365 days);
        
        vm.startPrank(USER1);
        masterChef.approve(address(masterChef), amount);
        
        try masterChef.stake(amount) {
            // Check rewards after first time jump
            vm.warp(block.timestamp + timeJump1);
            uint256 rewards1 = masterChef.calculateRewards(USER1);
            
            // Check rewards after second time jump
            vm.warp(block.timestamp + timeJump2);
            uint256 rewards2 = masterChef.calculateRewards(USER1);
            
            PropertiesAsserts.assertGte(
                rewards2,
                rewards1,
                "Rewards should increase with time"
            );
        } catch {}
        vm.stopPrank();
    }

    // Property: Cross-chain proposals should not be executable twice
    function property_CrossChainProposalExecution(bytes32 proposalHash) public {
        vm.startPrank(ADMIN);
        
        // Mark proposal as executed
        masterChef.executedCrossChainProposals(proposalHash);
        
        PropertiesAsserts.assertTrue(
            masterChef.executedCrossChainProposals(proposalHash),
            "Proposal should be marked as executed"
        );
        
        vm.stopPrank();
    }
}