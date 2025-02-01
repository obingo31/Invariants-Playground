# Deploy and Interact with WrappedToken

This document provides step-by-step instructions on how to deploy and interact with the `WrappedToken` contract using Forge and cast commands.

## Prerequisites

- Ensure you have Forge and cast installed.
- Ensure you have a running blockchain node (e.g., Ganache, Hardhat, or a local Ethereum node).

## 1. Write the WrappedToken Contract

Here is a basic implementation of a wrapped token contract in Solidity:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WrappedToken is ERC20 {
    address public nativeTokenHolder;

    constructor() ERC20("Wrapped Token", "WTKN") {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
        nativeTokenHolder = msg.sender;
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
}

#######################

#######################

forge create --rpc-url http://localhost:8545 --private-key <YOUR_PRIVATE_KEY> src/WrappedToken.sol:WrappedToken --broadcast

####################################################

####################################################
[⠊] Compiling...
No files changed, compilation skipped
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
Transaction hash: 0xa8ffabb97f8d85625d3690c3a83c89a6deb2cd9fd33f8a1fa0b1fe1d25d6f286

export WRAPPED_TOKEN=0x5FbDB2315678afecb367f032d93F642f64180aa3

cast send $WRAPPED_TOKEN "deposit()" --value 1000000000000000000 --rpc-url http://localhost:8545 --private-key <YOUR_PRIVATE_KEY>

blockHash               0x4333236efc4ef11745e332a89d04ab40ed787ec4eef1b0d34a13edae502c2534
blockNumber             2
from                    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
to                      0x5FbDB2315678afecb367f032d93F642f64180aa3
transactionHash         0x1a2884c9ed07ea52ba940729e4d8e0f62a99ca661a03c2e442d0b0c42804668f
gasUsed                 89863

cast send $WRAPPED_TOKEN "withdraw(uint256)" 1000000000000000000 --rpc-url http://localhost:8545 --private-key <YOUR_PRIVATE_KEY>

blockHash               0xeffaee3c3b00dcf69f3f341248c611ed2a89e2706d81e092a5a88a53e1931458
blockNumber             3
from                    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
to                      0x5FbDB2315678afecb367f032d93F642f64180aa3
transactionHash         0xe6bed5b678a1167995aae03e65530cacf6aba508ff0320d7fe6fde9d28bb44f9
gasUsed                 32608


###########################################################
 Check the balance of the deployer account
 ########################################################
$ cast call $WRAPPED_TOKEN "balanceOf(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
////////////////////////// 
////@title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
///////////////////////////////////////////////
0x0000000000000000000000000000000000000000000000001bc16d674ec80000
 ################################################
 # Withdraw 1 ETH from the WrappedToken contract
 ################################################

 cast send $WRAPPED_TOKEN "withdraw(uint256)" 1ether --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

blockHash               0x689843e78d337974bb02a9c47887cdbd91d4136a4f5d204a3c70856e240225bc
blockNumber             4
contractAddress         
cumulativeGasUsed       40759
effectiveGasPrice       674438436
from                    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
gasUsed                 40759
logs                    [{"address":"0x5fbdb2315678afecb367f032d93f642f64180aa3","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266","0x0000000000000000000000000000000000000000000000000000000000000000"],"data":"0x0000000000000000000000000000000000000000000000000de0b6b3a7640000","blockHash":"0x689843e78d337974bb02a9c47887cdbd91d4136a4f5d204a3c70856e240225bc","blockNumber":"0x4","blockTimestamp":"0x6797b6ea","transactionHash":"0xb08bdde6b7eafbe1645fee5e48eb4e661ada9f3698010ec43427cae2d8eeb503","transactionIndex":"0x0","logIndex":"0x0","removed":false}]
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000040020000000000000100000800000000000000000000000010000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000042000000200000000000000000000000002000000000000000000020000000000000000000000000000000000000000000000000000000000000000000
root                    
status                  1 (success)
transactionHash         
 0xb08bdde6b7eafbe1645fee5e48eb4e661ada9f3698010ec43427cae2d8eeb503
transactionIndex        0
type                    2
blobGasPrice            1
blobGasUsed             
authorizationList       
to                    
      0x5FbDB2315678afecb367f032d93F642f64180aa3

      