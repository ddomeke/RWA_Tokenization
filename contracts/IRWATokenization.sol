// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRWATokenization {
    /**
     * @notice Update token holder balances and maintain token holders list.
     * @param account The address of the token holder.
     * @param assetId The ID of the asset whose holdings are being updated.
     * @param balance The updated balance of the token holder.
     */
    function updateHoldings(address account, uint256 assetId, uint256 balance) external;

    /**
     * @notice Set the address of the FEXSE token.
     * @param _fexseToken The IERC20 token contract address.
     */
    function setFexseAddress(address _fexseToken) external;

    /**
     * @notice Function to distribute profits to token holders for a specific asset.
     * @param assetId The ID of the asset for which profits are distributed.
     * @param profitAmount Total profit to distribute.
     */
    function distributeProfit(uint256 assetId, uint256 profitAmount) external;

    /**
     * @notice Function to claim accumulated profits for the caller.
     */
    function claimProfit() external;

    /**
     * @notice Retrieve the token balance of a specific user for a given asset.
     * @param assetId The ID of the asset.
     * @param user The address of the user.
     * @return The balance of the user.
     */
    function getTokenBalance(uint256 assetId, address user) external view returns (uint256);

    /**
     * @notice Update the price of an existing asset.
     * @param assetId The ID of the asset to update.
     * @param newTokenPrice The new price per token for the asset.
     */
    function updateAsset(uint256 assetId, uint256 newTokenPrice) external;

    /**
     * @notice Retrieve the token contract associated with an asset.
     * @param assetId The ID of the asset.
     * @return The address of the asset's token contract.
     */
    function getTokenContract(uint256 assetId) external view returns (address);
}
