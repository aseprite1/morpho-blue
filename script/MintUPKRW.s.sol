// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";

interface IUPKRW {
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function minters(address account) external view returns (bool);
}

contract MintUPKRW is Script {
    address constant UPKRW = 0x159C54accF62C14C117474B67D2E3De8215F5A72;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address minter = vm.addr(privateKey);

        console.log("Minter address:", minter);
        console.log("Is minter:", IUPKRW(UPKRW).minters(minter));

        // 100억 UPKRW = 10,000,000,000 * 10^18
        uint256 amount = 10_000_000_000 * 10**18;

        console.log("Current balance:", IUPKRW(UPKRW).balanceOf(minter));

        vm.startBroadcast(privateKey);
        IUPKRW(UPKRW).mint(minter, amount);
        vm.stopBroadcast();

        console.log("New balance:", IUPKRW(UPKRW).balanceOf(minter));
        console.log("Minted 10 billion UPKRW!");
    }
}
