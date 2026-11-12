// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SymbolicPleasures} from "../src/SymbolicPleasures.sol";
import {SeedSale} from "../src/SeedSale.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract SeedSaleTest is Test {
    uint256 constant START = 1_861_920_000;
    uint256 constant END = 1_862_956_799;
    uint256 constant SOFT = 2_000e6;
    uint256 constant HARD = 10_000e6;
    uint256 constant MIN = 10e6;
    uint256 constant MAX_WALLET = 500e6;
    uint256 constant PRICE = 1000 ether; // SYMP per 1e6 USDC unit → quote uses /1e6 so 1000e18 per USDC

    SymbolicPleasures internal symp;
    MockUSDC internal usdc;
    SeedSale internal sale;
    address internal treasury;
    address internal buyer;

    function setUp() public {
        treasury = makeAddr("treasury");
        buyer = makeAddr("buyer");
        symp = new SymbolicPleasures(address(this));
        usdc = new MockUSDC();
        sale = new SeedSale(
            address(symp),
            address(usdc),
            treasury,
            SOFT,
            HARD,
            MIN,
            MAX_WALLET,
            START,
            END,
            PRICE
        );
        // Fund sale with 100M SYMP (seed allocation)
        symp.transfer(address(sale), 100_000_000 ether);
        usdc.mint(buyer, 1_000_000e6);
    }

    function _open() internal {
        vm.warp(START);
    }

    function test_timestampsMatchPlan() public view {
        assertEq(sale.start(), START);
        assertEq(sale.end(), END);
        assertEq(START, 1_861_920_000);
        assertEq(END, 1_862_956_799);
    }

    function test_phaseUpcomingOpenEnded() public {
        vm.warp(START - 1);
        assertEq(keccak256(bytes(sale.phase())), keccak256(bytes("Upcoming")));
        _open();
        assertEq(keccak256(bytes(sale.phase())), keccak256(bytes("Open")));
        vm.warp(END + 1);
        assertEq(keccak256(bytes(sale.phase())), keccak256(bytes("Ended")));
    }

    function test_contributeHappyPath() public {
        _open();
        uint256 usdcAmount = 100e6;
        uint256 expectedSymp = sale.quoteSymp(usdcAmount);
        assertEq(expectedSymp, 100_000 ether); // 100 USDC * 1000

        vm.startPrank(buyer);
        usdc.approve(address(sale), usdcAmount);
        sale.contribute(usdcAmount);
        vm.stopPrank();

        assertEq(symp.balanceOf(buyer), expectedSymp);
        assertEq(sale.contributedUsdc(buyer), usdcAmount);
        assertEq(sale.totalRaisedUsdc(), usdcAmount);
    }

    function test_revertBeforeStart() public {
        vm.warp(START - 1);
        vm.startPrank(buyer);
        usdc.approve(address(sale), MIN);
        vm.expectRevert(SeedSale.SaleNotOpen.selector);
        sale.contribute(MIN);
        vm.stopPrank();
    }

    function test_revertBelowMin() public {
        _open();
        vm.startPrank(buyer);
        usdc.approve(address(sale), MIN - 1);
        vm.expectRevert(SeedSale.BelowMinimum.selector);
        sale.contribute(MIN - 1);
        vm.stopPrank();
    }

    function test_revertMaxPerWallet() public {
        _open();
        vm.startPrank(buyer);
        usdc.approve(address(sale), MAX_WALLET + 1);
        vm.expectRevert(SeedSale.CapExceeded.selector);
        sale.contribute(MAX_WALLET + 1);
        vm.stopPrank();
    }

    function test_hardCap() public {
        _open();
        // Fill almost to hard with multiple wallets
        for (uint256 i = 0; i < 20; i++) {
            address w = makeAddr(string(abi.encodePacked("w", i)));
            usdc.mint(w, MAX_WALLET);
            vm.startPrank(w);
            usdc.approve(address(sale), MAX_WALLET);
            sale.contribute(MAX_WALLET);
            vm.stopPrank();
        }
        assertEq(sale.totalRaisedUsdc(), HARD);
        assertFalse(sale.isOpen());

        vm.startPrank(buyer);
        usdc.approve(address(sale), MIN);
        vm.expectRevert(SeedSale.SaleNotOpen.selector);
        sale.contribute(MIN);
        vm.stopPrank();
    }

    function test_finalizeAfterSoftCapByTreasury() public {
        _open();
        // Raise soft cap with 4 wallets * 500
        for (uint256 i = 0; i < 4; i++) {
            address w = makeAddr(string(abi.encodePacked("s", i)));
            usdc.mint(w, MAX_WALLET);
            vm.startPrank(w);
            usdc.approve(address(sale), MAX_WALLET);
            sale.contribute(MAX_WALLET);
            vm.stopPrank();
        }
        assertGe(sale.totalRaisedUsdc(), SOFT);

        vm.prank(buyer);
        vm.expectRevert(SeedSale.Unauthorized.selector);
        sale.finalize();

        vm.prank(treasury);
        sale.finalize();
        assertTrue(sale.finalized());
    }

    function test_finalizeAfterEndWithoutSoft() public {
        _open();
        vm.startPrank(buyer);
        usdc.approve(address(sale), MIN);
        sale.contribute(MIN);
        vm.stopPrank();

        vm.warp(END + 1);
        sale.finalize();
        assertTrue(sale.finalized());

        uint256 usdcBal = usdc.balanceOf(address(sale));
        uint256 unsold = symp.balanceOf(address(sale));
        vm.startPrank(treasury);
        sale.withdrawUSDC(treasury);
        sale.reclaimUnsold(treasury);
        vm.stopPrank();
        assertEq(usdc.balanceOf(treasury), usdcBal);
        assertEq(symp.balanceOf(treasury), unsold);
    }

    function test_withdrawBeforeFinalizeReverts() public {
        _open();
        vm.prank(treasury);
        vm.expectRevert(SeedSale.NotFinalized.selector);
        sale.withdrawUSDC(treasury);
    }
}
