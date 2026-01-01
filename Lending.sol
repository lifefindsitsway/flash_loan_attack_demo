// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/ILending.sol";

/// @title 有漏洞的借贷协议
/// @notice ⚠️ 演示用，使用 DEX 即时价格作为预言机（存在漏洞）
contract Lending is ILending {
    IPair public oracle;
    IERC20 public weth;
    IERC20 public dai;
    
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public debt;
    
    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount, uint256 priceUsed);

    constructor(address _oracle, address _weth, address _dai) {
        oracle = IPair(_oracle);
        weth = IERC20(_weth);
        dai = IERC20(_dai);
    }
    
    /// @notice 获取 WETH 价格
    /// @dev ⚠️ 漏洞：直接读取 DEX 即时价格，可被闪电贷操纵
    /// @return 价格（无精度缩放，单位 DAI/WETH）
    function getPrice() public view returns (uint256) {
        return uint256(oracle.reserve1()) / oracle.reserve0();
    }
    
    /// @notice 存入 WETH 作为抵押品
    /// @param amount 存入数量
    function deposit(uint256 amount) external {
        weth.transferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
    
    /// @notice 借出 DAI
    /// @dev 抵押率 80%
    /// @param amount 借款数量
    function borrow(uint256 amount) external {
        uint256 price = getPrice();
        uint256 maxAmount = collateral[msg.sender] * getPrice() * 80 / 100;
        require(debt[msg.sender] + amount <= maxAmount, "Undercollateralized");
        debt[msg.sender] += amount;
        dai.transfer(msg.sender, amount);
        emit Borrow(msg.sender, amount, price);
    }
    
    /// @notice 查询最大可借额度
    /// @param user 用户地址
    /// @return 可借 DAI 数量
    function maxBorrow(address user) external view returns (uint256) {
        uint256 max = collateral[user] * getPrice() * 80 / 100;
        return max > debt[user] ? max - debt[user] : 0;
    }
}