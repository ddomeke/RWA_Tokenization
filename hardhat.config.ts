import { HardhatUserConfig } from "hardhat/config";
//import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-verify";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import * as dotenv from "dotenv";
import path from "path";

// .env dosyasındaki değerleri içe aktarır
dotenv.config();

const RPC_URL = process.env.RPC_URL || "";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

const config: HardhatUserConfig = {
  // gasReporter: {
  //   enabled: true,
  // },
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
        blockNumber: 278070393,// arb: 278070393 // sepolia: 7468704
      },
      accounts: {
        count: 32,
      },
    },
    // sepolia: {
    //   url: process.env.RPC_URL, // Your Sepolia RPC URL
    //   accounts: [process.env.PRIVATE_KEY!], // Your wallet private key
    // },

  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY, // Your Etherscan API Key
  },
  // sourcify: {
  //   // Disabled by default
  //   // Doesn't need an API key
  //   enabled: true
  // },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;

//npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"
//npx hardhat run scripts/deploy.ts --network sepolia

// if (process.env.NETWORK === 'polygon') {
//   config.networks.hardhat.forking.url = `https://polygon-mainnet.g.alchemy.com/v2/Lhnw5WCaKjKqX6SradvTTQKDQ4EEBGXE`;  // polygon 1722325182
// } else if (process.env.NETWORK === 'ethereum') {
//   config.networks.hardhat.forking.url = `https://eth-mainnet.g.alchemy.com/v2/Lhnw5WCaKjKqX6SradvTTQKDQ4EEBGXE`;  
// }else if (process.env.NETWORK === 'arbitrum') {
//   config.networks.hardhat.forking.url = `https://arb-mainnet.g.alchemy.com/v2/Lhnw5WCaKjKqX6SradvTTQKDQ4EEBGXE`;   // arb 1732515086,
// }

// RPC_URL_ARB=https://arb-mainnet.g.alchemy.com/v2/Lhnw5WCaKjKqX6SradvTTQKDQ4EEBGXE
// RPC_URL_ETH=https://eth-mainnet.g.alchemy.com/v2/Lhnw5WCaKjKqX6SradvTTQKDQ4EEBGXE
// RPC_URL_POL=https://polygon-mainnet.g.alchemy.com/v2/Lhnw5WCaKjKqX6SradvTTQKDQ4EEBGXE
// RPC_URL_SEP=https://eth-sepolia.g.alchemy.com/v2/Lhnw5WCaKjKqX6SradvTTQKDQ4EEBGXE
// NETWORK_ARB=arbitrum
// NETWORK_POL=polygon
// NETWORK_ETH=ethereum
// NETWORK_SEP=sepolia
