// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "./UniswapV3Pool.Utils.t.sol";

import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/lib/LiquidityMath.sol";
import "../src/lib/TickMath.sol";
import "../src/UniswapV3Pool.sol";

import "forge-std/console.sol";

contract UniswapV3PoolSwapsTest is Test, TestUtils, UniswapV3PoolUtils {
	// contract
	ERC20Mintable token0;
	ERC20Mintable token1;
	UniswapV3Pool pool;

	bool transferInMintCallback = true;
	bool transferInSwapCallback = true;
	bytes extra;

	// set tokens contrat
	function setUp() public {
		token0 = new ERC20Mintable("Ether", "ETH", 18);
		token1 = new ERC20Mintable("USDC", "USDC", 18);
		extra = encodeExtra(address(token0), address(token1), address(this));
	}

	// test swap eth
	function testBuyETHOnePriceRange() public {
		LiquidityRange[] memory liquidity = new LiquidityRange[](1);
		liquidity[0] = liquidityRange(4545, 5500, 1 ether, 5000 ether, 5000);
		TestCaseParams memory params = TestCaseParams({
			wethBalance: 1 ether,
			usdcBalance: 5000 ether,
			currentPrice: 5000,
			liquidity: liquidity,
			transferInMintCallback: true,
			transferInSwapCallback: true,
			mintLiquidity: true
		});

		// mint pool
		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

		// mint swap token
		uint256 swapAmount = 42 ether;
		token1.mint(address(this), swapAmount);
		token1.approve(address(this), swapAmount);

		int256 userBalance0Before = int256(token0.balanceOf(address(this)));
		int256 userBalance1Before = int256(token1.balanceOf(address(this)));

		(int256 amount0Delta, int256 amount1Delta) = pool.swap(
			address(this),
			false,
			swapAmount,
			sqrtP(5004),
			extra
		);
		// check swap amount
		assertEq(amount0Delta, -0.008396874645169943 ether, "invalid ETH out");
		assertEq(amount1Delta, int256(swapAmount), "invalid USDC input");

		assertSwapState(
			ExpectedStateAfterSwap({
				pool: pool,
				token0: token0,
				token1: token1,
				userBalance0: uint256(userBalance0Before - amount0Delta),
				userBalance1: uint256(userBalance1Before - amount1Delta),
				poolBalance0: uint256(int256(poolBalance0) + amount0Delta),
				poolBalance1: uint256(int256(poolBalance1) + amount1Delta),
				sqrtPriceX96: 5604415652688968742392013927525,
				tick: 85183,
				currentLiquidity: liquidity[0].amount
			})
		);
	}

	// set pool contract
	function setupTestCase(
		TestCaseParams memory params
	) internal returns (uint256 poolBalance0, uint256 poolBalance1) {
		token0.mint(address(this), params.wethBalance);
		token1.mint(address(this), params.usdcBalance);

		// set pool contract
		pool = new UniswapV3Pool(
			address(token0),
			address(token1),
			sqrtP(params.currentPrice),
			tick(params.currentPrice)
		);

		if (params.mintLiquidity) {
			token0.approve(address(this), params.wethBalance);
			token1.approve(address(this), params.usdcBalance);

			// mint liquidity
			uint256 poolBalance0Tmp;
			uint256 poolBalance1Tmp;
			for (uint256 i = 0; i < params.liquidity.length; i++) {
				(poolBalance0Tmp, poolBalance1Tmp) = pool.mint(
					address(this),
					params.liquidity[i].lowerTick,
					params.liquidity[i].upperTick,
					params.liquidity[i].amount,
					extra
				);
				poolBalance0 += poolBalance0Tmp;
				poolBalance1 += poolBalance1Tmp;
			}
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
			IUniswapV3Pool.CallbackData memory extra__ = abi.decode(
				data,
				(IUniswapV3Pool.CallbackData)
			);
			IERC20(extra__.token0).transferFrom(
				extra__.payer,
				msg.sender,
				amount0
			);
			IERC20(extra__.token1).transferFrom(
				extra__.payer,
				msg.sender,
				amount1
			);
		}
	}

	// pass token to owner
	function uniswapV3SwapCallback(
		int256 amount0,
		int256 amount1,
		bytes calldata data
	) public {
		if (transferInSwapCallback) {
			IUniswapV3Pool.CallbackData memory extra_ = abi.decode(
				data,
				(IUniswapV3Pool.CallbackData)
			);

			if (amount0 > 0) {
				IERC20(extra_.token0).transferFrom(
					extra_.payer,
					msg.sender,
					uint256(amount0)
				);
			}

			if (amount1 > 0) {
				IERC20(extra_.token1).transferFrom(
					extra_.payer,
					msg.sender,
					uint256(amount1)
				);
			}
		}
	}
}
