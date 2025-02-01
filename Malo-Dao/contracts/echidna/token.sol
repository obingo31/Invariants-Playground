// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

contract Ownable {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
}

contract Pausable is Ownable {
    bool private _paused;

    modifier whenNotPaused() {
        require(!_paused, "Pausable: contract is paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() public onlyOwner {
        _paused = true;
    }

    function resume() public onlyOwner {
        _paused = false;
    }
}

contract Token is Pausable {
    mapping(address => uint256) public balances;

    function transfer(address to, uint256 value) public whenNotPaused {
        require(balances[msg.sender] >= value, "Token: insufficient balance");
        balances[msg.sender] -= value;
        balances[to] += value;
    }
}
