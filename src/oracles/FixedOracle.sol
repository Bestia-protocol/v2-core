// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {BaseOracle} from "./BaseOracle.sol";

contract FixedOracle is BaseOracle {
    uint256 public price;

    constructor(address _asset, uint256 _scalingFactor, uint256 _price) BaseOracle(_asset, _scalingFactor) {
        price = _price;
    }

    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }

    function getPrice() external view override returns (uint256) {
        return price * scalingFactor;
    }
}
