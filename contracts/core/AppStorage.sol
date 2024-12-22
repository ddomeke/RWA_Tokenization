// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../utils/Context.sol";
import "../libs/AddressLib.sol";
import "../libs/TransferLib.sol";

/**
 * @title AppStorage
 * @dev This library defines the layout of the storage and provides utility functions
 *      for interacting with various aspects of the application's storage, including
 *      asset management, pool management, project management, and more.
 */
library AppStorage {
    // Storage position for the application storage layout
    bytes32 constant APP_STORAGE_POSITION =
        keccak256("fexse.app.contracts.storage.base");

    /**
     * @dev Defines the layout of the application's storage.
     */
    struct Layout {
        bool initialized; // Indicates whether the application is initialized
        bool entered; // reentrancy guard
        uint8 nextAssetId; // Counter for the next asset ID
        uint16 selectorCount; // Number of function selectors in the application
        address deployer; // Address of the contract deployer
        address fallbackAddress; // Fallback address for contract call
        mapping(bytes4 => bytes32) facets; // Mapping of function selectors to facets
        mapping(uint256 => bytes32) selectorSlots; // Mapping of selector slots for functions
    }

    /**
     * @dev Retrieves the application's storage layout.
     * @return base The storage layout.
     */
    function layout() internal pure returns (Layout storage base) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            base.slot := position
        }
    }


}
