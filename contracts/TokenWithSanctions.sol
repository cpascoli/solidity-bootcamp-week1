// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 *  @title  Token with sanctions.
 *  @author Carlo Pascoli
 *  @notice A fungible token that allows an admin to ban specified addresses from sending and receiving tokens.
 */
contract TokenWithSanctions is ERC20, Ownable {

    /// @notice A mapping to track banned addresses
    mapping (address => bool) public bannedAddresses;

    /// @notice the error returned for invalid addresses
    error InvalidAddress();

    /// @notice the error returned when a banned address sends or receives tokens
    error BannedAddress();


    constructor(uint supply) ERC20("My Token", "MT") {
        _mint(msg.sender, supply);
    }


    /// @notice bans an address
    /// @param user the address to be banned
    function ban(address user) external onlyOwner {
        if (user == address(0)) revert InvalidAddress();

        bannedAddresses[user] = true;
    }

    /// @notice unbans an address
    /// @param user the address to be unbanned
    function unban(address user) external onlyOwner {
        if (user == address(0)) revert InvalidAddress();

        bannedAddresses[user] = false;
    }

    /// @notice returs if the address provided is banned
    /// @param user the address to check
    function isBanned(address user) external view returns(bool) {
        return bannedAddresses[user];
    }

    /// @dev prevents banned address from sending and receiving tokens. 
    ///      reverting the token transfer with the custom error BannedAddress
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (bannedAddresses[from] || bannedAddresses[to]) revert BannedAddress();

        super._beforeTokenTransfer(from, to, amount);
    }
}