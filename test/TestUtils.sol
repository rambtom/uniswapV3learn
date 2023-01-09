// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/UniswapV3Pool.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/lib/FixedPoint96.sol";
import "../src/UniswapV3Pool.sol";

import "./ERC20Mintable.sol";

abstract contract TestUtils is Test {
	function tick(uint256 price) internal pure returns (int24 tick_) {
		tick_ = TickMath.getTickAtSqrtRatio(
			uint160(
				int160(
					ABDKMath64x64.sqrt(int128(int256(price << 64))) <<
						(FixedPoint96.RESOLUTION - 64)
				)
			)
		);
	}

	function sqrtP(uint256 price) internal pure returns (uint160) {
		return uint160(TickMath.getSqrtRatioAtTick(tick(price)));
	}

	struct ExpectedStateAfterSwap {
		UniswapV3Pool pool;
		ERC20Mintable token0;
		ERC20Mintable token1;
		uint256 userBalance0;
		uint256 userBalance1;
		uint256 poolBalance0;
		uint256 poolBalance1;
		uint160 sqrtPriceX96;
		int24 tick;
		uint128 currentLiquidity;
	}

	function assertSwapState(ExpectedStateAfterSwap memory expected) internal {
		assertEq(
			expected.token0.balanceOf(address(this)),
			uint256(expected.userBalance0),
			"invalid user ETH balance"
		);
		assertEq(
			expected.token1.balanceOf(address(this)),
			uint256(expected.userBalance1),
			"invalid user USDC balance"
		);
		assertEq(
			expected.token0.balanceOf(address(expected.pool)),
			uint256(expected.poolBalance0),
			"invalid pool ETH balance"
		);
		assertEq(
			expected.token1.balanceOf(address(expected.pool)),
			uint256(expected.poolBalance1),
			"invalid pool USDC balance"
		);

		(uint160 sqrtPricex96, int24 currentTick) = expected.pool.slot0();
		assertEq(
			sqrtPricex96,
			expected.sqrtPriceX96,
			"invalid current sqrtPrice"
		);
		assertEq(currentTick, expected.tick, "invalid current tick");
		assertEq(
			expected.pool.liquidity(),
			expected.currentLiquidity,
			"invalid current liquidity"
		);
	}

	function encodeError(
		string memory error
	) internal pure returns (bytes memory encoded) {
		encoded = abi.encodeWithSignature(error);
	}

	function encodeExtra(
		address token0_,
		address token1_,
		address payer
	) internal pure returns (bytes memory) {
		return
			abi.encode(
				IUniswapV3Pool.CallbackData({
					token0: token0_,
					token1: token1_,
					payer: payer
				})
			);
	}

	function tickInBitmap(
		UniswapV3Pool pool,
		int24 tick_
	) internal view returns (bool initialized) {
		int16 wordPos = int16(tick_ >> 8);
		uint8 bitPos = uint8(uint24(tick_ % 256));
		uint256 word = pool.tickBitmap(wordPos);

		initialized = (word & (1 << bitPos)) != 0;
	}
}
