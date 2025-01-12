// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Constants.sol";
import "../utils/Context.sol";
import "../libs/AddressLib.sol";
import "../libs/TransferLib.sol";
import "../interfaces/IFexse.sol";

/**
 * @title AppStorage
 * @dev This library defines the layout of the application's storage and provides utility functions
 *      for interacting with different aspects of the application's state. This includes:
 *      - Managing initialization status
 *      - Preventing reentrancy attacks
 *      - Asset tracking and management
 *      - Function selector mappings for modularity
 *      - Whitelisting and blacklisting of addresses
 *      
 *      It uses a fixed storage slot defined by `APP_STORAGE_POSITION` to ensure
 *      consistent state management across contract upgrades and modular deployments.
 */
library AppStorage {
    // Storage position constant
    // This defines the specific storage slot in memory where the application’s storage layout
    // will be stored. It uses a unique hash to avoid conflicts with other contracts’ storage.
    bytes32 constant APP_STORAGE_POSITION =
        keccak256("fexse.app.contracts.storage.base");

    /**
     * @dev The main storage layout for the application.
     * This structure defines all the state variables used in the application.
     * Each variable is carefully chosen to minimize storage collisions and ensure compatibility
     * with upgrades.
     */
    struct Layout {
        bool initialized; // Flag to indicate whether the contract is fully initialized
        bool entered; // Reentrancy guard to prevent multiple calls to non-reentrant functions
        uint8 nextAssetId; // Counter for generating unique asset identifiers
        uint16 selectorCount; // The number of function selectors currently in use
        address deployer; // The address that deployed the contract (used for administrative purposes)
        address fallbackAddress; // Fallback address for handling contract call failures
        IFexse fexseToken; // Address of the associated Fexse token (custom ERC20 or similar interface)
        mapping(bytes4 => bytes32) facets; // Mapping of function selectors to corresponding facet data
        mapping(uint256 => bytes32) selectorSlots; // Mapping to store function selector slots, enabling modular function upgrades
        mapping(uint256 => Asset) assets; // A mapping of asset IDs to their corresponding asset details
        mapping(uint256 => Proposal) proposals; // A mapping of proposal IDs to their corresponding proposal details
        mapping(address => Stake) stakes;   // A mapping of addresses to their corresponding stake details
        mapping(address => bool) isWhitelisted; // Tracks addresses that are allowed specific privileges in the system
        mapping(address => bool) isBlacklisted; // Tracks addresses that are restricted from certain actions
    }

    /**
     * @dev Returns a reference to the application’s storage layout.
     * This function is used internally to access and modify the application's state consistently.
     * It leverages a fixed storage position to maintain data integrity across contract upgrades.
     *
     * @return base A storage reference to the application's `Layout` structure.
     */
    function layout() internal pure returns (Layout storage base) {
        bytes32 position = APP_STORAGE_POSITION; // Retrieve the storage position constant
        assembly {
            base.slot := position // Assign the storage position to the base reference
        }
    }
}