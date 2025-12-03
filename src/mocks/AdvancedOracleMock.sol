// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IAdvancedOracle} from "../interfaces/IAdvancedOracle.sol";

/// @title AdvancedOracleMock
/// @notice Mock oracle with kimchi premium and custom metrics for testing
contract AdvancedOracleMock is IAdvancedOracle {
    uint256 public price;
    uint256 public kimchiPremium;
    uint256 public customMetric;

    /// @notice Set the collateral price
    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }

    /// @notice Set kimchi premium (e.g., 0.03e18 = 3%)
    function setKimchiPremium(uint256 newPremium) external {
        kimchiPremium = newPremium;
    }

    /// @notice Set custom metric
    function setCustomMetric(uint256 newMetric) external {
        customMetric = newMetric;
    }

    /// @notice Batch set all values
    function setAll(
        uint256 newPrice,
        uint256 newKimchiPremium,
        uint256 newCustomMetric
    ) external {
        price = newPrice;
        kimchiPremium = newKimchiPremium;
        customMetric = newCustomMetric;
    }
}
