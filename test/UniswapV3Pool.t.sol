// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";

contract UniswapV3PoolTest is Test {
	ERC20Mintable token0;
	ERC20Mintable token1;
	UniswapV3Pool pool;

	bool transferInMintCallback = true;
	bool transferInSwapCallback = true;

	struct TestCaseParams {
		uint256 wethBalance;
		uint256 usdcBalance;
		int24 currentTick;
		int24 lowerTick;
		int24 upperTick;
		uint128 liquidity;
		uint160 currentSqrtP;
		bool transferInMintCallback;
		bool transferInSwapCallback;
		bool mintLiquidity;
	}

	// set tokens contrat
	function setUp() public {
		token0 = new ERC20Mintable("Ether", "ETH", 18);
		token1 = new ERC20Mintable("USDC", "USDC", 18);
	}

	function testMintSuccess() public {
		TestCaseParams memory params = TestCaseParams({
			wethBalance: 1 ether,
			usdcBalance: 5000 ether,
			currentTick: 85176,
			lowerTick: 84222,
			upperTick: 86129,
			liquidity: 1517882343751509868544,
			currentSqrtP: 5602277097478614198912276234240,
			transferInMintCallback: true,
			transferInSwapCallback: true,
			mintLiquidity: true
		});
		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

		uint256 expectedAmount0 = 0.998976618347425280 ether;
		uint256 expectedAmount1 = 5000 ether;
		assertEq(
			poolBalance0,
			expectedAmount0,
			"incorrect token0 deposited amount"
		);
		assertEq(
			poolBalance1,
			expectedAmount1,
			"incorrect token1 deposited amount"
		);
		assertEq(token0.balanceOf(address(pool)), expectedAmount0);
		assertEq(token1.balanceOf(address(pool)), expectedAmount1);

		bytes32 positionKey = keccak256(
			abi.encodePacked(address(this), params.lowerTick, params.upperTick)
		);
		uint128 posLiquidity = pool.positions(positionKey);
		assertEq(posLiquidity, params.liquidity);

		(bool tickInitialized, uint128 tickLiquidity) = pool.ticks(
			params.lowerTick
		);
		assertTrue(tickInitialized);
		assertEq(tickLiquidity, params.liquidity);

		(uint160 sqrtPriceX96, int24 tick) = pool.slot0();
		assertEq(
			sqrtPriceX96,
			5602277097478614198912276234240,
			"invalid current price"
		);
		assertEq(
			pool.liquidity(),
			1517882343751509868544,
			"invalid pool liquidity"
		);
		// add test
		// upper and lower ticks are too big or too small
		// zero liquidity is provided
		// liquidity provider doesn't have enough of tokens
	}

	// test swap
	function testSwapBuyEth() public {
		TestCaseParams memory params = TestCaseParams({
			wethBalance: 1 ether,
			usdcBalance: 5000 ether,
			currentTick: 85176,
			lowerTick: 84222,
			upperTick: 86129,
			liquidity: 1517882343751509868544,
			currentSqrtP: 5602277097478614198912276234240,
			transferInMintCallback: true,
			transferInSwapCallback: true,
			mintLiquidity: true
		});

		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

		uint256 swapAmount = 42 ether;
		token1.mint(address(this), swapAmount);
		token1.approve(address(this), swapAmount);

		UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
			token0: address(token0),
			token1: address(token1),
			payer: address(this)
		});

		int256 userBalanceBefore = int256(token0.balanceOf(address(this)));

		(int256 amount0Delta, int256 amount1Delta) = pool.swap(
			address(this),
			abi.encode(extra)
		);

		assertEq(amount0Delta, -0.008396714242162444 ether, "invalid ETH out");
		assertEq(amount1Delta, int256(swapAmount), "invalid USDC input");

		assertEq(
			token0.balanceOf(address(this)),
			uint256(userBalanceBefore - amount0Delta),
			"invalid user ETH balance"
		);
		assertEq(
			token1.balanceOf(address(this)),
			0,
			"invalid user USDC balance"
		);
		assertEq(
			token1.balanceOf(address(pool)),
			uint256(int256(poolBalance1) + amount1Delta),
			"invalid pool ETH balance"
		);
		assertEq(
			token0.balanceOf(address(pool)),
			uint256(int256(poolBalance0) + amount0Delta),
			"invalid pool USDC balance"
		);
		(uint160 sqrtPriceX96, int24 tick) = pool.slot0();
		assertEq(
			sqrtPriceX96,
			5604469350942327889444743441197,
			"invalid current sqrt price"
		);
		assertEq(tick, 85184, "invalid currect tick");
	}

	// insufficient amount on swap
	function testSwapInsufficientInputAmount() public {
		TestCaseParams memory params = TestCaseParams({
			wethBalance: 1 ether,
			usdcBalance: 5000 ether,
			currentTick: 85176,
			lowerTick: 84222,
			upperTick: 86129,
			liquidity: 1517882343751509868544,
			currentSqrtP: 5602277097478614198912276234240,
			transferInMintCallback: true,
			transferInSwapCallback: false,
			mintLiquidity: true
		});

		setupTestCase((params));

		vm.expectRevert(abi.encodeWithSignature("InsufficientInputAmount()"));
		pool.swap(address(this), "");
	}

	//set pool contract
	function setupTestCase(
		TestCaseParams memory params
	) internal returns (uint256 poolBalance0, uint256 poolBalance1) {
		token0.mint(address(this), params.wethBalance);
		token1.mint(address(this), params.usdcBalance);

		pool = new UniswapV3Pool(
			address(token0),
			address(token1),
			params.currentSqrtP,
			params.currentTick
		);

		if (params.mintLiquidity) {
			token0.approve(address(this), params.wethBalance);
			token1.approve(address(this), params.usdcBalance);

			UniswapV3Pool.CallbackData memory extra = UniswapV3Pool
				.CallbackData({
					token0: address(token0),
					token1: address(token1),
					payer: address(this)
				});

			(poolBalance0, poolBalance1) = pool.mint(
				address(this),
				params.lowerTick,
				params.upperTick,
				params.liquidity,
				abi.encode(extra)
			);
		}

		transferInMintCallback = params.transferInMintCallback;
		transferInSwapCallback = params.transferInSwapCallback;
	}

	//pass tokens to owner
	function uniswapV3MintCallback(
		uint256 amount0,
		uint256 amount1,
		bytes calldata data
	) public {
		if (transferInMintCallback) {
			UniswapV3Pool.CallbackData memory extra = abi.decode(
				data,
				(UniswapV3Pool.CallbackData)
			);
			IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
			IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
		}
	}

	// pass token to owner
	function uniswapV3SwapCallback(
		int256 amount0,
		int256 amount1,
		bytes calldata data
	) public {
		if (transferInSwapCallback) {
			UniswapV3Pool.CallbackData memory extra = abi.decode(
				data,
				(UniswapV3Pool.CallbackData)
			);
			if (amount0 > 0) {
				IERC20(extra.token0).transferFrom(
					extra.payer,
					msg.sender,
					uint256(amount0)
				);
			}
			if (amount1 > 0) {
				IERC20(extra.token1).transferFrom(
					extra.payer,
					msg.sender,
					uint256(amount1)
				);
			}
		}
	}
}
