// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

/**
 *  @title A basic ERC777 token
 *  @author Carlo Pascoli
 */
contract Token777 is ERC777 {

    constructor(uint256 supply) ERC777("My Token", "MT", new address[](0)) {
         _mint(msg.sender, supply, "", "");
    }
}