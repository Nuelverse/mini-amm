// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {MiniAMM} from "../../src/MiniAMM.sol";
import {BaseTest} from "../BaseTest.sol";
import {MaliciousToken} from "../mocks/MaliciousToken.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Reentrancy is BaseTest {
    MaliciousToken maliciousToken;

    function setUp() public override {
        super.setUp();
        maliciousToken = new MaliciousToken();
        miniAMM = new MiniAMM(maliciousToken, tokenB);

        maliciousToken.mint(MARIA, 1000e18);
        maliciousToken.mint(ALICE, 1000e18);

        vm.startPrank(MARIA);
        maliciousToken.approve(address(miniAMM), 1000e18);
        tokenB.approve(address(miniAMM), 1000e18);
        vm.stopPrank();

        vm.startPrank(ALICE);
        maliciousToken.approve(address(miniAMM), 1000e18);
        tokenB.approve(address(miniAMM), 1000e18);
        vm.stopPrank();
    }

    function _addLiquidityAlice() internal override {
        vm.prank(ALICE);
        miniAMM.addLiquidity(100e18, 400e18);
    }

    function test_reentrancy_SwapCannotBeReentered() external {
        _addLiquidityAlice();
        maliciousToken.arm(miniAMM, MaliciousToken.Action.Swap);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(MARIA);
        miniAMM.swap(maliciousToken, 10e18, 0);
    }

    function test_reentrancy_RemoveLiquidityCannotBeReentered() external {
        _addLiquidityAlice();
        maliciousToken.arm(miniAMM, MaliciousToken.Action.RemoveLiquidity);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(ALICE);
        miniAMM.removeLiquidity(200e18);
    }

    function test_reentrancy_AddLiquidityCannotBeReentered() external {
        _addLiquidityAlice();
        maliciousToken.arm(miniAMM, MaliciousToken.Action.AddLiquidity);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(MARIA);
        miniAMM.addLiquidity(30e18, 120e18);
    }
}
