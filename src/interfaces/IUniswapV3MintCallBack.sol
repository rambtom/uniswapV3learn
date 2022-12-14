// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

interface IUniswapV3MintCallback {
	function uniswapV3MintCallback(
		uint256 amount0,
		uint256 amount1,
		// calldata:外部コントラクト関数の参照型のパラメタとして要求される場合にのみ有効
		bytes calldata data
	) external;
}
