// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGovernanceNFT {
    function mint(address to, uint256 proposalId) external;
    function balanceOf(address account) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}
