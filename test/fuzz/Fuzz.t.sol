// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";

contract Fuzz is BaseTest {
    function test_fuzz_swapNeverDecreasesK(uint256 amountIn) external {
        _addLiquidityAlice();
        amountIn = bound(amountIn, 1, 1000e18); // bounding from one cause a 0 value revverts anyway

        uint256 reservesBefore = miniAMM.reserveA() * miniAMM.reserveB();
        vm.prank(MARIA);
        miniAMM.swap(tokenA, amountIn, 0);
        uint256 reservesAfter = miniAMM.reserveA() * miniAMM.reserveB();

        assertGt(reservesAfter, reservesBefore);
    }

    function test_fuzz_swapNeverDecreasesKTokenBIn(uint256 amountIn) external {
        _addLiquidityAlice();
        amountIn = bound(amountIn, 5, 1000e18); // bounding from one cause a 0 value revverts anyway

        uint256 reservesBefore = miniAMM.reserveA() * miniAMM.reserveB();
        vm.prank(MARIA);
        miniAMM.swap(tokenB, amountIn, 0);
        uint256 reservesAfter = miniAMM.reserveA() * miniAMM.reserveB();

        assertGt(reservesAfter, reservesBefore);
    }

    function test_fuzz_addThenRemoveNeverReturnsMoreThanDeposited(uint256 amountA, uint256 amountB) external {
        _addLiquidityAlice();
        amountA = bound(amountA, 1, 1000e18);
        amountB = bound(amountB, 4, 1000e18);

        uint256 tokenABalanceBefore = tokenA.balanceOf(MARIA);
        uint256 tokenBBalanceBefore = tokenB.balanceOf(MARIA);

        vm.startPrank(MARIA);
        miniAMM.addLiquidity(amountA, amountB);
        miniAMM.removeLiquidity(miniAMM.balanceOf(MARIA));
        vm.stopPrank();

        uint256 tokenABalanceAfter = tokenA.balanceOf(MARIA);
        uint256 tokenBBalanceAfter = tokenB.balanceOf(MARIA);

        assertLe(tokenABalanceAfter, tokenABalanceBefore);
        assertLe(tokenBBalanceAfter, tokenBBalanceBefore);
    }
}
