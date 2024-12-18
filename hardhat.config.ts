import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import * as dotenv from "dotenv";
import path from "path";

// .env dosyasındaki değerleri içe aktarır
dotenv.config();

const RPC_URL = process.env.RPC_URL || "";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "";

const config: HardhatUserConfig = {
  gasReporter: {
    enabled: true,
  },
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "shanghai",  // Specify the EVM version for Cancun
    },
  },
  // typechain: {
  //   outDir: "typechain", // Oluşturulacak tür dosyalarının klasörü
  //   target: "ethers-v5", // Ethers.js için türleri oluştur
  // },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: RPC_URL || "",        
        blockNumber: 278070393,
      },
      accounts: {
        count: 32,
      },
    },

  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
