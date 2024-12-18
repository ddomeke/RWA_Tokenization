// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRWATokenization {

    function updateHoldings(address account, uint256 assetId, uint256 balance) external;

    function createAsset(
        uint256 assetId,
        uint256 totalTokens,
        uint256 tokenPrice,
        string memory assetUri
    ) external;

    function getTokenContract(uint256 assetId) external view returns (address);

    function buyTokens(uint256 assetId, uint256 tokenAmount) external payable;

    function distributeProfit(uint256 assetId, uint256 profitAmount) external;

    function claimProfit() external;

    function getTokenBalance(uint256 assetId, address user) external view returns (uint256);

    function updateAsset(uint256 assetId, uint256 newTokenPrice) external;
}
