# import math

# MIN_TICK = -887272
# MAX_TICK = -MIN_TICK
# Q96 = 2**96
# eth = 10**18


# def getSqrtRatioAtTick(tick):
#     return math.floor(math.log(tick, 1.0001))


# def getTickAtSqrtRatio(sqrtPriceX96):
#     return int((1.0001 ** (sqrtPriceX96 / 2)) * Q96)


# def prictToSqrtPrice(price):
#     return int(math.sqrt(price) * Q96)


# def getLiquidity0(sqrtPriceAX96, sqrtPriceBX96, amount0) -> int:
#     if sqrtPriceAX96 > sqrtPriceBX96:
#         sqrtPriceAX96, sqrtPriceBX96 = sqrtPriceBX96, sqrtPriceAX96

#     return int(
#         (sqrtPriceAX96 * sqrtPriceBX96 * amount0 / Q96) / (sqrtPriceBX96 - sqrtPriceAX96)
#     )


# def getLiquidity1(sqrtPriceAX96, sqrtPriceBX96, amount1) -> int:
#     if sqrtPriceAX96 > sqrtPriceBX96:
#         sqrtPriceAX96, sqrtPriceBX96 = sqrtPriceBX96, sqrtPriceAX96

#     return int(Q96 * amount1 / (sqrtPriceBX96 - sqrtPriceAX96))


# def calcAmount0(sqrtPriceAX96, sqrtPriceBX96, liquidity) -> int:
#     if sqrtPriceAX96 > sqrtPriceBX96:
#         sqrtPriceAX96, sqrtPriceBX96 = sqrtPriceBX96, sqrtPriceAX96
#     return int(
#         (sqrtPriceBX96 - sqrtPriceAX96)
#         * liquidity
#         / sqrtPriceAX96
#         / sqrtPriceBX96
#         * Q96
#     )


# def calcAmount1(sqrtPriceAX96, sqrtPriceBX96, liquidity) -> int:
#     if sqrtPriceAX96 > sqrtPriceBX96:
#         sqrtPriceAX96, sqrtPriceBX96 = sqrtPriceBX96, sqrtPriceAX96
#     return int((sqrtPriceBX96 - sqrtPriceAX96) * liquidity / Q96)


# lowerPrice = 4545
# upperPrice = 5500
# currentPrice = 5000
# amount0 = 1 * eth
# amount1 = 5000 * eth

# sqrtLowerPriceX96 = prictToSqrtPrice(lowerPrice)
# sqrtUpperPriceX96 = prictToSqrtPrice(upperPrice)
# sqrtCurrentPriceX96 = prictToSqrtPrice(currentPrice)

# liquidity0 = getLiquidity0(sqrtCurrentPriceX96, sqrtUpperPriceX96, amount0)
# liquidity1 = getLiquidity1(sqrtLowerPriceX96, sqrtCurrentPriceX96, amount1)
# liquidity = int(min(liquidity0, liquidity1))

# print(f"liquidity: {liquidity}")
# print(
#     f"amount0: {calcAmount0(sqrtCurrentPriceX96,sqrtUpperPriceX96,liquidity)/eth}, amount1: {calcAmount1(sqrtLowerPriceX96,sqrtCurrentPriceX96,liquidity)/eth}"
# )
import math

min_tick = -887272
max_tick = 887272

q96 = 2**96
eth = 10**18


def price_to_tick(p):
    return math.floor(math.log(p, 1.0001))


def price_to_sqrtp(p):
    return int(math.sqrt(p) * q96)


def tick_to_sqrtp(t):
    return int((1.0001 ** (t / 2)) * q96)


def liquidity0(amount, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return (amount * (pa * pb) / q96) / (pb - pa)


def liquidity1(amount, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return amount * q96 / (pb - pa)


def calc_amount0(liq, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return int(liq * q96 * (pb - pa) / pb / pa)


def calc_amount1(liq, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return int(liq * (pb - pa) / q96)


# Liquidity provision
price_low = 4545
price_cur = 5000
price_upp = 5500

print(f"Price range: {price_low}-{price_upp}; current price: {price_cur}")

sqrtp_low = tick_to_sqrtp(price_to_tick(price_low))
sqrtp_cur = tick_to_sqrtp(price_to_tick(price_cur))
sqrtp_upp = tick_to_sqrtp(price_to_tick(price_upp))

amount_eth = 1 * eth
amount_usdc = 5000 * eth

liq0 = liquidity0(amount_eth, sqrtp_cur, sqrtp_upp)
liq1 = liquidity1(amount_usdc, sqrtp_cur, sqrtp_low)
liq = int(min(liq0, liq1))

# In mint function, we calcurate specified sqrt price range as follows
# 1. Specifying price range : 4545, 5500
# 2. Calucurating tick : 84222, 86129
# 3. Calucurating sqrt price range : -, -
# So we shouldn't calucutate as follows, via tick !
# sqrt(price) * Q96

print(tick_to_sqrtp(84222))
print(sqrtp_low)
print(liq)
print(calc_amount0(liq, sqrtp_cur, sqrtp_upp))
print(calc_amount1(liq, sqrtp_low, sqrtp_cur))
