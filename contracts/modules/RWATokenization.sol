// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "../core/abstracts/ModularInternal.sol";
import "../token/ERC20/IERC20.sol";
import "../utils/Strings.sol";
import {AssetToken} from "../token/AssetToken.sol";
import {IFexse} from "../interfaces/IFexse.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import {IMarketPlace} from "../interfaces/IMarketPlace.sol";
import "hardhat/console.sol";

contract RWATokenization is ModularInternal {
    using AppStorage for AppStorage.Layout;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IFexse public fexse;
    IMarketPlace public marketContract;

    // Admin address for managing token transfers
    address public admin;

    uint256 private constant FEXSE_DECIMALS = 10 ** 18; // 18 decimals for FEXSE
    uint256 private constant FEXSE_PRICE_IN_USDT = 45; // 0.045 USDT represented as 45 (scaled by 10^3)

    // Mapping to store assets by ID

    // Event to log profit distribution
    event ProfitDistributed(
        uint256 assetId,
        uint256 totalProfit,
        uint256 amountPerToken
    );
    event AssetUpdated(uint256 assetId, uint256 newTokenPrice);
    event TokensPurchased(
        address buyer,
        uint256 assetId,
        uint256 amount,
        uint256 cost
    );
    event TokensSold(
        address buyer,
        address seller,
        uint256 assetId,
        uint256 amount,
        uint256 cost
    );
    event AssetCreated(
        uint256 assetId,
        address tokenContract,
        uint256 totalTokens,
        uint256 tokenPrice
    );
    event fexseContractUpdated(address oldToken, address newToken);
    event Claimed(
        address sender,
        uint256 fexseAmount
    );
    event MarketPlaceContractUpdated(address oldContract, address newContract);

    address immutable _this;

    constructor(
        address _marketContract
    ) {
        _this = address(this);
        admin = msg.sender;
        marketContract = IMarketPlace(_marketContract);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Returns an array of ⁠ FacetCut ⁠ structs, which define the functions (selectors)
     *      provided by this module. This is used to register the module's functions
     *      with the modular system.
     * @return FacetCut[] Array of ⁠ FacetCut ⁠ structs representing function selectors.
     */
    function moduleFacets() external view returns (FacetCut[] memory) {
        uint256 selectorIndex = 0;
        bytes4[] memory selectors = new bytes4[](17);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.createAsset.selector;
        selectors[selectorIndex++] = this.getAssetId.selector;
        selectors[selectorIndex++] = this.getTotalTokens.selector;
        selectors[selectorIndex++] = this.getTokenPrice.selector;
        selectors[selectorIndex++] = this.getTotalProfit.selector;
        selectors[selectorIndex++] = this.getLastDistributed.selector;
        selectors[selectorIndex++] = this.getUri.selector;
        selectors[selectorIndex++] = this.getTokenContractAddress.selector;
        selectors[selectorIndex++] = this.getTokenHolders.selector;
        selectors[selectorIndex++] = this.getHolderBalance.selector;
        selectors[selectorIndex++] = this.getPendingProfits.selector;
        selectors[selectorIndex++] = this.distributeProfit.selector;
        selectors[selectorIndex++] = this.claimProfit.selector;
        selectors[selectorIndex++] = this.updateAsset.selector;
        selectors[selectorIndex++] = this.setFexseAddress.selector;
        selectors[selectorIndex++] = this.updateHoldings.selector;
        selectors[selectorIndex++] = this.updateMarketPlaceContract.selector;

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

    // Function to create a new asset and issue tokens to the admin
    function createAsset(
        uint256 assetId,
        uint256 totalTokens,
        uint256 tokenPrice,
        string memory assetUri
    ) external nonReentrant onlyRole(ADMIN_ROLE) {

        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id == 0, "Asset already exists");
        require(totalTokens > 0, "Total tokens must be greater than zero");
        require(tokenPrice > 0, "Token price must be greater than zero");

        // Deploy a new instance of AssetToken
        AssetToken token = new AssetToken(
            assetUri, // URI for metadata
            address(this),
            address(marketContract)
        );

        address tokenAddress = address(token);

        // Store the deployed contract information in the mapping
        asset.id = assetId;
        asset.totalTokens = totalTokens;
        asset.tokenPrice = tokenPrice;
        asset.uri = assetUri;
        asset.tokenContract = IAssetToken(tokenAddress);

        token.mint(admin, assetId, totalTokens, "");

        emit AssetCreated(assetId, address(token), totalTokens, tokenPrice);
    }

    // Function to get the ID of an asset
    function getAssetId(uint256 assetId) external view returns (uint256) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.id;
    }

    // Function to get the total tokens of an asset
    function getTotalTokens(uint256 assetId) external view returns (uint256) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.totalTokens;
    }

    // Function to get the token price of an asset
    function getTokenPrice(uint256 assetId) external view returns (uint256) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.tokenPrice;
    }

    // Function to get the total profit of an asset
    function getTotalProfit(uint256 assetId) external view returns (uint256) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.totalProfit;
    }

    // Function to get the last distributed timestamp of an asset
    function getLastDistributed(
        uint256 assetId
    ) external view returns (uint256) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.lastDistributed;
    }

    // Function to get the URI of an asset
    function getUri(uint256 assetId) external view returns (string memory) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return string(abi.encodePacked(asset.uri));
    }

    // Function to get the token contract address of an asset
    function getTokenContractAddress(
        uint256 assetId
    ) external view returns (address) {

        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return address(asset.tokenContract);
    }

    // Function to get the token holders of an asset
    function getTokenHolders(
        uint256 assetId
    ) external view returns (address[] memory) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.tokenHolders;
    }

    // Function to get the holdings of a specific holder for an asset
    function getHolderBalance(
        uint256 assetId,
        address holder
    ) external view returns (uint256) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.userTokenInfo[holder].holdings;
    }

    // Function to get the pending Profits of a specific holder for an asset
    function getPendingProfits(
        uint256 assetId,
        address holder
    ) external view returns (uint256) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(asset.id != 0, "Asset does not exist");
        return asset.userTokenInfo[holder].pendingProfits;
    }

    // Function to distribute profit to token holders
    function distributeProfit(
        uint256 assetId,
        uint256 profitAmount
    ) public nonReentrant onlyRole(ADMIN_ROLE) {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        // Calculate profit per token
        uint256 profitPerToken = profitAmount / asset.totalTokens;

        // Distribute profit to each holder
        for (uint256 i = 0; i < asset.tokenHolders.length; i++) {
            address holder = asset.tokenHolders[i];
            uint256 holderTokens = asset.userTokenInfo[holder].holdings;
            uint256 holderProfit = holderTokens * profitPerToken;
            asset.userTokenInfo[holder].pendingProfits =
                asset.userTokenInfo[holder].pendingProfits +
                holderProfit;
        }

        asset.totalProfit = asset.totalProfit + profitAmount;
        asset.lastDistributed = block.timestamp;

        // TODO: fexse tranfer fiyta dönüşümü chainlink integration
        uint256 fexse_amount = (profitAmount * FEXSE_DECIMALS) /
            (FEXSE_PRICE_IN_USDT * (10 ** 3));

        emit ProfitDistributed(assetId, fexse_amount, profitPerToken);
    }

    // Holders can claim profits themselves
    function claimProfit(uint256 assetId) public nonReentrant {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        uint256 amount = asset.userTokenInfo[msg.sender].pendingProfits;
        require(amount > 0, "No profit to claim");
        asset.userTokenInfo[msg.sender].pendingProfits = 0;

        // TODO: fexse tranfer fiyta dönüşümü chainlink integration
        uint256 fexse_amount = (amount * FEXSE_DECIMALS) /
            (FEXSE_PRICE_IN_USDT * (10 ** 3));

        fexse.transferFrom(admin, msg.sender, fexse_amount);

        emit Claimed(msg.sender, assetId);
    }

    // New function to update the token price for an existing asset
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

    function setFexseAddress(
        IFexse _fexseToken
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(
            address(_fexseToken) != address(0),
            "Invalid _fexseToken address"
        );

        address oldContract = address(fexse);
        fexse = _fexseToken;

        emit fexseContractUpdated(oldContract, address(_fexseToken));
    }

    function updateHoldings(
        address account,
        uint256 assetId,
        uint256 balance
    ) external {

        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(
            (msg.sender == address(asset.tokenContract)) ||
                (msg.sender == address(this)),
            "Unauthorized"
        );

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
    }

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

    // Function to remove holdings of a specific address
    function _removeHoldings(uint256 assetId, address holder) internal {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];

        require(
            asset.userTokenInfo[holder].holdings > 0,
            "No holdings to remove"
        );

        delete asset.userTokenInfo[holder].holdings;
    }

    // Function to remove pending profits of a specific address
    function _removePendingProfits(uint256 assetId, address holder) internal {
        
        AppStorage.Layout storage data = AppStorage.layout();
        Asset storage asset = data.assets[assetId];
        
        require(
            asset.userTokenInfo[holder].pendingProfits > 0,
            "No pending profits to remove"
        );

        delete asset.userTokenInfo[holder].pendingProfits;
    }

    // Function to clear all mappings and arrays for a specific holder
    function clearHolderData(uint256 assetId, address holder) internal {
        _removeHolder(assetId, holder);
        _removeHoldings(assetId, holder);
        _removePendingProfits(assetId, holder);
    }


    function updateMarketPlaceContract(address newContract) external onlyRole(ADMIN_ROLE) {
        require(newContract != address(0), "Invalid Market contract address");

        address oldContract = address(marketContract);
        marketContract = IMarketPlace(newContract);

        emit MarketPlaceContractUpdated(oldContract, newContract);
    }
}
