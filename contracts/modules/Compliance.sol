// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../utils/AccessControl.sol";

/**
 * @title Compliance
 * @dev Token transferleri ve kullanıcı etkileşimleri için KYC/AML uyumluluğunu yöneten akıllı kontrat.
 */
contract Compliance is AccessControl {
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");

    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isBlacklisted;

    event AddressWhitelisted(address indexed account);
    event AddressBlacklisted(address indexed account);
    event AddressRemovedFromBlacklist(address indexed account);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER_ROLE, msg.sender);
    }

    /**
     * @dev Adresi beyaz listeye ekler (KYC onayı).
     * @param account Beyaz listeye eklenecek adres.
     */
    function whitelistAddress(address account) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(!isBlacklisted[account], "Address is blacklisted");
        isWhitelisted[account] = true;
        emit AddressWhitelisted(account);
    }

    /**
     * @dev Adresi kara listeye ekler (AML ihlali veya riskli adres).
     * @param account Kara listeye eklenecek adres.
     */
    function blacklistAddress(address account) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        isBlacklisted[account] = true;
        isWhitelisted[account] = false;
        emit AddressBlacklisted(account);
    }

    /**
     * @dev Kara listeden adresi çıkarır.
     * @param account Kara listeden çıkarılacak adres.
     */
    function removeFromBlacklist(address account) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(isBlacklisted[account], "Address is not blacklisted");
        isBlacklisted[account] = false;
        emit AddressRemovedFromBlacklist(account);
    }

    /**
     * @dev Transfer işlemleri öncesinde kara liste kontrolü.
     * @param from Gönderen adres.
     * @param to Alıcı adres.
     */
    function preTransferCheck(address from, address to) external view {
        require(!isBlacklisted[from], "Sender address is blacklisted");
        require(!isBlacklisted[to], "Recipient address is blacklisted");
        require(isWhitelisted[from], "Sender is not whitelisted");
        require(isWhitelisted[to], "Recipient is not whitelisted");
    }

    /**
     * @dev Kullanıcının kara listede olup olmadığını kontrol eder.
     * @param account Kontrol edilecek adres.
     * @return bool Kara listede olup olmadığı.
     */
    function isAddressBlacklisted(address account) external view returns (bool) {
        return isBlacklisted[account];
    }
}
