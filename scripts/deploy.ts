const { ethers } = require("hardhat");
import hre from "hardhat";
import { log } from '../test/logger';
import * as dotenv from "dotenv";
dotenv.config();

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

async function verifyContract(address: string, constructorArgs: any[]) {
    try {
        console.log(`Verifying contract at address: ${address}`);
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: constructorArgs,
        });
        console.log(`Contract at address ${address} verified successfully!`);
    } catch (err: any) {
        console.error(`Verification failed for ${address}:`, err.message);
    }
}

async function main() {
    console.log("Starting deployment...");

    // Load private key and provider from .env
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


    let WETH_ADDRESS: string;
    let USDT_ADDRESS: string;
    let USDETH_AGGREGATOR: string;
    let USDFEXSE_AGGREGATOR: string;
    let UNISWAP_V3_ROUTER: string;

    WETH_ADDRESS = '';
    USDT_ADDRESS = '';
    USDETH_AGGREGATOR = '';
    UNISWAP_V3_ROUTER = '';

    UNISWAP_V3_ROUTER = '0xe592427a0aece92de3edee1f18e0157c05861564';

    if (NETWORK === 'polygon') {

        WETH_ADDRESS = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619';
        USDT_ADDRESS = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
        USDETH_AGGREGATOR = '0xF9680D99D6C9589e2a93a78A04A279e509205945';
        USDFEXSE_AGGREGATOR = '0x0000000000000000000000000000000000000001';

    } else if (NETWORK === 'ethereum') {

        WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
        USDT_ADDRESS = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
        USDETH_AGGREGATOR = '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419';
        USDFEXSE_AGGREGATOR = '0x0000000000000000000000000000000000000001';

    } else if (NETWORK === 'arbitrum') {

        WETH_ADDRESS = '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1';
        USDT_ADDRESS = '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9';
        USDETH_AGGREGATOR = '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612';
        USDFEXSE_AGGREGATOR = '0x0000000000000000000000000000000000000001';
    }
    else if (NETWORK === 'sepolia') {

        WETH_ADDRESS = '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9';
        USDT_ADDRESS = '0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0';
        //TODO: bul
        USDETH_AGGREGATOR = '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612';
        USDFEXSE_AGGREGATOR = '0x0000000000000000000000000000000000000001';
    }

    log('INFO', `Starting Deployment for modules using wallet: ${wallet.address}`);
    log('INFO', "");

    const balance = await provider.getBalance(wallet.address);
    log('INFO', `Owner Balance: -----> ${ethers.formatEther(balance)} ETH`);
    log('INFO', "");
    
        //--------------------- 1. App.sol deploy -------------------------------------------------------------
        // const AppContract = await hre.ethers.getContractFactory("App", wallet);
        // app = await AppContract.deploy() as App;
        // await app.waitForDeployment();
        // const appAddress = await app.getAddress();
        // log('INFO', `1  - App contract deployed at: ${appAddress}`);
    
        // await waitSec(30);


        //After app deployed, we can use this address
        const appAddress = "0x89E488715562c9f2200E5f277D78C5Da9E2fA41E";

        const AppContract = await hre.ethers.getContractAt("App", appAddress, wallet);
        app = AppContract as App;
    
        //--------------------- 2. MarketPlace.sol deploy ------------------------------------------------------
        const MarketPlaceContract = await hre.ethers.getContractFactory("MarketPlace", wallet);
        _marketPlace = await MarketPlaceContract.deploy(appAddress) as MarketPlace;
        await _marketPlace.waitForDeployment();
        const _marketPlaceAddress = await _marketPlace.getAddress();
        log('INFO', `2  - market Place contract deployed at: ${_marketPlaceAddress}`);
    
    
        await app.installModule(_marketPlaceAddress);
    
        marketPlace = await hre.ethers.getContractAt("MarketPlace", appAddress, wallet) as MarketPlace;
    
        await waitSec(15);
    
        //--------------------- 3. RWATokenization.sol deploy --------------------------------------------------------
        const RWATokenizationContract = await hre.ethers.getContractFactory("RWATokenization", wallet);
        _rwaTokenization = await RWATokenizationContract.deploy(appAddress) as RWATokenization;
        await _rwaTokenization.waitForDeployment();
    
        const _rwaTokenizationAddress = await _rwaTokenization.getAddress();
        await log('INFO', `3  - RWATokenization Address-> ${_rwaTokenizationAddress}`);
        await app.installModule(_rwaTokenizationAddress);
        
        rwaTokenization = await hre.ethers.getContractAt("RWATokenization", appAddress, wallet) as RWATokenization;
    
        await waitSec(30);
    
        //--------------------- 4. ProfitModule.sol deploy --------------------------------------------------------
        const ProfitModuleContract = await hre.ethers.getContractFactory("ProfitModule", wallet);
        _profitModule = await ProfitModuleContract.deploy(appAddress) as ProfitModule;
        await _profitModule.waitForDeployment();
    
        const _profitModuleAddress = await _profitModule.getAddress();
        await log('INFO', `4  - ProfitModule Address-> ${_profitModuleAddress}`);
        await app.installModule(_profitModuleAddress);
        
        profitModule = await hre.ethers.getContractAt("ProfitModule", appAddress, wallet) as ProfitModule;
    
        await waitSec(15);
    
        //--------------------- 5. Compliance.sol deploy --------------------------------------------------------
        const ComplianceContract = await hre.ethers.getContractFactory("Compliance", wallet);
        _compliance = await ComplianceContract.deploy(appAddress) as Compliance;
        await _compliance.waitForDeployment();
    
        const _complianceAddress = await _compliance.getAddress();
        await log('INFO', `5  - _compliance Address-> ${_complianceAddress}`);
    
        await app.installModule(_complianceAddress);
        await waitSec(15);
    
        //--------------------- 6. Fexse.sol deploy -------------------------------------------------------
        const FexseContract = await hre.ethers.getContractFactory("Fexse", wallet);
        fexse = await FexseContract.deploy() as Fexse;
        await fexse.waitForDeployment();
    
        const fexseAddress = await fexse.getAddress();
        await log('INFO', `6  - fexse Address-> ${fexseAddress}`);
    
        await rwaTokenization.setFexseAddress(fexseAddress);
    
        await waitSec(30);
    
        //--------------------- 7. RWA_DAO.sol deploy ---------------------------------------------------------
        // const RWA_DAO_Contract = await hre.ethers.getContractFactory("RWA_DAO", wallet);
        // _rwa_DAO = await RWA_DAO_Contract.deploy(appAddress) as RWA_DAO;
        // await _rwa_DAO.waitForDeployment();
    
        // const _rwa_DAOAddress = await _rwa_DAO.getAddress();
        // await log('INFO', `7  - _rwa_DAO Address-> ${_rwa_DAOAddress}`);
    
        // await app.installModule(_rwa_DAOAddress);
        // rwa_DAO = await hre.ethers.getContractAt("RWA_DAO", appAddress, wallet) as RWA_DAO;
    
        // await waitSec(15);
    
        //--------------------- 8. SwapModule.sol deploy  ----------------------------------------------------
        // const SwapModuleContract = await hre.ethers.getContractFactory("SwapModule", wallet);
        // _swapModule = await SwapModuleContract.deploy(UNISWAP_V3_ROUTER, USDT_ADDRESS, 3000) as SwapModule;
        // await _swapModule.waitForDeployment();
    
        // const _swapModuleAddress = await _swapModule.getAddress();
        // await log('INFO', `8  - _swapModule Address-> ${_swapModuleAddress}`);
    
        // await app.installModule(_swapModuleAddress);
        // swapModule = await hre.ethers.getContractAt("SwapModule", appAddress, wallet) as SwapModule;
        // await waitSec(15);
    
        //--------------------- 9. FexsePriceFetcher.sol deploy  -----------------------------------------------------
        // const FexsePriceFetcherContract = await hre.ethers.getContractFactory("FexsePriceFetcher", wallet);
        // _fexsePriceFetcher = await FexsePriceFetcherContract.deploy(fexseAddress, USDT_ADDRESS, 3000) as FexsePriceFetcher;
        // await _fexsePriceFetcher.waitForDeployment();
    
        // const _fexsePriceFetcherAddress = await _fexsePriceFetcher.getAddress();
        // await log('INFO', `9  - _fexsePriceFetcher Address-> ${_fexsePriceFetcherAddress}`);
    
        // await app.installModule(_fexsePriceFetcherAddress);
        // fexsePriceFetcher = await hre.ethers.getContractAt("FexsePriceFetcher", appAddress, wallet) as FexsePriceFetcher;
    
        // await waitSec(15);
    
        //--------------------- 10. SalesModule.sol deploy ------------------------------------------------------------------
    
        const SalesModuleContract = await hre.ethers.getContractFactory("SalesModule", wallet);
        _salesModule = await SalesModuleContract.deploy(USDT_ADDRESS) as SalesModule;
        await _salesModule.waitForDeployment();
        await waitSec(30);
    
        const _salesModuleAddress = await _salesModule.getAddress();
        await log('INFO', `10  - SalesModule Address-> ${_salesModuleAddress}`);
        await waitSec(30);
    
        await app.installModule(_salesModuleAddress);
        await waitSec(15);
    
        //----------------------------------------------------------------
    
        const finalBalance = await provider.getBalance(wallet.address);
        log('INFO', `Remaining Owner Balance: ----->  ${ethers.formatEther(finalBalance)} ETH`);
    
    
    
        await verifyContract(appAddress, []); 
        await verifyContract(_rwaTokenizationAddress, [appAddress]);
        await verifyContract(_profitModuleAddress, [appAddress]);
        await verifyContract(_marketPlaceAddress, [appAddress]);
        await verifyContract(_complianceAddress, [appAddress]);
        await verifyContract(fexseAddress, []);
        await verifyContract(_salesModuleAddress, [USDT_ADDRESS]);

    //await verifyContract("0x7b5DB687022f5c514027d110c423E50c93BFED12", ["SP Villa", "SPV", "0x0000000000000000000000000000000000000000", "https://olive-bright-quelea-862.mypinata.cloud/ipfs/bafkreihmk6ienxr6jnqbfoq53ncz5wouqnrjxnxwhkgdc7vkucenubua5a","0x89E488715562c9f2200E5f277D78C5Da9E2fA41E"]);


}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
