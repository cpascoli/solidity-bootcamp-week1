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

    event Bought(address indexed recipient, uint256 amouuntPaid, uint256 amountReceived);
    event Sold(address indexed recipient, uint256 amouuntPaid, uint256 amountReceived);


    constructor(address payTokenAddress) ERC20("Moon Token", "MT") {
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
        payToken = IERC20Metadata(payTokenAddress);
    }


    /// @notice Allows to buy 'amount' tokens from the contract
    /// @param amount THe amount of tokens to buy
    function buy(uint256 amount) external {
        // checks
        require(amount > 0, "Invalud amount");
        (, uint256 spendAmount) = quoteBuyPriceAmount(amount);
        require(payToken.allowance(msg.sender, address(this)) >= spendAmount, "Insufficient allowance");

        // effects
        _mint(msg.sender, amount);

        // interactions
        payToken.safeTransferFrom(msg.sender, address(this), spendAmount);

        emit Bought(msg.sender, spendAmount, amount);
    }


    /// @notice Allows to sell 'amount' tokens to the contract
    /// @param amount THe amount of tokens to sell
    function sell(uint256 amount) external {
        // checks
        require(amount > 0, "Invalud amount");

        // effects
        uint256 startingPrice = price();
        _burn(msg.sender, amount);
        uint256 finalPrice = price();

        // interactions
        uint256 precisionFactor = (10 ** decimals()) / pricePrecision;
        uint256 avgPrice = (startingPrice + finalPrice) / 2;
        uint256 boughtAmount = amount * avgPrice / precisionFactor;

        payToken.safeTransfer(msg.sender, boughtAmount);

        emit Sold(msg.sender, amount, boughtAmount);
    }


    /// @notice Handle the receiving of ERC777 tokens
    /// @param from the address of the sender that will receive the newly minted tokens
    /// @param amount THe amount of tokens received by the contract that will be used to pay for the new minted tokens
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

        uint256 toMint = amountToMint(amount);

        // interactions
        _mint(from, toMint);

        emit Bought(msg.sender, amount, toMint);
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

        uint256 toMint = amountToMint(amount);

        // interactions
        _mint(sender, toMint);

        emit Sold(msg.sender, amount, toMint);

        return bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"));
    }


    /// @notice return the average buy price and the amount of tokens to spend in when buying 'tokensToMint' tokens.
    /// @param tokensToMint The amount of tokens to buy
    function quoteBuyPriceAmount(uint256 tokensToMint) public view returns(uint256 avgPrice, uint256 quotedAmount) {
        uint256 initialPrice = price();

        // p2 = p1 + K * ds
        // includes the pricePrecision factor
        uint256 finalPrice = initialPrice + pricePrecision * K * tokensToMint / (10 ** decimals());

         // A =  (p1 + p2) * ds / 2 = avgPrice * deltaSupply
        avgPrice = (initialPrice + finalPrice) / 2;
        quotedAmount = (10 ** payToken.decimals()) * avgPrice * tokensToMint / pricePrecision / (10 ** decimals());
    }


    /// @notice return the average sell price and the amount of tokens received when selling 'tokensToBurn' tokens.
    /// @param tokensToBurn The amount of tokens to sell
    function quoteSellPriceAmount(uint256 tokensToBurn) external view returns(uint256 avgPrice, uint256 quotedAmount) {

        uint256 initialPrice = price();
        uint256 finalPrice = K * (totalSupply() - tokensToBurn) * pricePrecision / (10 ** decimals());

        // A =  (p1 + p2) * ds / 2 = avgPrice * deltaSupply
        avgPrice = (initialPrice + finalPrice) / 2;
        quotedAmount = (10 ** payToken.decimals()) * avgPrice * tokensToBurn / pricePrecision / (10 ** decimals());
    }

    
    /// @notice A linear bonding curve where prices increase proportionally to the supply
    function price() public view returns (uint256) {
        return K * totalSupply() * pricePrecision / (10 ** decimals());
    }


    /// @notice returns the additional supply of tokens 'toMint' in exchange for 'payAmount' tokens.
    /// @dev 'payAmount' represents the area of the trapezoid below the bonding curve 
    ///       between supply s1 (at price p1) and supply s2 (at price p2), where 'toMint' := s2 - s1
    ///       We need to solve the quadratic equation:
    ///         K * toMint^2 + 2 * p1 * toMint - 2 * payAmount = 0
    ///       Which is proportional to the difference in price p2 - p1 determiend by the area of the trapezoid: 
    ///         h := sqrt( 2Ak + p1^2 ) is the additional supply that will be minted ()'toMint')
    ///         p1 is the current price
    ///         p2 is the final price when additional 'toMint' tokens are minted
    ///         A is the amount of tokens paid to buy 'toMint' tokens: 'payAmount'

    function amountToMint(uint256 payAmount) public view returns (uint256 toMint) {
        uint startingPrice = price();
        uint256 priceWith18Decs = startingPrice * (10 ** decimals() / pricePrecision);

        uint256 finalPriceWith18Decs = Math.sqrt((2 * payAmount * K * 1e18) + (priceWith18Decs * priceWith18Decs));
        uint256 priceDiff = finalPriceWith18Decs - priceWith18Decs;

        toMint = priceDiff / K;
    }

}
