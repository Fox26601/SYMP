// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Minimal Uniswap v3 interfaces used for pool bootstrap.
interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function initialize(uint160 sqrtPriceX96) external;
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool);

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

/// @notice Create SYMP/USDC Uniswap v3 pool (0.3%) near seed price and mint LP.
/// @dev Env: UNISWAP_V3_FACTORY, UNISWAP_NPM, SYMP_TOKEN, USDC_TOKEN, SYMP_LP_AMOUNT, USDC_LP_AMOUNT (optional).
/// Seed price ~ $0.001 → 1 SYMP = 0.001 USDC. Token order: token0 < token1 by address.
contract CreatePool is Script {
    uint24 constant FEE = 3000;

    function run() external {
        address factory = vm.envAddress("UNISWAP_V3_FACTORY");
        address npm = vm.envAddress("UNISWAP_NPM");
        address symp = vm.envAddress("SYMP_TOKEN");
        address usdc = vm.envAddress("USDC_TOKEN");
        uint256 sympAmount = vm.envUint("SYMP_LP_AMOUNT");
        uint256 usdcAmount = vm.envOr("USDC_LP_AMOUNT", uint256(0));

        // sqrtPriceX96 for price = USDC per SYMP in raw units is non-trivial when decimals differ.
        // Operator supplies SQRT_PRICE_X96 explicitly (computed off-chain); default encodes ~0.001 USDC/SYMP
        // when SYMP is token1 and USDC is token0 — verify before mainnet.
        uint160 sqrtPriceX96 = uint160(vm.envUint("SQRT_PRICE_X96"));

        (address token0, address token1) = symp < usdc ? (symp, usdc) : (usdc, symp);
        uint256 amount0 = token0 == symp ? sympAmount : usdcAmount;
        uint256 amount1 = token1 == symp ? sympAmount : usdcAmount;

        int24 tickLower = int24(vm.envOr("TICK_LOWER", int256(-887220)));
        int24 tickUpper = int24(vm.envOr("TICK_UPPER", int256(887220)));

        vm.startBroadcast();
        IERC20(symp).approve(npm, sympAmount);
        if (usdcAmount > 0) {
            IERC20(usdc).approve(npm, usdcAmount);
        }

        address pool = INonfungiblePositionManager(npm).createAndInitializePoolIfNecessary(
            token0, token1, FEE, sqrtPriceX96
        );

        (uint256 tokenId, uint128 liquidity,,) = INonfungiblePositionManager(npm).mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: msg.sender,
                deadline: block.timestamp + 1 hours
            })
        );
        vm.stopBroadcast();

        console2.log("factory", factory);
        console2.log("pool", pool);
        console2.log("npmTokenId", tokenId);
        console2.log("liquidity", uint256(liquidity));
    }
}
