import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with account:", deployer.address);

  const AssetToken = await ethers.getContractFactory("AssetToken");
  const RWATokenization = await ethers.getContractFactory("RWATokenization");

  // Deploy AssetToken
  const assetToken = await AssetToken.deploy(
    deployer.address, // Initial owner
    deployer.address, // Mint to this account
    1,                // Token ID
    1000,             // Total tokens
    "0x",             // Data
    "https://example.com", // URI
    deployer.address  // RWATokenization reference
  );
  await assetToken.deployed();
  console.log("AssetToken deployed to:", assetToken.address);

  // Deploy RWATokenization
  const rwaTokenization = await RWATokenization.deploy(deployer.address);
  await rwaTokenization.deployed();
  console.log("RWATokenization deployed to:", rwaTokenization.address);
}

main().catch((error) => {
  console.error("Error deploying contracts:", error);
  process.exitCode = 1;
});
