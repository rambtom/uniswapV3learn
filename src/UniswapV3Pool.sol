// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;
import "./lib/Tick.sol";
import "./lib/Position.sol";
import "./lib/Math.sol";
import "./lib/SwapMath.sol";
import "./lib/TickMath.sol";
import "./lib/TickBitmap.sol";
import "./lib/LiquidityMath.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IERC20.sol";
import "forge-std/console.sol";

contract UniswapV3Pool is IUniswapV3Pool {
	// import
	using TickBitmap for mapping(int16 => uint256);
	using Tick for mapping(int24 => Tick.Info);
	using Position for mapping(bytes32 => Position.Info);
	using Position for Position.Info;

	// error
	error InvalidTickRange();
	error ZeroLiquidity();
	error InsufficientInputAmount();
	error NotEnoughLiquidity();
	error InvalidPriceLimit();

	// event
	event Mint(
		address sender,
		address indexed owner,
		int24 indexed tickLower,
		int24 indexed tickUpper,
		uint128 amount,
		uint256 amount0,
		uint256 amount1
	);

	event Swap(
		address indexed sender,
		address indexed recipient,
		int256 amount0,
		int256 amount1,
		uint160 sqrtPriceX96,
		uint128 liquidity,
		int24 tick
	);

	event Flash(address indexed recipient, uint256 amount0, uint256 amount1);

	// constant
	address public immutable token0;
	address public immutable token1;

	// structure
	struct Slot0 {
		uint160 sqrtPriceX96;
		int24 tick;
	}

	struct SwapState {
		uint256 amountSpecifiedRemaining;
		uint256 amountCaluculated;
		uint160 sqrtPriceX96;
		int24 tick;
		uint128 liquidity;
	}
	struct StepState {
		uint160 sqrtPriceStartX96;
		int24 nextTick;
		uint160 sqrtPriceNextX96;
		uint256 amountIn;
		uint256 amountOut;
	}

	// variables
	Slot0 public slot0;

	uint128 public liquidity;
	mapping(int24 => Tick.Info) public ticks;
	mapping(bytes32 => Position.Info) public positions;
	mapping(int16 => uint256) public tickBitmap;

	// constructor
	constructor(
		address token0_,
		address token1_,
		uint160 sqrtPriceX96,
		int24 tick
	) {
		token0 = token0_;
		token1 = token1_;
		slot0 = Slot0({ sqrtPriceX96: sqrtPriceX96, tick: tick });
	}

	// method
	function mint(
		address owner,
		int24 lowerTick,
		int24 upperTick,
		uint128 amount,
		bytes calldata data
	) external returns (uint256 amount0, uint256 amount1) {
		if (
			lowerTick >= upperTick ||
			lowerTick < TickMath.MIN_TICK ||
			upperTick > TickMath.MAX_TICK
		) revert InvalidTickRange();

		// set flag true, if added or removed liquidity
		// set flag false, if liq doesn't change
		if (amount == 0) revert ZeroLiquidity();
		bool flippedLower = ticks.update(lowerTick, int128(amount), false);
		bool flippedUpper = ticks.update(upperTick, int128(amount), true);

		// if flag true, ticks are flipped 1->0, 0->1
		if (flippedLower) {
			tickBitmap.flipTick(lowerTick, 1);
		}
		if (flippedUpper) {
			tickBitmap.flipTick(upperTick, 1);
		}
		// keccak256(owner, ltick, utick)
		Position.Info storage position = positions.get(
			owner,
			lowerTick,
			upperTick
		);
		// add specified owners liquidity
		position.update(amount);

		Slot0 memory slot0_ = slot0;

		// calc token amount to add liq in specified price range
		if (slot0_.tick < lowerTick) {
			amount0 = Math.calcAmount0Delta(
				TickMath.getSqrtRatioAtTick(lowerTick),
				TickMath.getSqrtRatioAtTick(upperTick),
				amount
			);
		} else if (slot0_.tick < upperTick) {
			amount0 = Math.calcAmount0Delta(
				// not slot0_.sqrtPriceX96,
				slot0_.sqrtPriceX96,
				TickMath.getSqrtRatioAtTick(upperTick),
				amount
			);
			amount1 = Math.calcAmount1Delta(
				slot0_.sqrtPriceX96,
				TickMath.getSqrtRatioAtTick(lowerTick),
				amount
			);
			// when current price is in specified price range, add current liquidity
			// use [int] not [uint]: amount is negative when removing liquidity
			liquidity = LiquidityMath.addLiquidity(liquidity, int128(amount));
		} else {
			amount1 = Math.calcAmount1Delta(
				TickMath.getSqrtRatioAtTick(lowerTick),
				TickMath.getSqrtRatioAtTick(upperTick),
				amount
			);
		}

		// record token amounts before minting
		uint256 balance0Before;
		uint256 balance1Before;
		if (amount0 > 0) balance0Before = balance0();
		if (amount1 > 0) balance1Before = balance1();

		// callback mint function
		IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
			amount0,
			amount1,
			data
		);

		// check whether success minting or not
		if (amount0 > 0 && balance0Before + amount0 > balance0())
			revert InsufficientInputAmount();
		if (amount1 > 0 && balance1Before + amount1 > balance1())
			revert InsufficientInputAmount();

		emit Mint(
			msg.sender,
			owner,
			lowerTick,
			upperTick,
			amount,
			amount0,
			amount1
		);
	}

	function swap(
		address recipient,
		bool zeroForOne,
		uint256 amountSpecified,
		uint160 sqrtPriceLimitX96,
		bytes calldata data
	) public returns (int256 amount0, int256 amount1) {
		Slot0 memory slot0_ = slot0;
		uint128 liquidity_ = liquidity;

		// slippage protection
		if (
			zeroForOne
				? sqrtPriceLimitX96 > slot0_.sqrtPriceX96 ||
					sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
				: sqrtPriceLimitX96 < slot0_.sqrtPriceX96 ||
					sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
		) revert InvalidPriceLimit();

		//initialized swap state
		SwapState memory state = SwapState({
			amountSpecifiedRemaining: amountSpecified,
			amountCaluculated: 0,
			sqrtPriceX96: slot0_.sqrtPriceX96,
			tick: slot0_.tick,
			liquidity: liquidity_
		});

		// loop for settlement of amount
		while (
			state.amountSpecifiedRemaining > 0 &&
			state.sqrtPriceX96 != sqrtPriceLimitX96
		) {
			StepState memory step;
			step.sqrtPriceStartX96 = state.sqrtPriceX96;

			// find tick of liquidity for swap
			(step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(
				state.tick,
				1,
				zeroForOne
			);

			// calcurate price from tick,
			// this is price range that should provide liquidity for the swap.
			step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

			// calcurate swap from liquidity and next tick price
			(state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath
				.computeSwapStep(
					state.sqrtPriceX96,
					(
						zeroForOne
							? sqrtPriceLimitX96 < step.sqrtPriceNextX96
							: sqrtPriceLimitX96 > step.sqrtPriceNextX96
					)
						? step.sqrtPriceNextX96
						: sqrtPriceLimitX96,
					state.liquidity,
					state.amountSpecifiedRemaining
				);

			state.amountSpecifiedRemaining -= step.amountIn;
			state.amountCaluculated += step.amountOut;

			if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
				int128 liquidityDelta = ticks.cross(step.nextTick);

				if (zeroForOne) liquidityDelta = -liquidityDelta;

				state.liquidity = LiquidityMath.addLiquidity(
					state.liquidity,
					liquidityDelta
				);

				if (state.liquidity == 0) revert NotEnoughLiquidity();

				state.tick = zeroForOne ? step.nextTick - 1 : step.nextTick;
			} else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
				state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
			}
		}

		// set price afret swapping
		if (state.tick != slot0_.tick) {
			(slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
		}

		if (liquidity_ != state.liquidity) liquidity = state.liquidity;

		(amount0, amount1) = zeroForOne
			? (
				int256(amountSpecified - state.amountSpecifiedRemaining),
				-int256(state.amountCaluculated)
			)
			: (
				-int256(state.amountCaluculated),
				int256(amountSpecified - state.amountSpecifiedRemaining)
			);
		if (zeroForOne) {
			// do nothing now because it's only interface
			IERC20(token1).transfer(recipient, uint256(-amount1));

			uint256 balance0Before = balance0();
			IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
				amount0,
				amount1,
				data
			);
			if (balance0Before + uint256(amount0) > balance0())
				revert InsufficientInputAmount();
		} else {
			IERC20(token0).transfer(recipient, uint256(-amount0));

			uint256 balance1Before = balance1();
			IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
				amount0,
				amount1,
				data
			);
			if (balance1Before + uint256(amount1) > balance1())
				revert InsufficientInputAmount();
		}
		emit Swap(
			msg.sender,
			recipient,
			amount0,
			amount1,
			slot0.sqrtPriceX96,
			liquidity,
			slot0.tick
		);
	}

	function flash(
		uint256 amount0,
		uint256 amount1,
		bytes calldata data
	) public {
		uint256 balance0Before = IERC20(token0).balanceOf(address(this));
		uint256 balance1Before = IERC20(token1).balanceOf(address(this));

		if (amount0 > 0) IERC20(token0).transfer(msg.sender, amount0);
		if (amount1 > 0) IERC20(token1).transfer(msg.sender, amount1);

		// user repay the loan
		IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(data);

		require(IERC20(token0).balanceOf(address(this)) >= balance0Before);
		require(IERC20(token1).balanceOf(address(this)) >= balance1Before);

		emit Flash(msg.sender, amount0, amount1);
	}

	function balance0() internal returns (uint256 balance) {
		balance = IERC20(token0).balanceOf(address(this));
	}

	function balance1() internal returns (uint256 balance) {
		balance = IERC20(token1).balanceOf(address(this));
	}
}
