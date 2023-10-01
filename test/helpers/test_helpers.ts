import { ethers } from "hardhat";
import {  BigNumber } from "ethers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

export type Bid = { price: number, timestamp: number }
export const day = 24 * 60 * 60;

/**
 * Increases the time of the test blockchain by the given number of seconds
 * @param secs the number of seconds to wait
 */
export const waitSeconds = async  (secs: number) => {
	const ts = (await time.latest()) + secs
	await time.increaseTo(ts)
}

/**
 * Converts from wei to units.
 * @param amount the amount in wei to convert in units
 * @returns the amount in units as a number
 */
export const toUnits = (amount: BigNumber) : number => {
    return Number(ethers.utils.formatUnits(amount, 18));
}

/**
 * Converts from units to wei.
 * @param units the amount of units to convert in wei
 * @returns the unit value in wei as a BigNumber
 */
export const toWei = (units: number) : BigNumber => {
    return ethers.utils.parseUnits( units.toString(), 18); 
}

/**
 * @returns the timestamp of the last mined block.
 */
export const getLastBlockTimestamp = async () => {
    return (await ethers.provider.getBlock(await ethers.provider.getBlockNumber())).timestamp
}

/**
 * @returns an object containing an instance of the TokenWithSanctions contract,
 * the owner and some users
 */
export const deployTokenWithSanctionsContract = async () => {

    const [ owner, user0, user1 ] = await ethers.getSigners();

    const TokenWithSanctions = await ethers.getContractFactory("TokenWithSanctions")
    const tokenContract = await TokenWithSanctions.deploy(toWei(1_000_000))

    // transfers 100 tokens to user0
    await tokenContract.connect(owner).transfer(user0.address, toWei(100))

    return { tokenContract, owner, user0, user1 };
}


/**
 * @returns an object containing an instance of the TokenWithGodMode contract
 */
export const deployTokenWithGodModeContract = async () => {

    const [ owner, user0, user1, another ] = await ethers.getSigners();

    const TokenWithSanctions = await ethers.getContractFactory("TokenWithGodMode")
    const tokenContract = await TokenWithSanctions.deploy(toWei(1_000_000))

    // transfers 100 tokens to user0
    await tokenContract.connect(owner).transfer(user0.address, toWei(100))


    return { tokenContract, owner, user0, user1, another };
}

/**
 * @returns an object containing an instance of the TokenSale contract that accepts ERC20 tokens
 */
export const deployTokenSaleContract_ERC20 = async () => {

    const [ owner, user0, user1, another ] = await ethers.getSigners();

    const Token20 = await ethers.getContractFactory("Token20")
    const token20 = await Token20.deploy(toWei(1_000_000))

    const TokenSale = await ethers.getContractFactory("TokenSale")
    const tokenSale = await TokenSale.deploy(token20.address)

    await token20.connect(owner).transfer(user0.address, toWei(100))
    await token20.connect(owner).transfer(user1.address, toWei(100))

    return { tokenSale, token20, owner, user0, user1, another };
}

/**
 * @returns an object containing an instance of the TokenSale contract that accepts ERC1363 tokens
 */
export const deployTokenSaleContract_ERC1363 = async () => {

    const [ owner, user0, user1, another ] = await ethers.getSigners();

    const Token1363 = await ethers.getContractFactory("Token1363")
    const token1363 = await Token1363.deploy(toWei(1_000_000))

    const TokenSale = await ethers.getContractFactory("TokenSale")
    const tokenSale = await TokenSale.deploy(token1363.address)

    await token1363.connect(owner).transfer(user0.address, toWei(100))
    await token1363.connect(owner).transfer(user1.address, toWei(100))

    return { tokenSale, token1363, owner, user0, user1, another };
}



