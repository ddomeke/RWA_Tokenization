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
import {AssetToken} from "../token/AssetToken.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import "hardhat/console.sol";

/**
 * @title RWATokenization
 * @dev This contract is part of the RWATokenization module and inherits from the ModularInternal contract.
 * It is designed to handle the tokenization of Real World Assets (RWA).
 */
contract RWATokenization is ModularInternal {
    using AppStorage for AppStorage.Layout;

    // Event to log profit distribution
    event AssetUpdated(uint256 assetId, uint256 newTokenPrice);

    event AssetCreated(
        uint256 assetId,
        address tokenContract,
        uint256 totalTokens,
        uint256 tokenPrice,
        string name,
        string symbol
    );

    event AssetHolderBalanceUpdated(
        address account,
        uint256 assetId,
        uint256 balance
    );
    event fexseContractUpdated(address oldToken, address newToken);

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
        bytes4[] memory selectors = new bytes4[](11);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.createAsset.selector;
        selectors[selectorIndex++] = this.getTotalTokens.selector;
        selectors[selectorIndex++] = this.getTokenPrice.selector;
        selectors[selectorIndex++] = this.getUri.selector;
        selectors[selectorIndex++] = this.getTokenContractAddress.selector;
        selectors[selectorIndex++] = this.getTokenHolders.selector;
        selectors[selectorIndex++] = this.getHolderBalance.selector;
        selectors[selectorIndex++] = this.sendToTheRealWorld.selector;
        selectors[selectorIndex++] = this.updateAsset.selector;
        selectors[selectorIndex++] = this.updateHoldings.selector;
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
     * @notice Creates a new asset with the specified parameters.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It deploys a new instance of the AssetToken contract and stores the asset information.
     * @param assetId The unique identifier for the asset.
     * @param totalTokens The total number of tokens to be created for the asset.
     * @param tokenPrice The price per token for the asset.
     * @param tokenLowerLimit The lower limit per holder for profit.
     * @param assetUri The URI for the asset's metadata.
     * @dev Reverts if the asset already exists.
     * @dev Reverts if the total number of tokens is zero.
     * @dev Reverts if the token price is zero.
     */
    function createAsset(
        uint256 assetId,
        uint256 totalTokens,
        uint256 tokenPrice,
        uint256 tokenLowerLimit,
        string memory assetUri,
        string memory name,
        string memory symbol
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id == 0, "Asset already exists");
        require(totalTokens > 0, "Total tokens must be greater than zero");
        require(tokenPrice > 0, "Token price must be greater than zero");
        require(
            tokenLowerLimit > 0,
            "Token lower limit must be greater than zero"
        );

        // Deploy a new instance of AssetToken
        AssetToken token = new AssetToken(
            name,
            symbol,
            assetUri, // URI for metadata
            address(this)
        );

        address tokenAddress = address(token);

        // Store the deployed contract information in the mapping
        asset.id = assetId;
        asset.totalTokens = totalTokens;
        asset.tokenPrice = tokenPrice;
        asset.uri = assetUri;
        asset.tokenContract = IAssetToken(tokenAddress);
        asset.tokenLowerLimit = tokenLowerLimit;

        token.mint(data.deployer, assetId, totalTokens, "");

        emit AssetCreated(
            assetId,
            address(token),
            totalTokens,
            tokenPrice,
            name,
            symbol
        );
    }

    /**
     * @notice Retrieves the total number of tokens for a specific asset.
     * @param assetId The unique identifier of the asset.
     * @return The total number of tokens associated with the asset.
     * Reverts if the asset does not exist.
     */
    function getTotalTokens(uint256 assetId) external view returns (uint256) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.totalTokens;
    }

    /**
     * @notice Retrieves the token price of a specified asset.
     * @param assetId The ID of the asset whose token price is being queried.
     * @return The token price of the specified asset.
     * @dev Reverts if the asset does not exist.
     */
    function getTokenPrice(uint256 assetId) external view returns (uint256) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.tokenPrice;
    }

    /**
     * @notice Retrieves the URI associated with a specific asset.
     * @dev This function fetches the URI of an asset from the storage layout.
     * @param assetId The unique identifier of the asset.
     * @return A string representing the URI of the asset.
     * @dev The asset must exist (asset ID should not be zero).
     */
    function getUri(uint256 assetId) external view returns (string memory) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return string(abi.encodePacked(asset.uri));
    }

    /**
     * @notice Retrieves the token contract address associated with a given asset ID.
     * @param assetId The ID of the asset for which to retrieve the token contract address.
     * @return The address of the token contract associated with the specified asset ID.
     * @dev Reverts if the asset with the given ID does not exist.
     */
    function getTokenContractAddress(
        uint256 assetId
    ) external view returns (address) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return address(asset.tokenContract);
    }

    /**
     * @notice Retrieves the list of token holders for a specific asset.
     * @param assetId The ID of the asset for which to retrieve token holders.
     * @return An array of addresses representing the token holders of the specified asset.
     * @dev Reverts if the asset does not exist.
     */
    function getTokenHolders(
        uint256 assetId
    ) external view returns (address[] memory) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.tokenHolders;
    }

    /**
     * @notice Retrieves the balance of a specific holder for a given asset.
     * @param assetId The ID of the asset.
     * @param holder The address of the holder whose balance is being queried.
     * @return The balance of the holder for the specified asset.
     * @dev Reverts if the asset does not exist.
     */
    function getHolderBalance(
        uint256 assetId,
        address holder
    ) external view returns (uint256) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.userTokenInfo[holder].holdings;
    }

    /**
     * @notice Updates the token price of an existing asset.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It uses the nonReentrant modifier to prevent reentrancy attacks.
     * @param assetId The ID of the asset to update.
     * @param newTokenPrice The new token price to set for the asset.
     * @dev The asset must exist (asset ID should not be 0).
     * Emits an {AssetUpdated} event when the asset's token price is updated.
     */
    function updateAsset(
        uint256 assetId,
        uint256 newTokenPrice
    ) public nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");

        asset.tokenPrice = newTokenPrice;

        emit AssetUpdated(assetId, newTokenPrice);
    }

    /**
     * @notice Sends the specified amount of an asset to the real world.
     * @dev This function burns the specified amount of tokens from the given account.
     * @param account The address of the account from which the tokens will be burned.
     * @param assetId The ID of the asset to be sent to the real world.
     * @param amount The amount of the asset to be sent.
     * @dev The asset must exist (asset.id != 0).
     * @dev The caller must have the ADMIN_ROLE.
     * @dev The function must not be reentrant.
     */
    function sendToTheRealWorld(
        address account,
        uint256 assetId,
        uint256 amount
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        
        asset.totalTokens -= amount;

        IAssetToken(asset.tokenContract).burn(account, assetId, amount);

    }

    /**
     * @notice Updates the holdings of a specific account for a given asset.
     * @dev This function can only be called by the token contract or the contract itself.
     * @param account The address of the account whose holdings are to be updated.
     * @param assetId The ID of the asset for which the holdings are being updated.
     * @param balance The new balance of the account for the specified asset.
     * @dev The caller must be the token contract or the contract itself.
     */
    function updateHoldings(
        address account,
        uint256 assetId,
        uint256 balance
    ) external {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require((msg.sender == address(asset.tokenContract)), "Unauthorized");

        uint256 currentBalance = asset.userTokenInfo[account].holdings;

        // Eğer balance değişmemişse işlemi atla
        if (currentBalance == balance) {
            return;
        }

        // Check if balance is zero, remove holder
        if (balance == 0 && currentBalance > 0) {
            clearHolderData(assetId, account);
        }
        // If balance > 0 and not already a holder, add holder
        else if (balance > 0 && currentBalance == 0) {
            asset.tokenHolders.push(account);
        }

        // Update holdings
        asset.userTokenInfo[account].holdings = balance;

        emit AssetHolderBalanceUpdated(account, assetId, balance);
    }

    /**
     * @dev Internal function to remove a holder from the list of token holders for a specific asset.
     * @param assetId The ID of the asset from which the holder will be removed.
     * @param holder The address of the holder to be removed.
     */
    function _removeHolder(uint256 assetId, address holder) internal {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        uint256 length = asset.tokenHolders.length;

        for (uint256 i = 0; i < length; i++) {
            if (asset.tokenHolders[i] == holder) {
                asset.tokenHolders[i] = asset.tokenHolders[length - 1];
                asset.tokenHolders.pop();
                break;
            }
        }
    }

    /**
     * @dev Internal function to remove holdings of a specific asset for a given holder.
     * @param assetId The ID of the asset from which holdings are to be removed.
     * @param holder The address of the holder whose holdings are to be removed.
     */
    function _removeHoldings(uint256 assetId, address holder) internal {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        delete asset.userTokenInfo[holder].holdings;
    }

    /**
     * @dev Internal function to remove pending profits for a specific asset holder.
     * @param assetId The ID of the asset.
     * @param holder The address of the asset holder.
     */
    function _removePendingProfits(uint256 assetId, address holder) internal {
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        delete asset.userTokenInfo[holder].pendingProfits;
    }

    /**
     * @dev Clears all data associated with a specific holder for a given asset.
     * This includes removing the holder from the asset's holder list,
     * removing their holdings, and removing any pending profits.
     *
     * @param assetId The ID of the asset for which the holder data is to be cleared.
     * @param holder The address of the holder whose data is to be cleared.
     */
    function clearHolderData(uint256 assetId, address holder) internal {
        _removeHolder(assetId, holder);
        _removeHoldings(assetId, holder);
        _removePendingProfits(assetId, holder);
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
