// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRulesEngine} from "@fortefoundation/forte-rules-engine/src/client/IRulesEngine.sol";

contract MockMarketplaceRulesEngine is IRulesEngine {
    function checkPolicies(bytes calldata arguments) external pure override {
        (
            address operator,
            address from,
            address to,
            uint256 tokenId,
            uint256 operatorAllowedFlag,
            uint256 fromBlacklistFlag,
            uint256 toBlacklistFlag,
            uint256 treasuryBypass,
            uint256 transfersPausedFlag
        ) = abi.decode(arguments[4:], (address, address, address, uint256, uint256, uint256, uint256, uint256, uint256));

        operator;
        from;
        to;
        tokenId;

        if (fromBlacklistFlag != 0 || toBlacklistFlag != 0) {
            revert("Blacklisted address");
        }

        if (treasuryBypass != 1 && operatorAllowedFlag != 1) {
            revert("Operator not allowed");
        }

        if (treasuryBypass != 1 && transfersPausedFlag != 0) {
            revert("Transfers paused");
        }
    }

    function grantCallingContractRole(address, address) external pure override returns (bytes32) {
        return bytes32(0);
    }

    function grantForeignCallAdminRole(address, address, bytes4) external pure override returns (bytes32) {
        return bytes32(0);
    }
}
