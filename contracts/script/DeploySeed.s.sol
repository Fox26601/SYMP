// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SymbolicPleasures} from "../src/SymbolicPleasures.sol";
import {SeedSale} from "../src/SeedSale.sol";

/// @notice Deploy SeedSale and fund it with 100M SYMP from the broadcaster balance.
contract DeploySeed is Script {
    uint256 constant SEED_ALLOCATION = 100_000_000 ether;
    uint256 constant SOFT = 2_000e6;
    uint256 constant HARD = 10_000e6;
    uint256 constant MIN = 10e6;
    uint256 constant MAX_WALLET = 500e6;
    uint256 constant PRICE = 1000 ether;

    function run() external {
        address sympAddr = vm.envAddress("SYMP_TOKEN");
        address usdcAddr = vm.envAddress("USDC_TOKEN");
        address treasury = vm.envOr("SYMP_TREASURY", msg.sender);
        // Mirror SeedSale.DEFAULT_START / DEFAULT_END (2029-01-01 .. 2029-01-12 UTC).
        uint256 start = vm.envOr("SEED_START", uint256(1_861_920_000));
        uint256 end = vm.envOr("SEED_END", uint256(1_862_956_799));

        SymbolicPleasures symp = SymbolicPleasures(sympAddr);

        vm.startBroadcast();
        SeedSale sale = new SeedSale(
            sympAddr, usdcAddr, treasury, SOFT, HARD, MIN, MAX_WALLET, start, end, PRICE
        );
        IERC20(sympAddr).transfer(address(sale), SEED_ALLOCATION);
        vm.stopBroadcast();

        console2.log("SeedSale", address(sale));
        console2.log("funded SYMP", SEED_ALLOCATION);
        console2.log("start", start);
        console2.log("end", end);
        console2.log("symp remaining with deployer", symp.balanceOf(msg.sender));
    }
}
