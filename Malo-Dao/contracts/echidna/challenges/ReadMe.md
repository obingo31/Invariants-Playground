#
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