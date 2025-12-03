// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

// Based on Morpho Blue by Morpho Labs (https://github.com/morpho-org/morpho-blue)
// Original License: BUSL-1.1
// Modified by: KORACLE

import "./Morpho.sol";
import {IAdvancedOracle} from "./interfaces/IAdvancedOracle.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {MarketParamsLib} from "./libraries/MarketParamsLib.sol";
import {MathLib, WAD} from "./libraries/MathLib.sol";
import {UtilsLib} from "./libraries/UtilsLib.sol";
import {SharesMathLib} from "./libraries/SharesMathLib.sol";
import {SafeTransferLib} from "./libraries/SafeTransferLib.sol";
import "./libraries/ConstantsLib.sol";

/// @title CustomMorpho
/// @author KORACLE
/// @notice Extended Morpho with custom liquidation conditions (kimchi premium, custom metrics)
/// @dev This does not override liquidate() but provides a new customLiquidate() function
contract CustomMorpho is Morpho {
    using MathLib for uint128;
    using MathLib for uint256;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using SafeTransferLib for IERC20;
    using MarketParamsLib for MarketParams;
    /* CUSTOM EVENTS */

    event SetKimchiPremiumThreshold(uint256 newThreshold);
    event SetCustomMetricThreshold(uint256 newThreshold);
    event SetCustomLiquidationBonus(Id indexed id, uint256 bonus);
    event KimchiPremiumLiquidation(Id indexed id, address indexed borrower, uint256 premium);
    event CustomMetricLiquidation(Id indexed id, address indexed borrower, uint256 metric);

    /* CUSTOM ERRORS */

    error InvalidThreshold();
    error InvalidBonus();
    error OracleNotAdvanced();

    /* CUSTOM STORAGE */

    /// @notice Kimchi premium threshold for liquidation (e.g., 0.03e18 = 3%)
    uint256 public kimchiPremiumThreshold;

    /// @notice Custom metric threshold for liquidation
    uint256 public customMetricThreshold;

    /// @notice Custom liquidation bonus per market (0 = use default)
    mapping(Id => uint256) public customLiquidationBonus;

    /// @notice Whether kimchi premium liquidation is enabled globally
    bool public kimchiPremiumEnabled;

    /// @notice Whether custom metric liquidation is enabled globally
    bool public customMetricEnabled;

    /* CONSTRUCTOR */

    /// @param newOwner The owner address
    /// @param initialKimchiThreshold Initial kimchi premium threshold (e.g., 0.03e18 for 3%)
    /// @param initialCustomThreshold Initial custom metric threshold
    constructor(
        address newOwner,
        uint256 initialKimchiThreshold,
        uint256 initialCustomThreshold
    ) Morpho(newOwner) {
        require(initialKimchiThreshold <= 1e18, ErrorsLib.MAX_FEE_EXCEEDED); // Max 100%
        require(initialCustomThreshold <= 10e18, "Invalid custom threshold"); // Max 1000%

        kimchiPremiumThreshold = initialKimchiThreshold;
        customMetricThreshold = initialCustomThreshold;
        kimchiPremiumEnabled = false; // Disabled by default for safety
        customMetricEnabled = false;

        emit SetKimchiPremiumThreshold(initialKimchiThreshold);
        emit SetCustomMetricThreshold(initialCustomThreshold);
    }

    /* CUSTOM LIQUIDATION */

    /// @notice Liquidate with custom conditions (kimchi premium, custom metric)
    /// @dev This is a new function, not an override. Use this for custom liquidations.
    function customLiquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external returns (uint256, uint256) {
        Id id = marketParams.id();
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(UtilsLib.exactlyOneZero(seizedAssets, repaidShares), ErrorsLib.INCONSISTENT_INPUT);

        _accrueInterest(marketParams, id);

        // Get collateral price
        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        // Check liquidation conditions
        bool canLiquidate = false;
        string memory liquidationReason;

        // 1. Standard health check
        bool isUnhealthy = !_isHealthy(marketParams, id, borrower, collateralPrice);
        if (isUnhealthy) {
            canLiquidate = true;
            liquidationReason = "Unhealthy";
        }

        // 2. Kimchi premium check (if enabled and oracle supports it)
        if (!canLiquidate && kimchiPremiumEnabled) {
            (bool supported, uint256 premium) = _tryGetKimchiPremium(marketParams.oracle);
            if (supported && premium >= kimchiPremiumThreshold) {
                canLiquidate = true;
                liquidationReason = "Kimchi premium";
                emit KimchiPremiumLiquidation(id, borrower, premium);
            }
        }

        // 3. Custom metric check (if enabled and oracle supports it)
        if (!canLiquidate && customMetricEnabled) {
            (bool supported, uint256 metric) = _tryGetCustomMetric(marketParams.oracle);
            if (supported && metric < customMetricThreshold) {
                canLiquidate = true;
                liquidationReason = "Custom metric";
                emit CustomMetricLiquidation(id, borrower, metric);
            }
        }

        require(canLiquidate, ErrorsLib.HEALTHY_POSITION);

        // Calculate liquidation incentive
        uint256 liquidationIncentiveFactor;
        if (customLiquidationBonus[id] > 0) {
            // Use custom bonus if set
            liquidationIncentiveFactor = customLiquidationBonus[id];
        } else {
            // Use default calculation
            liquidationIncentiveFactor = UtilsLib.min(
                MAX_LIQUIDATION_INCENTIVE_FACTOR,
                WAD.wDivDown(WAD - LIQUIDATION_CURSOR.wMulDown(WAD - marketParams.lltv))
            );
        }

        // Calculate seized assets and repaid shares
        if (seizedAssets > 0) {
            uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);
            repaidShares = seizedAssetsQuoted.wDivUp(liquidationIncentiveFactor)
                .toSharesUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);
        } else {
            seizedAssets = repaidShares.toAssetsDown(market[id].totalBorrowAssets, market[id].totalBorrowShares)
                .wMulDown(liquidationIncentiveFactor).mulDivDown(ORACLE_PRICE_SCALE, collateralPrice);
        }

        uint256 repaidAssets = repaidShares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);

        // Update positions
        position[id][borrower].borrowShares -= repaidShares.toUint128();
        market[id].totalBorrowShares -= repaidShares.toUint128();
        market[id].totalBorrowAssets = UtilsLib.zeroFloorSub(market[id].totalBorrowAssets, repaidAssets).toUint128();
        position[id][borrower].collateral -= seizedAssets.toUint128();

        // Handle bad debt
        uint256 badDebtShares;
        uint256 badDebtAssets;
        if (position[id][borrower].collateral == 0) {
            badDebtShares = position[id][borrower].borrowShares;
            badDebtAssets = UtilsLib.min(
                market[id].totalBorrowAssets,
                badDebtShares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares)
            );

            market[id].totalBorrowAssets -= badDebtAssets.toUint128();
            market[id].totalSupplyAssets -= badDebtAssets.toUint128();
            market[id].totalBorrowShares -= badDebtShares.toUint128();
            position[id][borrower].borrowShares = 0;
        }

        emit EventsLib.Liquidate(
            id, msg.sender, borrower, repaidAssets, repaidShares, seizedAssets, badDebtAssets, badDebtShares
        );

        IERC20(marketParams.collateralToken).safeTransfer(msg.sender, seizedAssets);

        if (data.length > 0) IMorphoLiquidateCallback(msg.sender).onMorphoLiquidate(repaidAssets, data);

        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), repaidAssets);

        return (seizedAssets, repaidAssets);
    }

    /* OWNER FUNCTIONS */

    /// @notice Set kimchi premium threshold
    /// @param newThreshold New threshold (e.g., 0.03e18 = 3%)
    function setKimchiPremiumThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold <= 1e18, ErrorsLib.MAX_FEE_EXCEEDED); // Max 100%
        kimchiPremiumThreshold = newThreshold;
        emit SetKimchiPremiumThreshold(newThreshold);
    }

    /// @notice Set custom metric threshold
    /// @param newThreshold New threshold
    function setCustomMetricThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold <= 10e18, "Invalid threshold"); // Max 1000%
        customMetricThreshold = newThreshold;
        emit SetCustomMetricThreshold(newThreshold);
    }

    /// @notice Set custom liquidation bonus for a specific market
    /// @param id Market ID
    /// @param bonus Liquidation bonus (e.g., 1.15e18 = 15% bonus)
    function setCustomLiquidationBonus(Id id, uint256 bonus) external onlyOwner {
        require(market[id].lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        require(bonus == 0 || (bonus >= 1e18 && bonus <= 1.5e18), "Invalid bonus"); // 0% to 50%
        customLiquidationBonus[id] = bonus;
        emit SetCustomLiquidationBonus(id, bonus);
    }

    /// @notice Enable or disable kimchi premium liquidation
    /// @param enabled Whether to enable
    function setKimchiPremiumEnabled(bool enabled) external onlyOwner {
        kimchiPremiumEnabled = enabled;
    }

    /// @notice Enable or disable custom metric liquidation
    /// @param enabled Whether to enable
    function setCustomMetricEnabled(bool enabled) external onlyOwner {
        customMetricEnabled = enabled;
    }

    /* VIEW FUNCTIONS */

    /// @notice Check if a position can be liquidated (including custom conditions)
    /// @return canLiquidate Whether the position can be liquidated
    /// @return reason Liquidation reason
    function canLiquidatePosition(
        MarketParams memory marketParams,
        address borrower
    ) external view returns (bool canLiquidate, string memory reason) {
        Id id = marketParams.id();

        if (market[id].lastUpdate == 0) {
            return (false, "Market not created");
        }

        uint256 collateralPrice = IOracle(marketParams.oracle).price();

        // Check standard health
        if (!_isHealthy(marketParams, id, borrower, collateralPrice)) {
            return (true, "Unhealthy position");
        }

        // Check kimchi premium
        if (kimchiPremiumEnabled) {
            (bool supported, uint256 premium) = _tryGetKimchiPremium(marketParams.oracle);
            if (supported && premium >= kimchiPremiumThreshold) {
                return (true, "Kimchi premium exceeded");
            }
        }

        // Check custom metric
        if (customMetricEnabled) {
            (bool supported, uint256 metric) = _tryGetCustomMetric(marketParams.oracle);
            if (supported && metric < customMetricThreshold) {
                return (true, "Custom metric below threshold");
            }
        }

        return (false, "Position is healthy");
    }

    /* INTERNAL HELPERS */

    /// @dev Try to get kimchi premium from oracle (returns false if not supported)
    function _tryGetKimchiPremium(address oracle) internal view returns (bool supported, uint256 premium) {
        try IAdvancedOracle(oracle).kimchiPremium() returns (uint256 _premium) {
            return (true, _premium);
        } catch {
            return (false, 0);
        }
    }

    /// @dev Try to get custom metric from oracle (returns false if not supported)
    function _tryGetCustomMetric(address oracle) internal view returns (bool supported, uint256 metric) {
        try IAdvancedOracle(oracle).customMetric() returns (uint256 _metric) {
            return (true, _metric);
        } catch {
            return (false, 0);
        }
    }
}
