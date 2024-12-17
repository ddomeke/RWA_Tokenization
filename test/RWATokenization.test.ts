import { expect } from "chai";
import { ethers } from "hardhat";

describe("RWATokenization", function () {
  it("Should deploy successfully", async function () {
    const [owner] = await ethers.getSigners();

    const RWATokenization = await ethers.getContractFactory("RWATokenization");
    const rwa = await RWATokenization.deploy(owner.address);
    await rwa.deployed();

    expect(await rwa.admin()).to.equal(owner.address);
  });
});
