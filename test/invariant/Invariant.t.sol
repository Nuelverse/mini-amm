// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

// import {MiniAMM} from "../../src/MiniAMM.sol";
import {BaseTest} from "../BaseTest.sol";
import {Handler} from "./Handler.sol";

contract Invariant is BaseTest {
    Handler handler;

    function setUp() public override {
        super.setUp();
        _addLiquidityAlice();
        handler = new Handler(miniAMM, tokenA, tokenB);
        targetContract(address(handler));
    }

    function invariant_poolBalanceCoversReserves() public view {
        assertGe(tokenA.balanceOf(address(miniAMM)), miniAMM.reserveA());
        assertGe(tokenB.balanceOf(address(miniAMM)), miniAMM.reserveB());
    }

    function invariant_swapNeverShrinksK() public view {
        assertFalse(handler.problem());
    }
}
