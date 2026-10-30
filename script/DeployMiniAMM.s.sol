// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MiniAMM} from "../src/MiniAMM.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract DeployMiniAMM is Script {
    function run() external returns (MiniAMM, MockERC20, MockERC20) {
        vm.startBroadcast();
        MockERC20 tokenA = new MockERC20("Token A", "TKNA");
        MockERC20 tokenB = new MockERC20("Token B", "TKNB");
        MiniAMM miniAMM = new MiniAMM(tokenA, tokenB);

        tokenA.mint(msg.sender, 1000e18);
        tokenB.mint(msg.sender, 1000e18);

        tokenA.approve(address(miniAMM), 1000e18);
        tokenB.approve(address(miniAMM), 1000e18);

        miniAMM.addLiquidity(500e18, 700e18);

        vm.stopBroadcast();

        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
        console.log("MiniAMM:", address(miniAMM));
        return (miniAMM, tokenA, tokenB);
    }
}
