// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RulesEngineClientCustom} from "src/RulesEngineClientCustom.sol";
import {BlacklistOracle} from "src/BlacklistOracle.sol";

contract ForteGuardedNFT is ERC721, Ownable, RulesEngineClientCustom {
    BlacklistOracle public blacklistOracle;
    address public treasury;
    bool public transfersPaused;
    uint256 public nextTokenId = 1;

    mapping(uint256 => uint256) public tokenUnlockTime;

    event TreasuryUpdated(address indexed treasury);
    event BlacklistOracleUpdated(address indexed oracle);
    event TransfersPausedUpdated(bool paused);
    event TokenUnlockTimeUpdated(uint256 indexed tokenId, uint256 unlockTime);

    constructor(address initialOwner, address blacklistOracle_, address treasury_)
        ERC721("Forte Guarded NFT", "FGNFT")
        Ownable(initialOwner)
    {
        blacklistOracle = BlacklistOracle(blacklistOracle_);
        treasury = treasury_;
    }

    function setCallingContractAdmin(address callingContractAdmin) public override onlyOwner {
        super.setCallingContractAdmin(callingContractAdmin);
    }

    function setBlacklistOracle(address blacklistOracle_) external onlyOwner {
        blacklistOracle = BlacklistOracle(blacklistOracle_);
        emit BlacklistOracleUpdated(blacklistOracle_);
    }

    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setTransfersPaused(bool paused) external onlyOwner {
        transfersPaused = paused;
        emit TransfersPausedUpdated(paused);
    }

    function setTokenUnlockTime(uint256 tokenId, uint256 unlockTime) external onlyOwner {
        tokenUnlockTime[tokenId] = unlockTime;
        emit TokenUnlockTimeUpdated(tokenId, unlockTime);
    }

    function mint(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _mint(to, tokenId);
    }

    function mintWithLock(address to, uint256 unlockTime) external onlyOwner returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _mint(to, tokenId);
        tokenUnlockTime[tokenId] = unlockTime;
        emit TokenUnlockTimeUpdated(tokenId, unlockTime);
    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        override
        checkRulesBeforeTransfer(
            _msgSender(),
            from,
            to,
            tokenId,
            block.timestamp,
            tokenUnlockTime[tokenId],
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
        checkRulesBeforeTransfer(
            _msgSender(),
            from,
            to,
            tokenId,
            block.timestamp,
            tokenUnlockTime[tokenId],
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

    function _treasuryBypass(address from) internal view returns (uint256) {
        return from == treasury ? 1 : 0;
    }

    function _transfersPausedFlag() internal view returns (uint256) {
        return transfersPaused ? 1 : 0;
    }
}
