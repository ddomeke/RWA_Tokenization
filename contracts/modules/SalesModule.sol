// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @file SalesModule.sol
 * @dev This file is part of the RWATokenization project and contains the SalesModule contract.
 *
 * Imports:
 * - ModularInternal.sol: Provides internal modular functionality.
 * - IERC20.sol: Interface for the ERC20 standard.
 * - Strings.sol: Utility functions for string operations.
 * - AssetToken.sol: AssetToken contract for tokenized assets.
 * - IRWATokenization.sol: Interface for the RWATokenization project.
 */

import "../core/abstracts/ModularInternal.sol";
import "../token/ERC20/IERC20.sol";
import "../utils/Strings.sol";
import {AssetToken} from "../token/AssetToken.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";

/**
 * @title SalesModule
 * @dev This contract is a module for handling sales within the RWATokenization system.
 * It extends the ModularInternal contract to leverage modular functionalities.
 */
contract SalesModule is ModularInternal {
    using AppStorage for AppStorage.Layout;

    IERC20 public usdt;
    address public owner;
    uint256 public price; // Price of 1 token in USDT (e.g., 1 token = 1 USDT => price = 1e6 for 6 decimals)

    address public appAddress;

    uint256 private constant FEXSE_DECIMALS = 10 ** 18; // 18 decimals for FEXSE
    uint256 private constant FEXSE_PRICE_IN_USDT = 45 * 10 ** 3; // 0.045 USDT represented as 45 (scaled by 10^3)

    // Event to log profit distribution
    event TokensSold(
        uint256 assetId,
        address buyer,
        uint256 totalTokens,
        uint256 tokenPrice
    );
    address immutable _this;

    /**
     * @dev Constructor for the SalesModule contract.
     * @param _appAddress The address of the application contract.
     *
     * Initializes the contract by setting the contract's own address and the application address.
     * Grants the ADMIN_ROLE to the deployer of the contract and the application address.
     */
    constructor(address _appAddress, address _usdt, uint256 _price) {
        _this = address(this);
        usdt = IERC20(_usdt);
        owner = msg.sender;
        price = _price;
        appAddress = _appAddress;
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, _appAddress);
    }

    /**
     * @notice Returns an array of FacetCut structs representing the module facets.
     * @dev This function creates an array of function selectors and a FacetCut array with a single element.
     *      The FacetCut array is populated with the target, action, and selectors.
     * @return facetCuts An array of FacetCut structs.
     */
    function moduleFacets() external view returns (FacetCut[] memory) {
        uint256 selectorIndex = 0;
        bytes4[] memory selectors = new bytes4[](3);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.setPrice.selector;
        selectors[selectorIndex++] = this.buyTokens.selector;
        selectors[selectorIndex++] = this.buyFexse.selector;

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
     * @notice Allows the purchase of tokens for a specified asset.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures that the buyer has sufficient balance and allowance of the sale currency.
     * If the sale currency is the fexseToken, the cost is adjusted according to FEXSE_DECIMALS and FEXSE_PRICE_IN_USDT.
     * Otherwise, a service fee of 0.5% is added to the cost.
     * The function transfers the sale currency from the buyer to the contract and transfers the asset tokens from the contract to the buyer.
     * Emits a TokensSold event upon successful purchase.
     * @param assetId The ID of the asset to purchase tokens for.
     * @param tokenAmount The amount of tokens to purchase.
     * @param tokenPrice The price per token.
     * @param saleCurrency The address of the currency used for the sale.
     */
    function buyTokens(
        uint256 assetId,
        uint256 tokenAmount,
        uint256 tokenPrice,
        address saleCurrency
    ) external nonReentrant {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        address buyer = msg.sender;
        address sender = data.deployer;
        uint256 servideFeeAmount;
        uint256 cost = tokenPrice * tokenAmount;

        require(asset.id != 0, "Asset already exists");
        require(tokenAmount > 0, "Total tokens must be greater than zero");
        require(tokenPrice > 0, "Token price must be greater than zero");
        require(
            IERC20(saleCurrency).balanceOf(buyer) >= cost,
            "Insufficient saleCurrency balance"
        );
        require(
            IERC20(saleCurrency).allowance(buyer, address(this)) >= cost,
            "Insufficient saleCurrency allowance"
        );

        if (saleCurrency == address(data.fexseToken)) {
            cost = (cost * FEXSE_DECIMALS) / (FEXSE_PRICE_IN_USDT);
        } else {
            servideFeeAmount = (cost * 5) / 1000;
            cost = cost + servideFeeAmount;
        }
        IERC20(saleCurrency).transferFrom(buyer, sender, cost);
        

        IAssetToken(asset.tokenContract).setApprovalForAll(address(this), true);

        IAssetToken(asset.tokenContract).safeTransferFrom(
            sender,
            buyer,
            assetId,
            tokenAmount,
            ""
        );

        emit TokensSold(assetId, buyer, tokenAmount, tokenPrice);
    }

    /**
     * @notice Allows a user to buy Fexse tokens using USDT.
     * @dev This function is protected against reentrancy attacks using the nonReentrant modifier.
     * @param tokenAmount The amount of Fexse tokens the user wants to buy.
     * Requirements:
     * - `tokenAmount` must be greater than 0.
     * - The buyer must have an allowance of USDT for the contract that is at least equal to `usdtAmount`.
     * - The buyer must have a USDT balance that is at least equal to `usdtAmount`.
     * - The contract must have a balance of Fexse tokens that is at least equal to `tokenAmount`.
     * - The transfer of USDT from the buyer to the contract must succeed.
     * - The transfer of Fexse tokens from the contract to the buyer must succeed.
     */
    function buyFexse(uint256 tokenAmount) external nonReentrant {
        AppStorage.Layout storage data = AppStorage.layout();

        address buyer = msg.sender;
        address sender = address(this);

        require(tokenAmount > 0, "You must buy at least 1 token");

        uint256 usdtAmount = tokenAmount * price; // Total USDT required

        // Check USDT allowance and balance
        require(
            IERC20(usdt).allowance(buyer, address(this)) >= usdtAmount,
            "USDT allowance too low"
        );
        require(
            IERC20(usdt).balanceOf(buyer) >= usdtAmount,
            "Insufficient USDT balance"
        );

        // Check if contract has enough tokens to sell
        require(
            IERC20(data.fexseToken).balanceOf(sender) >= tokenAmount,
            "Insufficient token balance in contract"
        );

        // Transfer USDT from buyer to contract
        require(
            IERC20(usdt).transferFrom(buyer, sender, usdtAmount),
            "USDT transfer failed"
        );

        // Transfer tokens from contract to buyer
        require(
            IERC20(data.fexseToken).transferFrom(sender, buyer, tokenAmount),
            "Token transfer failed"
        );
    }

    /**
     * @notice Sets the price of the token.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It is protected against reentrancy attacks by the nonReentrant modifier.
     * @param _price The new price of the token.
     */
    function setPrice(
        uint256 _price
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        price = _price;
    }
}
