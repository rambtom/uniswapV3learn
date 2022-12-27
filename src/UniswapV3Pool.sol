// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;
import "./lib/Tick.sol";
import "./lib/Position.sol";
import "./lib/Math.sol";
import "./lib/SwapMath.sol";
import "./lib/TickMath.sol";
import "./lib/TickBitmap.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./interfaces/IERC20.sol";

contract UniswapV3Pool {
	// import
	using TickBitmap for mapping(int16 => uint256);
	using Tick for mapping(int24 => Tick.Info);
	using Position for mapping(bytes32 => Position.Info);
	using Position for Position.Info;

	// error
	error InvalidTickRange();
	error ZeroLiquidity();
	error InsufficientInputAmount();

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

	// constant
	int24 internal constant MIN_TICK = -887272;
	int24 internal constant MAX_TICK = -MIN_TICK;

	address public immutable token0;
	address public immutable token1;

	// structure
	struct Slot0 {
		uint160 sqrtPriceX96;
		int24 tick;
	}

	struct CallbackData {
		address token0;
		address token1;
		address payer;
	}

	struct SwapState {
		uint256 amountSpecifiedRemaining;
		uint256 amountCaluculated;
		uint160 sqrtPriceX96;
		int24 tick;
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
			lowerTick < MIN_TICK ||
			upperTick > MAX_TICK
		) revert InvalidTickRange();

		// set flag true, if added or removed liquidity
		// set flag false, if liq doesn't change
		if (amount == 0) revert ZeroLiquidity();
		bool flippedLower = ticks.update(lowerTick, amount);
		bool flippedUpper = ticks.update(upperTick, amount);

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
		amount0 = Math.calcAmount0Delta(
			// not slot0_.sqrtPriceX96,
			TickMath.getSqrtRatioAtTick(slot0_.tick),
			TickMath.getSqrtRatioAtTick(upperTick),
			amount
		);
		amount1 = Math.calcAmount1Delta(
			TickMath.getSqrtRatioAtTick(slot0_.tick),
			TickMath.getSqrtRatioAtTick(lowerTick),
			amount
		);

		// update liquidity
		liquidity += uint128(amount);

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
		bytes calldata data
	) public returns (int256 amount0, int256 amount1) {
		Slot0 memory slot0_ = slot0;

		//initialized swap state
		SwapState memory state = SwapState({
			amountSpecifiedRemaining: amountSpecified,
			amountCaluculated: 0,
			sqrtPriceX96: slot0_.sqrtPriceX96,
			tick: slot0_.tick
		});
		// loop for settlement of amount
		while (state.amountSpecifiedRemaining > 0) {
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
					step.sqrtPriceNextX96,
					liquidity,
					state.amountSpecifiedRemaining
				);

			state.amountSpecifiedRemaining -= step.amountIn;
			state.amountCaluculated += step.amountOut;
			state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
		}

		// set price afret swapping
		if (state.tick != slot0_.tick) {
			(slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
		}

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

	function balance0() internal returns (uint256 balance) {
		balance = IERC20(token0).balanceOf(address(this));
	}

	function balance1() internal returns (uint256 balance) {
		balance = IERC20(token1).balanceOf(address(this));
	}
}
