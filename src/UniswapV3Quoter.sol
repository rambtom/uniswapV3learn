// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3Pool.sol";
import "./lib/TickMath.sol";

contract UniswapV3Quoter {
	struct Quoteparams {
		address pool;
		uint256 amountIn;
		uint160 sqrtPriceLimitX96;
		bool zeroForOne;
	}

	function quote(
		Quoteparams memory params
	)
		public
		returns (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter)
	{
		try
			IUniswapV3Pool(params.pool).swap(
				address(this),
				params.zeroForOne,
				params.amountIn,
				params.sqrtPriceLimitX96 == 0
					? (
						params.zeroForOne
							? TickMath.MIN_SQRT_RATIO + 1
							: TickMath.MAX_SQRT_RATIO - 1
					)
					: params.sqrtPriceLimitX96,
				abi.encode(params.pool)
			)
		{} catch (bytes memory reason) {
			// if catch reverted data, this method return decoded data
			return abi.decode(reason, (uint256, uint160, int24));
		}
	}

	function uniswapV3SwapCallback(
		int256 amount0Delta,
		int256 amount1Delta,
		bytes memory data
	) external view {
		address pool = abi.decode(data, (address));

		uint256 amountOut = amount0Delta > 0
			? uint256(-amount1Delta)
			: uint256(-amount0Delta);

		(uint160 sqrtPriceX96After, int24 tickAfter) = IUniswapV3Pool(pool)
			.slot0();

		assembly {
			// store free memory pointer
			let ptr := mload(0x40)
			// store amountOut in prt
			mstore(ptr, amountOut)
			// store sqrtPriceX96After in prt + 20
			mstore(add(ptr, 0x20), sqrtPriceX96After)
			mstore(add(ptr, 0x40), tickAfter)
			// revert the call and return 96 bytes that is length of we wrote to memory
			revert(ptr, 96)
			// revert method reset pool contract so that we don't change pool contract.
		}
	}
}
