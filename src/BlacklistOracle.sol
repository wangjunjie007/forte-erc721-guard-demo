// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BlacklistOracle is Ownable {
    mapping(address => bool) private _blacklisted;

    event BlacklistUpdated(address indexed account, bool blacklisted);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setBlacklisted(address account, bool blacklisted) external onlyOwner {
        _blacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _blacklisted[account];
    }
}
