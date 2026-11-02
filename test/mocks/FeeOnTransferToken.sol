// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MiniAMM} from "../../src/MiniAMM.sol";

contract FeeOnTransferToken is ERC20 {
    MiniAMM miniAMM;
    uint256 public constant PERCENTAGE = 10; // 10%

    constructor() ERC20("FeeOnTransferToken Token", "FTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            value = value * (100 - PERCENTAGE) / 100;
        }
        super._update(from, to, value);
    }
}
