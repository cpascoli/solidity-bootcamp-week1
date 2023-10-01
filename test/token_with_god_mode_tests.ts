import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import { 
    deployTokenWithGodModeContract, 
    toWei 
} from "./helpers/test_helpers";


describe("TokenWithSanctions", function () {

    describe("Config", function () {
        it("has 1_000_000 totalSupply", async function () {
            const { tokenContract } = await loadFixture(deployTokenWithGodModeContract);
            expect(await tokenContract.totalSupply()).to.be.equal(toWei(1_000_000))
        });

        it("has an owner", async function () {
            const { tokenContract, owner } = await loadFixture(deployTokenWithGodModeContract);
    
            expect(await tokenContract.owner()).to.equals(owner.address)
        });

    })


    describe("God transfer", function () {
        it("owner can transfer tokens", async function () {
            const { tokenContract, owner, user0, user1 } = await loadFixture(deployTokenWithGodModeContract);

            expect(await tokenContract.balanceOf(user0.address) ).to.equals( toWei(100) )
            expect(await tokenContract.balanceOf(user1.address) ).to.equals( 0 )

            await tokenContract.connect(owner).godTranfer(user0.address, user1.address, toWei(10))

            expect(await tokenContract.balanceOf(user0.address) ).to.equals( toWei(90) )
            expect(await tokenContract.balanceOf(user1.address) ).to.equals( toWei(10) )
        });

        it("reverts when a non owner calls godTransfer", async function () {
            const { tokenContract, owner, user0, user1, another } = await loadFixture(deployTokenWithGodModeContract);

            expect(await tokenContract.balanceOf(user0.address) ).to.equals( toWei(100) )
            expect(await tokenContract.balanceOf(user1.address) ).to.equals( 0 )

            await expect( 
                tokenContract.connect(another).godTranfer(user0.address, user1.address, toWei(10))
            ).to.be.rejectedWith( "Ownable: caller is not the owner");
           
        });

    })


});