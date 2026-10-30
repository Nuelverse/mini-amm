// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {MiniAMM} from "../../src/MiniAMM.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract Handler is Test {
    MiniAMM miniAMM;
    MockERC20 tokenA;
    MockERC20 tokenB;
    bool public problem;

    constructor(MiniAMM _miniAMM, MockERC20 _tokenA, MockERC20 _tokenB) {
        miniAMM = _miniAMM;
        tokenA = _tokenA;
        tokenB = _tokenB;

        tokenA.mint(address(this), 1000000000e18);
        tokenB.mint(address(this), 1000000000e18);
        tokenA.approve(address(miniAMM), 1000000000e18);
        tokenB.approve(address(miniAMM), 1000000000e18);
    }

    function swap(uint256 amount, bool aToB) external {
        amount = bound(amount, 1, 1000e18);
        MockERC20 tokenIn = aToB ? tokenA : tokenB;

        uint256 k = miniAMM.reserveA() * miniAMM.reserveB();

        miniAMM.swap(tokenIn, amount, 0);

        uint256 kAfter = miniAMM.reserveA() * miniAMM.reserveB();
        if (kAfter < k) {
            problem = true;
        }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        amountA = bound(amountA, 1, 1000e18);
        amountB = bound(amountB, 4, 1000e18);

        miniAMM.addLiquidity(amountA, amountB);
    }

    function removeLiquidity(uint256 shares) external {
        uint256 bal = miniAMM.balanceOf(address(this));
        if (bal == 0) {
            return;
        }
        shares = bound(shares, 1, bal);
        miniAMM.removeLiquidity(shares);
    }

    function donate(uint256 amount, bool aToB) external {
        amount = bound(amount, 1, 1000e18);
        MockERC20 tokenIn = aToB ? tokenA : tokenB;
        tokenIn.transfer(address(miniAMM), amount);
    }
}
