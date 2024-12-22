// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockToken
 * @dev Test amaçlı kullanılan sahte bir ERC20 token kontratı.
 */
contract MockyToken is ERC20 {
    uint8 private _decimals;

    /**
     * @dev Kontrat kurucu fonksiyonu.
     * @param name Token adı
     * @param symbol Token sembolü
     * @param initialSupply Başlangıç arzı (wei cinsinden)
     * @param decimals_ Desimal basamak sayısı
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 decimals_
    ) ERC20(name, symbol) {
        _decimals = decimals_;
        _mint(msg.sender, initialSupply * (10 ** uint256(decimals_)));
    }

    /**
     * @dev Tokenın desimal basamak sayısını döner.
     * @return uint8 Desimal basamak sayısı
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Test amaçlı yeni token mintleme fonksiyonu.
     * @param account Alıcı adresi
     * @param amount Mintlenecek miktar
     */
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /**
     * @dev Test amaçlı token yakma fonksiyonu.
     * @param amount Yakılacak miktar
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
