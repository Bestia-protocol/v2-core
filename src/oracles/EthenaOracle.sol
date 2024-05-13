// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {BaseOracle} from "./BaseOracle.sol";

contract EthenaOracle is BaseOracle {
    IERC4626 public immutable susde;

    constructor(IERC4626 _susde, address _asset, uint256 _scalingFactor) BaseOracle(_asset, _scalingFactor) {
        susde = _susde;
    }

    function getPrice() external view override returns (uint256) {
        uint256 sharePrice = susde.convertToAssets(1e18);
        return sharePrice * scalingFactor;
    }
}
