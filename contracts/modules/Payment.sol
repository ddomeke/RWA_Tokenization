// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../utils/AccessControl.sol";
import "../utils//ReentrancyGuard.sol";

/**
 * @title Payment
 * @dev Tokenize edilmiş varlıkların ödemelerini yöneten akıllı kontrat.
 */
contract Payment is AccessControl, ReentrancyGuard {
    bytes32 public constant PAYMENT_MANAGER_ROLE = keccak256("PAYMENT_MANAGER_ROLE");
    
    mapping(address => uint256) public balances;

    event PaymentReceived(address indexed from, uint256 amount);
    event PaymentWithdrawn(address indexed to, uint256 amount);
    event PaymentDistributed(address indexed to, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAYMENT_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Ödeme alma fonksiyonu (ETH kabul edilir).
     */
    receive() external payable {
        require(msg.value > 0, "Payment must be greater than 0");
        balances[msg.sender] += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }

    /**
     * @dev Belirtilen adrese ödeme çekme fonksiyonu.
     * @param to Alıcı adresi
     * @param amount Çekilecek miktar
     */
    function withdraw(address payable to, uint256 amount) external nonReentrant onlyRole(PAYMENT_MANAGER_ROLE) {
        require(balances[to] >= amount, "Insufficient balance");
        balances[to] -= amount;
        (bool success,) = to.call{value: amount}("");
        require(success, "Transfer failed");
        emit PaymentWithdrawn(to, amount);
    }

    /**
     * @dev Birden fazla adrese ödeme dağıtımı yapar.
     * @param recipients Alıcı adresleri
     * @param amounts Miktarlar
     */
    function distributePayments(address[] calldata recipients, uint256[] calldata amounts) 
        external nonReentrant onlyRole(PAYMENT_MANAGER_ROLE) {
        require(recipients.length == amounts.length, "Mismatched arrays");
        for (uint256 i = 0; i < recipients.length; i++) {
            require(address(this).balance >= amounts[i], "Contract balance is insufficient");
            (bool success,) = recipients[i].call{value: amounts[i]}("");
            require(success, "Payment failed");
            emit PaymentDistributed(recipients[i], amounts[i]);
        }
    }

    /**
     * @dev Kontrat bakiyesini görüntüler.
     * @return uint256 Kontrat bakiyesi (wei cinsinden)
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
