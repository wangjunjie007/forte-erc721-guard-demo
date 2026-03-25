// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {BlacklistOracle} from "src/BlacklistOracle.sol";
import {OperatorRegistry} from "src/OperatorRegistry.sol";
import {ForteMarketplaceGuardedNFT} from "src/ForteMarketplaceGuardedNFT.sol";

contract DeployMarketplaceDemo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIV_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        BlacklistOracle oracle = new BlacklistOracle(deployer);
        OperatorRegistry registry = new OperatorRegistry(deployer);
        ForteMarketplaceGuardedNFT nft =
            new ForteMarketplaceGuardedNFT(deployer, address(oracle), address(registry), deployer);

        vm.stopBroadcast();

        console2.log("BlacklistOracle:", address(oracle));
        console2.log("OperatorRegistry:", address(registry));
        console2.log("ForteMarketplaceGuardedNFT:", address(nft));
        console2.log("Owner / Treasury:", deployer);
    }
}
