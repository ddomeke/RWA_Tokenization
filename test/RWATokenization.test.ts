import { expect } from "chai";
const { ethers } = require("hardhat");
import hre from "hardhat";
import { IERC20, RWATokenization__factory } from "../typechain-types";
import { log } from './logger';

import {
  AssetToken,
  Fexse,
  RWATokenization,
  SwapEthToUsdt,
} from "../typechain-types";

//const params = require('./parameters.json');
const params = require(`${__dirname}/test_parameters.json`);


// ERC20 ABI - Minimum required to interact with the approve function
const ERC20_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)",
  "function transfer(address recipient, uint256 amount) external returns (bool)"
];


describe("RWATokenization Test", function () {

  this.timeout(200000);

  let rwaTokenization: RWATokenization;
  let assetToken: AssetToken;
  let fexse: Fexse;
  let swapEthToUsdt: SwapEthToUsdt;  
  let usdtContract: any;

  const ADDR_COUNT = params.ADDR_COUNT;
  const ASSET_ID = params.ASSET_ID;
  const TOTALTOKENS = params.TOTALTOKENS;
  const TOKENPRICE = params.TOKENPRICE;
  const ASSETURI = params.ASSETURI;
  
  
  const My_ADDRESS = params.My_ADDRESS;
  const My_ADDRESS2 = params.My_ADDRESS2;
  const FEXSE_ADDRESS = params.FEXSE_ADDRESS;
  const ZERO_ADDRESS = params.ZERO_ADDRESS;
  const TEST_CHAIN = params.TEST_CHAIN;

  const PRIVATE_KEY = process.env.PRIVATE_KEY!;
  const RPC_URL = process.env.RPC_URL!;
  const NETWORK = process.env.NETWORK;

  if (!PRIVATE_KEY || !RPC_URL || !NETWORK) {
      throw new Error("Please set PRIVATE_KEY, RPC_URL, and NETWORK in your .env file.");
  }

  // Connect to provider using private key
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  let addresses: any[] = [];

  // Populate addresses dynamically
  for (let i = 1; i <= ADDR_COUNT; i++) {
      addresses.push(`addr${i}`);
  }
  
  let USDT_ADDRESS: string;
  let UNISWAP_V3_ROUTER: string;
  
  USDT_ADDRESS = '';
  UNISWAP_V3_ROUTER = '';

  if (TEST_CHAIN === 'polygon') {
    USDT_ADDRESS = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
  } else if (TEST_CHAIN === 'ethereum') {
      USDT_ADDRESS = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
  } else if (TEST_CHAIN === 'arbitrum') {
      USDT_ADDRESS = '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9';
      UNISWAP_V3_ROUTER = '0xe592427a0aece92de3edee1f18e0157c05861564';
      
  }

  before(async function () {

    // Then get the signers and assign each one to the corresponding variable
    log('INFO', 'Starting deployment process...');
    const signers = await hre.ethers.getSigners();
    addresses = signers.slice(0, ADDR_COUNT);

    log('INFO', ``);
    const balance = await ethers.provider.getBalance(addresses[0]);
    log('INFO', `Owner Balance: -----> ${ethers.formatEther(balance)} ETH`);
    log('INFO', ``);

    log('INFO', "--------------------------------DEPLOY--------------------------------");


    //--------------------- 1. RWATokenization.sol deploy  ---------------------------------------------
    rwaTokenization = await hre.ethers.deployContract("RWATokenization",[addresses[0]]);
    const rwaTokenizationAddress = await rwaTokenization.getAddress();
    await log('INFO', `1  - rwaTokenization Address-> ${rwaTokenizationAddress}`);
    //await gasPriceCalc(rwaTokenization.deploymentTransaction());  

    //await waitSec(3);

    //--------------------- 2. createAsset.sol deploy  ---------------------------------------------
    const createTx = await rwaTokenization.createAsset(ASSET_ID,TOTALTOKENS,TOKENPRICE,ASSETURI);
    await createTx.wait();

    const assetTokenAddress = await rwaTokenization.getTokenContract(ASSET_ID);    
    assetToken = await hre.ethers.getContractAt("AssetToken", assetTokenAddress) as AssetToken;    
    await log('INFO', `2  - assetToken Address -> ${assetTokenAddress}`);

    //--------------------- 3. Fexse.sol deploy  ---------------------------------------------
    fexse = await hre.ethers.deployContract("Fexse",[addresses[0]]);
    const fexseAddress = await fexse.getAddress();
    await log('INFO', `3  - fexse Address-> ${fexseAddress}`);
    //await gasPriceCalc(fexse.deploymentTransaction()); 

    await rwaTokenization.setFexseAddress(fexseAddress);

    //--------------------- 4. SwapEthToUsdt.sol deploy  ---------------------------------------------
    // swapEthToUsdt = await hre.ethers.deployContract("SwapEthToUsdt",[UNISWAP_V3_ROUTER]);
    // const swapEthToUsdtAddress = await swapEthToUsdt.getAddress();
    // await log('INFO', `4  - swapEthToUsdt Address-> ${swapEthToUsdtAddress}`);
    // //await gasPriceCalc(swapEthToUsdt.deploymentTransaction()); 

    // const tx = await swapEthToUsdt.swapEthForUsdt(
    //     ethers.parseUnits("500", 6), // Minimum 50 USDT alınmalı
    //     Math.floor(Date.now() / 1000) + 60 * 10, // 10 dakika içinde tamamlanmalı
    //     { value: ethers.parseEther("1000"),gasLimit: 500000, } // 1 ETH gönder
    // );
    // await tx.wait();
    
    //--------------------- 5. USDT ERC20   ---------------------------------------------
    usdtContract = (await hre.ethers.getContractAt(ERC20_ABI, USDT_ADDRESS)) as unknown as IERC20;

    log('INFO', "---------------------------TRANSFER - APPROVE----------------------------------------");
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [My_ADDRESS],
    });

    const impersonatedSigner = await hre.ethers.getSigner(My_ADDRESS);

    const amountUSDC = 1500000000; // Amount to transfer (in USDC smallest unit, i.e., without decimals)
    const amountETH = ethers.parseEther("0.0001");
    const amountFexse = ethers.parseEther("1000");

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [My_ADDRESS2],
    });
    const buyer = await hre.ethers.getSigner(My_ADDRESS2);

    let idx = 1;

    log('INFO', ``);
    log('INFO', "----------------------------TRANSFER ASSETS------------------------------------------");
    log('INFO', ``);

    await getProject_All_Balances(impersonatedSigner, 0);
    await getProject_All_Balances(buyer, 0);
    await getProject_All_Balances(addresses[0], 0);

    for (const addr of addresses) {

      await usdtContract.connect(impersonatedSigner).transfer(addr.address, amountUSDC); // Transfer USDC
      await fexse.connect(addresses[0]).transfer(addr.address, amountFexse); // Transfer fexse
      await usdtContract.connect(addr).approve(rwaTokenizationAddress, hre.ethers.MaxUint256);
      await fexse.connect(addr).approve(rwaTokenizationAddress, hre.ethers.MaxUint256);

      log('INFO', `Approval successful for fexse and USDt ${addr.address}`);
      idx++;
    }    

    
    
    await fexse.connect(addresses[0]).transfer(buyer, amountFexse); // Transfer fexse
    await fexse.connect(addresses[0]).transfer(impersonatedSigner, amountFexse); // Transfer fexse

    await assetToken.connect(addresses[0]).setApprovalForAll(rwaTokenizationAddress, true); // Transfer fexse

    await usdtContract.connect(addresses[0]).approve(rwaTokenizationAddress, hre.ethers.MaxUint256);
    await usdtContract.connect(impersonatedSigner).approve(rwaTokenizationAddress, hre.ethers.MaxUint256);
    await fexse.connect(addresses[0]).approve(rwaTokenizationAddress, hre.ethers.MaxUint256);
    await fexse.connect(impersonatedSigner).approve(rwaTokenizationAddress, hre.ethers.MaxUint256);

    await getProject_All_Balances(impersonatedSigner, 0);
    await getProject_All_Balances(buyer, 0);
    await getProject_All_Balances(addresses[0], 0);

  });

      /*-----------------------------------------------------------------------------------------------
    ------------------------------------------COMMON FUNCTIONS     -----------------------------------
    -----------------------------------------------------------------------------------------------*/

    /**
     * Calculates and logs the gas price, gas used, and ETH cost for a given deployment transaction.
     *
     * @param deploymentTx - The deployment transaction object to calculate gas costs for.
     *
     * This function waits for the transaction receipt, retrieves the gas used and gas price, 
     * calculates the total cost in ETH, and logs the details with different log levels for 
     * information and error scenarios.
     */
    async function gasPriceCalc(deploymentTx: any) {
      // Check if the deployment transaction is provided
      if (deploymentTx) {
          const receipt = await deploymentTx.wait();

          // Check if the receipt is successfully obtained
          if (receipt) {
              const gasUsed = receipt.gasUsed;
              const gasPrice = deploymentTx.gasPrice!;
              const ethCost = gasUsed * gasPrice;

              // Log gas price, gas used, and the total ETH cost
              log('INFO', ` ${gasPrice.toString()} Price -> ${gasUsed.toString()} Used -> ${ethers.formatEther(ethCost)} ETH`);
          } else {
              // Log error if the transaction receipt is null
              log('ERROR', `Transaction receipt for is null.`);
          }
      } else {
          // Log error if the deployment transaction is null
          log('ERROR', `Deployment transaction for is null.`);
      }
  }

  /**
   * Sends ETH from the specified wallet to a receiver address.
   *
   * @param wallet - The wallet object initiating the transaction.
   * @param receiverAddress - The address of the receiver.
   * @param amountInWei - The amount of ETH to send, in Wei.
   *
   * This function creates a transaction object with the recipient address and specified amount,
   * then attempts to send the transaction from the given wallet. If the transaction is successful,
   * it logs a confirmation. In case of an error, it catches and logs the error message.
   */
  async function sendEth(wallet: any, receiverAddress: any, amountInWei: any) {
      const tx = {
          to: receiverAddress,
          value: amountInWei
      };

      try {
          // Attempt to send the transaction
          const transaction = await wallet.sendTransaction(tx);
          // Log success confirmation once transaction is sent
          log('INFO', "Transaction confirmed:"/*, receipt*/);
      } catch (error) {
          // Log error if the transaction fails
          log('ERROR', `Transaction failed: ${error}`);
      }
  }


  /**
   * Retrieves and logs all balance information for a given signer and project ID.
   *
   * @param signer - The wallet or signer object from which balances will be fetched.
   * @param projectId - The ID of the project for which to retrieve balance information.
   *
   * This function retrieves the balance of multiple assets (WETH, WBTC, USDC, USDT, PAXG) both from 
   * the corresponding hubs and directly from the signer's wallet. It then formats and logs this 
   * information along with the ETH and PECTO balances of the signer and the project's health factors.
   */
  async function getProject_All_Balances(signer: any, projectId: any) {

      const usdt_balance = await usdtContract.connect(signer).balanceOf(signer.address);
      const asset_balance = await assetToken.connect(signer).balanceOf(signer.address,ASSET_ID);
      const fexse_balance = await fexse.connect(signer).balanceOf(signer.address);

      // Create a function to align and log each line consistently
      const formatLog = (label1: string, value1: any) => {
          log('INFO', `${label1.padEnd(20)} ${value1.toString().padStart(20)}`);
      };

      log('INFO', ``);
      log('INFO', "--------------------------all asset for this address-----------------------------");
      log('INFO', ``);
      log('INFO', `Signer: ${signer.address}  `);
      log('INFO', ``);
      formatLog("usdt_balance:  ", usdt_balance);
      formatLog("asset_balance:  ", asset_balance);
      formatLog("fexse_balance: ", fexse_balance);
      log('INFO', ``);
      const balance = await ethers.provider.getBalance(signer.address);
      log('INFO', `ETH Balance:   -----> ${ethers.formatEther(balance)} ETH`);
      log('INFO', ``);
      log('INFO', "-----------------------------------------------------------------------------------------");
      log('INFO', ``);
  }

  /**
   * Pauses execution for a specified number of seconds.
   *
   * @param time - The number of seconds to wait before resuming execution.
   *
   * This function uses a delay function to pause execution for the specified number of seconds.
   * A log message is generated before the delay to indicate the wait time.
   */
  async function waitSec(time: any) {

      // Wait until the start time
      function delay(ms: number) {
          return new Promise(resolve => setTimeout(resolve, ms));
      }

      log('INFO', `Waiting for ${time} seconds...`);
      await delay(time * 1000); // Wait for specified seconds
  }

    /*-----------------------------------------------------------------------------------------------
    -------------------buyTokens-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  1  -------------->Should buyTokens", async function () {

        log('INFO', ``);
        log('INFO', "-------------------------buyTokens-------------------------------");
        log('INFO', ``);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [My_ADDRESS],
        });
        const buyer = await hre.ethers.getSigner(My_ADDRESS);

        await getProject_All_Balances(buyer, 0);

        const rwaTokenizationAddress = await rwaTokenization.getAddress();
        const buyerUsdtallowance = await usdtContract.connect(buyer).allowance(buyer, rwaTokenizationAddress);
        log('INFO', `buyerUsdtallowance : ${buyerUsdtallowance} ...`);

        await expect(rwaTokenization.connect(buyer).buyTokens(ASSET_ID, 15))
            .to.emit(rwaTokenization, "TokensPurchased")
            .withArgs(buyer, ASSET_ID,15,15000);

       
    });

});
