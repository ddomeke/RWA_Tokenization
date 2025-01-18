// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;
/**
 * @file Fexse.sol
 * @dev This file contains the implementation of the Fexse token contract.
 *
 * The contract imports various modules and interfaces to extend its functionality:
 * - AccessControl: Provides role-based access control mechanisms.
 * - ERC20: Standard ERC20 token implementation.
 * - ERC20Burnable: Allows tokens to be burned (destroyed).
 * - ERC20Pausable: Allows token transfers to be paused.
 * - ERC20Permit: Adds permit functionality for approvals via signatures.
 * - ERC20Votes: Adds voting capabilities to the token.
 * - IFexse: Interface for the Fexse token contract.
 * - Nonces: Utility for managing nonces.
 */

import "../utils/AccessControl.sol";
import {ERC20} from "./ERC20/ERC20.sol";
import {ERC20Burnable} from "./ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "./ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "./ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "./ERC20/extensions/ERC20Votes.sol";
import {IFexse} from "../interfaces/IFexse.sol";
import {Nonces} from "../utils/Nonces.sol";

/**
 * @title Fexse Token Contract
 * @dev This contract implements the Fexse token, which is an ERC20 token with additional features.
 * It includes access control, burnable tokens, pausable token transfers, permit-based approvals, and voting capabilities.
 *
 * Inherits from:
 * - AccessControl: Provides role-based access control mechanisms.
 * - ERC20: Standard ERC20 token implementation.
 * - ERC20Burnable: Allows tokens to be burned (destroyed).
 * - ERC20Pausable: Allows token transfers to be paused and unpaused.
 * - ERC20Permit: Allows approvals to be made via signatures, as defined in EIP-2612.
 * - ERC20Votes: Adds voting capabilities to the token, allowing it to be used in governance.
 */
contract Fexse is
    AccessControl,
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Permit,
    ERC20Votes
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @dev Constructor for the Fexse token contract.
     * @param appAddress The address to be granted the ADMIN_ROLE.
     *
     * The constructor initializes the ERC20 token with the name "Fexse" and symbol "FeXSe".
     * It also initializes the ERC20Permit with the name "Fexse".
     * The constructor mints 2,7 billion tokens (with decimals applied) to the deployer's address.
     * Additionally, it grants the ADMIN_ROLE to both the deployer's address and the provided appAddress.
     */
    constructor(
        address appAddress
    ) ERC20("Fexse", "FeXSe") ERC20Permit("Fexse") {
        _mint(msg.sender, 2700000000 * 10 ** decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, appAddress);
    }

    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Internal function to update token balances and state.
     * This function overrides the _update function from ERC20, ERC20Pausable, and ERC20Votes.
     * It calls the parent _update function to perform the actual update.
     *
     * @param from The address from which tokens are transferred.
     * @param to The address to which tokens are transferred.
     * @param value The amount of tokens transferred.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        super._update(from, to, value);
    }

    /**
     * @notice Returns the current nonce for the given owner address.
     * @dev This function overrides the `nonces` function from both `ERC20Permit` and `Nonces` contracts.
     * @param owner The address of the token owner.
     * @return The current nonce for the owner.
     */
    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
