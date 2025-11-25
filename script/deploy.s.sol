// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/MockV3Aggregator.sol";
import "../src/PriceOracle.sol";
import "../src/StableCoin.sol";
import "../src/VaultManager.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockV3Aggregator with decimals=8 and initialPrice=2000e8
        MockV3Aggregator aggregator = new MockV3Aggregator(8, 2000e8);
        console.log("MockV3Aggregator deployed at:", address(aggregator));

        // Deploy PriceOracle pointing to the mock
        PriceOracle oracle = new PriceOracle(address(aggregator));
        console.log("PriceOracle deployed at:", address(oracle));

        // Deploy StableCoin
        StableCoin sUSD = new StableCoin();
        console.log("StableCoin deployed at:", address(sUSD));

        // Deploy VaultManager with sUSD and oracle addresses
        VaultManager vaultManager = new VaultManager(address(sUSD), address(oracle));
        console.log("VaultManager deployed at:", address(vaultManager));

        // Transfer ownership of sUSD to VaultManager (so VaultManager can mint/burn)
        sUSD.transferOwnership(address(vaultManager));
        console.log("StableCoin ownership transferred to VaultManager");

        vm.stopBroadcast();
    }
}

