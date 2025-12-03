// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {AdvancedOracleMock} from "../src/mocks/AdvancedOracleMock.sol";

/// @title DeployOracle
/// @notice Deployment script for AdvancedOracleMock
contract DeployOracle is Script {
    function run() external {
        console.log("=== Oracle Deployment ===");

        vm.startBroadcast();

        // Deploy Oracle
        AdvancedOracleMock oracle = new AdvancedOracleMock();
        console.log("\nAdvancedOracleMock deployed at:", address(oracle));

        // Set initial values
        // Current rate: 1 ETH = 4,566,000 KRW (from Upbit)
        // So: 1 KRW = 1/4,566,000 ETH
        // Price is scaled by 1e36
        // Formula: 1e36 / 4,566,000 = 219,062,380,290,562
        uint256 initialPrice = 219062380290562371; // Pre-calculated to avoid division
        oracle.setPrice(initialPrice);
        console.log("- Initial Price (1 UPKRW in UPETH):", initialPrice);
        console.log("- Exchange Rate: 1 ETH = 4,566,000 KRW");

        // Kimchi Premium: +1.45% (current market)
        // 1.45% = 0.0145 * 1e18 = 14,500,000,000,000,000
        uint256 kimchiPremium = 14500000000000000; // 1.45%
        oracle.setKimchiPremium(kimchiPremium);
        console.log("- Initial Kimchi Premium: 1.45%");

        // Custom Metric: 1.0 initially
        oracle.setCustomMetric(1e18);
        console.log("- Initial Custom Metric: 1.0");

        console.log("\n=== Oracle Configuration ===");
        console.log("Price (UPKRW/UPETH):", oracle.price());
        console.log("Kimchi Premium:", oracle.kimchiPremium());
        console.log("Custom Metric:", oracle.customMetric());

        console.log("\n=== Next Steps ===");
        console.log("1. Use this oracle when creating markets");
        console.log("2. Update price: oracle.setPrice(newPrice)");
        console.log("3. Update kimchi premium: oracle.setKimchiPremium(premium)");

        vm.stopBroadcast();
    }
}
