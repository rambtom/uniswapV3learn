// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

interface IUniswapV3SwapCallback {
	function uniswapV3SwapCallback(
		int256 amount0,
		int256 amount1,
		// calldata:外部コントラクト関数の参照型のパラメタとして要求される場合にのみ有効
		bytes calldata data
	) external;
}
