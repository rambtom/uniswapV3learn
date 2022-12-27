# Uniswap V3 Book

Learning Uniswap V3 in [this book](https://uniswapv3book.com/)

## env

Using [foundry]() and developed on Docker Desktop

```bash
docker pull ghcr.io/foundry-rs/foundry:latest
```

VSC formatter is [hardhat-solidity](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity)

```bash
code --install-extension NomicFoundation.hardhat-solidity
```

## memo

When installing prb-math library, need commit number

```bash
forge install paulrberg/prb-math@e33a042
```

not

```bash
forge install paulrberg/prb-math
```

```mermaid
classDiagram
class UniswapV3Manager
UniswapV3Manager: mint()
UniswapV3Manager: swap()
UniswapV3Manager: UniswapV3MintCallback()
UniswapV3Manager: UniswapV3SwapCallback()

class UniswapV3Pool
UniswapV3Pool: address token0
UniswapV3Pool: address token1
UniswapV3Pool: uint160 sqrtPriceX96
UniswapV3Pool: int24 tick
UniswapV3Pool: mint()
UniswapV3Pool: swap()
UniswapV3Pool: balance0()
UniswapV3Pool: balance1()
```

```mermaid
classDiagram
class UniswapV3ManagerTest
UniswapV3ManagerTest: setUp()
UniswapV3ManagerTest: testMintSuccess()
UniswapV3ManagerTest: testMintInvalidTickRangeLower()
UniswapV3ManagerTest: testMintInvalidTickRangeUpper()
UniswapV3ManagerTest: testMintZeroLiquidity()
UniswapV3ManagerTest: testMintInsufficientTokenBalance()
UniswapV3ManagerTest: testSwapBuyEth()
UniswapV3ManagerTest: testSwapBuyUSDC()
UniswapV3ManagerTest: testSwapBuyEthNotEnoughLiquidity()
UniswapV3ManagerTest: testSwapBuyUSDCNotEnoughLiquidity()
UniswapV3ManagerTest: testSwapInsufficientInputAmount()
UniswapV3ManagerTest: setupTestCase()

class UniswapV3PoolTest
UniswapV3PoolTest: setUp()
UniswapV3PoolTest: testMintSuccess()
UniswapV3PoolTest: testMintInvalidTickRangeLower()
UniswapV3PoolTest: testMintInvalidTickRangeUpper()
UniswapV3PoolTest: testMintZeroLiquidity()
UniswapV3PoolTest: testMintInsufficientTokenBalance()
UniswapV3PoolTest: testSwapBuyEth()
UniswapV3PoolTest: testSwapBuyUSDC()
UniswapV3PoolTest: testSwapMixed()
UniswapV3PoolTest: testSwapBuyEthNotEnoughLiquidity()
UniswapV3PoolTest: testSwapBuyUSDCNotEnoughLiquidity()
UniswapV3PoolTest: testSwapInsufficientInputAmount()
UniswapV3PoolTest: uniswapV3SwapCallback()
UniswapV3PoolTest: uniswapV3MintCallback()
UniswapV3PoolTest: setupTestCase()
```
