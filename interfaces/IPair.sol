// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function reserve0() external view returns (uint112);
    function reserve1() external view returns (uint112);
    function getPrice() external view returns (uint256);
    function addLiquidity(uint256 amount0, uint256 amount1) external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function swapExact(uint256 amountIn, bool oneForZero) external returns (uint256);
}