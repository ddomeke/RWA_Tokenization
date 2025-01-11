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
        bytes4[] memory selectors = new bytes4[](6);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.transferAsset.selector;
        selectors[selectorIndex++] = this.lockFexseToBeBought.selector;
        selectors[selectorIndex++] = this.unlockFexse.selector;
        selectors[selectorIndex++] = this.lockTokensToBeSold.selector;
        selectors[selectorIndex++] = this.unlockTokensToBeSold.selector;
        selectors[selectorIndex++] = this.setFexseAddress.selector;

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
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(address(sender) != address(0), "Invalid sender address");
        require(address(buyer) != address(0), "Invalid buyer address");
        require(tokenAmount > 0, "Token amount must be greater than zero");
        require(tokenPrice > 0, "Token price must be greater than zero");

        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        uint256 cost = tokenPrice * tokenAmount;

        // TODO: fexse tranfer fiyta dönüşümü chainlink integration
        // uint256 fexse_amount = (cost * FEXSE_DECIMALS) /
        //     (FEXSE_PRICE_IN_USDT * (10 ** 3));

        uint256 fexseAmount = tokenPrice * tokenAmount;

        // TODO: servicesfee  backend de hesaplanmadığı durumda burda hesaplayalım.
        uint256 servideFeeAmount = (fexseAmount * 5) / 1000;

        // TODO : kilitli mi diye kontrol edelim. approve kontrol edelim. fexse amountu kotrol edelim
        // TODO: başka bir emir yoksa tüm fexseler unlock edilmeli
        data.fexseToken.unlock(buyer, (fexseAmount + servideFeeAmount));

        require(
            data.fexseToken.transferFrom(
                buyer,
                address(this),
                servideFeeAmount
            ),
            "FEXSE transfer failed"
        );

        require(
            data.fexseToken.transferFrom(buyer, sender, fexseAmount),
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
            fexseAmount,
            cost
        );
    }

    /**
     * @notice Locks a specified amount of FEXSE tokens for a given owner.
     * @dev This function locks a specified amount of FEXSE tokens for a given owner.
     *      It requires the caller to have the ADMIN_ROLE and is protected against reentrancy.
     * @param owner The address of the owner whose FEXSE tokens are to be locked.
     * @param fexseLockedAmount The amount of FEXSE tokens to be locked.
     */
    function lockFexseToBeBought(
        address owner,
        uint256 fexseLockedAmount
    ) public nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();

        uint256 fexseAmount = data.fexseToken.balanceOf(owner);

        require(fexseAmount >= fexseLockedAmount, "Insufficient fexse balance");

        data.fexseToken.lock(owner, fexseLockedAmount);

        emit Fexselocked(owner, fexseLockedAmount);
    }

    /**
     * @notice Unlocks a specified amount of Fexse tokens for a given owner.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures that the owner has a sufficient balance of Fexse tokens before unlocking.
     * Emits a {FexseUnlocked} event upon successful unlocking.
     * @param owner The address of the token owner whose tokens are to be unlocked.
     * @param fexseLockedAmount The amount of Fexse tokens to unlock.
     */
    function unlockFexse(
        address owner,
        uint256 fexseLockedAmount
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();

        uint256 fexseAmount = data.fexseToken.balanceOf(owner);

        require(fexseAmount >= fexseLockedAmount, "Insufficient token balance");

        data.fexseToken.unlock(owner, fexseLockedAmount);

        emit FexseUnlocked(owner, fexseLockedAmount);
    }

    /**
     * @notice Locks a specified amount of tokens to be sold for a given asset.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It locks the specified amount of tokens for sale and sets the sale price.
     * Emits a {TokensLockedForSale} event.
     * @param owner The address of the token owner.
     * @param assetId The ID of the asset.
     * @param tokenAmount The amount of tokens to be locked for sale.
     * @param salePrice The sale price for the tokens.
     * @dev Requires the token owner's holdings to be greater than or equal to the token amount.
     */
    function lockTokensToBeSold(
        address owner,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 salePrice
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

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

    /**
     * @notice Unlocks tokens to be sold by the owner.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures that the owner has sufficient token balance before unlocking the tokens.
     * The function interacts with the IAssetToken contract to unlock the tokens.
     * It also updates the user's token information by reducing the tokens for sale and resetting the sale price.
     * Emits a {TokensUnlocked} event.
     * @param owner The address of the token owner.
     * @param assetId The ID of the asset.
     * @param tokenAmount The amount of tokens to be unlocked.
     * @param salePrice The sale price of the tokens.
     */
    function unlockTokensToBeSold(
        address owner,
        uint256 assetId,
        uint256 tokenAmount,
        uint256 salePrice
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

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

    /**
     * @notice Sets the address of the Fexse token contract.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures that the provided address is not the zero address.
     * Emits a `fexseContractUpdated` event upon successful update.
     * Uses the `nonReentrant` modifier to prevent reentrancy attacks.
     * @param _fexseToken The address of the new Fexse token contract.
     */
    function setFexseAddress(
        IFexse _fexseToken
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(
            address(_fexseToken) != address(0),
            "Invalid _fexseToken address"
        );

        AppStorage.Layout storage data = AppStorage.layout();

        address oldContract = address(data.fexseToken);

        data.fexseToken = _fexseToken;

        emit fexseContractUpdated(oldContract, address(_fexseToken));
    }
}
