// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {MiniAMM} from "../../src/MiniAMM.sol";

contract AddLiquidity is BaseTest {
    event LiquidityAdded(address indexed depositor, uint256 sharesAmount, uint256 amountA, uint256 amountB);

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
