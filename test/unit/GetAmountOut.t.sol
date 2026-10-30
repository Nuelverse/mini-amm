// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.sol";
import {MiniAMM} from "../../src/MiniAMM.sol";

contract GetAmountOut is BaseTest {
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
}
