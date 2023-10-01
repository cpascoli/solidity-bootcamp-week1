// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 *  @title Token with god mode.
 *  @author Carlo Pascoli
 *  @notice A special address is able to transfer tokens between addresses at will.
 */
contract TokenWithGodMode is ERC20, Ownable {

    constructor(uint supply) ERC20("My Token", "MT") {
        _mint(msg.sender, supply);
    }
 
    /// @notice allows the owner to transfer tokens between two addresses at will
    /// @param from the address spending the tokens
    /// @param to the address receiving the tokens
    /// @param amount the number of tokens being tranferred
    function godTranfer(address from, address to, uint256 amount) external onlyOwner {
        _transfer(from, to, amount);
    }

}