// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../utils/AccessControl.sol";
import "../token/ERC20/IERC20.sol";
import "../utils/Strings.sol";
import "../utils/ReentrancyGuard.sol";
import "../utils/Ownable.sol";
import {AssetToken} from "../token/AssetToken.sol";
import {IAssetToken} from "../interfaces/IAssetToken.sol";
import {IFexse} from "../interfaces/IFexse.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import "hardhat/console.sol";

// TODO : market module yap. transertoken, buy sell cancelbuy cancelsell hepsini oraya koy

contract Marketplace is AccessControl, Ownable, ReentrancyGuard {
   IFexse public fexse;

    struct UserTokenInfo {
        uint256 holdings; // User's holdings in the asset
        uint256 pendingProfits; // Pending profits for the user
        uint256 tokensForSale; // Number of tokens put for sale by the user
        uint256 salePrices; // Sale price set by the user
    }

    // Asset struct to store asset information
    struct Asset {
        uint256 id; // Unique ID for the asset
        uint256 totalTokens; // Total number of tokens representing the asset
        uint256 tokenPrice; // Price per token in USDT (scaled by 10^18 for precision)
        uint256 totalProfit; // Total profit accumulated by the asset
        uint256 profitPeriod; // Total profit accumulated by the asset
        uint256 lastDistributed; // Last distribution timestamp
        string uri; // URI for metadata
        IAssetToken tokenContract;
        address[] tokenHolders; // List of token holders for profit sharing
        mapping(address => UserTokenInfo) userTokenInfo;
    }

    // Admin address for managing token transfers
    address public admin;

    uint256 private constant FEXSE_DECIMALS = 10 ** 18; // 18 decimals for FEXSE
    uint256 private constant FEXSE_PRICE_IN_USDT = 45; // 0.045 USDT represented as 45 (scaled by 10^3)

    // Mapping to store assets by ID
    mapping(uint256 => Asset) public assets;

    event TokensLockedForSale(
        address seller,
        uint256 assetId,
        uint256 amount,
        uint256 price
    );
    event TokensUnlocked(
        address seller,
        uint256 assetId,
        uint256 amount,
        uint256 price
    );
    event Fexselocked(address sender, uint256 fexseLockedAmount);
    event FexseUnlocked(address sender, uint256 fexseLockedAmount);

    event fexseContractUpdated(address oldToken, address newToken);
    event TransferExecuted(
        address sender,
        address buyer,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 fexseAmount,
        uint256 cost
    );
    constructor(address initialOwner) Ownable(initialOwner) {
        admin = msg.sender;
    }


    /**
     * @notice Transfers a specified amount of asset tokens from a sender to a buyer.
     * @dev This function handles the transfer of asset tokens and the corresponding FEXSE token payment.
     *      It requires the caller to be the contract owner and is protected against reentrancy.
     * @param sender The address of the current token holder who is transferring the tokens.
     * @param buyer The address of the recipient who is buying the tokens.
     * @param assetId The unique identifier of the asset whose tokens are being transferred.
     * @param tokenAmount The number of tokens to be transferred.
     * @param tokenPrice The price per token in USDT.
     */
    function transferAsset(
        address sender,
        address buyer,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 tokenPrice
    ) external onlyOwner nonReentrant {
        require(address(sender) != address(0), "Invalid sender address");
        require(address(buyer) != address(0), "Invalid buyer address");
        require(tokenAmount > 0, "Token amount must be greater than zero");
        require(tokenPrice > 0, "Token price must be greater than zero");

        Asset storage asset = assets[assetId];
        uint256 cost = tokenPrice * tokenAmount;

        // TODO: fexse tranfer fiyta dönüşümü chainlink integration
        uint256 fexse_amount = (cost * FEXSE_DECIMALS) /
            (FEXSE_PRICE_IN_USDT * (10 ** 3));

        fexse.unlock(buyer, fexse_amount);

        require(
            fexse.transferFrom(buyer, sender, fexse_amount),
            "FEXSE transfer failed"
        );

        IAssetToken(asset.tokenContract).unlockTokens(
            sender,
            assetId,
            tokenAmount
        );

        IAssetToken(asset.tokenContract).safeTransferFrom(
            sender,
            buyer,
            assetId,
            tokenAmount,
            ""
        );

        emit TransferExecuted(
            sender,
            buyer,
            assetId,
            tokenAmount,
            fexse_amount,
            cost
        );
    }

    // Function to allow users to buy tokens from the admin address
    function lockFexseToBeBought(
        address owner,
        uint256 fexseLockedAmount
    ) public nonReentrant {
        uint256 fexseAmount = fexse.balanceOf(owner);

        require(fexseAmount >= fexseLockedAmount, "Insufficient fexse balance");

        fexse.lock(owner, fexseLockedAmount);

        emit Fexselocked(owner, fexseLockedAmount);
    }

    function unlockFexse(
        address owner,
        uint256 fexseLockedAmount
    ) external nonReentrant {
        uint256 fexseAmount = fexse.balanceOf(owner);

        require(fexseAmount >= fexseLockedAmount, "Insufficient token balance");

        fexse.unlock(owner, fexseLockedAmount);

        emit FexseUnlocked(owner, fexseLockedAmount);
    }

    function lockTokensToBeSold(
        address owner,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 salePrice
    ) external nonReentrant {
        Asset storage asset = assets[assetId];
        require(
            asset.userTokenInfo[owner].holdings >= tokenAmount,
            "Insufficient token balance"
        );

        IAssetToken(asset.tokenContract).lockTokens(
            owner,
            assetId,
            tokenAmount
        );

        asset.userTokenInfo[owner].tokensForSale += tokenAmount;
        asset.userTokenInfo[owner].salePrices = salePrice;

        emit TokensLockedForSale(owner, assetId, tokenAmount, salePrice);
    }

    function unlockTokensToBeSold(
        address owner,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 salePrice
    ) external nonReentrant {
        Asset storage asset = assets[assetId];

        require(
            asset.userTokenInfo[owner].holdings >= tokenAmount,
            "Insufficient token balance"
        );

        IAssetToken(asset.tokenContract).unlockTokens(
            owner,
            assetId,
            tokenAmount
        );

        asset.userTokenInfo[owner].tokensForSale -= tokenAmount;
        asset.userTokenInfo[owner].salePrices = 0;

        emit TokensUnlocked(owner, assetId, tokenAmount, salePrice);
    }

    function setFexseAddress(
        IFexse _fexseToken
    ) external onlyOwner nonReentrant {
        require(
            address(_fexseToken) != address(0),
            "Invalid _fexseToken address"
        );

        address oldContract = address(fexse);
        fexse = _fexseToken;

        emit fexseContractUpdated(oldContract, address(_fexseToken));
    }

}
