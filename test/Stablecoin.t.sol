// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Stablecoin} from "../src/Stablecoin.sol";
import {FixedOracle} from "../src/oracles/FixedOracle.sol";
import {MockAsset} from "./mocks/Asset.sol";

contract StablecoinTest is Test {
    Stablecoin public immutable stablecoin;
    address public immutable admin = address(1);
    address public immutable user = address(2);
    MockAsset public immutable asset = new MockAsset();
    FixedOracle public immutable assetOracle = new FixedOracle(address(asset), 1e18, 1);

    constructor() {
        vm.startPrank(admin);
        stablecoin = new Stablecoin(admin);
        stablecoin.updateWhitelistedAsset(
            address(asset),
            Stablecoin.AssetData({
                absoluteCap: type(uint256).max,
                relativeCap: 50 * 1e18, // 50%, scaled by RESOLUTION
                baseFee: 1e16, // 1%, scaled by RESOLUTION
                incrementFee: 1e15, // 0.1%, scaled by RESOLUTION
                enabled: true,
                oracle: assetOracle
            })
        );
        vm.stopPrank();

        vm.label(user, "User");
        vm.label(address(asset), "Asset");

        vm.prank(user);
        asset.approve(address(stablecoin), type(uint256).max);
    }

    function testDeposit(uint256 amount) public {
        vm.startPrank(user);
        asset.mint(user, amount);
        uint256 expectedBalance = stablecoin.previewDeposit(address(asset), amount);
        stablecoin.deposit(address(asset), amount);
        assertApproxEqAbs(
            stablecoin.balanceOf(user), expectedBalance, 1, "Minted amount should match deposited amount minus fees"
        );
    }

    function testFailDepositNotSupported() public {
        address nonWhitelistedAsset = address(4);
        vm.prank(user);
        stablecoin.deposit(nonWhitelistedAsset, 1); // Should fail
    }

    function testWithdraw(uint256 deposit, uint256 withdraw) public {
        // Ensure withdraw amount is not more than deposit and is positive
        vm.assume(deposit >= withdraw && withdraw > 0);

        testDeposit(deposit);

        vm.startPrank(user);
        uint256 expectedWithdrawAmount = stablecoin.previewWithdrawal(address(asset), withdraw);
        stablecoin.withdraw(address(asset), withdraw);
        uint256 expectedBalance = deposit - expectedWithdrawAmount; // Expected remaining TKN after withdrawal
        assertApproxEqAbs(
            stablecoin.balanceOf(user), expectedBalance, 1, "Remaining balance should reflect the withdrawal"
        );
    }

    function testHarvestAfterPriceIncrease() public {
        testDeposit(1e18);

        uint256 newPrice = 2;
        assetOracle.setPrice(newPrice);

        testDeposit(1e18);

        // Calculate expected surplus to be minted
        uint256 totalPoolValue = stablecoin.getTotalPoolValue(); // Should reflect the price increase
        uint256 mintedSupply = stablecoin.totalSupply();
        uint256 expectedMintAmount = totalPoolValue - mintedSupply;

        vm.prank(admin);
        stablecoin.harvest();

        // Check if the correct amount of surplus was minted to the admin
        assertEq(stablecoin.balanceOf(admin), expectedMintAmount, "Admin should receive the correct surplus amount");
    }
}
