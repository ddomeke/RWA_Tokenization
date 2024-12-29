// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IAssetToken.sol";
import "../token/ERC20/IERC20.sol";

interface IRWATokenization {
    struct UserTokenInfo {
        uint256 holdings; // User's holdings in the asset
        uint256 pendingProfits; // Pending profits for the user
        uint256 tokensForSale; // Number of tokens put for sale by the user
        uint256 salePrices; // Sale price set by the user
    }

    struct Asset {
        uint256 id; // Unique ID for the asset
        uint256 totalTokens; // Total number of tokens representing the asset
        uint256 tokenPrice; // Price per token in USDT (scaled by 10^18 for precision)
        uint256 totalProfit; // Total profit accumulated by the asset
        uint256 lastDistributed; // Last distribution timestamp
        string uri; // URI for metadata
        IAssetToken tokenContract;
        address[] tokenHolders; // List of token holders for profit sharing
    }

    function createAsset(
        uint256 assetId,
        uint256 totalTokens,
        uint256 tokenPrice,
        string memory assetUri
    ) external;

    function distributeProfit(uint256 assetId, uint256 profitAmount) external;

    function claimProfit(uint256 assetId) external;

    function updateAsset(uint256 assetId, uint256 newTokenPrice) external;

    function setFexseAddress(address fexseToken) external;

    function getAssetId(uint256 assetId) external view returns (uint256);

    function getTotalTokens(uint256 assetId) external view returns (uint256);

    function getTokenPrice(uint256 assetId) external view returns (uint256);

    function getTotalProfit(uint256 assetId) external view returns (uint256);

    function getLastDistributed(uint256 assetId) external view returns (uint256);

    function getUri(uint256 assetId) external view returns (string memory);

    function getTokenContractAddress(uint256 assetId) external view returns (address);

    function getTokenHolders(uint256 assetId) external view returns (address[] memory);

    function getHolderBalance(uint256 assetId, address holder) external view returns (uint256);

    function getPendingProfits(uint256 assetId, address holder) external view returns (uint256);

    function transferAsset(
        address sender,
        address buyer,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 tokenPrice
    ) external;

    function lockTokensToBeSold(
        address owner,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 salePrice
    ) external;

    function unlockTokensToBeSold(
        address owner,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 salePrice
    ) external;

    function lockFexseToBeBought(address owner, uint256 fexseLockedAmount) external;

    function unlockFexse(address owner, uint256 fexseLockedAmount) external;

    function updateHoldings(
        address account,
        uint256 assetId,
        uint256 balance
    ) external;
}