// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IOracle} from "../interfaces/IOracle.sol";

abstract contract BaseOracle is IOracle {
    address public immutable asset;
    uint256 public immutable scalingFactor;

    constructor(address _asset, uint256 _scalingFactor) {
        asset = _asset;
        scalingFactor = _scalingFactor;
    }

    function getPrice() external view virtual returns (uint256) {}
}
