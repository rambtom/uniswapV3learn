// //SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.14;

// import "forge-std/Test.sol";
// import "./ERC20Mintable.sol";
// import "./TestUtils.sol";
// import "../src/UniswapV3Pool.sol";
// import "../src/UniswapV3Manager.sol";
// import "../src/UniswapV3Quoter.sol";
// import "forge-std/console.sol";

// contract UniswapV3QuoterTest is Test, TestUtils {
// 	// contract
// 	UniswapV3Pool pool;
// 	UniswapV3Manager manager;
// 	UniswapV3Quoter quoter;
// 	ERC20Mintable token0;
// 	ERC20Mintable token1;

// 	struct TestCaseParams {
// 		uint256 wethBalance;
// 		uint256 usdcBalance;
// 		int24 currentTick;
// 		int24 lowerTick;
// 		int24 upperTick;
// 		uint128 liquidity;
// 		uint160 currentSqrtP;
// 	}

// 	function setUp() public {
// 		token0 = new ERC20Mintable("Ether", "ETH", 18);
// 		token1 = new ERC20Mintable("USDC", "USDC", 18);

// 		TestCaseParams memory params = TestCaseParams({
// 			wethBalance: 1 ether,
// 			usdcBalance: 5000 ether,
// 			currentTick: 85176,
// 			lowerTick: 84222,
// 			upperTick: 86129,
// 			liquidity: 1517882343751509868544,
// 			currentSqrtP: 5602277097478614198912276234240
// 		});

// 		token0.mint(address(this), params.wethBalance);
// 		token1.mint(address(this), params.usdcBalance);

// 		pool = new UniswapV3Pool(
// 			address(token0),
// 			address(token1),
// 			params.currentSqrtP,
// 			params.currentTick
// 		);

// 		manager = new UniswapV3Manager();

// 		token0.approve(address(manager), params.wethBalance);
// 		token1.approve(address(manager), params.usdcBalance);

// 		UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
// 			token0: address(token0),
// 			token1: address(token1),
// 			payer: address(this)
// 		});

// 		manager.mint(
// 			address(pool),
// 			params.lowerTick,
// 			params.upperTick,
// 			params.liquidity,
// 			abi.encode(extra)
// 		);

// 		quoter = new UniswapV3Quoter();
// 	}

// 	function testQuoteBuyEth() public {
// 		uint256 swapAmount = 42 ether;
// 		UniswapV3Quoter.Quoteparams memory quoterparams = UniswapV3Quoter
// 			.Quoteparams({
// 				pool: address(pool),
// 				amountIn: swapAmount,
// 				zeroForOne: false
// 			});

// 		(uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter) = quoter
// 			.quote(quoterparams);

// 		assertEq(amountOut, 0.008396714242162445 ether, "invalid ETH out");

// 		assertEq(
// 			sqrtPriceX96After,
// 			5604469350942327889444743441197,
// 			"invalid quote sqrt price"
// 		);

// 		assertEq(tickAfter, 85184, "invalid quote tick");
// 	}

// 	function testQuoteAndSwapBuyUSDC() public {
// 		uint256 swapAmount = 0.1 ether;
// 		(uint256 amountOut, , ) = quoter.quote(
// 			UniswapV3Quoter.Quoteparams({
// 				pool: address(pool),
// 				amountIn: swapAmount,
// 				zeroForOne: true
// 			})
// 		);
// 		// console.log(amountOut);

// 		bytes memory extra = encodeExtra(
// 			address(token0),
// 			address(token1),
// 			address(this)
// 		);

// 		token0.mint(address(this), swapAmount);
// 		token0.approve(address(manager), swapAmount);

// 		(int256 amount0, int256 amount1) = manager.swap(
// 			address(pool),
// 			true,
// 			swapAmount,
// 			extra
// 		);

// 		assertEq(
// 			swapAmount,
// 			uint256(amount0),
// 			"invalid USDC amount between quote and swap"
// 		);
// 		assertEq(
// 			amountOut,
// 			uint256(-amount1),
// 			"invalid Eth amount between quote and swap"
// 		);
// 	}
// }
