import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

import { deployTokenWithSanctionsContract, toUnits, toWei } from "./helpers/test_helpers";

describe("TokenWithSanctions", function () {

    describe("Config", function () {
        it("has 1_000_000 totalSupply", async function () {
            const { tokenContract } = await loadFixture(deployTokenWithSanctionsContract);
            expect(await tokenContract.totalSupply()).to.be.equal(toWei(1_000_000))
        });

        it("has an owner", async function () {
            const { tokenContract, owner } = await loadFixture(deployTokenWithSanctionsContract);
    
            expect(await tokenContract.owner()).to.equals(owner.address)
        });

        it("allocates 100 tokens to user0", async function () {
            const { tokenContract, user0 } = await loadFixture(deployTokenWithSanctionsContract);
    
             expect( await tokenContract.balanceOf(user0.address) ).to.be.equal( toWei(100) )
        });
    })


    describe("Ban", function () {
        it("bans an address", async function () {
            const { tokenContract, owner, user0 } = await loadFixture(deployTokenWithSanctionsContract);

            // ban user0
            await tokenContract.connect(owner).ban(user0.address)

            // verify that user0 is banned
            expect(await tokenContract.isBanned(user0.address)).to.be.true
        });

        it("reverts when banned addresses send tokens", async function () {
            const { tokenContract, owner, user0, user1 } = await loadFixture(deployTokenWithSanctionsContract);
            
            // user0 has 100 tokens
            expect( await tokenContract.balanceOf(user0.address) ).to.be.equal( toWei(100) )

            // ban user0
            await tokenContract.connect(owner).ban(user0.address)

            // verify that token transfer from user0 should revert with the BannedAddress error
            await expect( 
                tokenContract.connect(user0).transfer(user1.address, toWei(10)) 
            ).to.be.revertedWithCustomError(tokenContract, "BannedAddress");
        });

        it("reverts when banned addresses receive tokens", async function () {
            const { tokenContract, owner, user0, user1 } = await loadFixture(deployTokenWithSanctionsContract);
            expect( await tokenContract.balanceOf(user0.address) ).to.be.equal( toWei(100) )

            // ban user1
            await tokenContract.connect(owner).ban(user1.address)

            // verify that token transfer to user1 should revert with the BannedAddress error
            await expect( 
                tokenContract.connect(user0).transfer(user1.address, toWei(10)) 
            ).to.be.revertedWithCustomError(tokenContract, "BannedAddress");
        });
    })


});