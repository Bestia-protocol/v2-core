// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IOracle} from "./interfaces/IOracle.sol";

contract Stablecoin is Ownable, ERC20 {
    using SafeERC20 for IERC20;

    struct AssetData {
        uint256 absoluteCap;
        uint256 relativeCap; // scaled by RESOLUTION
        uint256 baseFee; // scaled by RESOLUTION
        uint256 incrementFee; // in bps, scaled by RESOLUTION
        bool enabled;
        IOracle oracle;
    }

    uint256 public constant RESOLUTION = 1e18;
    mapping(address => AssetData) public assets;
    address[] public poolAssets;

    event AssetDataUpdated(AssetData indexed oldVal, AssetData indexed newVal);

    error AssetAlreadyWhitelisted();
    error AssetNotSupported();
    error ExceedsDepositCap();
    error InvalidRelativeCap();

    constructor(address admin) Ownable(admin) ERC20("TKN", "token") {}

    function updateWhitelistedAsset(address asset, AssetData memory data) external onlyOwner {
        if (assets[asset].enabled) revert AssetAlreadyWhitelisted();
        if (data.relativeCap > 100 * RESOLUTION) revert InvalidRelativeCap();

        emit AssetDataUpdated(assets[asset], data);

        assets[asset] = data;
        for (uint8 i = 0; i < poolAssets.length; i++) {
            if (poolAssets[i] == asset) return;
        }
        poolAssets.push(asset);
    }

    function deposit(address asset, uint256 amount) external returns (uint256) {
        if (!assets[asset].enabled) revert AssetNotSupported();

        IERC20 token = IERC20(asset);
        if (token.balanceOf(address(this)) + amount > assets[asset].absoluteCap) revert ExceedsDepositCap();

        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 amountOut = previewDeposit(asset, amount);
        _mint(msg.sender, amountOut);

        return amountOut;
    }

    function withdraw(address asset, uint256 amount) external returns (uint256) {
        if (!assets[asset].enabled) revert AssetNotSupported();

        IERC20 token = IERC20(asset);
        token.safeTransfer(msg.sender, amount);

        uint256 amountIn = previewWithdrawal(asset, amount);
        _burn(msg.sender, amountIn);

        return amountIn;
    }

    function previewDeposit(address asset, uint256 amount) public view returns (uint256) {
        if (!assets[asset].enabled) return 0;

        uint256 fee = _calculateFee(asset, amount);
        uint256 amountAfterFee = amount - fee;

        return assets[asset].oracle.getPrice() * amountAfterFee / RESOLUTION;
    }

    function previewWithdrawal(address asset, uint256 amount) public view returns (uint256) {
        if (!assets[asset].enabled) return 0;

        uint256 fee = _calculateFee(asset, amount);
        uint256 amountAfterFee = amount - fee;

        return assets[asset].oracle.getPrice() * amountAfterFee / RESOLUTION;
    }

    function _calculateFee(address asset, uint256 amount) internal view returns (uint256) {
        uint256 totalValue = getTotalPoolValue();
        if (totalValue == 0) return 0;

        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 currentPercentage = (balance * RESOLUTION + amount * RESOLUTION) / totalValue;
        uint256 idealPercentage = assets[asset].relativeCap;

        uint256 delta = 0;
        if (currentPercentage > idealPercentage) {
            delta = currentPercentage - idealPercentage;
        } else {
            delta = idealPercentage - currentPercentage;
        }

        // Linear fee calculation: y = baseFee + incrementFee * delta
        return (assets[asset].baseFee + (assets[asset].incrementFee * delta / RESOLUTION)) * amount / RESOLUTION;
    }

    function getTotalPoolValue() public view returns (uint256) {
        uint256 value = 0;
        for (uint8 i = 0; i < poolAssets.length; i++) {
            address asset = poolAssets[i];
            uint256 balance = IERC20(asset).balanceOf(address(this));
            uint256 price = assets[asset].oracle.getPrice();
            value += balance * price / RESOLUTION;
        }
        return value;
    }

    function harvest() external {
        // Rebalance and harvest profits
        uint256 poolValue = getTotalPoolValue();
        uint256 mintedSupply = totalSupply();

        if (poolValue > mintedSupply) {
            uint256 delta = poolValue - mintedSupply;
            _mint(owner(), delta);
        }
    }
}
