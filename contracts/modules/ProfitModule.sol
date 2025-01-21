// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @file RWATokenization.sol
 * @dev This file is part of the RWATokenization module. It imports several dependencies:
 * - ModularInternal.sol: Provides internal modular functionality.
 * - IERC20.sol: Interface for the ERC20 token standard.
 * - Strings.sol: Utility library for string operations.
 * - AssetToken.sol: Contract for asset token implementation.
 * - IRWATokenization.sol: Interface for RWATokenization.
 */
import "../core/abstracts/ModularInternal.sol";
import "../token/ERC20/IERC20.sol";
import "../utils/Strings.sol";

/**
 * @title RWATokenization
 * @dev This contract is part of the RWATokenization module and inherits from the ModularInternal contract.
 * It is designed to handle the tokenization of Real World Assets (RWA).
 */
contract ProfitModule is ModularInternal {
    using AppStorage for AppStorage.Layout;

    address public appAddress;

    // Event to log profit distribution
    event ProfitDistributed(
        uint256 assetId,
        uint256 startIndex,
        uint256 endIndex
    );
    event Claimed(
        address indexed user,
        uint256[] assetIds,
        uint256 totalFexseAmount
    );
    event AssetLowerLimitUpdated(uint256 assetId, uint256 newTokenLowerLimit);

    address immutable _this;

    /**
     * @dev Constructor for the RWATokenization contract.
     * @param _appAddress The address of the application to be granted the ADMIN_ROLE.
     *
     * This constructor initializes the contract by setting the contract's own address,
     * assigning the provided application address, and granting the ADMIN_ROLE to both
     * the deployer (msg.sender) and the provided application address (_appAddress).
     */
    constructor(address _appAddress) {
        _this = address(this);
        appAddress = _appAddress;
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, _appAddress);
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
        selectors[selectorIndex++] = this.getTotalProfit.selector;
        selectors[selectorIndex++] = this.getLastDistributed.selector;
        selectors[selectorIndex++] = this.getPendingProfits.selector;
        selectors[selectorIndex++] = this.distributeProfit.selector;
        selectors[selectorIndex++] = this.updateAssetLowerLimit.selector;
        selectors[selectorIndex++] = this.claimProfit.selector;

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
     * @notice Retrieves the total profit for a given asset.
     * @param assetId The unique identifier of the asset.
     * @return The total profit associated with the specified asset.
     * @dev This function reads from the AppStorage to get the asset details.
     *      It requires that the asset with the given ID exists.
     */
    function getTotalProfit(uint256 assetId) external view returns (uint256) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.totalProfit;
    }

    /**
     * @notice Retrieves the timestamp of the last distribution for a given asset.
     * @param assetId The unique identifier of the asset.
     * @return The timestamp of the last distribution for the specified asset.
     * @dev Reverts if the asset does not exist.
     */
    function getLastDistributed(
        uint256 assetId
    ) external view returns (uint256) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.lastDistributed;
    }

    /**
     * @notice Retrieves the pending profits for a specific asset holder.
     * @param assetId The ID of the asset.
     * @param holder The address of the asset holder.
     * @return The amount of pending profits for the specified asset holder.
     * @dev Reverts if the asset does not exist.
     */
    function getPendingProfits(
        uint256 assetId,
        address holder
    ) external view returns (uint256) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.userTokenInfo[holder].pendingProfits;
    }

    /**
     * @notice Distributes profit to token holders within a specified range.
     * @dev This function can only be called by an account with the ADMIN_ROLE and is protected against reentrancy.
     * @param assetId The ID of the asset for which profit is being distributed.
     * @param profitPerToken The amount of profit to be distributed per token, denominated in fexse currency.
     * @param startIndex The starting index of the token holders array to distribute profit.
     * @param endIndex The ending index of the token holders array to distribute profit.
     *
     * Requirements:
     * - The caller must have the ADMIN_ROLE.
     * - The function is non-reentrant.
     *
     * Emits a {ProfitDistributed} event.
     */
    function distributeProfit(
        uint256 assetId,
        uint256 profitPerToken, //fexse currency
        uint256 startIndex,
        uint256 endIndex
    ) public nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        uint256 tokenLowerLimit = asset.tokenLowerLimit;

        for (uint256 i = startIndex; i <= endIndex; i++) {
            address holder = asset.tokenHolders[i];
            uint256 holderTokens = asset.userTokenInfo[holder].holdings;
            if (holderTokens >= tokenLowerLimit) {
                uint256 holderProfit = holderTokens * profitPerToken;
                asset.userTokenInfo[holder].pendingProfits += holderProfit;
            }
        }

        if (endIndex == asset.tokenHolders.length) {
            asset.totalProfit += profitPerToken * asset.totalTokens;
            asset.lastDistributed = block.timestamp;
        }

        emit ProfitDistributed(assetId, startIndex, endIndex);
    }

    function updateAssetLowerLimit(
        uint256 assetId,
        uint256 newTokenLowerLimit
    ) public nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");

        asset.tokenLowerLimit = newTokenLowerLimit;

        emit AssetLowerLimitUpdated(assetId, newTokenLowerLimit);
    }

    /**
     * @notice Allows a user to claim profit for the specified asset IDs.
     * @dev This function is protected against reentrancy attacks using the nonReentrant modifier.
     * @param assetIds An array of asset IDs for which the user wants to claim profit.
     */
    function claimProfit(uint256[] calldata assetIds) public nonReentrant {
        AppStorage.Layout storage data = AppStorage.layout();

        uint256 totalFexseAmount = 0;
        uint256[] memory claimedAssetIds = new uint256[](assetIds.length);

        for (uint256 i = 0; i < assetIds.length; i++) {
            uint256 assetId = assetIds[i];

            uint256 fexseAmount = data
                .assets[assetId]
                .userTokenInfo[msg.sender]
                .pendingProfits;
            require(
                fexseAmount > 0,
                "No profit to claim for one of the assets"
            );

            data.assets[assetId].userTokenInfo[msg.sender].pendingProfits = 0;

            totalFexseAmount += fexseAmount;

            claimedAssetIds[i] = assetId;
        }

        require(
            totalFexseAmount > 0,
            "Total FEXSE amount must be greater than zero"
        );
        data.fexseToken.transferFrom(
            data.deployer,
            msg.sender,
            totalFexseAmount
        );

        emit Claimed(msg.sender, claimedAssetIds, totalFexseAmount);
    }
}
