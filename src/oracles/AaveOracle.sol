// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {BaseOracle} from "./BaseOracle.sol";

contract AaveOracle is BaseOracle {
    constructor(address _asset, uint256 _scalingFactor) BaseOracle(_asset, _scalingFactor) {}

    function getPrice() external view override returns (uint256) {
        return 1 * scalingFactor;
    }
}
