// //SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.14;

// import "forge-std/Test.sol";
// import "./ERC20Mintable.sol";
// import "./TestUtils.sol";
// import "../src/UniswapV3Pool.sol";
// import "../src/UniswapV3Manager.sol";
// import "forge-std/console.sol";

// contract UniswapV3ManagerTest is Test, TestUtils {
// 	// contract
// 	ERC20Mintable token0;
// 	ERC20Mintable token1;
// 	UniswapV3Pool pool;
// 	UniswapV3Manager manager;

// 	bool transferInMintCallback = true;
// 	bool transferInSwapCallback = true;

// 	struct TestCaseParams {
// 		uint256 wethBalance;
// 		uint256 usdcBalance;
// 		int24 currentTick;
// 		int24 lowerTick;
// 		int24 upperTick;
// 		uint128 liquidity;
// 		uint160 currentSqrtP;
// 		bool transferInMintCallback;
// 		bool transferInSwapCallback;
// 		bool mintLiquidity;
// 	}

// 	// set tokens contrat
// 	function setUp() public {
// 		token0 = new ERC20Mintable("Ether", "ETH", 18);
// 		token1 = new ERC20Mintable("USDC", "USDC", 18);
// 	}

// 	function testMintSuccess() public {
// 		TestCaseParams memory params = TestCaseParams({
// 			wethBalance: 1 ether,
// 			usdcBalance: 5000 ether,
// 			currentTick: 85176,
// 			lowerTick: 84222,
// 			upperTick: 86129,
// 			liquidity: 1517882343751509868544,
// 			currentSqrtP: 5602277097478614198912276234240,
// 			transferInMintCallback: true,
// 			transferInSwapCallback: true,
// 			mintLiquidity: true
// 		});

// 		// set pool contract and mint liquidity
// 		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

// 		//
// 		// uint256 expectedAmount0 = 0.998976618347425280 ether;
// 		// uint256 expectedAmount1 = 5000 ether;
// 		uint256 expectedAmount0 = 0.998833192822975409 ether;
// 		uint256 expectedAmount1 = 4999.187247111820044641 ether;

// 		// check minted token amount
// 		assertEq(
// 			poolBalance0,
// 			expectedAmount0,
// 			"incorrect token0 deposited amount"
// 		);
// 		assertEq(
// 			poolBalance1,
// 			expectedAmount1,
// 			"incorrect token1 deposited amount"
// 		);

// 		// check contracts have calcurated token amounts
// 		assertEq(token0.balanceOf(address(pool)), expectedAmount0);
// 		assertEq(token1.balanceOf(address(pool)), expectedAmount1);

// 		// check specified owner's liquidity
// 		bytes32 positionKey = keccak256(
// 			abi.encodePacked(address(this), params.lowerTick, params.upperTick)
// 		);
// 		uint128 posLiquidity = pool.positions(positionKey);
// 		assertEq(posLiquidity, params.liquidity);

// 		// check lower tick
// 		(bool tickInitialized, uint128 tickLiquidity) = pool.ticks(
// 			params.lowerTick
// 		);
// 		assertTrue(tickInitialized);
// 		assertEq(tickLiquidity, params.liquidity);

// 		// check upper tick
// 		(tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
// 		assertTrue(tickInitialized);
// 		assertEq(tickLiquidity, params.liquidity);

// 		// check price and liquidity
// 		(uint160 sqrtPriceX96, int24 tick) = pool.slot0();
// 		assertEq(
// 			sqrtPriceX96,
// 			5602277097478614198912276234240,
// 			"invalid current price"
// 		);
// 		assertEq(
// 			pool.liquidity(),
// 			1517882343751509868544,
// 			"invalid pool liquidity"
// 		);

// 		// check ticks in the bitmap is initialized
// 		assertTrue(tickInBitmap(pool, params.lowerTick));
// 		assertTrue(tickInBitmap(pool, params.upperTick));
// 		// add test
// 		// upper and lower ticks are too big or too small
// 		// zero liquidity is provided
// 		// liquidity provider doesn't have enough of tokens
// 	}

// 	function testMintInvalidTickRangeLower() public {
// 		pool = new UniswapV3Pool(
// 			address(token0),
// 			address(token1),
// 			uint160(1),
// 			0
// 		);
// 		manager = new UniswapV3Manager();

// 		vm.expectRevert(encodeError("InvalidTickRange()"));
// 		manager.mint(address(pool), -887273, 0, 0, "");
// 	}

// 	function testMintInvalidTickRangeUpper() public {
// 		pool = new UniswapV3Pool(
// 			address(token0),
// 			address(token1),
// 			uint160(1),
// 			0
// 		);
// 		manager = new UniswapV3Manager();

// 		vm.expectRevert(encodeError("InvalidTickRange()"));
// 		manager.mint(address(pool), 0, 887273, 0, "");
// 	}

// 	function testMintZeroLiquidity() public {
// 		pool = new UniswapV3Pool(
// 			address(token0),
// 			address(token1),
// 			uint160(1),
// 			0
// 		);
// 		manager = new UniswapV3Manager();

// 		vm.expectRevert(encodeError("ZeroLiquidity()"));
// 		manager.mint(address(pool), -1, 0, 0, "");
// 	}

// 	// have no token but execute mint
// 	function testMintInsufficientTokenBalance() public {
// 		TestCaseParams memory params = TestCaseParams({
// 			wethBalance: 0,
// 			usdcBalance: 0,
// 			currentTick: 85176,
// 			lowerTick: 84222,
// 			upperTick: 86129,
// 			liquidity: 1517882343751509868544,
// 			currentSqrtP: 5602277097478614198912276234240,
// 			transferInMintCallback: false,
// 			transferInSwapCallback: true,
// 			mintLiquidity: false
// 		});
// 		setupTestCase(params);

// 		UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
// 			token0: address(token0),
// 			token1: address(token1),
// 			payer: address(this)
// 		});

// 		// differrent from test of Pool contract, we can't avoid callback
// 		// because manager contract has callback function
// 		// so reverted Error occur in callback and not in InsufficientInputAmount()
// 		vm.expectRevert(stdError.arithmeticError);
// 		manager.mint(
// 			address(pool),
// 			params.lowerTick,
// 			params.upperTick,
// 			params.liquidity,
// 			abi.encode(extra)
// 		);
// 	}

// 	// test swap eth
// 	function testSwapBuyEth() public {
// 		TestCaseParams memory params = TestCaseParams({
// 			wethBalance: 1 ether,
// 			usdcBalance: 5000 ether,
// 			currentTick: 85176,
// 			lowerTick: 84222,
// 			upperTick: 86129,
// 			liquidity: 1517882343751509868544,
// 			currentSqrtP: 5602277097478614198912276234240,
// 			transferInMintCallback: true,
// 			transferInSwapCallback: true,
// 			mintLiquidity: true
// 		});

// 		// mint pool
// 		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);
// 		// mint swap token
// 		uint256 swapAmount = 42 ether;
// 		token1.mint(address(this), swapAmount);
// 		token1.approve(address(manager), swapAmount);
// 		// It seems that token1 address has 42.8 ether. I don't know why.

// 		UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
// 			token0: address(token0),
// 			token1: address(token1),
// 			payer: address(this)
// 		});

// 		int256 userBalance0Before = int256(token0.balanceOf(address(this)));
// 		int256 userBalance1Before = int256(token1.balanceOf(address(this)));

// 		(int256 amount0Delta, int256 amount1Delta) = manager.swap(
// 			address(pool),
// 			false,
// 			swapAmount,
// 			abi.encode(extra)
// 		);
// 		// check swap amount
// 		assertEq(amount0Delta, -0.008396714242162445 ether, "invalid ETH out");
// 		assertEq(amount1Delta, int256(swapAmount), "invalid USDC input");
// 		// check user amount
// 		assertEq(
// 			token0.balanceOf(address(this)),
// 			uint256(userBalance0Before - amount0Delta),
// 			"invalid user ETH balance"
// 		);
// 		assertEq(
// 			token1.balanceOf(address(this)),
// 			uint256(userBalance1Before - amount1Delta),
// 			"invalid user USDC balance"
// 		);
// 		// check pool amount
// 		assertEq(
// 			token1.balanceOf(address(pool)),
// 			uint256(int256(poolBalance1) + amount1Delta),
// 			"invalid pool ETH balance"
// 		);
// 		assertEq(
// 			token0.balanceOf(address(pool)),
// 			uint256(int256(poolBalance0) + amount0Delta),
// 			"invalid pool USDC balance"
// 		);
// 		// check pool price and liquidity
// 		(uint160 sqrtPriceX96, int24 tick) = pool.slot0();
// 		assertEq(
// 			sqrtPriceX96,
// 			5604469350942327889444743441197,
// 			"invalid current sqrt price"
// 		);
// 		assertEq(tick, 85184, "invalid currect tick");
// 	}

// 	// insufficient user's amount on swap
// 	function testSwapInsufficientInputAmount() public {
// 		TestCaseParams memory params = TestCaseParams({
// 			wethBalance: 1 ether,
// 			usdcBalance: 5000 ether,
// 			currentTick: 85176,
// 			lowerTick: 84222,
// 			upperTick: 86129,
// 			liquidity: 1517882343751509868544,
// 			currentSqrtP: 5602277097478614198912276234240,
// 			transferInMintCallback: true,
// 			transferInSwapCallback: false,
// 			mintLiquidity: true
// 		});

// 		setupTestCase(params);

// 		UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
// 			token0: address(token0),
// 			token1: address(token1),
// 			payer: address(this)
// 		});

// 		vm.expectRevert(stdError.arithmeticError);
// 		manager.swap(address(pool), false, 42 ether, abi.encode(extra));
// 	}

// 	// test swap usdc
// 	function testSwapBuyEthButNotEnoughLiquidity() public {
// 		TestCaseParams memory params = TestCaseParams({
// 			wethBalance: 1 ether,
// 			usdcBalance: 5000 ether,
// 			currentTick: 85176,
// 			lowerTick: 84222,
// 			upperTick: 86129,
// 			liquidity: 1517882343751509868544,
// 			currentSqrtP: 5602277097478614198912276234240,
// 			transferInMintCallback: true,
// 			transferInSwapCallback: false,
// 			mintLiquidity: true
// 		});

// 		setupTestCase(params);
// 		// swap amount
// 		uint256 swapAmount = 5500 ether;
// 		token1.mint(address(this), swapAmount);
// 		token1.approve(address(manager), swapAmount);

// 		UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
// 			token0: address(token0),
// 			token1: address(token1),
// 			payer: address(this)
// 		});

// 		// stdError.arithmeticError
// 		// the internal solidity error when an arithmetic operation fails.
// 		vm.expectRevert(stdError.arithmeticError);
// 		manager.swap(address(pool), false, swapAmount, abi.encode(extra));
// 	}

// 	// set pool contract
// 	function setupTestCase(
// 		TestCaseParams memory params
// 	) internal returns (uint256 poolBalance0, uint256 poolBalance1) {
// 		token0.mint(address(this), params.wethBalance);
// 		token1.mint(address(this), params.usdcBalance);

// 		// set pool contract
// 		pool = new UniswapV3Pool(
// 			address(token0),
// 			address(token1),
// 			params.currentSqrtP,
// 			params.currentTick
// 		);

// 		manager = new UniswapV3Manager();

// 		if (params.mintLiquidity) {
// 			token0.approve(address(manager), params.wethBalance);
// 			token1.approve(address(manager), params.usdcBalance);

// 			UniswapV3Pool.CallbackData memory extra = UniswapV3Pool
// 				.CallbackData({
// 					token0: address(token0),
// 					token1: address(token1),
// 					payer: address(this)
// 				});

// 			// mint liquidity
// 			(poolBalance0, poolBalance1) = manager.mint(
// 				address(pool),
// 				params.lowerTick,
// 				params.upperTick,
// 				params.liquidity,
// 				abi.encode(extra)
// 			);
// 		}

// 		transferInMintCallback = params.transferInMintCallback;
// 		transferInSwapCallback = params.transferInSwapCallback;
// 	}
// }
