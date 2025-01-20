// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;
/**
 * @file AssetToken.sol
 * @dev This file contains the implementation of the AssetToken contract, which is an ERC1155 token with additional features such as access control, pausing, and supply management.
 *
 * Imports:
 * - AccessControl: Provides role-based access control mechanisms.
 * - ERC1155: Standard implementation of the ERC1155 multi-token standard.
 * - ERC1155Pausable: Extension of ERC1155 that allows tokens to be paused.
 * - ERC1155Supply: Extension of ERC1155 that tracks the total supply of tokens.
 * - IAssetToken: Interface for the AssetToken contract.
 * - IERC1155: Interface for the ERC1155 standard.
 * - IERC165: Interface for the ERC165 standard.
 * - IRWATokenization: Interface for the RWATokenization contract.
 * - IMarketPlace: Interface for the MarketPlace contract.
 */

import "../utils/AccessControl.sol";
import {ERC1155} from "./ERC1155/ERC1155.sol";
import {ERC1155Pausable} from "./ERC1155/extensions/ERC1155Pausable.sol";
import {ERC1155Supply} from "./ERC1155/extensions/ERC1155Supply.sol";
import {IAssetToken} from "../interfaces/IAssetToken.sol";
import {IERC1155} from "./ERC1155/IERC1155.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IRWATokenization} from "../interfaces/IRWATokenization.sol";
import {IMarketPlace} from "../interfaces/IMarketPlace.sol";

/**
 * @title AssetToken
 * @dev AssetToken is an ERC1155 token with additional functionalities such as access control, pausing, and supply tracking.
 * It implements the IAssetToken interface and extends the ERC1155, ERC1155Pausable, and ERC1155Supply contracts.
 *
 * Inherits:
 * - AccessControl: Provides role-based access control mechanisms.
 * - IAssetToken: Interface for the AssetToken.
 * - ERC1155: Standard multi-token contract.
 * - ERC1155Pausable: Adds the ability to pause token transfers.
 * - ERC1155Supply: Tracks the total supply of each token ID.
 */
contract AssetToken is
    AccessControl,
    IAssetToken,
    ERC1155,
    ERC1155Pausable,
    ERC1155Supply
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    string public name;
    string public symbol;

    address public appAddress;
    IRWATokenization public rwaContract;


    /**
     * @dev Constructor for the AssetToken contract.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _appAddress The address of the application.
     * @param uri_ The URI for the token metadata.
     * @param _rwaContract The address of the RWATokenization contract.
     *
     * Initializes the ERC1155 contract with the given URI.
     * Sets the application address and the RWATokenization contract address.
     * Grants the DEFAULT_ADMIN_ROLE and ADMIN_ROLE to the deployer and the application address.
     * Sets the name and symbol of the token.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _appAddress,
        string memory uri_,
        address _rwaContract
    ) ERC1155(uri_) {
        appAddress = _appAddress;
        rwaContract = IRWATokenization(_rwaContract);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, appAddress);
        name = _name;
        symbol = _symbol;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *
     * This function checks if the contract implements the interface defined by
     * `interfaceId`. It uses the `supportsInterface` function from the parent
     * contracts `AccessControl`, `ERC1155`, and `IERC165`.
     *
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return bool `true` if the contract implements `interfaceId`, `false` otherwise.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl, ERC1155, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Mints a specified amount of tokens to a given account.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * @param account The address of the account to mint tokens to.
     * @param id The ID of the token type to mint.
     * @param amount The amount of tokens to mint.
     * @param data Additional data with no specified format, sent in call to `account`.
     */
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyRole(ADMIN_ROLE) {
        _mint(account, id, amount, data);
    }

    /**
     * @dev Sets a new URI for the token.
     * Can only be called by an account with the `ADMIN_ROLE`.
     * @param newuri The new URI to be set.
     */
    function setURI(string memory newuri) external onlyRole(ADMIN_ROLE) {
        _setURI(newuri);
    }

    /**
     * @notice Pauses all token transfers.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It triggers the internal _pause function from the Pausable contract.
     * Once paused, all token transfers will be halted until unpaused.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * Requirements:
     *
     * - The caller must have the `ADMIN_ROLE`.
     *
     * Emits a {Unpaused} event.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Internal function to update token balances and notify external contracts.
     * Overrides the _update function from ERC1155, ERC1155Pausable, and ERC1155Supply.
     *
     * @param from The address of the sender.
     * @param to The address of the receiver.
     * @param ids An array of token IDs.
     * @param values An array of token amounts.
     *
     * Requirements:
     *
     * - `rwaContract` must be a valid contract address.
     *
     * This function performs the following actions:
     * - Calls the parent `_update` function to update balances.
     * - Notifies the `rwaContract` of balance changes for each token ID.
     * - If `from` is not the zero address, updates the holdings of `from` in `rwaContract`.
     * - If `to` is not the zero address, updates the holdings of `to` in `rwaContract`.
     */

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        require(
            address(rwaContract).code.length > 0,
            "Target address is not a contract"
        );

        super._update(from, to, ids, values);

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
}
