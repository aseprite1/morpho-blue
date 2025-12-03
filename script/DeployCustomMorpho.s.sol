// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {CustomMorpho} from "../src/CustomMorpho.sol";

/// @title DeployCustomMorpho
/// @notice Deployment script for CustomMorpho on Giwa Chain
contract DeployCustomMorpho is Script {
    function run() external {
        // Load environment variables
        address owner = vm.envOr("OWNER_ADDRESS", msg.sender);

        // Kimchi premium threshold: default 3% = 0.03e18
        uint256 kimchiThreshold = vm.envOr("KIMCHI_PREMIUM_THRESHOLD", uint256(0.03e18));

        // Custom metric threshold: default 1e18
        uint256 customThreshold = vm.envOr("CUSTOM_METRIC_THRESHOLD", uint256(1e18));

        console.log("=== CustomMorpho Deployment ===");
        console.log("Owner:", owner);
        console.log("Kimchi Premium Threshold:", kimchiThreshold);
        console.log("Custom Metric Threshold:", customThreshold);

        vm.startBroadcast();

        // Deploy CustomMorpho
        CustomMorpho customMorpho = new CustomMorpho(
            owner,
            kimchiThreshold,
            customThreshold
        );

        console.log("\n=== Deployment Successful ===");
        console.log("CustomMorpho deployed at:", address(customMorpho));
        console.log("\nConfiguration:");
        console.log("- Owner:", customMorpho.owner());
        console.log("- Kimchi Premium Threshold:", customMorpho.kimchiPremiumThreshold());
        console.log("- Custom Metric Threshold:", customMorpho.customMetricThreshold());
        console.log("- Kimchi Premium Enabled:", customMorpho.kimchiPremiumEnabled());
        console.log("- Custom Metric Enabled:", customMorpho.customMetricEnabled());

        console.log("\n=== Next Steps ===");
        console.log("1. Enable features: setKimchiPremiumEnabled(true)");
        console.log("2. Enable features: setCustomMetricEnabled(true)");
        console.log("3. Enable IRM contracts");
        console.log("4. Enable LLTV values");
        console.log("5. Create markets");

        vm.stopBroadcast();
    }
}
