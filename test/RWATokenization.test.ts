import { expect } from "chai";
const { ethers } = require("hardhat");
import hre from "hardhat";
import { IERC20, RWATokenization__factory } from "../typechain-types";
import { log } from './logger';

import {
App,
  AssetToken,
  Fexse,
  RWATokenization,
  Compliance,
  MarketPlace,
  SwapEthToUsdt,
  RWA_DAO,
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

  let app: App;
  let rwaTokenization: RWATokenization;
  let _rwaTokenization: RWATokenization;
  let compliance: Compliance;
  let _compliance: Compliance;
  let rwa_DAO: RWA_DAO;
  let _rwa_DAO: RWA_DAO;
  let marketPlace: MarketPlace;
  let _marketPlace: MarketPlace;
  let assetToken: AssetToken;
  let assetToken_sample: AssetToken;  
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

    //--------------------- 1. App.sol deploy  -------------------------------------------------------------
    app = await hre.ethers.deployContract("App");
    const appAddress = await app.getAddress();
    await log('INFO', `1  - app Address-> ${appAddress}`);
    await gasPriceCalc(app.deploymentTransaction());

    //--------------------- 2. MarketPlace.sol deploy --------------------------------------------------------
    _marketPlace = await hre.ethers.deployContract("MarketPlace", [appAddress]);
    const _marketPlaceAddress = await _marketPlace.getAddress();
    await log('INFO', `2  - market Place Address-> ${_marketPlaceAddress}`);
    gasPriceCalc(_marketPlace.deploymentTransaction());

    await app.installModule(_marketPlaceAddress);
    marketPlace = await hre.ethers.getContractAt("MarketPlace", appAddress) as MarketPlace;

    //--------------------- 3. RWATokenization.sol deploy --------------------------------------------------------
    _rwaTokenization = await hre.ethers.deployContract("RWATokenization",[appAddress]);
    const _rwaTokenizationAddress = await _rwaTokenization.getAddress();
    await log('INFO', `3  - _mrwaTokenization Address-> ${_rwaTokenizationAddress}`);
    gasPriceCalc(_rwaTokenization.deploymentTransaction());

    await app.installModule(_rwaTokenizationAddress);
    rwaTokenization = await hre.ethers.getContractAt("RWATokenization", appAddress) as RWATokenization;


    //--------------------- 4. Compliance.sol deploy --------------------------------------------------------
    _compliance = await hre.ethers.deployContract("Compliance", [appAddress]);
    const _complianceAddress = await _compliance.getAddress();
    await log('INFO', `4  - _compliance Address-> ${_complianceAddress}`);
    gasPriceCalc(_compliance.deploymentTransaction());

    await app.installModule(_complianceAddress);
    compliance = await hre.ethers.getContractAt("Compliance", appAddress) as Compliance;


    //--------------------- 5. createAsset.sol deploy  ---------------------------------------------
    const createTx = await rwaTokenization.createAsset(ASSET_ID,TOTALTOKENS,TOKENPRICE,ASSETURI);
    await createTx.wait();

    const assetTokenAddress = await rwaTokenization.getTokenContractAddress(ASSET_ID);    
    assetToken = await hre.ethers.getContractAt("AssetToken", assetTokenAddress) as AssetToken;    
    await log('INFO', `5  - assetToken Address -> ${assetTokenAddress}`);

    //--------------------- 6. Fexse.sol deploy  ---------------------------------------------
    fexse = await hre.ethers.deployContract("Fexse",[appAddress]);
    const fexseAddress = await fexse.getAddress();
    await log('INFO', `6  - fexse Address-> ${fexseAddress}`);
    await gasPriceCalc(fexse.deploymentTransaction()); 

    await marketPlace.setFexseAddress(fexseAddress);

    //--------------------- 7. RWA_DAO.sol deploy --------------------------------------------------------
    _rwa_DAO = await hre.ethers.deployContract("RWA_DAO", [appAddress]);
    const _rwa_DAOAddress = await _rwa_DAO.getAddress();
    await log('INFO', `7  - _rwa_DAO Address-> ${_rwa_DAOAddress}`);
    gasPriceCalc(_rwa_DAO.deploymentTransaction());

    await app.installModule(_rwa_DAOAddress);
    rwa_DAO = await hre.ethers.getContractAt("RWA_DAO", appAddress) as RWA_DAO;

    //--------------------- 8. SwapEthToUsdt.sol deploy  ---------------------------------------------
    // swapEthToUsdt = await hre.ethers.deployContract("SwapEthToUsdt",[UNISWAP_V3_ROUTER]);
    // const swapEthToUsdtAddress = await swapEthToUsdt.getAddress();
    // await log('INFO', `8  - swapEthToUsdt Address-> ${swapEthToUsdtAddress}`);
    // //await gasPriceCalc(swapEthToUsdt.deploymentTransaction()); 

    // const tx = await swapEthToUsdt.swapEthForUsdt(
    //     ethers.parseUnits("500", 6), // Minimum 50 USDT alınmalı
    //     Math.floor(Date.now() / 1000) + 60 * 10, // 10 dakika içinde tamamlanmalı
    //     { value: ethers.parseEther("1000"),gasLimit: 500000, } // 1 ETH gönder
    // );
    // await tx.wait();
    
    //--------------------- 8. USDT ERC20   ---------------------------------------------
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

    let idx = 1;

    log('INFO', ``);
    log('INFO', "----------------------------TRANSFER ASSETS------------------------------------------");
    log('INFO', ``);

    await getProject_All_Balances(impersonatedSigner, 0);
    await getProject_All_Balances(addresses[0], 0);

    for (const addr of addresses) {

      await usdtContract.connect(impersonatedSigner).transfer(addr.address, amountUSDC); // Transfer USDC
      await fexse.connect(addresses[0]).transfer(addr.address, amountFexse); // Transfer fexse
      await fexse.connect(addresses[0]).transfer(impersonatedSigner, amountFexse); // Transfer fexse
      await usdtContract.connect(addr).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
      await fexse.connect(addr).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);

      log('INFO', `Approval successful for fexse and USDt ${addr.address}`);
      idx++;
    }        
    
    await fexse.connect(addresses[0]).transfer(impersonatedSigner, amountFexse); 

    await assetToken.connect(addresses[0]).setApprovalForAll(_rwaTokenizationAddress, true); 

    await usdtContract.connect(addresses[0]).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
    await usdtContract.connect(impersonatedSigner).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
    await fexse.connect(addresses[0]).approve(appAddress, hre.ethers.MaxUint256);
    await fexse.connect(impersonatedSigner).approve(appAddress, hre.ethers.MaxUint256);
    await assetToken.connect(addresses[0]).setApprovalForAll(addresses[0],true);
    await assetToken.connect(addresses[0]).setApprovalForAll(appAddress,true);
    await assetToken.connect(impersonatedSigner).setApprovalForAll(appAddress,true);

    await getProject_All_Balances(impersonatedSigner, 0);
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

  async function logAssetDetails(  assetId: string, holderAddress: string) {

        const TotalTokens = await rwaTokenization.getTotalTokens(assetId);
        const TokenPrice = await rwaTokenization.getTokenPrice(assetId);
        const TotalProfit = await rwaTokenization.getTotalProfit(assetId);
        const LastDistributed = await rwaTokenization.getLastDistributed(assetId);
        const Uri = await rwaTokenization.getUri(assetId);
        const TokenContractAddress = await rwaTokenization.getTokenContractAddress(assetId);
        const TokenHolders = await rwaTokenization.getTokenHolders(assetId);
        const HolderBalance = await rwaTokenization.getHolderBalance(assetId, holderAddress);
        const PendingProfits = await rwaTokenization.getPendingProfits(assetId, holderAddress);
    
        log("INFO", `TotalTokens                        : ${TotalTokens}`);
        log("INFO", `TokenPrice                         : ${TokenPrice}`);
        log("INFO", `TotalProfit                        : ${TotalProfit}`);
        log("INFO", `LastDistributed                    : ${LastDistributed}`);
        log("INFO", `Uri                                : ${Uri}`);
        log("INFO", `TokenContractAddress               : ${TokenContractAddress}`);
        log("INFO", `TokenHolders                       : ${TokenHolders.join(", ")}`);
        log("INFO", `HolderBalance                      : ${HolderBalance}`);
        log("INFO", `PendingProfits                     : ${PendingProfits}`);
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
    -------------------createAsset-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  1  -------------->Should createAsset", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------createAsset-----------------------------------------------------");
        log('INFO', ``);

        const ASSETID_V2 = ASSET_ID+5;

        const createTx1 = await rwaTokenization.createAsset(ASSETID_V2,TOTALTOKENS,TOKENPRICE,ASSETURI);
        await createTx1.wait();   
    
        await logAssetDetails(ASSETID_V2,addresses[0])

        const TokenContractAddress = await rwaTokenization.getTokenContractAddress(ASSETID_V2);
        assetToken_sample = await hre.ethers.getContractAt("AssetToken", TokenContractAddress) as AssetToken;
        
    });

    /*-----------------------------------------------------------------------------------------------
    -------------------TranserAsset-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  2  -------------->Should TranserAsset", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------TranserAsset-----------------------------------------------------");
        log('INFO', ``);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [My_ADDRESS],
        });
        const buyer = await hre.ethers.getSigner(My_ADDRESS);
        
        //const TranserAssetAddress = await marketPlace.getAddress();

        const amountFexselock = ethers.parseEther("10000");

        await getProject_All_Balances(buyer, 0);
        await getProject_All_Balances(addresses[0], 0);

        // const buyerUsdtallowance = await usdtContract.connect(buyer).allowance(buyer, TranserAssetAddress);
        // log('INFO', `buyerUsdtallowance : ${buyerUsdtallowance} `);

        await assetToken.connect(addresses[0]).safeTransferFrom(
            addresses[0],
            buyer,
            ASSET_ID,
            3,
            "0x");

        log('INFO', ``);
        log('INFO', "-------------------token send-----------------------");
        log('INFO', ``);


        await getProject_All_Balances(buyer, 0);
        await getProject_All_Balances(addresses[0], 0);


        await marketPlace.connect(addresses[0]).lockTokensToBeSold(buyer, ASSET_ID, 3, 1000000);

        await marketPlace.connect(addresses[0]).lockFexseToBeBought(addresses[0], amountFexselock);
            

        await marketPlace.connect(addresses[0]).transferAsset( 
            buyer,
            addresses[0],
            ASSET_ID,
            3,
            1000000);


        log('INFO', ``);
        log('INFO', "-------------------aseet transfer -----------------------");
        log('INFO', ``);


        await getProject_All_Balances(buyer, 0);        
        await getProject_All_Balances(addresses[0], 0);

        for (const addr of addresses) {

            if(addr!=addresses[0]){

                // await getProject_All_Balances(addr, 0);
                // await getProject_All_Balances(addresses[0], 0);

                // await rwaTokenization.connect(addr).buyTokens(ASSET_ID, 15,rwaTokenizationAddress);               

                // await getProject_All_Balances(addr, 0);        
                // await getProject_All_Balances(addresses[0], 0);
            }
        }   

        await logAssetDetails(ASSET_ID,addresses[0]);
       
    });

    /*-----------------------------------------------------------------------------------------------
    -------------------getTokenContract-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  3  -------------->Should getTokenContract", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------getTokenContract-----------------------------------------------------");
        log('INFO', ``);

        const TokenContract = await rwaTokenization.getTokenContractAddress(ASSET_ID);
        log('INFO', `TokenContract : ${TokenContract} `);

        const assetTokennAddress = await assetToken.getAddress();

        expect(TokenContract).to.equal(assetTokennAddress);
       
    });

    /*-----------------------------------------------------------------------------------------------
    -------------------distributeProfit-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  4  -------------->Should distributeProfit", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------distributeProfit-----------------------------------------------------");
        log('INFO', ``);     

        await rwaTokenization.connect(addresses[0]).distributeProfit(ASSET_ID, 70000000000);

        for (const addr of addresses) {
            await getProject_All_Balances(addr, 0);

            const pendingProfit = await rwaTokenization.getPendingProfits(ASSET_ID, addr);
            log('INFO', `pendingProfit for addr: ${addr.address} amount: ${pendingProfit}  `);
        }
        
        await logAssetDetails(ASSET_ID,addresses[0]);
    });


    /*-----------------------------------------------------------------------------------------------
    -------------------claimProfit-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    // it("  5  -------------->Should claimProfit", async function () {

    //     log('INFO', ``);
    //     log('INFO', "-----------------------------------------------claimProfit-----------------------------------------------------");
    //     log('INFO', ``);

    //     await hre.network.provider.request({
    //         method: "hardhat_impersonateAccount",
    //         params: [My_ADDRESS],
    //     });
    //     const buyer = await hre.ethers.getSigner(My_ADDRESS);

    //     // rwaTokenization.connect(buyer).claimProfit(ASSET_ID);
    //     // await getProject_All_Balances(buyer, 0);

    //     for (const addr of addresses) {
    //         await rwaTokenization.connect(addr).claimProfit(ASSET_ID);
    //         await getProject_All_Balances(addr, 0);
    //     }          
    // });   

    /*-----------------------------------------------------------------------------------------------
    -------------------updateAsset-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  6  -------------->Should updateAsset", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------updateAsset-----------------------------------------------------");
        log('INFO', ``);
         
        const TokenPrice                = await rwaTokenization.getTokenPrice(ASSET_ID);   
        log('INFO', `TokenPrice : ${TokenPrice}`); 
        
        await expect(rwaTokenization.connect(addresses[0]).updateAsset(ASSET_ID, 1111))
        .to.emit(rwaTokenization, "AssetUpdated")
        .withArgs(ASSET_ID,1111);   

        const NewTokenPrice             = await rwaTokenization.getTokenPrice(ASSET_ID);   
        log('INFO', `NewTokenPrice : ${NewTokenPrice}`);
        
    }); 

});
