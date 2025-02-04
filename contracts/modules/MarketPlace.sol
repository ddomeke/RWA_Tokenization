// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
/**
 * @file MarketPlace.sol
 * @dev This file contains the implementation of the MarketPlace contract.
 *
 * Imports:
 * - ModularInternal: Provides internal modular functionality.
 * - Strings: Utility library for string operations.
 * - AssetToken: Token contract for asset tokens.
 * - IAssetToken: Interface for the AssetToken contract.
 * - IMarketPlace: Interface for the MarketPlace contract.
 * - console: Hardhat console for debugging.
 */

import "../core/abstracts/ModularInternal.sol";
import "../utils/Strings.sol";
import "../interfaces/IFexsePriceFetcher.sol";
import {AssetToken} from "../token/AssetToken.sol";
import {IAssetToken} from "../interfaces/IAssetToken.sol";
import {IMarketPlace} from "../interfaces/IMarketPlace.sol";

/**
 * @title MarketPlace
 * @dev This contract is a module that extends the ModularInternal contract.
 * It is part of the RWATokenization project and is located at /c:/Users/duran/RWATokenization/contracts/modules/MarketPlace.sol.
 */
contract MarketPlace is ModularInternal {
    using AppStorage for AppStorage.Layout;

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

    event TransferExecuted(
        address sender,
        address buyer,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 fexseAmount
    );

    address immutable _this;

    /**
     * @dev Constructor for the MarketPlace contract.
     * Grants the ADMIN_ROLE to the deployer of the contract and the specified appAddress.
     *
     * @param appAddress The address to be granted the ADMIN_ROLE.
     */
    constructor(address appAddress) {
        _this = address(this);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, appAddress);
    }

    /**
     * @dev Returns an array of ⁠ FacetCut ⁠ structs, which define the functions (selectors)
     *      provided by this module. This is used to register the module's functions
     *      with the modular system.
     * @return FacetCut[] Array of ⁠ FacetCut ⁠ structs representing function selectors.
     */
    function moduleFacets() external view returns (FacetCut[] memory) {
        uint256 selectorIndex = 0;
        bytes4[] memory selectors = new bytes4[](1);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.transferAsset.selector;

        // Create a FacetCut array with a single element
        FacetCut[] memory facetCuts = new FacetCut[](1);

        // Set the facetCut target, action, and selectors
        facetCuts[0] = FacetCut({
            target: _this,
            action: FacetCutAction.ADD,
            selectors: selectors
        });
        return facetCuts;
    }

    /**
     * @notice Transfers an asset from the sender to the buyer.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures that the sender and buyer addresses are valid, and that the token amount and price are greater than zero.
     * It checks the FEXSE token allowance and balance of the buyer, and the asset token approval and balance of the sender.
     * It then transfers the FEXSE tokens from the buyer to the sender, and the asset tokens from the sender to the buyer.
     * Finally, it updates the asset's user token information and emits a TransferExecuted event.
     * @param sender The address of the asset sender.
     * @param buyer The address of the asset buyer.
     * @param assetId The ID of the asset being transferred.
     * @param tokenAmount The amount of asset tokens being transferred.
     * @param tokenPrice The price of each asset token in FEXSE tokens.
     */
    function transferAsset(
        address sender,
        address buyer,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 tokenPrice
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(address(sender) != address(0), "Invalid sender address");
        require(address(buyer) != address(0), "Invalid buyer address");
        require(tokenAmount > 0, "Token amount must be greater than zero");
        require(tokenPrice > 0, "Token price must be greater than zero");

        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        //uint256 fexsePrice = IFexsePriceFetcher(address(this)).getFexsePrice();

        uint256 fexseAmount = tokenPrice * tokenAmount;

        require(
            IERC20(data.fexseToken).allowance(buyer, address(this)) >=
                fexseAmount,
            "FEXSE allowance too low"
        );

        require(
            IAssetToken(asset.tokenContract).isApprovedForAll(
                sender,
                address(this)
            ) == true,
            "asset is not approved"
        );

        require(
            IERC20(data.fexseToken).balanceOf(buyer) >= fexseAmount,
            "Insufficient fexse balance in buyer"
        );

        require(
            IAssetToken(asset.tokenContract).balanceOf(sender, assetId) >=
                tokenAmount,
            "sender does not have enough asset "
        );

        require(
            data.fexseToken.transferFrom(buyer, sender, fexseAmount),
            "FEXSE transfer failed"
        );

        IAssetToken(asset.tokenContract).safeTransferFrom(
            sender,
            buyer,
            assetId,
            tokenAmount,
            ""
        );

        asset.userTokenInfo[sender].tokensForSale -= tokenAmount;
        asset.userTokenInfo[sender].salePrices = 0;

        emit TransferExecuted(sender, buyer, assetId, tokenAmount, fexseAmount);
    }
}
