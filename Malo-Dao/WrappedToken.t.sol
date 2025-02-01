// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/WrappedToken.sol";

contract WrappedTokenFuzzTest is Test {
    WrappedToken wrappedToken;
    
    // Test addresses from config
    address constant DEPLOYER = address(0x30000);
    address constant USER1 = address(0x10000);
    address constant USER2 = address(0x20000);
    
    function setUp() public {
        vm.prank(DEPLOYER);
        wrappedToken = new WrappedToken();
    }

    // Property: Total supply should always equal contract balance
    function property_TotalSupplyEqualsBalance(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);
        
        // Give USER1 some ETH and deposit
        deal(USER1, amount);
        vm.prank(USER1);
        wrappedToken.deposit{value: amount}();
        
        assert(wrappedToken.totalSupply() == address(wrappedToken).balance);
    }

    // Property: No user can withdraw more than their balance
    function property_NoOverWithdrawal(address user, uint256 amount) public {
        vm.assume(user != address(0) && user != address(wrappedToken));
        amount = bound(amount, 0.1 ether, 100 ether);
        
        uint256 initialBalance = wrappedToken.balanceOf(user);
        
        if (initialBalance == 0) {
            vm.expectRevert("Insufficient balance");
            vm.prank(user);
            wrappedToken.withdraw(amount);
        }
    }

    // Property: Token transfers preserve total supply
    function property_TransferPreservesTotalSupply(
        address from,
        address to,
        uint256 amount
    ) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        amount = bound(amount, 0.1 ether, 100 ether);
        
        // Setup initial state
        deal(from, amount);
        vm.prank(from);
        wrappedToken.deposit{value: amount}();
        
        uint256 initialSupply = wrappedToken.totalSupply();
        
        // Perform transfer
        vm.prank(from);
        wrappedToken.transfer(to, amount);
        
        assert(wrappedToken.totalSupply() == initialSupply);
    }

    // Optimization test: Check gas usage for deposits
    function optimize_DepositGasUsage(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);
        deal(USER1, amount);
        
        uint256 gasStart = gasleft();
        vm.prank(USER1);
        wrappedToken.deposit{value: amount}();
        uint256 gasUsed = gasStart - gasleft();
        
        // Gas should be reasonable
        assert(gasUsed < 100000);
    }

    // Optimization test: Check gas usage for withdrawals
    function optimize_WithdrawGasUsage(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 100 ether);
        
        // Setup: deposit first
        deal(USER1, amount);
        vm.prank(USER1);
        wrappedToken.deposit{value: amount}();
        
        // Measure withdrawal gas
        uint256 gasStart = gasleft();
        vm.prank(USER1);
        wrappedToken.withdraw(amount);
        uint256 gasUsed = gasStart - gasleft();
        
        // Gas should be reasonable
        assert(gasUsed < 100000);
    }

    // Sequence test using configured sequence length
    function testFuzz_LongSequence(
        uint256[] calldata amounts,
        bool[] calldata isDeposit
    ) public {
        vm.assume(amounts.length > 0);
        vm.assume(isDeposit.length > 0);
        
        uint256 totalDeposited = 0;
        
        for(uint i = 0; i < 100; i++) {  // Using config's callSequenceLength
            uint256 amount = bound(amounts[i % amounts.length], 0.1 ether, 5 ether);
            bool shouldDeposit = isDeposit[i % isDeposit.length];
            
            if(shouldDeposit) {
                deal(USER1, amount);
                vm.prank(USER1);
                wrappedToken.deposit{value: amount}();
                totalDeposited += amount;
            } else if(totalDeposited > 0) {
                uint256 withdrawAmount = bound(amount, 0, totalDeposited);
                vm.prank(USER1);
                wrappedToken.withdraw(withdrawAmount);
                totalDeposited -= withdrawAmount;
            }
            
            // Verify invariants after each operation
            assert(wrappedToken.totalSupply() == address(wrappedToken).balance);
            assert(wrappedToken.balanceOf(USER1) == totalDeposited);
        }
    }

    receive() external payable {}
}