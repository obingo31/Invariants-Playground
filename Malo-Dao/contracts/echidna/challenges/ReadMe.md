# walk through the following steps:

Understanding the Vulnerability: Analyze the FlashLoanReceiver contract and identify the bug.

Writing an Echidna Test: Create a property to test the contract.

## Use Echidna to uncover the vulnerability.

## The FlashLoanReceiver contract is vulnerable because:

Anyone can request a flash loan on behalf of the receiver, even if they have no Ether.

The receiver pays the fee unconditionally, regardless of who initiated the flash loan.

This allows an attacker to repeatedly call pool.flashLoan(address(receiver), 0) to drain the receiver's balance.


```solidity

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

contract FlashLoanReceiver {
    using Address for address payable;

    address payable private pool;

    constructor(address payable poolAddress) {
        pool = poolAddress;
    }

    // Function called by the pool during flash loan
    function receiveEther(uint256 fee) public payable {
        require(msg.sender == pool, "Sender must be pool");

        uint256 amountToBeRepaid = msg.value + fee;

        require(address(this).balance >= amountToBeRepaid, "Cannot borrow that much");
        
        _executeActionDuringFlashLoan();
        
        // Return funds to pool
        pool.sendValue(amountToBeRepaid);
    }

    // Internal function where the funds received are used
    function _executeActionDuringFlashLoan() internal { }

    // Allow deposits of ETH
    receive () external payable {}
}
```
## Writing an Echidna Test

 we’ll write a property that checks if the receiver's balance is always >= 10 ether. If the balance falls below this threshold, Echidna will report a failure.

## Echidna Test Contract
```solidity
pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";
import "./FlashLoanReceiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NaiveReceiverEchidna {
    using Address for address payable;

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant ETHER_IN_RECEIVER = 10e18;

    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;

    constructor() payable {
        pool = new NaiveReceiverLenderPool();
        receiver = new FlashLoanReceiver(payable(address(pool)));
        payable(address(pool)).sendValue(ETHER_IN_POOL);
        payable(address(receiver)).sendValue(ETHER_IN_RECEIVER);
    }

    function testFlashLoan() public {
        // Drain receiver by repeatedly calling flashLoan
        for(uint i = 0; i < 10; i++) {
            pool.flashLoan(address(receiver), 0);
        }
    }

    // This should fail as the receiver's balance can be drained
    function echidna_test_contract_balance() public view returns (bool) {
        return address(receiver).balance >= 10 ether;
    }
}
```

## Run Echidna on the NaiveReceiverEchidna contract:

```echidna echidna/challenges/NaiveReceiverEchidna.sol --contract NaiveReceiverEchidna --config naivereceiver.yaml
```

## Output

Echidna will output something like this:

```
Analyzing contract: /path/to/NaiveReceiverEchidna.sol:NaiveReceiverEchidna
echidna_test_contract_balance: failed!💥  
  Call sequence:
    NaiveReceiverEchidna.testFlashLoan()

Traces: 

Unique instructions: 1205
Unique codehashes: 3
Corpus size: 4
Seed: 1596810450091279771
Total calls: 404
Fixing the Vulnerability
To fix the vulnerability, we’ll restrict flash loan calls to the owner of the FlashLoanReceiver contract.
```

Fixed FlashLoanReceiver Contract
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

contract FlashLoanReceiver {
    using Address for address payable;

    address payable private pool;
    address public owner;

    constructor(address payable poolAddress) {
        pool = poolAddress;
        owner = msg.sender; // Set the deployer as the owner
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Function called by the pool during flash loan
    function receiveEther(uint256 fee) public payable onlyOwner {
        require(msg.sender == pool, "Sender must be pool");

        uint256 amountToBeRepaid = msg.value + fee;

        require(address(this).balance >= amountToBeRepaid, "Cannot borrow that much");
        
        _executeActionDuringFlashLoan();
        
        // Return funds to pool
        pool.sendValue(amountToBeRepaid);
    }

    // Internal function where the funds received are used
    function _executeActionDuringFlashLoan() internal { }

    // Allow deposits of ETH
    receive () external payable {}
}
```

## After applying the fix, re-run Echidna:

```echidna echidna/challenges/NaiveReceiverEchidna.sol --contract NaiveReceiverEchidna --config naivereceiver.yaml
```

## Output

Echidna will now output something like this:

```Analyzing contract: /path/to/NaiveReceiverEchidna.sol:NaiveReceiverEchidna
echidna_test_contract_balance: passing 🎉

Unique instructions: 1023
Unique codehashes: 3
Corpus size: 10
Seed: 2821571204059176920
Total calls: 50263
```

we used Echidna to:

Uncover a vulnerability in the FlashLoanReceiver contract.

Fix the vulnerability by restricting flash loan calls to the owner.

Verify the fix by re-running Echidna.

Echidna is a powerful tool for detecting vulnerabilities in smart contracts. By writing properties and running fuzz tests, you can ensure that your contracts are secure and behave as expected.

https://www.damnvulnerabledefi.xyz/challenges/naive-receiver/

## Goals


Set up the testing environment with the correct contracts and necessary balances.
Analyze the "before" function in test/naive-receiver/naive-receiver.challenge.js to identify the required initial setup.
Add a property to check if the balance of the FlashLoanReceiver contract can change.
Create a config.yaml with the necessary configuration option(s).
Once Echidna finds the bug, fix the issue and re-test your property with Echidna.
The following contracts are relevant:

```contracts/naive-receiver/FlashLoanReceiver.sol```
```contracts/naive-receiver/NaiveReceiverLenderPool.sol ```