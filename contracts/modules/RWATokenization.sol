// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../utils/AccessControl.sol";
import "../token/ERC20/IERC20.sol";
import "../utils/Strings.sol";
import "../utils/ReentrancyGuard.sol";
import "../utils/Ownable.sol";
import {AssetToken} from "../token/AssetToken.sol";
import {IAssetToken} from "../interfaces/IAssetToken.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import "hardhat/console.sol";


contract RWATokenization is AccessControl, Ownable, ReentrancyGuard  {

    IERC20 public usdt = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 public fexse;

    // Asset struct to store asset information
    struct Asset {
        uint256 id;                  // Unique ID for the asset
        uint256 totalTokens;         // Total number of tokens representing the asset
        uint256 tokenPrice;          // Price per token in USDT (scaled by 10^18 for precision)
        uint256 totalProfit;         // Total profit accumulated by the asset
        uint256 lastDistributed;     // Last distribution timestamp
        string uri;                  // URI for metadata
        IAssetToken tokenContract;
        address[] tokenHolders;      // List of token holders for profit sharing
        mapping(address => uint256) holdings; // User's holdings in the asset
        mapping(address => uint256) pendingProfits;
        mapping(address => uint256) tokensForSale;
        mapping(address => uint256) salePrices;
    }

    // Admin address for managing token transfers
    address public admin;
    string private baseURI;

    uint256 private constant USDT_DECIMALS = 10**6; // 6 decimals for USDT
    uint256 private constant FEXSE_DECIMALS = 10**18; // 18 decimals for FEXSE
    uint256 private constant FEXSE_PRICE_IN_USDT = 45; // 0.045 USDT represented as 45 (scaled by 10^3)


    // Mapping to store assets by ID
    mapping(uint256 => Asset) public assets;

    // Event to log profit distribution
    event ProfitDistributed(uint256 assetId, uint256 totalProfit, uint256 amountPerToken);
    event AssetUpdated(uint256 assetId, uint256 newTokenPrice);
    event TokensPurchased(address buyer, uint256 assetId, uint256 amount, uint256 cost);
    event TokensSold(address buyer, address seller, uint256 assetId, uint256 amount, uint256 cost);
    event TokensListedForSale(address seller, uint256 assetId, uint256 amount, uint256 price);
    event AssetCreated(uint256 assetId, address tokenContract, uint256 totalTokens, uint256 tokenPrice);
    event fexseContractUpdated(address oldToken, address newToken);


    constructor(address initialOwner)
        Ownable(initialOwner)
    {
        admin = msg.sender;
    } 

    // Function to create a new asset and issue tokens to the admin
    function createAsset(
        uint256 assetId,
        uint256 totalTokens,
        uint256 tokenPrice,
        string memory assetUri
    ) external onlyOwner nonReentrant  {

        require(assets[assetId].id == 0, "Asset already exists");
        require(totalTokens > 0, "Total tokens must be greater than zero");
        require(tokenPrice > 0, "Token price must be greater than zero");

        // Deploy a new instance of AssetToken
        AssetToken token = new AssetToken(
            admin,          // Owner of the new token
            assetUri,       // URI for metadata
            address(this) 
        );

        address tokenAddress = address(token);     

        // Store the deployed contract information in the mapping
        Asset storage newAsset = assets[assetId];
        newAsset.id = assetId;
        newAsset.totalTokens = totalTokens;
        newAsset.tokenPrice = tokenPrice;
        newAsset.uri = assetUri;
        newAsset.tokenContract = IAssetToken(tokenAddress);

        token.mint( admin, assetId, totalTokens, "");

        emit AssetCreated(assetId, address(token), totalTokens, tokenPrice);
    } 

    // Function to get the ID of an asset
    function getAssetId(uint256 assetId) external view returns (uint256) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return asset.id;
    }

    // Function to get the total tokens of an asset
    function getTotalTokens(uint256 assetId) external view returns (uint256) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return asset.totalTokens;
    }

    // Function to get the token price of an asset
    function getTokenPrice(uint256 assetId) external view returns (uint256) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return asset.tokenPrice;
    }

    // Function to get the total profit of an asset
    function getTotalProfit(uint256 assetId) external view returns (uint256) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return asset.totalProfit;
    }

    // Function to get the last distributed timestamp of an asset
    function getLastDistributed(uint256 assetId) external view returns (uint256) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return asset.lastDistributed;
    }

    // Function to get the URI of an asset
    function getUri(uint256 assetId) external view returns (string memory) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return string(abi.encodePacked(asset.uri));
    }

    // Function to get the token contract address of an asset
    function getTokenContractAddress(uint256 assetId) external view returns (address) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return address(asset.tokenContract);
    }

    // Function to get the token holders of an asset
    function getTokenHolders(uint256 assetId) external view returns (address[] memory) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return asset.tokenHolders;
    }

    // Function to get the holdings of a specific holder for an asset
    function getHolderBalance(uint256 assetId, address holder) external view returns (uint256) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return asset.holdings[holder];
    }

        // Function to get the pending Profits of a specific holder for an asset
    function getPendingProfits(uint256 assetId, address holder) external view returns (uint256) {
        Asset storage asset = assets[assetId];
        require(asset.id != 0, "Asset does not exist");
        return asset.pendingProfits[holder];
    }

    // Function to allow users to buy tokens from the admin address
    function buyTokens(uint256 assetId, uint256 tokenAmount, address seller) public payable nonReentrant  {
        Asset storage asset = assets[assetId];
        uint256 cost;

        /*TODO: frontend Approve*/

        // TODO: frontend Approve Transfer tokens from the admin to the buyer

        if (seller == address(this)) {
            cost = asset.tokenPrice * tokenAmount;
            require(usdt.transferFrom(msg.sender, admin, cost), "USDT transfer failed");
            IAssetToken(asset.tokenContract).safeTransferFrom(admin, msg.sender, assetId, tokenAmount, "");
        } else {
            cost = asset.salePrices[seller] * tokenAmount;
            require(asset.tokensForSale[seller] >= tokenAmount, "Insufficient tokens for sale");
            require(usdt.transferFrom(msg.sender, seller, cost), "USDT transfer to seller failed");

            asset.tokensForSale[seller] -= tokenAmount;
            IAssetToken(asset.tokenContract).safeTransferFrom(seller, msg.sender, assetId, tokenAmount, "");

            emit TokensSold(msg.sender, seller, assetId, tokenAmount, cost);
        }

        emit TokensPurchased(msg.sender, assetId, tokenAmount, cost);
    }

    function sellTokens(uint256 assetId, uint256 tokenAmount, uint256 salePrice) external nonReentrant  {
        Asset storage asset = assets[assetId];
        require(asset.holdings[msg.sender] >= tokenAmount, "Insufficient token balance");

        /*TODO: frontend Approve*/

        // TODO: frontend Approve Transfer tokens from the admin to the buyer

        asset.tokensForSale[msg.sender] += tokenAmount;
        asset.salePrices[msg.sender] = salePrice;

        emit TokensListedForSale(msg.sender, assetId, tokenAmount, salePrice);
    }


    // Function to distribute profit to token holders
    function distributeProfit(uint256 assetId, uint256 profitAmount) public onlyOwner nonReentrant  {
        Asset storage asset = assets[assetId];
        
        // Calculate profit per token
        uint256 profitPerToken = profitAmount / asset.totalTokens;

        // Distribute profit to each holder
        for (uint256 i = 0; i < asset.tokenHolders.length; i++) {  
            address holder = asset.tokenHolders[i];
            uint256 holderTokens = asset.holdings[holder];
            uint256 holderProfit = holderTokens*profitPerToken;   
            asset.pendingProfits[holder] = asset.pendingProfits[holder] + holderProfit;
        }

        asset.totalProfit = asset.totalProfit + profitAmount;
        asset.lastDistributed = block.timestamp;
        //TODO: fexse miktarını atalım profit amount olarak.
        emit ProfitDistributed(assetId, profitAmount, profitPerToken);
    }


    // Holders can claim profits themselves
    function claimProfit(uint256 assetId) public nonReentrant  {

        Asset storage asset = assets[assetId];

        uint256 amount = asset.pendingProfits[msg.sender];
        require(amount > 0, "No profit to claim");
        asset.pendingProfits[msg.sender] = 0;

        // TODO: fexse tranfer fiyta dönüşümü chainlink integration
        uint256 fexse_amount = (amount * FEXSE_DECIMALS) / (FEXSE_PRICE_IN_USDT * (10**3));

        //console.log("fexse_amount", fexse_amount);

        fexse.transferFrom(admin, msg.sender, fexse_amount);

        // TODO: emit claimed(assetid array, )
    }

    // New function to update the token price for an existing asset
    function updateAsset(uint256 assetId, uint256 newTokenPrice) public onlyOwner nonReentrant  {
        require(assets[assetId].id != 0, "Asset does not exist");

        Asset storage asset = assets[assetId];
        asset.tokenPrice = newTokenPrice;

        emit AssetUpdated(assetId, newTokenPrice);
    }

    function setFexseAddress(
        IERC20 _fexseToken
    ) external onlyOwner nonReentrant  {
        require(
            address(_fexseToken) != address(0),
            "Invalid _fexseToken address"
        );
        
        address oldContract = address(fexse);
        fexse = _fexseToken;

        emit fexseContractUpdated(oldContract, address(_fexseToken));
    }

    function updateHoldings(address account, uint256 assetId, uint256 balance) external {

        Asset storage asset = assets[assetId];

        require((msg.sender == address(assets[assetId].tokenContract)) || 
                (msg.sender == address(this)), "Unauthorized");
       
        uint256 currentBalance = asset.holdings[account];

        // Eğer balance değişmemişse işlemi atla
        if (currentBalance == balance) {
            return;
        }

        // Check if balance is zero, remove holder
        if (balance == 0 && currentBalance > 0) {
            clearHolderData(assetId, account);
        }
        // If balance > 0 and not already a holder, add holder
        else if (balance > 0 && currentBalance == 0) {
            asset.tokenHolders.push(account);
        }

        // Update holdings
        asset.holdings[account] = balance;
    }

    function _removeHolder(uint256 assetId, address holder) internal {
        Asset storage asset = assets[assetId];
        uint256 length = asset.tokenHolders.length;

        for (uint256 i = 0; i < length; i++) {
            if (asset.tokenHolders[i] == holder) {
                asset.tokenHolders[i] = asset.tokenHolders[length - 1];
                asset.tokenHolders.pop();
                break;
            }
        }
    }

    // Function to remove holdings of a specific address
    function _removeHoldings(uint256 assetId, address holder) internal {
        Asset storage asset = assets[assetId];
        require(asset.holdings[holder] > 0, "No holdings to remove");

        delete asset.holdings[holder];
    }

    // Function to remove pending profits of a specific address
    function _removePendingProfits(uint256 assetId, address holder) internal {
        Asset storage asset = assets[assetId];
        require(asset.pendingProfits[holder] > 0, "No pending profits to remove");

        delete asset.pendingProfits[holder];
    }

    // Function to clear all mappings and arrays for a specific holder
    function clearHolderData(uint256 assetId, address holder) internal {
        _removeHolder(assetId, holder);
        _removeHoldings(assetId, holder);
        _removePendingProfits(assetId, holder);
    }
}

