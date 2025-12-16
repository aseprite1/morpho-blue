// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/oracles/KoracleAdapter.sol";
import "../src/CustomMorpho.sol";
import "../src/interfaces/IMorpho.sol";

contract DeployKoracle is Script {
    // Koracle mainnet address
    address constant KORACLE = 0x0532d3A42318Ebbd10CECAF34517780fBf3e51D7;

    // Existing tokens
    address constant UPETH = 0xc05bAe1723bd929306B0ab8125062Efc111fb338;
    address constant UPKRW = 0x159C54accF62C14C117474B67D2E3De8215F5A72;
    address constant IRM = 0xA99676204e008B511dA8662F9bE99e2bfA5afd63;

    // LLTV 92%
    uint256 constant LLTV = 0.92e18;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying from:", deployer);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy KoracleAdapter
        KoracleAdapter koracleAdapter = new KoracleAdapter(KORACLE);
        console.log("KoracleAdapter deployed at:", address(koracleAdapter));

        // 2. Deploy CustomMorpho
        // Initial kimp threshold: 5% (0.05e18)
        // Initial custom threshold: 0
        CustomMorpho customMorpho = new CustomMorpho(
            deployer,           // owner
            0.05e18,           // initial kimchi threshold (5%)
            0                  // initial custom threshold
        );
        console.log("CustomMorpho deployed at:", address(customMorpho));

        // 3. Enable IRM and LLTV
        customMorpho.enableIrm(IRM);
        console.log("IRM enabled");

        customMorpho.enableLltv(LLTV);
        console.log("LLTV enabled");

        // 4. Create market with new oracle
        MarketParams memory marketParams = MarketParams({
            loanToken: UPETH,
            collateralToken: UPKRW,
            oracle: address(koracleAdapter),
            irm: IRM,
            lltv: LLTV
        });

        customMorpho.createMarket(marketParams);
        console.log("Market created!");

        // Get market ID
        bytes32 marketId = keccak256(abi.encode(marketParams));
        console.log("Market ID:");
        console.logBytes32(marketId);

        vm.stopBroadcast();

        // Summary
        console.log("\n=== Deployment Summary ===");
        console.log("KoracleAdapter:", address(koracleAdapter));
        console.log("CustomMorpho:", address(customMorpho));
        console.log("Market ID:", vm.toString(marketId));
        console.log("LLTV:", LLTV);

        // Verification commands
        console.log("\n=== Verify Commands ===");
        console.log("Run these after deployment:");
        console.log("");
        console.log("# Verify KoracleAdapter");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(address(koracleAdapter)),
            " src/oracles/KoracleAdapter.sol:KoracleAdapter ",
            "--constructor-args $(cast abi-encode \"constructor(address)\" ",
            vm.toString(KORACLE),
            ") ",
            "--chain-id 91342 ",
            "--verifier blockscout ",
            "--verifier-url https://sepolia-explorer.giwa.io/api/"
        ));
        console.log("");
        console.log("# Verify CustomMorpho");
        console.log(string.concat(
            "forge verify-contract ",
            vm.toString(address(customMorpho)),
            " src/CustomMorpho.sol:CustomMorpho ",
            "--constructor-args $(cast abi-encode \"constructor(address,uint256,uint256)\" ",
            vm.toString(deployer),
            " 50000000000000000 0) ",
            "--chain-id 91342 ",
            "--verifier blockscout ",
            "--verifier-url https://sepolia-explorer.giwa.io/api/"
        ));
    }
}
