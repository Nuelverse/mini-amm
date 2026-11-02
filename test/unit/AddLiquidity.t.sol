// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {MiniAMM} from "../../src/MiniAMM.sol";
import {FeeOnTransferToken} from "../mocks/FeeOnTransferToken.sol";

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

    function test_addLiquidity_DonationBeforeDepositCannotBeCaptured() external {
        _addLiquidityAlice();
        vm.prank(ALICE);
        tokenA.transfer(address(miniAMM), 100e18);
        vm.startPrank(MARIA);
        miniAMM.addLiquidity(100e18, 400e18);
        miniAMM.removeLiquidity(miniAMM.balanceOf(MARIA));
        vm.stopPrank();

        assertEq(tokenA.balanceOf(MARIA), 1000e18);
        assertEq(tokenB.balanceOf(MARIA), 1000e18);
        assertEq(miniAMM.reserveA(), 200e18);
        assertEq(miniAMM.reserveB(), 400e18);
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

    function test_addLiquidity_MintsSharesForReceivedAmountsOnFeeOnTransferToken() external {
        FeeOnTransferToken feeToken = new FeeOnTransferToken();
        MiniAMM feePool = new MiniAMM(feeToken, tokenB);
        feeToken.mint(ALICE, 1000e18);

        vm.startPrank(ALICE);
        feeToken.approve(address(feePool), 1000e18);
        tokenB.approve(address(feePool), 1000e18);

        // the pool receives 90 of the 100 sent, so shares = sqrt(90e18 * 400e18)
        vm.expectEmit(true, false, false, true);
        emit LiquidityAdded(ALICE, 189736659610102759919, 90e18, 400e18);
        uint256 shares = feePool.addLiquidity(100e18, 400e18);
        vm.stopPrank();

        assertEq(shares, 189736659610102759919);
        assertEq(feePool.balanceOf(ALICE), 189736659610102759919);
        assertEq(feePool.reserveA(), 90e18);
        assertEq(feePool.reserveB(), 400e18);
        assertEq(feeToken.balanceOf(address(feePool)), 90e18);
    }

    function test_addLiquidity_CreditsOnlyTheSmallerSideWhenOneTokenTakesAFee() external {
        FeeOnTransferToken feeToken = new FeeOnTransferToken();
        MiniAMM feePool = new MiniAMM(tokenA, feeToken);
        feeToken.mint(ALICE, 1000e18);
        feeToken.mint(MARIA, 1000e18);

        vm.startPrank(ALICE);
        tokenA.approve(address(feePool), 1000e18);
        feeToken.approve(address(feePool), 1000e18);
        // pool receives 100 A and 360 B (10% of the 400 B is cut): 189736659610102759919 shares
        feePool.addLiquidity(100e18, 400e18);
        vm.stopPrank();

        vm.startPrank(MARIA);
        tokenA.approve(address(feePool), 1000e18);
        feeToken.approve(address(feePool), 1000e18);
        // matching pair is 30 A and 108 B; the pool receives 30 A and 97.2 B.
        // A side supports 56920997883030827975 shares, B side only 51228898094727745178.
        uint256 shares = feePool.addLiquidity(30e18, 120e18);
        vm.stopPrank();

        assertEq(shares, 51228898094727745178);
        assertEq(feePool.balanceOf(MARIA), 51228898094727745178);
    }
}
