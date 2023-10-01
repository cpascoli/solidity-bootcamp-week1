import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import { 
    deployTokenSaleContract_ERC20, 
    deployTokenSaleContract_ERC1363,
    toUnits, 
    toWei 
} from "./helpers/test_helpers";


describe("TokenSale", function () {

    describe("ERC20", function () {

        describe("config", function () {
            it("has 0 initial supply", async function () {
                const { tokenSale } = await loadFixture(deployTokenSaleContract_ERC20);
                expect(await tokenSale.totalSupply()).to.be.equal( 0 )
            });

            it("supports payments with ERC20", async function () {
                const { tokenSale, token20 } = await loadFixture(deployTokenSaleContract_ERC20);
        
                expect( await tokenSale.payToken() ).to.be.equal( token20.address )
        });
        })

        describe("buy", function () {

            it("can buy units of the token", async function () {
                const { tokenSale, token20, user0, user1 } = await loadFixture(deployTokenSaleContract_ERC20);
             
                const buyAmount = 3
                const [ price, payAmount ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount) )
                await token20.connect(user0).approve(tokenSale.address, payAmount)
                await tokenSale.connect(user0).buy( toWei(buyAmount) )
    
                const precision = await tokenSale.pricePrecision()
                const expectedPrice = 3
                expect( (await tokenSale.price()).div( precision) ).to.be.equal( expectedPrice )
                expect( await tokenSale.balanceOf(user0.address) ).to.be.equal( toWei( buyAmount ) )
            });
    
    
            it("can buy a fraction of a token", async function () {
                const { tokenSale, token20, user0, user1 } = await loadFixture(deployTokenSaleContract_ERC20);
             
                const buyAmount = 0.1
                const [ price, payAmount ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount) )
                const balanceBefore = await token20.balanceOf(user0.address)
    
                await token20.connect(user0).approve(tokenSale.address, payAmount)
                await tokenSale.connect(user0).buy( toWei(buyAmount) )
    
                const balanceAfter = await token20.balanceOf(user0.address)
    
                console.log(">> spent: ",  toUnits(balanceBefore.sub(balanceAfter)) )
                const spentAmount = balanceBefore.sub(balanceAfter)
    
                expect( spentAmount ).to.be.equal( payAmount )
            });
    
    
            it("increases prices when multiple buys increase the supply", async function () {
    
                const { tokenSale, token20, user0, user1 } = await loadFixture(deployTokenSaleContract_ERC20);
                const precision = (await tokenSale.pricePrecision()).toNumber()
    
                // get quote for 2 tokens buy
                const buyAmount0 = 2
                const [ price0, payAmount0 ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount0) )
                expect(price0.toNumber() / precision).to.be.equal(2)
    
                // user0 buys 2 tokens
                await token20.connect(user0).approve(tokenSale.address, payAmount0)
                await tokenSale.connect(user0).buy( toWei(buyAmount0) )
    
                const pricePaid0 = toUnits(payAmount0) / toUnits(await tokenSale.balanceOf(user0.address))
                expect(pricePaid0).to.be.equal(price0.toNumber() / precision)
                expect(pricePaid0).to.be.equal(2)
    
                // get quote for 2 tokens buy
                const buyAmount1 = 2
                const [ price1, payAmount1 ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount1) )
                expect(price1.toNumber() / precision).to.be.equal(4)
    
                // user1 buys 2 tokens
                await token20.connect(user1).approve(tokenSale.address, payAmount1)
                await tokenSale.connect(user1).buy( toWei(buyAmount1) )
    
                const pricePaid1 = toUnits(payAmount1) / toUnits(await tokenSale.balanceOf(user1.address))
               
                expect(pricePaid1).to.be.equal(price1.toNumber() / precision)
              
            });
    
        })
    
        describe("sell", function () {
    
            it("moves the price back the price where it was when an amount is bought and sold", async function () {
                const { tokenSale, token20, user0, user1 } = await loadFixture(deployTokenSaleContract_ERC20);
                const precision = (await tokenSale.pricePrecision()).toNumber()
    
                const buyAmount = 1
    
                console.log(">> price before 1st sale: ", (await tokenSale.price()).toNumber() / precision )
    
                // first buy
                const [ price0, payAmount0 ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount) )
    
                console.log(">> buy price0: ", price0.toNumber() / precision )
                console.log(">> payAmount0: ", payAmount0, toUnits(payAmount0) )
                console.log(">> balance: ",  toUnits(await token20.balanceOf(user0.address)) )
    
                await token20.connect(user0).approve(tokenSale.address, payAmount0)
                await tokenSale.connect(user0).buy( toWei(buyAmount) )
    
                console.log(">> balance after: ",  toUnits(await token20.balanceOf(user0.address)) )
                console.log(">> price after 1 buy: ", (await tokenSale.price()).toNumber() / precision )
    
                // second buy
                const [ price1, payAmount1 ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount) )
                console.log(">> buy price0: ", price0.toNumber() / precision )
                console.log(">> payAmount1: ", payAmount1, toUnits(payAmount1) )
    
                await token20.connect(user0).approve(tokenSale.address, payAmount1)
                await tokenSale.connect(user0).buy( toWei(buyAmount) )
    
                console.log(">> balance after: ",  toUnits(await token20.balanceOf(user0.address)) )
                console.log(">> price after 2 buy: ", (await tokenSale.price()).toNumber() / precision )
    
    
                await tokenSale.connect(user0).sell( toWei(buyAmount) )
                console.log(">> price after 1 sell: ", (await tokenSale.price()).toNumber() / precision )
            });
    
        })
    })


    describe("ERC1363", function () {

        describe("config", function () {
            it("has 0 initial supply", async function () {
                const { tokenSale } = await loadFixture(deployTokenSaleContract_ERC1363);
                expect(await tokenSale.totalSupply()).to.be.equal( 0 )
            });

            it("supports payments with ERC1363", async function () {
                const { tokenSale, token1363 } = await loadFixture(deployTokenSaleContract_ERC1363);
               
                // verify tokens supports the ERC1363 intrface
                expect( await token1363.supportsInterface("0x88a7ca5c") ).to.be.true
                expect( await tokenSale.payToken() ).to.be.equal( token1363.address )
            });
        })

        describe("buy", function () {

            it("can buy units of the token", async function () {
                const { tokenSale, token1363, user0, user1 } = await loadFixture(deployTokenSaleContract_ERC1363);
             
                // user0 wants to buy 3 tokens from the TokenSale
                const buyAmount = 1
                const [ quotedPrice, payAmount ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount) )
              
                await token1363.connect(user0)["transferAndCall(address,uint256)"](tokenSale.address, payAmount)
    
                expect( await tokenSale.balanceOf( user0.address ) ).to.be.equal( toWei( buyAmount ) )
            });
    
    
            it("can buy a fraction of a token", async function () {
                const { tokenSale, token1363, user0, user1 } = await loadFixture(deployTokenSaleContract_ERC1363);
             
                const buyAmount = 0.1
                const [ price, payAmount ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount) )
                const balanceBefore = await token1363.balanceOf(user0.address)
    
                await token1363.connect(user0)["transferAndCall(address,uint256)"](tokenSale.address, payAmount)

                const balanceAfter = await token1363.balanceOf(user0.address)
                const spentAmount = balanceBefore.sub(balanceAfter)
    
                expect( spentAmount ).to.be.equal( payAmount )
            });
    
    
            it("increases prices when multiple buys increase the supply", async function () {
    
                const { tokenSale, token1363, user0, user1 } = await loadFixture(deployTokenSaleContract_ERC1363);
                const precision = (await tokenSale.pricePrecision()).toNumber()
    
                // get quote for 1 tokens buy
                const buyAmount0 = 1
                const [ price0, payAmount0 ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount0) )
                const initalBalance = toUnits(await token1363.balanceOf(user0.address))

                // user0 buys 1 token
                await token1363.connect(user0)["transferAndCall(address,uint256)"](tokenSale.address, payAmount0)

                expect( await tokenSale.balanceOf(user0.address) ).to.be.equal( toWei(1) )
                expect( await token1363.balanceOf(user0.address) ).to.be.equal( toWei(initalBalance - 0.5) )

                const [ price1, payAmount1 ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount0) )
                await token1363.connect(user0)["transferAndCall(address,uint256)"](tokenSale.address, payAmount1)
                
                expect( await tokenSale.balanceOf(user0.address) ).to.be.equal( toWei(2) )
                expect( await token1363.balanceOf(user0.address) ).to.be.equal( toWei(initalBalance - 0.5 - 1.5) )
            });
    
        })
    
        describe("sell", function () {
    
            it.only("moves the price back the price where it was when an amount is bought and sold", async function () {
                const { tokenSale, token1363, user0, user1 } = await loadFixture(deployTokenSaleContract_ERC1363);
                const precision = (await tokenSale.pricePrecision()).toNumber()
    
                const buyAmount = 1
    
                console.log(">> price before 1st sale: ", (await tokenSale.price()).toNumber() / precision )
    
                // first buy
                const [ price0, payAmount0 ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount) )
                await token1363.connect(user0)["transferAndCall(address,uint256)"](tokenSale.address, payAmount0)

                // second buy
                const priceBeforeSecondBuy = (await tokenSale.price()).toNumber() / precision
                const [ price1, payAmount1 ] = await tokenSale.quoteBuyPriceAmount( toWei(buyAmount) )
    
                const balanceBefore = await tokenSale.balanceOf(user0.address)
                await token1363.connect(user0)["transferAndCall(address,uint256)"](tokenSale.address, payAmount1)
                const balanceAfter = await tokenSale.balanceOf(user0.address)

                const boughtAmount = balanceAfter.sub(balanceBefore)
                expect (toUnits(boughtAmount) ).to.be.equal(buyAmount)

                // sell tokens bought in the second buy
                await tokenSale.connect(user0).sell( boughtAmount )
                console.log(">> price after 1 sell: ", (await tokenSale.price()).toNumber() / precision )

                const priceAfterSell = (await tokenSale.price()).toNumber() / precision

                // verify that the price moved back to where it was before the second buy
                expect (priceAfterSell).to.be.equal(priceBeforeSecondBuy)

            });
    
        })
    })





});