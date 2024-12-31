// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "../utils/AccessControl.sol";
import {ERC1155} from "./ERC1155/ERC1155.sol";
import {ERC1155Pausable} from "./ERC1155/extensions/ERC1155Pausable.sol";
import {ERC1155Supply} from "./ERC1155/extensions/ERC1155Supply.sol";
import {IAssetToken} from "../interfaces/IAssetToken.sol";
import {IERC1155} from "./ERC1155/IERC1155.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import {IMarketPlace} from "../interfaces/IMarketPlace.sol";
import "hardhat/console.sol";



contract AssetToken is AccessControl, IAssetToken, ERC1155, ERC1155Pausable, ERC1155Supply {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public appAddress;
    IRWATokenization public rwaContract;

    mapping(uint256 => mapping(address => uint256)) public lockedTokens;  // assetId -> user -> amount locked

    event TokensLocked(address indexed account, uint256 assetId, uint256 amount);
    event TokensUnlocked(address indexed account, uint256 assetId, uint256 amount);

    constructor(
        address _appAddress,
        string memory uri_,
        address _rwaContract
    )
        ERC1155(uri_)
    {
        appAddress = _appAddress;
        rwaContract = IRWATokenization(_rwaContract);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, appAddress);
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

    // Override required by Solidity
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC1155, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Lock a specific amount of tokens
    function lockTokens(address account, uint256 id, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(balanceOf(account, id) >= lockedTokens[id][account] + amount, "Insufficient balance to lock");
        lockedTokens[id][account] += amount;
        emit TokensLocked(account, id, amount);
    }

    // Unlock a specific amount of tokens
    function unlockTokens(address account, uint256 id, uint256 amount) external onlyRole(ADMIN_ROLE) {
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
    ) external onlyRole(ADMIN_ROLE) {
        _mint(account, id, amount, data);
    }

    function setURI(string memory newuri) external onlyRole(ADMIN_ROLE) {
        _setURI(newuri);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)

        //TODO: ----
    {
        require(address(rwaContract).code.length > 0, "Target address is not a contract");

        super._update(from, to, ids, values);
        
        // Notify external contracts of balance changes
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if (from != address(0)) {

                // (bool success, ) = appAddress.delegatecall(
                //     abi.encodeWithSignature("updateHoldings(address,uint256,uint256)", from, id, balanceOf(from, id))
                // );
                // require(success, "RWATokenization.updateHoldingscall failed");


                rwaContract.updateHoldings(from, id, balanceOf(from, id));
            }
            if (to != address(0)) {

                // (bool success, ) = appAddress.delegatecall(
                //     abi.encodeWithSignature("updateHoldings(address,uint256,uint256)", to, id, balanceOf(to, id))
                // );
                // require(success, "RWATokenization.updateHoldingscall failed");


                rwaContract.updateHoldings(to, id, balanceOf(to, id));
            }
        }
    }
}
