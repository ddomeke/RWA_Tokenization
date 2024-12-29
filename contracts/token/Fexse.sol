// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "./ERC20/ERC20.sol";
import {ERC20Burnable} from "./ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "./ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "./ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "./ERC20/extensions/ERC20Votes.sol";
import {IFexse} from "../interfaces/IFexse.sol";
import {Nonces} from "../utils/Nonces.sol";
import {Ownable} from "../utils/Ownable.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import "hardhat/console.sol";


contract Fexse is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit, ERC20Votes {

    mapping(address => uint256) private _lockedBalances;

    IRWATokenization public rwaContract;

    event TokensLocked(address indexed account, uint256 amount);
    event TokensUnlocked(address indexed account, uint256 amount);
    event RWATokenizationContractUpdated(address oldContract, address newContract);

    modifier onlyOwnerOrRWAContract() {
        require(msg.sender == owner() || msg.sender == address(rwaContract), "Not authorized");
        _;
    }

    constructor(
        address initialOwner,
        address _rwaContract
    )
        ERC20("Fexse", "FXS")
        Ownable(initialOwner)
        ERC20Permit("Fexse")
    {
        _mint(msg.sender, 270000000000 * 10 ** decimals());
        rwaContract = IRWATokenization(_rwaContract);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Lock a certain amount of tokens for the caller.
     * @param amount The amount of tokens to lock.
     */
    function lock(uint256 amount) external onlyOwnerOrRWAContract{
        require(amount > 0, "Lock amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance to lock");
        _lockedBalances[msg.sender] += amount;
        emit TokensLocked(msg.sender, amount);
    }

    /**
     * @dev Unlock a certain amount of tokens for the caller.
     * @param amount The amount of tokens to unlock.
     */
    function unlock(uint256 amount) external onlyOwnerOrRWAContract {
        require(amount > 0, "Unlock amount must be greater than zero");
        require(_lockedBalances[msg.sender] >= amount, "Insufficient locked balance to unlock");
        _lockedBalances[msg.sender] -= amount;
        emit TokensUnlocked(msg.sender, amount);
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

    function setRWATokenizationContract(address newContract) external onlyOwner {
        require(newContract != address(0), "Invalid RWA contract address");

        address oldContract = address(rwaContract);
        rwaContract = IRWATokenization(newContract);

        emit RWATokenizationContractUpdated(oldContract, newContract);
    }
}
