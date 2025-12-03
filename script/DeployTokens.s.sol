// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {UPKRW} from "../src/tokens/UPKRW.sol";
import {UPETH} from "../src/tokens/UPETH.sol";

/// @title DeployTokens
/// @notice Deployment script for UPKRW and UPETH tokens
contract DeployTokens is Script {
    function run() external {
        address owner = vm.envOr("OWNER_ADDRESS", msg.sender);

        console.log("=== Token Deployment ===");
        console.log("Owner:", owner);

        vm.startBroadcast();

        // Deploy UPKRW
        UPKRW upkrw = new UPKRW(owner);
        console.log("\nUPKRW deployed at:", address(upkrw));
        console.log("- Name:", upkrw.name());
        console.log("- Symbol:", upkrw.symbol());
        console.log("- Decimals:", upkrw.decimals());

        // Deploy UPETH
        UPETH upeth = new UPETH(owner);
        console.log("\nUPETH deployed at:", address(upeth));
        console.log("- Name:", upeth.name());
        console.log("- Symbol:", upeth.symbol());
        console.log("- Decimals:", upeth.decimals());

        console.log("\n=== Deployment Complete ===");
        console.log("Owner has minting privileges for both tokens");
        console.log("\nNext steps:");
        console.log("1. Mint initial supply if needed");
        console.log("2. Add additional minters if needed");

        vm.stopBroadcast();
    }
}
