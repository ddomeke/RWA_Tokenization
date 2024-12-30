// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "../utils/AccessControl.sol";
import {ERC20} from "./ERC20/ERC20.sol";
import {ERC20Burnable} from "./ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "./ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "./ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "./ERC20/extensions/ERC20Votes.sol";
import {IFexse} from "../interfaces/IFexse.sol";
import {Nonces} from "../utils/Nonces.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import {IMarketPlace} from "../interfaces/IMarketPlace.sol";
import "hardhat/console.sol";


contract Fexse is AccessControl, ERC20, ERC20Burnable, ERC20Pausable, ERC20Permit, ERC20Votes {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => uint256) private _lockedBalances;

    IRWATokenization public rwaContract;
    IMarketPlace public marketContract;

    event TokensLocked(address indexed account, uint256 amount);
    event TokensUnlocked(address indexed account, uint256 amount);
    event RWATokenizationContractUpdated(address oldContract, address newContract);
    event MarketPlaceContractUpdated(address oldContract, address newContract);

    constructor(
        address _rwaContract,
        address _marketContract
    )
        ERC20("Fexse", "FeXSe")
        ERC20Permit("Fexse")
    {
        _mint(msg.sender, 270000000000 * 10 ** decimals());
        rwaContract = IRWATokenization(_rwaContract);
        marketContract = IMarketPlace(_marketContract);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, _rwaContract);
        _grantRole(ADMIN_ROLE, _marketContract);
    }

    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Lock a certain amount of tokens for the caller.
     * @param amount The amount of tokens to lock.
     */
    function lock(address owner, uint256 amount) external onlyRole(ADMIN_ROLE){
        require(amount > 0, "Lock amount must be greater than zero");
        require(balanceOf(owner) >= amount, "Insufficient balance to lock");
        _lockedBalances[owner] += amount;
        emit TokensLocked(owner, amount);
    }

    /**
     * @dev Unlock a certain amount of tokens for the caller.
     * @param amount The amount of tokens to unlock.
     */
    function unlock(address owner, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(amount > 0, "Unlock amount must be greater than zero");
        require(_lockedBalances[owner] >= amount, "Insufficient locked balance to unlock");
        _lockedBalances[owner] -= amount;
        emit TokensUnlocked(owner, amount);
    }

    /**
     * @dev Returns the locked balance of a given account.
     * @param account The account to query the locked balance.
     */
    function lockedBalanceOf(address account) public view returns (uint256) {
        return _lockedBalances[account];
    }


    // Override transfer function to include locked balance check
    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 availableBalance = balanceOf(msg.sender) - _lockedBalances[msg.sender];
        require(amount <= availableBalance, "Transfer amount exceeds available balance");
        return super.transfer(to, amount);
    }

    // Override transferFrom function to include locked balance check
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 availableBalance = balanceOf(from) - _lockedBalances[from];
        require(amount <= availableBalance, "Transfer amount exceeds available balance");
        return super.transferFrom(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function updateRWATokenizationContract(address newContract) external onlyRole(ADMIN_ROLE) {
        require(newContract != address(0), "Invalid RWA contract address");

        address oldContract = address(rwaContract);
        rwaContract = IRWATokenization(newContract);

        emit RWATokenizationContractUpdated(oldContract, newContract);
    }

    function updateMarketPlaceContract(address newContract) external onlyRole(ADMIN_ROLE) {
        require(newContract != address(0), "Invalid Market contract address");

        address oldContract = address(marketContract);
        marketContract = IMarketPlace(newContract);

        emit MarketPlaceContractUpdated(oldContract, newContract);
    }
}
