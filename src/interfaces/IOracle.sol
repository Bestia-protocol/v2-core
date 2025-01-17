// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

interface IOracle {
    function getPrice() external view returns (uint256);
}
