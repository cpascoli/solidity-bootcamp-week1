// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC1363/ERC1363.sol";

/**
 *  @title A basic ERC1363 token
 *  @author Carlo Pascoli
 */
contract Token1363 is ERC1363, Ownable {

    constructor(uint supply) ERC20("My ERC1363 Token", "MT") {
        _mint(msg.sender, supply);
    }
}