// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SymbolicPleasures} from "../src/SymbolicPleasures.sol";

contract SymbolicPleasuresTest is Test {
    SymbolicPleasures internal token;
    address internal recipient = address(0xBEEF);

    function setUp() public {
        token = new SymbolicPleasures(recipient);
    }

    function test_totalSupplyAndRecipient() public view {
        assertEq(token.totalSupply(), 1_000_000_000 ether);
        assertEq(token.balanceOf(recipient), 1_000_000_000 ether);
        assertEq(token.name(), "SymbolicPleasures");
        assertEq(token.symbol(), "SYMP");
        assertEq(token.decimals(), 18);
    }

    function test_transfer() public {
        vm.prank(recipient);
        token.transfer(address(0xCAFE), 1 ether);
        assertEq(token.balanceOf(address(0xCAFE)), 1 ether);
    }

    function test_revertZeroRecipient() public {
        vm.expectRevert(bytes("SYMP: zero recipient"));
        new SymbolicPleasures(address(0));
    }
}
