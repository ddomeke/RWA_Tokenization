// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IAssetToken.sol";
import "../token/ERC20/IERC20.sol";

interface IRWATokenization {
    function createAsset(
        uint256 assetId,
        uint256 totalTokens,
        uint256 tokenPrice,
        uint256 tokenLowerLimit,
        string memory assetUri,
        string memory name,
        string memory symbol
    ) external;

    function updateAsset(uint256 assetId, uint256 newTokenPrice) external;

    function getAssetId(uint256 assetId) external view returns (uint256);

    function getTotalTokens(uint256 assetId) external view returns (uint256);

    function getTokenPrice(uint256 assetId) external view returns (uint256);

    function getUri(uint256 assetId) external view returns (string memory);

    function getTokenContractAddress(
        uint256 assetId
    ) external view returns (address);

    function getTokenHolders(
        uint256 assetId
    ) external view returns (address[] memory);

    function getHolderBalance(
        uint256 assetId,
        address holder
    ) external view returns (uint256);

    function sendToTheRealWorld(
        address account,
        uint256 assetId,
        uint256 amount
    ) external;

    function updateHoldings(
        address account,
        uint256 assetId,
        uint256 balance
    ) external;
}
