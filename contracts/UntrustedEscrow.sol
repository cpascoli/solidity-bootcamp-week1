// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 *  @title Untrusted Escrow
 *  @author Carlo Pascoli
 *  @notice A contract where a buyer can put an arbitrary ERC20 token into a contract
 *         and a seller can withdraw it 3 days later.
 */
contract UntrustedEscrow is ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;

    /// @notice maps the address of a seller against the deposit made by a buyer
    mapping(address => DepositInfo) deposits;

    /// @notice the duration of the timelock for the tokens in escrow
    uint256 public constant UNLOCK_DELAY = 3 days;

    /// @notice after this interval expires the transaction is considered voided
    /// and the buyer can get their tokens back.
    uint256 public constant EXPIRY_DELAY = 30 days;

    struct DepositInfo {
        address token;
        uint256 amount;
        address buyer;
        uint256 depositTimestamp;
    }

    event Deposited(
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 amount
    );

    event Withdrawn(
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 amount
    );

    event Voided(
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 amount
    );


    /// @notice Allows the buyer to lock some tokens into the contract.
    ///         It reverts when a deposit already exists for a seller.
    /// @param tokenAddress The address of the token being tranferred
    /// @param sellerAddress The address of the seller that can withdraw the tokens
    /// @param amount The amount of tokens being transferred
    function deposit(address tokenAddress, address sellerAddress, uint256 amount) external nonReentrant {

        require(tokenAddress != address(0), "Invalid token address");
        require(sellerAddress != address(0), "Invalid seller address");
        require(amount > 0, "Invalid amount");
        require(
            deposits[sellerAddress].depositTimestamp == 0,
            "Deposit already exists for seller"
        );

        // store deposit info
        deposits[sellerAddress] = DepositInfo({
            token: tokenAddress,
            amount: amount,
            buyer: msg.sender,
            depositTimestamp: block.timestamp
        });

        // transfer tokens to the contract
        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit Deposited(msg.sender, sellerAddress, tokenAddress, amount);
    }


    /// @notice Allows the seller to withdraw the funds after the timelock expires
    function withdraw() external nonReentrant {
        DepositInfo memory depositInfo = deposits[msg.sender];
        require(depositInfo.amount > 0, "Tokens not found");
        require(
            block.timestamp > depositInfo.depositTimestamp + UNLOCK_DELAY,
            "Tokens locked"
        );

        // delete deposit
        delete deposits[msg.sender];

        // transfer tokens to the seller
        IERC20(depositInfo.token).safeTransfer(msg.sender, depositInfo.amount);

        emit Withdrawn(
            depositInfo.buyer,
            msg.sender,
            depositInfo.token,
            depositInfo.amount
        );
    }


    /// @notice Allows buyers to get their tokens back if the transaction expires
    function returnTokens(address seller) external onlyOwner {
        DepositInfo memory depositInfo = deposits[seller];

        require(depositInfo.buyer == msg.sender, "Caller must be the buyer");
        require(
            block.timestamp > depositInfo.depositTimestamp + EXPIRY_DELAY,
            "Depposit not expired"
        );

        // transfer tokens back to the buyer
        IERC20(depositInfo.token).safeTransfer(msg.sender, depositInfo.amount);

        emit Voided (
            depositInfo.buyer,
            msg.sender,
            depositInfo.token,
            depositInfo.amount
        );

    }


    /// @notice returns the depoist info for a seller
    /// @param sellerAddress The address of the seller
    function getDepoist(address sellerAddress) external view returns (DepositInfo memory) {
        return deposits[sellerAddress];
    }
}
