// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MiniAMM} from "../../src/MiniAMM.sol";

contract MaliciousToken is ERC20 {
    MiniAMM miniAMM;
    enum Action {
        None,
        Swap,
        RemoveLiquidity,
        AddLiquidity
    }
    Action action;

    constructor() ERC20("Malicious Token", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function arm(MiniAMM ammAddress, Action _action) public {
        miniAMM = ammAddress;
        action = _action;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        Action armedAction = action; // create a local copy of the action to read from.
        action = Action.None; // reset the action to avoid endless loops
        if (armedAction == Action.Swap) {
            miniAMM.swap(ERC20(address(this)), value, 0);
        } else if (armedAction == Action.RemoveLiquidity) {
            miniAMM.removeLiquidity(value);
        } else if (armedAction == Action.AddLiquidity) {
            miniAMM.addLiquidity(value, value);
        }
    }
}
