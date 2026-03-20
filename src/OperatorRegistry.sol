// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OperatorRegistry is Ownable {
    mapping(address => bool) private _allowedOperators;

    event OperatorUpdated(address indexed operator, bool allowed);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setAllowedOperator(address operator, bool allowed) external onlyOwner {
        _allowedOperators[operator] = allowed;
        emit OperatorUpdated(operator, allowed);
    }

    function isAllowedOperator(address operator) external view returns (bool) {
        return _allowedOperators[operator];
    }
}
