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

contract UniswapV3PoolTest is Test, TestUtils, UniswapV3PoolUtils {
	// contract
	ERC20Mintable token0;
	ERC20Mintable token1;
	UniswapV3Pool pool;

	bool transferInMintCallback = true;
	bool flashCallbackCalled = false;

	// set tokens contrat
	function setUp() public {
		token0 = new ERC20Mintable("Ether", "ETH", 18);
		token1 = new ERC20Mintable("USDC", "USDC", 18);
	}

	function testMintInRange() public {
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

		// set pool contract and mint liquidity
		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

		(uint256 expectedAmount0, uint256 expectedAmount1) = (
			0.998995580131581600 ether,
			4999.999999999999999999 ether
		);

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
	}

	function testMintRangeBelow() public {
		LiquidityRange[] memory liquidity = new LiquidityRange[](1);
		liquidity[0] = liquidityRange(3000, 4500, 1 ether, 5000 ether, 5000);
		TestCaseParams memory params = TestCaseParams({
			wethBalance: 1 ether,
			usdcBalance: 5000 ether,
			currentPrice: 5000,
			liquidity: liquidity,
			transferInMintCallback: true,
			transferInSwapCallback: true,
			mintLiquidity: true
		});

		// set pool contract and mint liquidity
		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

		(uint256 expectedAmount0, uint256 expectedAmount1) = (
			0 ether,
			4999.999999999999999999 ether
		);

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
	}

	function testMintRangeAbove() public {
		LiquidityRange[] memory liquidity = new LiquidityRange[](1);
		liquidity[0] = liquidityRange(5500, 6000, 1 ether, 5000 ether, 5000);
		TestCaseParams memory params = TestCaseParams({
			wethBalance: 1 ether,
			usdcBalance: 5000 ether,
			currentPrice: 5000,
			liquidity: liquidity,
			transferInMintCallback: true,
			transferInSwapCallback: true,
			mintLiquidity: true
		});

		// set pool contract and mint liquidity
		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

		(uint256 expectedAmount0, uint256 expectedAmount1) = (1 ether, 0 ether);

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
	}

	function testMintOverlappingRanges() public {
		LiquidityRange[] memory liquidity = new LiquidityRange[](2);
		liquidity[0] = liquidityRange(4500, 5500, 1 ether, 5000 ether, 5000);
		liquidity[1] = liquidityRange(
			4000,
			6000,
			(liquidity[0].amount * 80) / 100
		);
		TestCaseParams memory params = TestCaseParams({
			// these amounts of tokens are minted amounts we can use from ERC20
			wethBalance: 3 ether,
			usdcBalance: 15000 ether,
			currentPrice: 5000,
			liquidity: liquidity,
			transferInMintCallback: true,
			transferInSwapCallback: true,
			mintLiquidity: true
		});

		// set pool contract and mint liquidity
		(uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

		(uint256 expectedAmount0, uint256 expectedAmount1) = (
			2.264132471028352136 ether,
			13228.095315639652355135 ether
		);

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
	}

	function testMintInvalidTickRangeLower() public {
		pool = new UniswapV3Pool(
			address(token0),
			address(token1),
			uint160(1),
			0
		);

		vm.expectRevert(encodeError("InvalidTickRange()"));
		pool.mint(address(this), -887273, 0, 0, "");
	}

	function testMintInvalidTickRangeUpper() public {
		pool = new UniswapV3Pool(
			address(token0),
			address(token1),
			uint160(1),
			0
		);

		vm.expectRevert(encodeError("InvalidTickRange()"));
		pool.mint(address(this), 0, 887273, 0, "");
	}

	function testMintZeroLiquidity() public {
		pool = new UniswapV3Pool(
			address(token0),
			address(token1),
			uint160(1),
			0
		);

		vm.expectRevert(encodeError("ZeroLiquidity()"));
		pool.mint(address(this), -1, 0, 0, "");
	}

	// have no token but execute mint
	function testMintInsufficientTokenBalance() public {
		LiquidityRange[] memory liquidity = new LiquidityRange[](1);
		liquidity[0] = liquidityRange(5500, 6000, 1 ether, 5000 ether, 5000);
		TestCaseParams memory params = TestCaseParams({
			wethBalance: 0 ether,
			usdcBalance: 0 ether,
			currentPrice: 5000,
			liquidity: liquidity,
			transferInMintCallback: false,
			transferInSwapCallback: true,
			// Don't mint in setUpTestCase, we validate mint here
			mintLiquidity: false
		});
		setupTestCase(params);

		vm.expectRevert(encodeError("InsufficientInputAmount()"));
		pool.mint(
			address(this),
			liquidity[0].lowerTick,
			liquidity[0].upperTick,
			liquidity[0].amount,
			""
		);
	}

	// // insufficient user's amount on swap
	// function testSwapInsufficientInputAmount() public {
	// 	TestCaseParams memory params = TestCaseParams({
	// 		wethBalance: 1 ether,
	// 		usdcBalance: 5000 ether,
	// 		currentTick: 85176,
	// 		lowerTick: 84222,
	// 		upperTick: 86129,
	// 		liquidity: 1517882343751509868544,
	// 		currentSqrtP: 5602277097478614198912276234240,
	// 		transferInMintCallback: true,
	// 		transferInSwapCallback: false,
	// 		mintLiquidity: true
	// 	});

	// 	setupTestCase(params);

	// 	vm.expectRevert(abi.encodeWithSignature("InsufficientInputAmount()"));
	// 	pool.swap(address(this), false, 42 ether, "");
	// }

	// // test swap usdc
	// function testSwapBuyEthButNotEnoughLiquidity() public {
	// 	TestCaseParams memory params = TestCaseParams({
	// 		wethBalance: 1 ether,
	// 		usdcBalance: 5000 ether,
	// 		currentTick: 85176,
	// 		lowerTick: 84222,
	// 		upperTick: 86129,
	// 		liquidity: 1517882343751509868544,
	// 		currentSqrtP: 5602277097478614198912276234240,
	// 		transferInMintCallback: true,
	// 		transferInSwapCallback: false,
	// 		mintLiquidity: true
	// 	});

	// 	setupTestCase(params);
	// 	// swap amount
	// 	uint256 swapAmount = 5500 ether;
	// 	token1.mint(address(this), swapAmount);
	// 	token1.approve(address(this), swapAmount);

	// 	UniswapV3Pool.CallbackData memory extra = IUniswapV3Pool.CallbackData({
	// 		token0: address(token0),
	// 		token1: address(token1),
	// 		payer: address(this)
	// 	});

	// 	// stdError.arithmeticError
	// 	// the internal solidity error when an arithmetic operation fails.
	// 	vm.expectRevert(stdError.arithmeticError);
	// 	pool.swap(address(this), false, swapAmount, abi.encode(extra));
	// }

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

			bytes memory extra = encodeExtra(
				address(token0),
				address(token1),
				address(this)
			);

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
	}

	//pass tokens to owner
	function uniswapV3MintCallback(
		uint256 amount0,
		uint256 amount1,
		bytes calldata data
	) public {
		if (transferInMintCallback) {
			IUniswapV3Pool.CallbackData memory extra = abi.decode(
				data,
				(IUniswapV3Pool.CallbackData)
			);
			IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
			IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
		}
	}

	// pass token to owner
	// function uniswapV3SwapCallback(
	// 	int256 amount0,
	// 	int256 amount1,
	// 	bytes calldata data
	// ) public {
	// 	if (transferInSwapCallback) {
	// 		IUniswapV3Pool.CallbackData memory extra = abi.decode(
	// 			data,
	// 			(IUniswapV3Pool.CallbackData)
	// 		);

	// 		if (amount0 > 0) {
	// 			IERC20(extra.token0).transferFrom(
	// 				extra.payer,
	// 				msg.sender,
	// 				uint256(amount0)
	// 			);
	// 		}

	// 		if (amount1 > 0) {
	// 			IERC20(extra.token1).transferFrom(
	// 				extra.payer,
	// 				msg.sender,
	// 				uint256(amount1)
	// 			);
	// 		}
	// 	}
	// }
}
