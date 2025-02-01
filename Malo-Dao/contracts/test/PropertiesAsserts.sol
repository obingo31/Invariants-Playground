// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library PropertiesAsserts {
    event LogUint256(string message, uint256 value);
    event LogAddress(string message, address value);
    event LogString(string message, string value);

    function assertEq(uint256 a, uint256 b, string memory message) internal pure {
        if (a != b) {
            revert(message);
        }
    }

    function assertGt(uint256 a, uint256 b, string memory message) internal pure {
        if (a <= b) {
            revert(message);
        }
    }

    function assertGte(uint256 a, uint256 b, string memory message) internal pure {
        if (a < b) {
            revert(message);
        }
    }

    function assertLt(uint256 a, uint256 b, string memory message) internal pure {
        if (a >= b) {
            revert(message);
        }
    }

    function assertLte(uint256 a, uint256 b, string memory message) internal pure {
        if (a > b) {
            revert(message);
        }
    }

    function assertTrue(bool condition, string memory message) internal pure {
        if (!condition) {
            revert(message);
        }
    }

    function assertFalse(bool condition, string memory message) internal pure {
        if (condition) {
            revert(message);
        }
    }

    function assertNotEq(uint256 a, uint256 b, string memory message) internal pure {
        if (a == b) {
            revert(message);
        }
    }

    function assertAddressNotZero(address addr, string memory message) internal pure {
        if (addr == address(0)) {
            revert(message);
        }
    }

    function assertAddressEq(address a, address b, string memory message) internal pure {
        if (a != b) {
            revert(message);
        }
    }
}
