// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/abstracts/ModularInternal.sol";

/**
 * @title Compliance
 * @dev Token transferleri ve kullanıcı etkileşimleri için KYC/AML uyumluluğunu yöneten akıllı kontrat.
 */
contract Compliance is ModularInternal {
    using AppStorage for AppStorage.Layout;

    event AddressWhitelisted(address indexed account);
    event AddressBlacklisted(address indexed account);
    event AddressRemovedFromBlacklist(address indexed account);

    address immutable _this;

    constructor(
        address appAddress
    ) {

        _this = address(this);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, appAddress);
        _grantRole(COMPLIANCE_OFFICER_ROLE, appAddress);
    }

       /**
     * @dev Returns an array of ⁠ FacetCut ⁠ structs, which define the functions (selectors)
     *      provided by this module. This is used to register the module's functions
     *      with the modular system.
     * @return FacetCut[] Array of ⁠ FacetCut ⁠ structs representing function selectors.
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
     * @dev Adresi beyaz listeye ekler (KYC onayı).
     * @param account Beyaz listeye eklenecek adres.
     */
    function whitelistAddress(address account) external onlyRole(COMPLIANCE_OFFICER_ROLE) {

        AppStorage.Layout storage data = AppStorage.layout();

        require(!data.isBlacklisted[account], "Address is blacklisted");
        data.isWhitelisted[account] = true;
        emit AddressWhitelisted(account);
    }

    /**
     * @dev Adresi kara listeye ekler (AML ihlali veya riskli adres).
     * @param account Kara listeye eklenecek adres.
     */
    function blacklistAddress(address account) external onlyRole(COMPLIANCE_OFFICER_ROLE) {

        AppStorage.Layout storage data = AppStorage.layout();

        data.isBlacklisted[account] = true;
        data.isWhitelisted[account] = false;
        emit AddressBlacklisted(account);
    }

    /**
     * @dev Kara listeden adresi çıkarır.
     * @param account Kara listeden çıkarılacak adres.
     */
    function removeFromBlacklist(address account) external onlyRole(COMPLIANCE_OFFICER_ROLE) {

        AppStorage.Layout storage data = AppStorage.layout();

        require(data.isBlacklisted[account], "Address is not blacklisted");
        data.isBlacklisted[account] = false;
        emit AddressRemovedFromBlacklist(account);
    }

    /**
     * @dev Transfer işlemleri öncesinde kara liste kontrolü.
     * @param from Gönderen adres.
     * @param to Alıcı adres.
     */
    function preTransferCheck(address from, address to) external view {

        AppStorage.Layout storage data = AppStorage.layout();

        require(!data.isBlacklisted[from], "Sender address is blacklisted");
        require(!data.isBlacklisted[to], "Recipient address is blacklisted");
        require(data.isWhitelisted[from], "Sender is not whitelisted");
        require(data.isWhitelisted[to], "Recipient is not whitelisted");
    }

    /**
     * @dev Kullanıcının kara listede olup olmadığını kontrol eder.
     * @param account Kontrol edilecek adres.
     * @return bool Kara listede olup olmadığı.
     */
    function isAddressBlacklisted(address account) external view returns (bool) {

        AppStorage.Layout storage data = AppStorage.layout();

        return data.isBlacklisted[account];
    }
}
