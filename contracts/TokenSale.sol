// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20 } from  "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC777Recipient } from "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import { SafeERC20 } from  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC1820Registry } from  "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";

import { IERC1363Receiver } from "./tokens/ERC1363/IERC1363Receiver.sol";


import "hardhat/console.sol";

/**
 *  @title Token sale and buyback with bonding curve.
 *  @author Carlo Pascoli
 *  @notice The more tokens a user buys, the more expensive the token becomes.
 *          To keep things simple, use a linear bonding curve.
 *          When a person sends a token to the contract with ERC1363 or ERC777, it should trigger the receive function.
 *          If you use a separate contract to handle the reserve and use ERC20, you need to use the approve and send workflow.
 *          This should support fractions of tokens.
 */
contract TokenSale is ERC20, Ownable, IERC777Recipient, IERC1363Receiver {

    using SafeERC20 for IERC20Metadata;

    IERC1820Registry internal constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    /// @notice the slope of the bonding courve
    uint256 constant public K = 1;

    /// @notice the factor used for the precision of the token prices
    uint256 constant public pricePrecision = 1e6;

    /// @notice the token used to pay for the tokens sold by the contract
    IERC20Metadata immutable public payToken;


    constructor(address payTokenAddress) ERC20("Moon Token", "MT") {
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
        payToken = IERC20Metadata(payTokenAddress);
    }


    function buy(uint256 amount) external {
        // checks
        require(amount > 0, "Invalud amount");
        (, uint256 spendAmount) = quoteBuyPriceAmount(amount);
        require(payToken.allowance(msg.sender, address(this)) >= spendAmount, "Insufficient allowance");

        // effects
        _mint(msg.sender, amount);

        // interactions
        payToken.safeTransferFrom(msg.sender, address(this), spendAmount);
    }


    function sell(uint256 amount) external {
        // checks
        require(amount > 0, "Invalud amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        // effects
        uint256 initialPrice = price() * 10**12;
        _burn(msg.sender, amount);
        uint256 finalPrice = price() * 10**12;

        // interactions
        uint256 boughtAmount = (initialPrice + finalPrice) * amount / 2 / 10 ** 18;

        payToken.transfer(msg.sender, boughtAmount);
    }


    /// @notice Handle the receiving of ERC777 tokens
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {

        // checks
        require(msg.sender == address(payToken), "Invalid caller");
        require(amount > 0, "Invalud amount");

        uint256 toMint = amountToMintForTokens(amount);

        // interactions
        _mint(from, toMint);
    }


    /// @notice Handle the receiving of ERC1363 tokens.
    /// @dev Any ERC1363 smart contract calls this function on the recipient
    /// @param spender address The address which called `transferAndCall` or `transferFromAndCall` function
    /// @param sender address The address which are token transferred from
    /// @param amount uint256 The amount of tokens transferred
    /// @param data bytes Additional data with no specified format
    /// @return `bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))` unless throwing
    function onTransferReceived(
        address spender,
        address sender,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes4) {
        // checks
        require(msg.sender == address(payToken), "Invalid caller");
        require(amount > 0, "Invalud amount");

        uint256 toMint = amountToMintForTokens(amount);

        // interactions
        _mint(sender, toMint);

        return bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"));
    }


    /// @notice return the average price and the amount of tokens to spend in order to mint 'tokensToMint' tokens.
    /// @param tokensToMint The amount of tokens to mint
    function quoteBuyPriceAmount(uint256 tokensToMint) public view returns(uint256 avgPrice, uint256 quotedAmount) {
        uint256 initialPrice = price();

        // p2 = p1 + K * ds
        // includes the pricePrecision factor
        uint256 finalPrice = initialPrice + pricePrecision * K * tokensToMint / (10 ** decimals());

        // includes the pricePrecision factor
        avgPrice = (initialPrice + finalPrice) / 2;

        // A =  (p1 + p2) * ds / 2
        quotedAmount = (10 ** payToken.decimals()) * avgPrice * tokensToMint / pricePrecision / (10 ** decimals());
    }


    function quoteSellPriceAmount(uint256 tokensToBurn) external view returns(uint256 avgPrice, uint256 quotedAmount) {

        uint256 initialPrice = price();
        uint256 finalPrice = K * (totalSupply() - tokensToBurn) * pricePrecision / (10 ** decimals());

        avgPrice = (initialPrice + finalPrice) / 2;

        // A =  (p1 + p2) * ds / 2
        quotedAmount = (10 ** payToken.decimals()) * avgPrice * tokensToBurn / pricePrecision / (10 ** decimals());
    }

    
    /// Linear bonding curve
    function price() public view returns (uint256) {
        return K * totalSupply() * pricePrecision / (10 ** decimals());
    }


    /// @notice returns the amount of tokens to mint in exchange for 'payAmount' tokens
    /// @dev  We need to solve the equation:
    ///       K * tokensToMint^2 + 2 * price * tokensToMint - 2 * payAmount = 0
    function amountToMintForTokens(uint256 payAmount) public view returns (uint256 toMint) {
        // This would solve a quadratic equation in case of a linear curve
        // Result derived from area of trapezoid formula
        uint initialPrice = price();

        uint256 priceWith18Decs = initialPrice * (10 ** 12);

        // console.log(">>> amountToMintForTokens - initialPrice: ", initialPrice, priceWith18Decs);
        // console.log(">>> amountToMintForTokens - payAmount: ", payAmount);
        //toMint =  (2 * payAmount) / (initialPrice + Math.sqrt((initialPrice ** 2) + (2 * K * payAmount)));

        // p2 := h := sqrt( 2Ak + p1^2 )  1000000000000000000
        uint256 finalPrice = Math.sqrt((2 * payAmount * K * 1e18) + (priceWith18Decs * priceWith18Decs));
        uint256 priceDiff = finalPrice - priceWith18Decs;

        // console.log(">>> amountToMintForTokens - finalPrice: ", finalPrice);
        // console.log(">>> amountToMintForTokens - priceDiff: ", priceDiff);

        toMint = priceDiff / K;
        
        // console.log(">>> amountToMintForTokens - toMint!!: ", toMint); // 2000000000 000000000  2000000000
    }


    function tokensForPaidAmount(uint256 paidAmount ) internal view returns(uint256) {
           return pricePrecision * paidAmount / price();
    }

    function payTokensForAmount(uint256 buyAmount ) internal view returns(uint256) {
           return buyAmount * price() / pricePrecision;
    }


    function calculateTrapezoidArea(uint256 base1, uint256 base2, uint256 height) internal pure returns (uint256) {
        return (base1 + base2) * height / 2;
    }


}
