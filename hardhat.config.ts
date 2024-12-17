import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";
import path from "path";

const RPC_URL = process.env.RPC_URL || "";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    arbitrum: {
      url: RPC_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  paths: {
    sources: path.resolve(__dirname, "./contracts"), // Contracts klasörü
    artifacts: path.resolve(__dirname, "./artifacts"), // Derlenmiş dosyalar
    tests: path.resolve(__dirname, "./test"), // Derlenmiş dosyalar
  },
};

export default config;
