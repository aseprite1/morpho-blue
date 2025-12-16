// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TestFaucet} from "../src/Faucet.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DeployFaucet is Script {
    address constant UPKRW = 0x159C54accF62C14C117474B67D2E3De8215F5A72;
    address constant UPETH = 0xc05bAe1723bd929306B0ab8125062Efc111fb338;

    // Faucet funding amounts
    uint256 constant UPKRW_FUND = 10_000_000_000 * 10**18;  // 100억 UPKRW
    uint256 constant UPETH_FUND = 5000 * 10**18;            // 5000 UPETH

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        console.log("Deployer:", deployer);
        console.log("UPKRW balance:", IERC20(UPKRW).balanceOf(deployer));
        console.log("UPETH balance:", IERC20(UPETH).balanceOf(deployer));

        vm.startBroadcast(privateKey);

        // Deploy Faucet
        TestFaucet faucet = new TestFaucet(UPKRW, UPETH);
        console.log("Faucet deployed at:", address(faucet));

        // Fund Faucet with tokens
        IERC20(UPKRW).transfer(address(faucet), UPKRW_FUND);
        IERC20(UPETH).transfer(address(faucet), UPETH_FUND);

        vm.stopBroadcast();

        console.log("Faucet UPKRW balance:", IERC20(UPKRW).balanceOf(address(faucet)));
        console.log("Faucet UPETH balance:", IERC20(UPETH).balanceOf(address(faucet)));
        console.log("Faucet deployed and funded!");
    }
}
