// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @file Compliance.sol
 * @notice This file is part of the RWATokenization project and is located at /c:/Users/duran/RWATokenization/contracts/modules/Compliance.sol
 * @dev This contract imports the ModularInternal abstract contract from the core/abstracts directory.
 */
import "../core/abstracts/ModularInternal.sol";

/**
 * @title Compliance
 * @dev This contract is a module that extends the ModularInternal contract.
 * It is intended to handle compliance-related functionalities for tokenization.
 */
contract Compliance is ModularInternal {
    using AppStorage for AppStorage.Layout;

    event AddressWhitelisted(address indexed account);
    event AddressBlacklisted(address indexed account);
    event AddressRemovedFromBlacklist(address indexed account);

    address immutable _this;

    /**
     * @dev Constructor for the Compliance contract.
     * Grants the ADMIN_ROLE and COMPLIANCE_OFFICER_ROLE to the deployer and the specified appAddress.
     *
     * @param appAddress The address to be granted the ADMIN_ROLE and COMPLIANCE_OFFICER_ROLE.
     */
    constructor(address appAddress) {
        _this = address(this);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, appAddress);
        _grantRole(COMPLIANCE_OFFICER_ROLE, appAddress);
    }

    /**
     * @notice Returns an array of FacetCut structs representing the module facets.
     * @dev This function constructs an array of function selectors and creates a FacetCut array with a single element.
     * The FacetCut array is configured to add the specified selectors to the module.
     * @return facetCuts An array of FacetCut structs containing the target, action, and selectors.
     */
    function moduleFacets() external view returns (FacetCut[] memory) {
        uint256 selectorIndex = 0;
        bytes4[] memory selectors = new bytes4[](5);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.whitelistAddress.selector;
        selectors[selectorIndex++] = this.blacklistAddress.selector;
        selectors[selectorIndex++] = this.removeFromBlacklist.selector;
        selectors[selectorIndex++] = this.preTransferCheck.selector;
        selectors[selectorIndex++] = this.isAddressBlacklisted.selector;

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
     * @notice Adds an address to the whitelist.
     * @dev This function can only be called by an account with the COMPLIANCE_OFFICER_ROLE.
     * @param account The address to be whitelisted.
     * @dev Requirements: The address must not be blacklisted.
     * @dev Emits: AddressWhitelisted when an address is successfully whitelisted.
     */
    function whitelistAddress(
        address account
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();

        require(!data.isBlacklisted[account], "Address is blacklisted");
        data.isWhitelisted[account] = true;
        emit AddressWhitelisted(account);
    }

    /**
     * @notice Blacklists an address, preventing it from participating in token transfers.
     * @dev Only accounts with the COMPLIANCE_OFFICER_ROLE can call this function.
     * @param account The address to be blacklisted.
     * Emits an {AddressBlacklisted} event.
     */
    function blacklistAddress(
        address account
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();

        data.isBlacklisted[account] = true;
        data.isWhitelisted[account] = false;
        emit AddressBlacklisted(account);
    }

    /**
     * @notice Removes an address from the blacklist.
     * @dev This function can only be called by an account with the COMPLIANCE_OFFICER_ROLE.
     * @param account The address to be removed from the blacklist.
     * @dev Requirements: The address must be currently blacklisted.
     * @dev Emits: AddressRemovedFromBlacklist event upon successful removal.
     */
    function removeFromBlacklist(
        address account
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();

        require(data.isBlacklisted[account], "Address is not blacklisted");
        data.isBlacklisted[account] = false;
        emit AddressRemovedFromBlacklist(account);
    }

    /**
     * @notice Performs checks before a token transfer is allowed.
     * @dev This function checks if the seller and recipient addresses are blacklisted or whitelisted.
     * @param from The address of the seller.
     * @param to The address of the recipient.
     * @dev The seller address must not be blacklisted.
     * @dev The recipient address must not be blacklisted.
     * @dev The seller address must be whitelisted.
     * @dev The recipient address must be whitelisted.
     */
    function preTransferCheck(address from, address to) external view {
        AppStorage.Layout storage data = AppStorage.layout();

        require(!data.isBlacklisted[from], "Sender address is blacklisted");
        require(!data.isBlacklisted[to], "Recipient address is blacklisted");
        require(data.isWhitelisted[from], "Sender is not whitelisted");
        require(data.isWhitelisted[to], "Recipient is not whitelisted");
    }

    /**
     * @notice Checks if an address is blacklisted.
     * @param account The address to check.
     * @return bool True if the address is blacklisted, false otherwise.
     */
    function isAddressBlacklisted(
        address account
    ) external view returns (bool) {
        AppStorage.Layout storage data = AppStorage.layout();

        return data.isBlacklisted[account];
    }
}
