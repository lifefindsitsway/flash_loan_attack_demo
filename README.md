## 闪电贷攻击演示

完整内容参见博客：[闪电贷：从原理到攻击演示](https://lifefindsitsway.wiki/web3/defi/flash_loan_attack_260101)

### 攻击原理

闪电贷本身不是漏洞，它只是**放大器**。真正的漏洞是：**使用 DEX 即时价格作为预言机**。

AMM（自动做市商）的价格由池子比例决定：

```
价格 = reserve1 / reserve0
```

大额交易会**立即**改变这个比例，从而操纵价格。

**攻击四步曲**

1. 从 Pool A 闪电贷借入大量 DAI；
2. 在 Pool B 用 DAI 买 WETH，拉高 WETH 价格；
3. 将 WETH 存入 Lending 作抵押，按虚高价格借出超额 DAI；
4. 归还闪电贷，剩余即为利润。

简单数学（以本演示为例）：

```
初始状态：
  Pool B: 100 WETH + 300,000 DAI，价格 = 3,000 DAI/WETH

攻击过程：
  1. 从 Pool A 借 1,500,000 DAI
  2. 用 1,350,000 DAI 在 Pool B 买 WETH
     → 获得约 81 WETH
     → Pool B 新价格 ≈ 86,842 DAI/WETH（涨了 29 倍！）
  3. 存 81 WETH 到 Lending
     → 按虚高价格计算抵押价值：81 × 86,842 ≈ 7,034,202 DAI
     → 可借 (80%)：约 5,627,361 DAI
  4. 还款 1,504,514 DAI
  
利润：5,627,361 - 1,504,514 + 150,000 ≈ 4,272,847 DAI
```

### Remix 部署演示

**文件结构**

```
Flash_Loan_Attack_Demo/
├── interfaces/
│   ├── IERC20.sol           # ERC20 标准接口
│   ├── ILending.sol         # 借贷协议接口
│   ├── IPair.sol            # 交易对接口
│   └── IUniswapV2Callee.sol # 闪电贷回调接口
│
├── Attacker.sol             # 攻击合约
├── ERC20.sol                # 测试代币
├── Lending.sol              # 有漏洞的借贷协议
└── UniswapV2Pair.sol        # 交易对（部署两次）
```

**部署步骤**

1.部署代币

- 部署 WETH，mint 20,000 个
- 部署 DAI，mint 60,000,000 个

2.部署交易对

- Pool A（大池）：10,000 WETH + 30,000,000 DAI
- Pool B（小池）：100 WETH + 300,000 DAI

3.部署 Lending

- 构造函数传入 Pool B 地址（读取 Pool B 价格）
- 转入 20,000,000 DAI 作为储备

4.部署 Attacker

- 传入 Pool A、Pool B、Lending、WETH、DAI 地址

5.执行攻击

- 调用 `Attacker.attack(1500000)`

**攻击结果**

从 [Attacker合约日志](https://sepolia.etherscan.io/address/0x562192326504d8966e56097eab2dfc7e304dbd8a#events) 可以看到：借出 1,500,000 DAI，用 1,350,000 DAI 买入约 81 WETH，价格从 3,000 拉升至 86,842，最终利润 4,272,847 DAI。

**常见问题**

**Q：为什么需要两个池子？**

Uniswap V2 的 swap 函数有重入锁，回调期间无法调用同池的 swap。这也解释了为什么真实攻击通常涉及多个协议。

**Q：Pool B 为什么这么小？**

教学演示用。真实场景中，攻击者会寻找流动性薄弱的池子。

---

> ⚠️ 本文仅供学习研究，请勿用于非法用途。
