// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {RulesEngineClient} from "@fortefoundation/forte-rules-engine/src/client/RulesEngineClient.sol";

abstract contract RulesEngineClientCustom is RulesEngineClient {
    modifier checkRulesBeforeTransfer(
        address operator,
        address from,
        address to,
        uint256 tokenId,
        uint256 blockTime,
        uint256 tokenUnlockTime,
        uint256 fromBlacklistFlag,
        uint256 toBlacklistFlag,
        uint256 treasuryBypass,
        uint256 transfersPausedFlag
    ) {
        bytes memory encoded = abi.encodeWithSelector(
            msg.sig,
            operator,
            from,
            to,
            tokenId,
            blockTime,
            tokenUnlockTime,
            fromBlacklistFlag,
            toBlacklistFlag,
            treasuryBypass,
            transfersPausedFlag
        );
        _invokeRulesEngine(encoded);
        _;
    }
}
