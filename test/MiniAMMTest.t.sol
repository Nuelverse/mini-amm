// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {MiniAMM} from "../src/MiniAMM.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract MiniAMMTest is Test {
    MiniAMM miniAMM;
    MockERC20 tokenA;
    MockERC20 tokenB;

    address MARIA;
    address ALICE;

    event LiquidityAdded(address indexed depositor, uint256 sharesAmount, uint256 amountA, uint256 amountB);

    function setUp() external {
        MARIA = makeAddr("MARIA");
        ALICE = makeAddr("ALICE");
        tokenA = new MockERC20("Token A", "TKNA");
        tokenB = new MockERC20("Token B", "TKNB");
        miniAMM = new MiniAMM(tokenA, tokenB);

        tokenA.mint(MARIA, 1000e18);
        tokenA.mint(ALICE, 1000e18);

        tokenB.mint(MARIA, 1000e18);
        tokenB.mint(ALICE, 1000e18);

        vm.startPrank(MARIA);
        tokenA.approve(address(miniAMM), 1000e18);
        tokenB.approve(address(miniAMM), 1000e18);
        vm.stopPrank();

        vm.startPrank(ALICE);
        tokenA.approve(address(miniAMM), 1000e18);
        tokenB.approve(address(miniAMM), 1000e18);
        vm.stopPrank();
    }

    // ----- Happy Test ------

    function test_getAmountOut_EqualReserves() external view {
        uint256 amountOut = miniAMM.getAmountOut(100, 1000, 1000);
        assertEq(amountOut, 90);
    }

    function test_getAmountOut_ReserveOutLarger() external view {
        uint256 amountOut = miniAMM.getAmountOut(50, 1000, 4000);
        assertEq(amountOut, 189);
    }

    function test_getAmountOut_ReserveInLarger() external view {
        uint256 amountOut = miniAMM.getAmountOut(200, 2000, 500);
        assertEq(amountOut, 45);
    }

    // ----- Revert Tests -----

    function test_getAmount_RevertsWhenReserveInIsZero() external {
        vm.expectRevert(MiniAMM.MiniAMM__ZeroReserveInAmount.selector);
        miniAMM.getAmountOut(100, 0, 1000);
    }

    function test_getAmount_RevertsWhenReserveOutIsZero() external {
        vm.expectRevert(MiniAMM.MiniAMM__ZeroReserveOutAmount.selector);
        miniAMM.getAmountOut(100, 1000, 0);
    }

    function test_getAmount_RevertsWhenAmountInIsZero() external {
        vm.expectRevert(MiniAMM.MiniAMM__ZeroAmountIn.selector);
        miniAMM.getAmountOut(0, 1000, 1000);
    }

    function test_getAmount_RevertsWhenOutputWouldRoundToZero() external {
        vm.expectRevert(MiniAMM.MiniAMM__ZeroAmountOut.selector);
        miniAMM.getAmountOut(1, 1000, 1000);
    }

    function test_createMiniAMM_RevertsZeroAddress() external {
        vm.expectRevert(MiniAMM.MiniAMM__ZeroAddress.selector);
        miniAMM = new MiniAMM(MiniAMM(address(0)), tokenA);
    }

    function test_createMiniAMM_RevertsSameToken() external {
        vm.expectRevert(MiniAMM.MiniAMM__SameToken.selector);
        miniAMM = new MiniAMM(tokenA, tokenA);
    }

    // ------ Add Liquidity Tests --------
    function _addLiquidityAlice() internal {
        vm.prank(ALICE);
        miniAMM.addLiquidity(100e18, 400e18);
    }

    function test_addLiquidity_FirstDepositMintsSharesAndSetsReserves() external {
        _addLiquidityAlice();

        assertEq(miniAMM.totalSupply(), 200e18);
        assertEq(miniAMM.reserveA(), 100e18);
        assertEq(miniAMM.reserveB(), 400e18);
        assertEq(miniAMM.balanceOf(ALICE), 200e18);
        assertEq(tokenA.balanceOf(address(miniAMM)), 100e18);
        assertEq(tokenB.balanceOf(address(miniAMM)), 400e18);
        assertEq(tokenA.balanceOf(ALICE), 1000e18 - 100e18);
        assertEq(tokenB.balanceOf(ALICE), 1000e18 - 400e18);
    }

    function test_addLiquidity_LaterDepositPullsOnlyMatchingB() external {
        _addLiquidityAlice();
        vm.prank(MARIA);
        miniAMM.addLiquidity(30e18, 200e18);

        assertEq(miniAMM.balanceOf(MARIA), 60e18);
        assertEq(miniAMM.reserveA(), 130e18);
        assertEq(miniAMM.reserveB(), 520e18);
        assertEq(tokenA.balanceOf(MARIA), 970e18);
        assertEq(tokenB.balanceOf(MARIA), 880e18);
    }

    function test_addLiquidity_LaterDepositPullsOnlyMatchingA() external {
        _addLiquidityAlice();
        vm.prank(MARIA);
        miniAMM.addLiquidity(200e18, 60e18);

        assertEq(miniAMM.balanceOf(MARIA), 30e18);
        assertEq(miniAMM.reserveA(), 115e18);
        assertEq(miniAMM.reserveB(), 460e18);
        assertEq(tokenA.balanceOf(MARIA), 985e18);
        assertEq(tokenB.balanceOf(MARIA), 940e18);
    }

    function test_addLiquidity_RevertsWhenAnyAmountIsZero() external {
        vm.expectRevert(MiniAMM.MiniAMM__ZeroAmountIn.selector);
        vm.prank(ALICE);
        miniAMM.addLiquidity(0, 400e18);

        vm.expectRevert(MiniAMM.MiniAMM__ZeroAmountIn.selector);
        vm.prank(ALICE);
        miniAMM.addLiquidity(100e18, 0);
    }

    function test_addLiquidity_RevertsWhenSharesWouldBeZero() external {
        _addLiquidityAlice();
        vm.expectRevert(MiniAMM.MiniAMM__ZeroShare.selector);
        vm.prank(MARIA);
        miniAMM.addLiquidity(30e18, 1);
    }

    function test_addLiquidity_EmitsEventWithCorrectValues() external {
        _addLiquidityAlice();
        vm.expectEmit(true, false, false, true);
        emit LiquidityAdded(MARIA, 60e18, 30e18, 120e18);
        vm.prank(MARIA);
        miniAMM.addLiquidity(30e18, 200e18);
    }
}
