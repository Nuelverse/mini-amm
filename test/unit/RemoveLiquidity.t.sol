// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {MiniAMM} from "../../src/MiniAMM.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract RemoveLiquidity is BaseTest {
    function test_removeLiquidity_PaysProportionalSlice() external {
        _addLiquidityAlice();
        vm.startPrank(MARIA);
        miniAMM.addLiquidity(30e18, 200e18);
        (uint256 Atoken, uint256 Btoken) = miniAMM.removeLiquidity(60e18);

        assertEq(Atoken, 30e18);
        assertEq(Btoken, 120e18);
        assertEq(miniAMM.balanceOf(MARIA), 0);
        assertEq(tokenA.balanceOf(MARIA), 1000e18);
        assertEq(tokenB.balanceOf(MARIA), 1000e18);
        assertEq(tokenA.balanceOf(address(miniAMM)), 100e18);
        assertEq(tokenB.balanceOf(address(miniAMM)), 400e18);
        assertEq(miniAMM.reserveA(), 100e18);
        assertEq(miniAMM.reserveB(), 400e18);
        assertEq(miniAMM.totalSupply(), 200e18);
    }

    function test_removeLiquidity_LastLPCanWithdrawEverythingAfterDonation() external {
        _addLiquidityAlice();
        vm.prank(MARIA);
        tokenA.transfer(address(miniAMM), 10e18);

        vm.prank(ALICE);
        (uint256 amountA, uint256 amountB) = miniAMM.removeLiquidity(200e18);

        assertEq(amountA, 110e18);
        assertEq(amountB, 400e18);
        assertEq(miniAMM.totalSupply(), 0);
        assertEq(miniAMM.reserveA(), 0);
        assertEq(miniAMM.reserveB(), 0);
        assertEq(tokenA.balanceOf(address(miniAMM)), 0);
        assertEq(tokenB.balanceOf(address(miniAMM)), 0);
        assertEq(tokenA.balanceOf(ALICE), 1010e18);
    }

    function test_removeLiquidity_RevertsWhenSharesAreZero() external {
        _addLiquidityAlice();
        vm.expectRevert(MiniAMM.MiniAMM__ZeroShare.selector);
        vm.prank(ALICE);
        miniAMM.removeLiquidity(0);
    }

    function test_removeLiquidity_RevertsWhenPoolHasNoShares() external {
        vm.expectRevert(MiniAMM.MiniAMM__NothingToBurn.selector);
        vm.prank(MARIA);
        miniAMM.removeLiquidity(60e18);
    }

    function test_removeLiquidity_RevertsWhenAmountsRoundToZero() external {
        _addLiquidityAlice();
        vm.expectRevert(MiniAMM.MiniAMM__ZeroAmountOut.selector);
        vm.prank(ALICE);
        miniAMM.removeLiquidity(1 wei);
    }

    function test_removeLiquidity_RevertsWhenBurningMoreThanOwned() external {
        _addLiquidityAlice();
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, MARIA, miniAMM.balanceOf(MARIA), 60e18
            )
        );
        vm.prank(MARIA);
        miniAMM.removeLiquidity(60e18);
    }
}
