// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "prb-math/PRBMath.sol";

contract TestSomeIdea is Script {
	// function setUp() public {}

	function run() public {
		uint128 liquidity = 1517882343751509868544;
		uint160 sqrtPriceX96 = 5602277097478614198912276234240;
		uint256 amount0Delta=  0.1337 ether;

		uint160 currentPriceX96 = divRoundingUp(amount0Delta, liquidity)+divRoundingUp(1,)
	}
}
