// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library VulnerableStorageLib {
    struct Data { uint256 value; }

    // Vulnerable: No mask applied - potential collision risk
    bytes32 constant LOCATION = 
        keccak256(abi.encode(uint256(keccak256("storage.collision.vulnerable")) - 1));

    function load(address asset) internal pure returns (Data storage data) {
        bytes32 slot = keccak256(abi.encode(LOCATION, asset));
        assembly { data.slot := slot }
    }

    function setValue(address asset, uint256 value) internal {
        Data storage data = load(asset);
        data.value = value;
    }

    function getValue(address asset) internal view returns (uint256) {
        Data storage data = load(asset);
        return data.value;
    }
}

contract CollisionTestContract {
    using VulnerableStorageLib for address;

    mapping(address => uint256) public initialValues;
    bool public collisionDetected;

    function demonstrateCollision() public {
        // Intentionally create addresses with high collision probability
        address addr1 = address(0x1);
        address addr2 = address(0x2);
        
        // Set initial values
        addr1.setValue(100);
        addr2.setValue(200);

        // Check for unexpected value interference
        if (addr1.getValue() != 100 || addr2.getValue() != 200) {
            collisionDetected = true;
        }
    }

    // Function to check for collisions
    function checkForCollisions() public view {
        require(!collisionDetected, "Storage collision detected!");
    }
}

