// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BlacklistOracle} from "src/BlacklistOracle.sol";
import {OperatorRegistry} from "src/OperatorRegistry.sol";
import {RulesEngineClientMarketplace} from "src/RulesEngineClientMarketplace.sol";

contract ForteMarketplaceGuardedNFT is ERC721, Ownable, RulesEngineClientMarketplace {
    BlacklistOracle public blacklistOracle;
    OperatorRegistry public operatorRegistry;
    address public treasury;
    bool public transfersPaused;
    uint256 public nextTokenId = 1;

    event TreasuryUpdated(address indexed treasury);
    event BlacklistOracleUpdated(address indexed oracle);
    event OperatorRegistryUpdated(address indexed registry);
    event TransfersPausedUpdated(bool paused);

    constructor(address initialOwner, address blacklistOracle_, address operatorRegistry_, address treasury_)
        ERC721("Forte Marketplace Guarded NFT", "FMGNFT")
        Ownable(initialOwner)
    {
        blacklistOracle = BlacklistOracle(blacklistOracle_);
        operatorRegistry = OperatorRegistry(operatorRegistry_);
        treasury = treasury_;
    }

    function setCallingContractAdmin(address callingContractAdmin) public override onlyOwner {
        super.setCallingContractAdmin(callingContractAdmin);
    }

    function setBlacklistOracle(address blacklistOracle_) external onlyOwner {
        blacklistOracle = BlacklistOracle(blacklistOracle_);
        emit BlacklistOracleUpdated(blacklistOracle_);
    }

    function setOperatorRegistry(address operatorRegistry_) external onlyOwner {
        operatorRegistry = OperatorRegistry(operatorRegistry_);
        emit OperatorRegistryUpdated(operatorRegistry_);
    }

    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setTransfersPaused(bool paused) external onlyOwner {
        transfersPaused = paused;
        emit TransfersPausedUpdated(paused);
    }

    function mint(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _mint(to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        override
        checkRulesBeforeMarketplaceTransfer(
            _msgSender(),
            from,
            to,
            tokenId,
            _operatorAllowedFlag(_msgSender(), from),
            _blacklistFlag(from),
            _blacklistFlag(to),
            _treasuryBypass(from),
            _transfersPausedFlag()
        )
    {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        checkRulesBeforeMarketplaceTransfer(
            _msgSender(),
            from,
            to,
            tokenId,
            _operatorAllowedFlag(_msgSender(), from),
            _blacklistFlag(from),
            _blacklistFlag(to),
            _treasuryBypass(from),
            _transfersPausedFlag()
        )
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function _blacklistFlag(address account) internal view returns (uint256) {
        if (address(blacklistOracle) == address(0)) {
            return 0;
        }
        return blacklistOracle.isBlacklisted(account) ? 1 : 0;
    }

    function _operatorAllowedFlag(address operator, address from) internal view returns (uint256) {
        if (operator == from) {
            return 1;
        }
        if (address(operatorRegistry) == address(0)) {
            return 0;
        }
        return operatorRegistry.isAllowedOperator(operator) ? 1 : 0;
    }

    function _treasuryBypass(address from) internal view returns (uint256) {
        return from == treasury ? 1 : 0;
    }

    function _transfersPausedFlag() internal view returns (uint256) {
        return transfersPaused ? 1 : 0;
    }
}
