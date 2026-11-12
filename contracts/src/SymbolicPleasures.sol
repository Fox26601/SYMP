// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title SymbolicPleasures (SYMP)
/// @notice Fixed-supply ERC-20. Entire supply minted once to deployer. No further minting.
contract SymbolicPleasures is ERC20, ERC20Permit {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1B * 1e18

    constructor(address recipient) ERC20("SymbolicPleasures", "SYMP") ERC20Permit("SymbolicPleasures") {
        require(recipient != address(0), "SYMP: zero recipient");
        _mint(recipient, TOTAL_SUPPLY);
    }
}
