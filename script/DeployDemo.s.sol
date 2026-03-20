// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {BlacklistOracle} from "src/BlacklistOracle.sol";
import {ForteGuardedNFT} from "src/ForteGuardedNFT.sol";

contract DeployDemo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIV_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        BlacklistOracle oracle = new BlacklistOracle(deployer);
        ForteGuardedNFT nft = new ForteGuardedNFT(deployer, address(oracle), deployer);

        nft.mint(deployer);
        nft.mint(deployer);

        vm.stopBroadcast();

        console2.log("BlacklistOracle:", address(oracle));
        console2.log("ForteGuardedNFT:", address(nft));
        console2.log("Owner / Treasury:", deployer);
    }
}
