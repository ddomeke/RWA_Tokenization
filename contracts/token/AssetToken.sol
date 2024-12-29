// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {ERC1155} from "./ERC1155/ERC1155.sol";
import {ERC1155Pausable} from "./ERC1155/extensions/ERC1155Pausable.sol";
import {ERC1155Supply} from "./ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "../utils/Ownable.sol";
import {IAssetToken} from "../interfaces/IAssetToken.sol";
import {IERC1155} from "./ERC1155/IERC1155.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import "hardhat/console.sol";



contract AssetToken is IAssetToken, ERC1155, Ownable, ERC1155Pausable, ERC1155Supply {

    IRWATokenization public rwaContract;

    mapping(uint256 => mapping(address => uint256)) public lockedTokens;  // assetId -> user -> amount locked

    event RWATokenizationContractUpdated(address oldContract, address newContract);
    event TokensLocked(address indexed account, uint256 assetId, uint256 amount);
    event TokensUnlocked(address indexed account, uint256 assetId, uint256 amount);

    modifier onlyOwnerOrRWAContract() {
        require(msg.sender == owner() || msg.sender == address(rwaContract), "Not authorized");
        _;
    }

    constructor(
        address initialOwner,
        string memory uri_,
        address _rwaContract
    )
        ERC1155(uri_)
        Ownable(initialOwner)
    {
        rwaContract = IRWATokenization(_rwaContract);
    }


    // Override safeTransferFrom to block locked tokens
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public override(ERC1155, IERC1155){
        uint256 balance = balanceOf(from, id);
        uint256 locked = lockedTokens[id][from];
        require(balance - locked >= value, "Insufficient unlocked balance");
        super.safeTransferFrom(from, to, id, value, data);
    }

    // Override safeBatchTransferFrom to block locked tokens
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public override(ERC1155, IERC1155) {
        require(ids.length == values.length, "IDs and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = values[i];
            uint256 balance = balanceOf(from, id);
            uint256 locked = lockedTokens[id][from];
            require(balance - locked >= amount, "Insufficient unlocked balance for one of the tokens");
        }

        super.safeBatchTransferFrom(from, to, ids, values, data);
    }

    // Lock a specific amount of tokens
    function lockTokens(address account, uint256 id, uint256 amount) external onlyOwnerOrRWAContract {
        require(balanceOf(account, id) >= lockedTokens[id][account] + amount, "Insufficient balance to lock");
        lockedTokens[id][account] += amount;
        emit TokensLocked(account, id, amount);
    }

    // Unlock a specific amount of tokens
    function unlockTokens(address account, uint256 id, uint256 amount) external onlyOwnerOrRWAContract {
        require(lockedTokens[id][account] >= amount, "No enough tokens to unlock");
        lockedTokens[id][account] -= amount;
        emit TokensUnlocked(account, id, amount);
    }

    //Get the number of locked tokens for an account
    // function getLockedTokens(address account, uint256 id) external view returns (uint256) {
    //     return lockedTokens[id][account];
    // }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwnerOrRWAContract {
        _mint(account, id, amount, data);
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        require(address(rwaContract).code.length > 0, "Target address is not a contract");

        super._update(from, to, ids, values);
        
        //console.log("rwaContract", rwaContract);

        // Notify external contracts of balance changes
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if (from != address(0)) {
                rwaContract.updateHoldings(from, id, balanceOf(from, id));
            }
            if (to != address(0)) {
                rwaContract.updateHoldings(to, id, balanceOf(to, id));
            }
        }
    }

    function updateRWATokenizationContract(address newContract) external onlyOwner {
        require(newContract != address(0), "Invalid RWA contract address");

        address oldContract = address(rwaContract);
        rwaContract = IRWATokenization(newContract);

        emit RWATokenizationContractUpdated(oldContract, newContract);
    }
}
