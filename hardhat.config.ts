import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";
import path from "path";

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
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: process.env.RPC_URL || "",        
        blockNumber: 278070393,
      },
      accounts: {
        count: 32,
      },
    },

  },
  paths: {
    sources: path.resolve(__dirname, "./contracts"), // Contracts klasörü
    artifacts: path.resolve(__dirname, "./artifacts"), // Derlenmiş dosyalar
    tests: path.resolve(__dirname, "./test"), // Derlenmiş dosyalar
  },
};

export default config;
