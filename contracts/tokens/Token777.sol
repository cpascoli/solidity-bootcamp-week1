// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 *  @title A basic ERC777 token
 *  @author Carlo Pascoli
 */
contract Token777 is ERC777, Ownable{

    constructor(
        address[] memory defaultOperators,
        uint256 supply
    ) ERC777("My Token", "MT", defaultOperators) {
        _mint(msg.sender, supply, "", "");
    }
}