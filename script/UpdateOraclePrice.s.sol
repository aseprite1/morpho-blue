// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {AdvancedOracleMock} from "../src/mocks/AdvancedOracleMock.sol";

/// @title UpdateOraclePrice
/// @notice Script to fix the oracle price (was 1e12 too small)
contract UpdateOraclePrice is Script {
    // Oracle deployed at
    address constant ORACLE = 0x258d90F00eEd27c69514A934379Aa41Cc03ea875;

    function run() external {
        console.log("=== Fixing Oracle Price ===");

        AdvancedOracleMock oracle = AdvancedOracleMock(ORACLE);

        // Current (wrong) price
        uint256 oldPrice = oracle.price();
        console.log("Old price:", oldPrice);

        // Correct price calculation:
        // 1 ETH = 4,800,000 KRW
        // 1 KRW = 1/4,800,000 ETH
        // price = (1 KRW in ETH) * 1e36 = 1e36 / 4,800,000
        uint256 ethPriceInKrw = 4_800_000;
        uint256 correctPrice = 1e36 / ethPriceInKrw;

        console.log("Correct price:", correctPrice);
        console.log("Ratio (correct/old):", correctPrice / oldPrice);

        vm.startBroadcast();

        oracle.setPrice(correctPrice);

        vm.stopBroadcast();

        console.log("\n=== Price Updated ===");
        console.log("New price:", oracle.price());
        console.log("Verification: 1e36 / price =", 1e36 / oracle.price(), "KRW per ETH");
    }
}
