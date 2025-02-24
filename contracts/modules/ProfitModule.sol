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
    event ProfitDistributed(uint256 assetId, uint256 ProfitInfoLength);
    event Claimed(
        address indexed user,
        uint256[] assetIds,
        uint256 totalFexseAmount
    );
    event AssetLowerLimitUpdated(uint256 assetId, uint256 newTokenLowerLimit);
    event AssetPaused(uint256 assetId);
    event AssetUnPaused(uint256 assetId);
    event AssetProfitPeriodUpdated(uint256 assetId, uint256 newProfitPeriod);

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
        bytes4[] memory selectors = new bytes4[](10);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.getTotalProfit.selector;
        selectors[selectorIndex++] = this.getLastDistributed.selector;
        selectors[selectorIndex++] = this.getPendingProfits.selector;
        selectors[selectorIndex++] = this.getProfitPeriod.selector;
        selectors[selectorIndex++] = this.distributeProfit.selector;
        selectors[selectorIndex++] = this.updateAssetLowerLimit.selector;
        selectors[selectorIndex++] = this.updateProfitPeriod.selector;
        selectors[selectorIndex++] = this.claimProfit.selector;
        selectors[selectorIndex++] = this.pauseAsset.selector;
        selectors[selectorIndex++] = this.unPauseAsset.selector;

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
     * The asset with the given ID must exist.
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
     * @notice Retrieves the profit period for a given asset.
     * @param assetId The ID of the asset for which to retrieve the profit period.
     * @return The profit period of the specified asset.
     * @dev Reverts if the asset does not exist.
     */
    function getProfitPeriod(
        uint256 assetId
    ) external view returns (uint256) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.profitPeriod;
    }

    /**
     * @notice Distributes profits to asset holders.
     * @dev This function is protected by the `nonReentrant` and `onlyRole(ADMIN_ROLE)` modifiers.
     * @param assetId The ID of the asset for which profits are being distributed.
     * @param profits An array of `ProfitInfo` structs containing the holder addresses and their respective profit amounts.
     *
     * Requirements:
     * - The caller must have the `ADMIN_ROLE`.
     * - The function cannot be reentered.
     *
     * Emits a {ProfitDistributed} event indicating the asset ID and the number of profit distributions.
     */
    function distributeProfit(
        uint256 assetId,
        ProfitInfo[] calldata profits
    ) public nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        uint256 timeElapsed = block.timestamp - asset.lastDistributed;
        uint256 requiredWaitTime = (asset.profitPeriod * 86400 * 90) / 100;

        require(
            timeElapsed >= requiredWaitTime,
            "Profit distribution too soon"
        );

        for (uint256 i = 0; i < profits.length; i++) {
            address holder = profits[i].holder;
            uint256 profitAmount = profits[i].profitAmount;

            asset.userTokenInfo[holder].pendingProfits += profitAmount;
        }

        emit ProfitDistributed(assetId, profits.length);
    }

    /**
     * @notice Updates the lower limit of tokens for a specific asset.
     * @dev This function can only be called by an account with the ADMIN_ROLE and is protected against reentrancy.
     * @param assetId The ID of the asset to update.
     * @param newTokenLowerLimit The new lower limit of tokens for the asset.
     * @dev The asset must exist (asset.id != 0).
     * @dev Emits an {AssetLowerLimitUpdated} event when the asset's lower limit is updated.
     */
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
     * @notice Updates the profit period of a specific asset.
     * @dev This function can only be called by an account with the ADMIN_ROLE and is protected against reentrancy.
     * @param assetId The ID of the asset whose profit period is to be updated.
     * @param newProfitPeriod The new profit period to be set for the asset.
     * @dev The asset must exist (asset.id != 0).
     * @dev Emits an {AssetProfitPeriodUpdated} when the profit period of an asset is updated.
     */
    function updateProfitPeriod(
        uint256 assetId,
        uint256 newProfitPeriod
    ) public nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");

        asset.profitPeriod = newProfitPeriod;

        emit AssetProfitPeriodUpdated(assetId, newProfitPeriod);
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

    /**
     * @notice Pauses the asset associated with the given asset ID.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It uses the nonReentrant modifier to prevent reentrancy attacks.
     * @param assetId The ID of the asset to be paused.
     */
    function pauseAsset(
        uint256 assetId
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        IAssetToken(asset.tokenContract).pause();

        emit AssetPaused(assetId);
    }

    /**
     * @notice Unpauses the asset with the given assetId.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It uses the nonReentrant modifier to prevent reentrancy attacks.
     * @param assetId The ID of the asset to unpause.
     */
    function unPauseAsset(
        uint256 assetId
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        asset.lastDistributed = block.timestamp;

        IAssetToken(asset.tokenContract).unpause();

        emit AssetUnPaused(assetId);
    }
}
