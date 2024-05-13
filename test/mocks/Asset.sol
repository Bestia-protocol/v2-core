// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAsset is ERC20 {
    constructor() ERC20("Asset", "AST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
