// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {MiniAMM} from "../src/MiniAMM.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

abstract contract BaseTest is Test {
    MiniAMM miniAMM;
    MockERC20 tokenA;
    MockERC20 tokenB;

    address MARIA;
    address ALICE;

    function setUp() public virtual {
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

    function _addLiquidityAlice() internal virtual {
        vm.prank(ALICE);
        miniAMM.addLiquidity(100e18, 400e18);
    }
}
