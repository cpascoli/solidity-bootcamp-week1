// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 *  @title A basic ERC20 token
 *  @author Carlo Pascoli
 */
contract Token20 is ERC20, Ownable {

    constructor(uint supply) ERC20("My Token", "MT") {
        _mint(msg.sender, supply);
    }
}