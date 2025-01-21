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
    ProfitModule,
    Compliance,
    MarketPlace,
    RWA_DAO,
    SwapModule,
    FexsePriceFetcher,
    SalesModule,
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
    let profitModule: ProfitModule;
    let _profitModule: ProfitModule;
    let compliance: Compliance;
    let _compliance: Compliance;
    let rwa_DAO: RWA_DAO;
    let _rwa_DAO: RWA_DAO;
    let swapModule: SwapModule;
    let _swapModule: SwapModule;
    let fexsePriceFetcher: FexsePriceFetcher;
    let _fexsePriceFetcher: FexsePriceFetcher;
    let marketPlace: MarketPlace;
    let _marketPlace: MarketPlace;
    let assetToken: AssetToken;
    let assetToken_sample: AssetToken;
    let assetToken_sample1: AssetToken;
    let salesModule: SalesModule;
    let _salesModule: SalesModule;
    let fexse: Fexse;
    let usdtContract: any;
    let wethContract: any;
    let assetToken1: any;

    const ADDR_COUNT = params.ADDR_COUNT;
    const ASSET_ID = params.ASSET_ID;
    const TOTALTOKENS = params.TOTALTOKENS;
    const TOKENPRICE = params.TOKENPRICE;
    const TOKENLOWERLIMIT = params.TOKENLOWERLIMIT;
    const ASSETURI = params.ASSETURI;


    const My_ADDRESS = params.My_ADDRESS;
    const My_ADDRESS2 = params.My_ADDRESS2;
    const FEXSE_ADDRESS = params.FEXSE_ADDRESS;
    const ZERO_ADDRESS = params.ZERO_ADDRESS;
    const TEST_CHAIN = params.TEST_CHAIN;

    const PRIVATE_KEY = process.env.PRIVATE_KEY!;
    //change this to your rpc url and network
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
    let WETH_ADDRESS: string;
    let UNISWAP_V3_ROUTER: string;

    USDT_ADDRESS = '';
    WETH_ADDRESS = '';
    UNISWAP_V3_ROUTER = '';

    if (TEST_CHAIN === 'polygon') {
        USDT_ADDRESS = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
        WETH_ADDRESS = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619';
    } else if (TEST_CHAIN === 'ethereum') {
        USDT_ADDRESS = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
        WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    } else if (TEST_CHAIN === 'arbitrum') {
        USDT_ADDRESS = '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9';
        WETH_ADDRESS = '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1';
    }
    else if (NETWORK === 'sepolia') {

        WETH_ADDRESS = '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9';
        USDT_ADDRESS = '0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0';
    }

    UNISWAP_V3_ROUTER = '0xe592427a0aece92de3edee1f18e0157c05861564';

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
        _rwaTokenization = await hre.ethers.deployContract("RWATokenization", [appAddress]);
        const _rwaTokenizationAddress = await _rwaTokenization.getAddress();
        await log('INFO', `3  - _mrwaTokenization Address-> ${_rwaTokenizationAddress}`);
        gasPriceCalc(_rwaTokenization.deploymentTransaction());

        await app.installModule(_rwaTokenizationAddress);
        rwaTokenization = await hre.ethers.getContractAt("RWATokenization", appAddress) as RWATokenization;

        //--------------------- 4. ProfitModule.sol deploy --------------------------------------------------------
        _profitModule = await hre.ethers.deployContract("ProfitModule", [appAddress]);
        const _profitModuleAddress = await _profitModule.getAddress();
        await log('INFO', `4  - _profitModule Address-> ${_profitModuleAddress}`);
        gasPriceCalc(_profitModule.deploymentTransaction());

        await app.installModule(_profitModuleAddress);
        profitModule = await hre.ethers.getContractAt("ProfitModule", appAddress) as ProfitModule;


        //--------------------- 5. Compliance.sol deploy --------------------------------------------------------
        _compliance = await hre.ethers.deployContract("Compliance", [appAddress]);
        const _complianceAddress = await _compliance.getAddress();
        await log('INFO', `5  - _compliance Address-> ${_complianceAddress}`);
        gasPriceCalc(_compliance.deploymentTransaction());

        await app.installModule(_complianceAddress);
        compliance = await hre.ethers.getContractAt("Compliance", appAddress) as Compliance;


        //--------------------- 6. createAsset.sol deploy  ---------------------------------------------
        const createTx = await rwaTokenization.createAsset(ASSET_ID, TOTALTOKENS, TOKENPRICE,TOKENLOWERLIMIT, ASSETURI, "Otel", "OT");
        await createTx.wait();

        const assetTokenAddress = await rwaTokenization.getTokenContractAddress(ASSET_ID);
        assetToken = await hre.ethers.getContractAt("AssetToken", assetTokenAddress) as AssetToken;
        await log('INFO', `6  - assetToken Address -> ${assetTokenAddress}`);

        //--------------------- 7. Fexse.sol deploy  ---------------------------------------------
        fexse = await hre.ethers.deployContract("Fexse");
        const fexseAddress = await fexse.getAddress();
        await log('INFO', `7  - fexse Address-> ${fexseAddress}`);
        await gasPriceCalc(fexse.deploymentTransaction());

        await rwaTokenization.setFexseAddress(fexseAddress);

        //--------------------- 8. RWA_DAO.sol deploy --------------------------------------------------------
        _rwa_DAO = await hre.ethers.deployContract("RWA_DAO", [appAddress]);
        const _rwa_DAOAddress = await _rwa_DAO.getAddress();
        await log('INFO', `8  - _rwa_DAO Address-> ${_rwa_DAOAddress}`);
        gasPriceCalc(_rwa_DAO.deploymentTransaction());

        await app.installModule(_rwa_DAOAddress);
        rwa_DAO = await hre.ethers.getContractAt("RWA_DAO", appAddress) as RWA_DAO;


        //--------------------- 9. SwapModule.sol deploy --------------------------------------------------------
        _swapModule = await hre.ethers.deployContract("SwapModule", [UNISWAP_V3_ROUTER, USDT_ADDRESS, 3000]);
        const _swapModuleAddress = await _swapModule.getAddress();
        await log('INFO', `9  - _swap Module Address-> ${_swapModuleAddress}`);
        gasPriceCalc(_swapModule.deploymentTransaction());

        await app.installModule(_swapModuleAddress);
        swapModule = await hre.ethers.getContractAt("SwapModule", appAddress) as SwapModule;

        //--------------------- 10. FexsePriceFetcher.sol deploy --------------------------------------------------------
        _fexsePriceFetcher = await hre.ethers.deployContract("FexsePriceFetcher", ["0xf97f4df75117a78c1A5a0DBb814Af92458539FB4", USDT_ADDRESS, 3000]);
        const _fexsePriceFetcherAddress = await _fexsePriceFetcher.getAddress();
        await log('INFO', `10  - _fexsePriceFetcher Module Address-> ${_fexsePriceFetcherAddress}`);
        gasPriceCalc(_fexsePriceFetcher.deploymentTransaction());

        await app.installModule(_fexsePriceFetcherAddress);
        fexsePriceFetcher = await hre.ethers.getContractAt("FexsePriceFetcher", appAddress) as FexsePriceFetcher;



        //--------------------- 11. SalesModule.sol deploy --------------------------------------------------------
        _salesModule = await hre.ethers.deployContract("SalesModule",[USDT_ADDRESS]);
        const _salesModuleAddress = await _salesModule.getAddress();
        await log('INFO', `11  - _sales Module Address-> ${_salesModuleAddress}`);
        gasPriceCalc(_salesModule.deploymentTransaction());

        await app.installModule(_salesModuleAddress);
        salesModule = await hre.ethers.getContractAt("SalesModule", appAddress) as SalesModule;

        //--------------------- 12. USDT ERC20   ---------------------------------------------
        usdtContract = (await hre.ethers.getContractAt(ERC20_ABI, USDT_ADDRESS)) as unknown as IERC20;

        //--------------------- 12. WETH ERC20   ---------------------------------------------
        wethContract = (await hre.ethers.getContractAt(ERC20_ABI, WETH_ADDRESS)) as unknown as IERC20;

        log('INFO', "---------------------------TRANSFER - APPROVE----------------------------------------");
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [My_ADDRESS],
        });

        const impersonatedSigner = await hre.ethers.getSigner(My_ADDRESS);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [My_ADDRESS2],
        });

        const impersonatedSigner2 = await hre.ethers.getSigner(My_ADDRESS2);

        const amountUSDT = 150000000; // Amount to transfer (in USDC smallest unit, i.e., without decimals)
        const amountETH = ethers.parseEther("1");
        const amountFexse = ethers.parseEther("1000");
        const amountWETH = ethers.parseEther("100");

        let idx = 1;

        log('INFO', ``);
        log('INFO', "----------------------------TRANSFER ASSETS------------------------------------------");
        log('INFO', ``);

        //await sendEth(impersonatedSigner, impersonatedSigner2, amountETH);

        await getProject_All_Balances(impersonatedSigner, 0);
        await getProject_All_Balances(impersonatedSigner2, 0);
        await getProject_All_Balances(addresses[0], 0);


        for (const addr of addresses) {

            await usdtContract.connect(impersonatedSigner).transfer(addr.address, amountUSDT); // Transfer USDT
            //await wethContract.connect(impersonatedSigner2).transfer(addr.address, amountWETH); // Transfer WETH
            await usdtContract.connect(addr).approve(appAddress, hre.ethers.MaxUint256);
            //await wethContract.connect(addr).approve(appAddress, hre.ethers.MaxUint256); // Transfer WETH
            await fexse.connect(addresses[0]).transfer(addr.address, amountFexse); // Transfer fexse
            await fexse.connect(addr).approve(appAddress, hre.ethers.MaxUint256);

            log('INFO', `Approval successful for fexse and token1 ${addr.address}`);
            idx++;
        }

        await fexse.connect(addresses[0]).transfer(impersonatedSigner, amountFexse);
        await fexse.connect(addresses[0]).transfer(impersonatedSigner2, amountFexse); // Transfer fexse

        await assetToken.connect(addresses[0]).setApprovalForAll(_rwaTokenizationAddress, true);
        await usdtContract.connect(addresses[0]).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
        await usdtContract.connect(impersonatedSigner).approve(appAddress, hre.ethers.MaxUint256);
        await usdtContract.connect(impersonatedSigner).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
        await usdtContract.connect(impersonatedSigner2).approve(appAddress, hre.ethers.MaxUint256);
        await usdtContract.connect(impersonatedSigner2).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);

        await wethContract.connect(addresses[0]).approve(appAddress, hre.ethers.MaxUint256);
        await wethContract.connect(addresses[0]).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
        await wethContract.connect(impersonatedSigner).approve(appAddress, hre.ethers.MaxUint256);
        await wethContract.connect(impersonatedSigner).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
        await wethContract.connect(impersonatedSigner2).approve(appAddress, hre.ethers.MaxUint256);
        await wethContract.connect(impersonatedSigner2).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);

        await fexse.connect(addresses[0]).approve(appAddress, hre.ethers.MaxUint256);
        await fexse.connect(addresses[0]).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
        await fexse.connect(impersonatedSigner).approve(appAddress, hre.ethers.MaxUint256);
        await fexse.connect(impersonatedSigner).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);
        await fexse.connect(impersonatedSigner2).approve(appAddress, hre.ethers.MaxUint256);
        await fexse.connect(impersonatedSigner2).approve(_rwaTokenizationAddress, hre.ethers.MaxUint256);

        await assetToken.connect(addresses[0]).setApprovalForAll(addresses[0], true);
        await assetToken.connect(addresses[0]).setApprovalForAll(appAddress, true);
        await assetToken.connect(impersonatedSigner).setApprovalForAll(appAddress, true);
        await assetToken.connect(impersonatedSigner2).setApprovalForAll(appAddress, true);

        await getProject_All_Balances(impersonatedSigner, 0);
        await getProject_All_Balances(impersonatedSigner2, 0);
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
        const weth_balance = await wethContract.connect(signer).balanceOf(signer.address);
        const asset_balance = await assetToken.connect(signer).balanceOf(signer.address, ASSET_ID);
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
        formatLog("weth_balance:  ", weth_balance);
        formatLog("asset_balance:  ", asset_balance);
        formatLog("fexse_balance: ", fexse_balance);
        log('INFO', ``);
        const balance = await ethers.provider.getBalance(signer.address);
        log('INFO', `ETH Balance:   -----> ${ethers.formatEther(balance)} ETH`);
        log('INFO', ``);
        log('INFO', "-----------------------------------------------------------------------------------------");
        log('INFO', ``);
    }

    async function logAssetDetails(assetId: string, holderAddress: string) {

        const TotalTokens = await rwaTokenization.getTotalTokens(assetId);
        const TokenPrice = await rwaTokenization.getTokenPrice(assetId);
        const TotalProfit = await profitModule.getTotalProfit(assetId);
        const LastDistributed = await profitModule.getLastDistributed(assetId);
        const Uri = await rwaTokenization.getUri(assetId);
        const TokenContractAddress = await rwaTokenization.getTokenContractAddress(assetId);
        const TokenHolders = await rwaTokenization.getTokenHolders(assetId);
        const HolderBalance = await rwaTokenization.getHolderBalance(assetId, holderAddress);
        const PendingProfits = await profitModule.getPendingProfits(assetId, holderAddress);

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
    it("  1  --------------> Should createAsset", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------createAsset-----------------------------------------------------");
        log('INFO', ``);

        const ASSETID_V2 = ASSET_ID + 5;

        const createTx1 = await rwaTokenization.createAsset(ASSETID_V2, TOTALTOKENS, TOKENPRICE,TOKENLOWERLIMIT, ASSETURI, "Otel", "OT");
        await createTx1.wait();

        await logAssetDetails(ASSETID_V2, addresses[0])

        const TokenContractAddress = await rwaTokenization.getTokenContractAddress(ASSETID_V2);
        assetToken_sample = await hre.ethers.getContractAt("AssetToken", TokenContractAddress) as AssetToken;

    });

    /*-----------------------------------------------------------------------------------------------
    -------------------TranserAsset-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  2  --------------> Should TranserAsset", async function () {

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

        log('INFO', ``);
        log('INFO', "-------------------lockTokensToBeSold-----------------------");
        log('INFO', ``);


        await marketPlace.connect(addresses[0]).lockFexseToBeBought(addresses[0], amountFexselock);


        await marketPlace.connect(addresses[0]).transferAsset(
            buyer,
            addresses[0],
            ASSET_ID,
            3,
            1000000);


        log('INFO', ``);
        log('INFO', "-------------------asset transfer -----------------------");
        log('INFO', ``);


        await getProject_All_Balances(buyer, 0);
        await getProject_All_Balances(addresses[0], 0);

        for (const addr of addresses) {

            if (addr != addresses[0]) {

                // await getProject_All_Balances(addr, 0);
                // await getProject_All_Balances(addresses[0], 0);

                // await rwaTokenization.connect(addr).buyTokens(ASSET_ID, 15,rwaTokenizationAddress);               

                // await getProject_All_Balances(addr, 0);        
                // await getProject_All_Balances(addresses[0], 0);
            }
        }

        await logAssetDetails(ASSET_ID, addresses[0]);

    });

    /*-----------------------------------------------------------------------------------------------
    -------------------getTokenContract-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  3  --------------> Should getTokenContract", async function () {

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
    it("  4  --------------> Should distributeProfit", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------distributeProfit-----------------------------------------------------");
        log('INFO', ``);

        
        const profitPerToken = ethers.parseEther("100");


        for (const addr of addresses) {
            await assetToken.connect(addresses[0]).safeTransferFrom(
                addresses[0],
                addr,
                ASSET_ID,
                11,
                "0x");
        }

        await profitModule.connect(addresses[0]).distributeProfit(ASSET_ID, profitPerToken,0,3);
        await profitModule.connect(addresses[0]).distributeProfit(ASSET_ID, profitPerToken,4,6);
        await profitModule.connect(addresses[0]).distributeProfit(ASSET_ID, profitPerToken,7,9);

        for (const addr of addresses) {
            const pendingProfit = await profitModule.getPendingProfits(ASSET_ID, addr);
            log('INFO', `pendingProfit for addr: ${addr.address} amount: ${pendingProfit}  `);
        }

        await logAssetDetails(ASSET_ID, addresses[0]);
    });


    /*-----------------------------------------------------------------------------------------------
    -------------------claimProfit-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  5  --------------> Should claimProfit", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------claimProfit-----------------------------------------------------");
        log('INFO', ``);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [My_ADDRESS],
        });
        const buyer = await hre.ethers.getSigner(My_ADDRESS);
        const ASSET_IDS = [ASSET_ID];

        // rwaTokenization.connect(buyer).claimProfit(ASSET_ID);
        // await getProject_All_Balances(buyer, 0);

        for (const addr of addresses) {
            await profitModule.connect(addr).claimProfit(ASSET_IDS);
            await getProject_All_Balances(addr, 0);
        }
    });

    /*-----------------------------------------------------------------------------------------------
    -------------------updateAsset-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  6  --------------> Should updateAsset", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------updateAsset-----------------------------------------------------");
        log('INFO', ``);

        const TokenPrice = await rwaTokenization.getTokenPrice(ASSET_ID);
        log('INFO', `TokenPrice : ${TokenPrice}`);

        await expect(rwaTokenization.connect(addresses[0]).updateAsset(ASSET_ID, 1111))
            .to.emit(rwaTokenization, "AssetUpdated")
            .withArgs(ASSET_ID, 1111);

        const NewTokenPrice = await rwaTokenization.getTokenPrice(ASSET_ID);
        log('INFO', `NewTokenPrice : ${NewTokenPrice}`);

    });

    /*-----------------------------------------------------------------------------------------------
    -------------------buyTokens-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  7  --------------> Should buyTokens", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------buyTokens-----------------------------------------------------");
        log('INFO', ``);

        const ASSETID_V3 = ASSET_ID + 6;

        const appAddress = await app.getAddress();
        const fexseAddress = await fexse.getAddress();

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [My_ADDRESS],
        });
        const buyer = await hre.ethers.getSigner(My_ADDRESS);

        const createTx2 = await rwaTokenization.createAsset(ASSETID_V3, TOTALTOKENS + 100, TOKENPRICE * 1000, TOKENLOWERLIMIT, ASSETURI, "Otel", "OT");
        await createTx2.wait();

        const TokenContractAddress = await rwaTokenization.getTokenContractAddress(ASSETID_V3);
        assetToken_sample1 = await hre.ethers.getContractAt("AssetToken", TokenContractAddress) as AssetToken;

        //assetToken1 = (await hre.ethers.getContractAt(ASSETTOKEN_ABI, TokenContractAddress)) as unknown as IAssetToken;

        await logAssetDetails(ASSETID_V3, addresses[0])
        await logAssetDetails(ASSETID_V3, buyer.address)
        await getProject_All_Balances(addresses[0], 0)
        await getProject_All_Balances(buyer, 0)        
        
        log('INFO', ``);
        log('INFO', "----------------------------------------------------------------------------------------------");
        log('INFO', ``);

        await assetToken_sample1.connect(addresses[0]).setApprovalForAll(appAddress,true);
        await salesModule.connect(buyer).buyTokens(ASSETID_V3, 5, USDT_ADDRESS/*fexseAddress*/);
        
        await logAssetDetails(ASSETID_V3, addresses[0])
        await logAssetDetails(ASSETID_V3, buyer.address)
        await getProject_All_Balances(addresses[0], 0)
        await getProject_All_Balances(buyer, 0)

        
    });

    /*-----------------------------------------------------------------------------------------------
    ------------------------------buyFexse-----------------------------------------------------------
    -----------------------------------------------------------------------------------------------*/
    it("  8  --------------> Should buyFexse", async function () {

        log('INFO', ``);
        log('INFO', "-----------------------------------------------buyFexse-----------------------------------------------------");
        log('INFO', ``);


        const appAddress = await app.getAddress();
        
        const amountFexse = ethers.parseEther("40000");
        
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [My_ADDRESS],
        });
        
        const buyer = await hre.ethers.getSigner(My_ADDRESS);

        await getProject_All_Balances(buyer, 0);
        await getProject_All_Balances(addresses[0], 0);

        log('INFO', ``);
        log('INFO', "----------------------------------------------------------------------------------------------");
        log('INFO', ``);

        await fexse.connect(addresses[0]).approve(appAddress, hre.ethers.MaxUint256);
        log('INFO', `1`);
        //await usdtContract.connect(buyer).approve(appAddress, hre.ethers.MaxUint256);
        log('INFO', `2`);

        //await salesModule.connect(addresses[0]).setPrice(45000);
        await salesModule.connect(buyer).buyFexse(amountFexse, USDT_ADDRESS);
        log('INFO', `3`);

        await getProject_All_Balances(addresses[0], 0);
        await getProject_All_Balances(buyer, 0);
    });

});
