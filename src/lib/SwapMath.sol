// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

import "./Math.sol";

library SwapMath {
	function computeSwapStep(
		uint160 sqrtPriceCurrentX96,
		uint160 sqrtPriceTargetX96,
		uint128 liquidity,
		uint256 amountRemaining
	)
		internal
		pure
		returns (uint160 sqrtPriceNextX96, uint256 amountIn, uint256 amountOut)
	{
		// check swap direction
		bool zeroForOne = sqrtPriceCurrentX96 >= sqrtPriceTargetX96;

		// calcurate price after swap
		sqrtPriceNextX96 = Math.getNextSqrtPriceFromInput(
			sqrtPriceCurrentX96,
			liquidity,
			amountRemaining,
			zeroForOne
		);
		// calcurate executed in/out Amount
		amountIn = Math.calcAmount0Delta(
			sqrtPriceCurrentX96,
			sqrtPriceNextX96,
			liquidity
		);

		amountOut = Math.calcAmount1Delta(
			sqrtPriceCurrentX96,
			sqrtPriceNextX96,
			liquidity
		);
		if (!zeroForOne) {
			(amountIn, amountOut) = (amountOut, amountIn);
		}
	}
}
