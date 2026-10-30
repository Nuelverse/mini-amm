// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {MiniAMM} from "../../src/MiniAMM.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract Swap is BaseTest {
    event Swapped(address indexed swapper, address tokenIn, uint256 amountIn, uint256 amountOut);

    function test_swap_TokenAInReturnsExpectedAndUpdatesReserves() external {
        _addLiquidityAlice();
        vm.prank(MARIA);
        uint256 amountOut = miniAMM.swap(tokenA, 10e18, 0);

        assertEq(amountOut, 3.6264435755205965263e19);
        assertEq(tokenA.balanceOf(MARIA), 990e18);
        assertEq(tokenB.balanceOf(MARIA), 1000e18 + amountOut);
        assertEq(miniAMM.reserveA(), 110e18);
        assertEq(miniAMM.reserveB(), 400e18 - amountOut);
    }

    function test_swap_TokenBInReturnsExpectedAndUpdatesReserves() external {
        _addLiquidityAlice();
        vm.prank(MARIA);
        uint256 amountOut = miniAMM.swap(tokenB, 40e18, 0);

        assertEq(amountOut, 9.066108938801491315e18);
        assertEq(tokenB.balanceOf(MARIA), 960e18);
        assertEq(tokenA.balanceOf(MARIA), 1000e18 + amountOut);
        assertEq(miniAMM.reserveB(), 440e18);
        assertEq(miniAMM.reserveA(), 100e18 - amountOut);
    }

    function test_swap_RevertsWhenTokenIsNotInPool() external {
        _addLiquidityAlice();
        MockERC20 strangeToken = new MockERC20("Strange Token", "STK");

        vm.expectRevert(MiniAMM.MiniAMM__TokenNotInPool.selector);
        vm.prank(MARIA);
        miniAMM.swap(strangeToken, 40e18, 0);
    }

    function test_swap_RevertsWhenOutputBelowMinimum() external {
        _addLiquidityAlice();
        vm.expectRevert(MiniAMM.MiniAMM__AmountOutBelowExpected.selector);
        vm.prank(MARIA);
        miniAMM.swap(tokenA, 10e18, 3.6264435755205965263e19 + 1 wei);
    }

    function test_swap_RevertsWhenAmountInIsZero() external {
        _addLiquidityAlice();
        vm.expectRevert(MiniAMM.MiniAMM__ZeroAmountIn.selector);
        vm.prank(MARIA);
        miniAMM.swap(tokenA, 0, 0);
    }

    function test_swap_AbsorbsDirectTransferIntoReserves() external {
        _addLiquidityAlice();
        vm.prank(ALICE);
        tokenB.transfer(address(miniAMM), 50e18);

        assertEq(tokenB.balanceOf(address(miniAMM)), 450e18);
        assertEq(miniAMM.reserveB(), 400e18);

        vm.prank(MARIA);
        uint256 amountOut = miniAMM.swap(tokenA, 10e18, 0);

        assertEq(amountOut, 3.6264435755205965263e19);
        assertEq(miniAMM.reserveB(), 450e18 - amountOut);
    }

    function test_swap_EmitsEventWithMeasuredAmounts() external {
        _addLiquidityAlice();

        vm.expectEmit(true, false, false, true);
        emit Swapped(MARIA, address(tokenA), 10e18, 3.6264435755205965263e19);
        vm.prank(MARIA);
        miniAMM.swap(tokenA, 10e18, 0);
    }
}
