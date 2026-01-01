// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IUniswapV2Callee.sol";

/// @title Uniswap V2 风格交易对
/// @notice 支持闪电贷和普通 swap
contract UniswapV2Pair is IPair {
    address public token0;
    address public token1;

    uint112 public reserve0;
    uint112 public reserve1;

    event AddLiquidity(address indexed provider, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
    
    /// @notice 添加流动性（简化版，仅用于初始化池子）
    /// @param amount0 token0 数量
    /// @param amount1 token1 数量
    function addLiquidity(uint256 amount0, uint256 amount1) external {
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        _sync();
        emit AddLiquidity(msg.sender, amount0, amount1);
    }
    
    /// @notice 闪电贷 swap（真实 Uniswap V2 有重入锁，防止回调中再次调用 swap
    ///         本演示采用双池架构，天然规避了这个问题，故省略）
    /// @dev 先转账后回调，回调结束检查 K 值
    /// @param amount0Out 借出的 token0
    /// @param amount1Out 借出的 token1
    /// @param to 接收地址（也是回调地址）
    /// @param data 非空则触发回调
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "INSUFFICIENT_LIQUIDITY");
        
        // 1. 乐观转账 - 先把代币转给调用者
        if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);
        
        // 2. 如果 data 不为空，触发闪电贷回调
        if (data.length > 0) {
            IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        }
        
        // 3. 获取当前余额
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        // 4. 计算实际输入量
        // 思路：如果只发生了“输出转出”，余额应该是 reserve - amountOut
        // 现在余额比它多出来的部分，就是本次实际转入的 amountIn
        uint256 amount0In;
        uint256 amount1In;
        {
            uint256 balance0AfterOut = uint256(_reserve0) - amount0Out;
            uint256 balance1AfterOut = uint256(_reserve1) - amount1Out;
            amount0In = balance0 > balance0AfterOut ? balance0 - balance0AfterOut : 0;
            amount1In = balance1 > balance1AfterOut ? balance1 - balance1AfterOut : 0;
        }
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT_AMOUNT");

        // 5. K 值校验（含 0.3% 手续费）
        {
            uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * uint256(_reserve1) * 1000000, "K");
        }
        // 6. 更新储备量
        _sync();
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
    
    /// @notice 普通 swap（无回调，用于价格操纵）
    /// @param amountIn 输入数量
    /// @param oneForZero true: token1→token0, false: token0→token1
    /// @return amountOut 输出数量
    function swapExact(uint256 amountIn, bool oneForZero) external returns (uint256 amountOut) {
        (uint256 rIn, uint256 rOut) = oneForZero ? (reserve1, reserve0) : (reserve0, reserve1);
        amountOut = amountIn * 997 * rOut / (rIn * 1000 + amountIn * 997);
        
        if (oneForZero) {
            IERC20(token1).transferFrom(msg.sender, address(this), amountIn);
            IERC20(token0).transfer(msg.sender, amountOut);
        } else {
            IERC20(token0).transferFrom(msg.sender, address(this), amountIn);
            IERC20(token1).transfer(msg.sender, amountOut);
        }
        _sync();
    }
    
    /// @notice 获取价格（token0 计价 token1）
    /// @return 价格（无精度缩放，直接显示比值）
    function getPrice() external view returns (uint256) {
        return uint256(reserve1) / reserve0;
    }
    
    /// @dev 更新储备量
    function _sync() private {
        reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(IERC20(token1).balanceOf(address(this)));
        emit Sync(reserve0, reserve1);
    }
}