// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IAssetToken.sol";
import "../token/ERC20/IERC20.sol";

interface IMarketPlace {

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
}