// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILending {
    function deposit(uint256 amount) external;
    function borrow(uint256 amount) external;
    function maxBorrow(address user) external view returns (uint256);
    function getPrice() external view returns (uint256);
    function collateral(address user) external view returns (uint256);
}