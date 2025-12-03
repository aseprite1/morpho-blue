// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IOracle} from "./IOracle.sol";

/// @title IAdvancedOracle
/// @author Custom Extension for Giwa Chain
/// @notice Extended oracle interface with additional metrics
interface IAdvancedOracle is IOracle {
    /// @notice Returns the kimchi premium percentage scaled by 1e18
    /// @dev 3% premium = 0.03e18 = 30000000000000000
    /// @return Kimchi premium as a percentage (1e18 = 100%)
    function kimchiPremium() external view returns (uint256);

    /// @notice Returns any custom metric for liquidation conditions
    /// @dev Can be used for volatility, funding rate, or other metrics
    /// @return Custom metric value scaled by 1e18
    function customMetric() external view returns (uint256);
}
