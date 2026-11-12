// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {SymbolicPleasures} from "../src/SymbolicPleasures.sol";

/// @notice Deploy SYMP. Recipient defaults to msg.sender (deployer / treasury).
contract Deploy is Script {
    function run() external {
        address recipient = vm.envOr("SYMP_RECIPIENT", msg.sender);
        vm.startBroadcast();
        SymbolicPleasures token = new SymbolicPleasures(recipient);
        vm.stopBroadcast();
        console2.log("SymbolicPleasures", address(token));
        console2.log("recipient", recipient);
        console2.log("totalSupply", token.totalSupply());
    }
}
