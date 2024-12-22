// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../AppStorage.sol";
import "../../interfaces/IModularInternal.sol";
import "../../utils/AccessControl.sol";

/**
 * @title ModularInternal
 * @dev This abstract contract provides the internal functions for managing facets (modules) in a diamond storage pattern,
 *      allowing dynamic addition, replacement, and removal of functionality within the contract.
 */
abstract contract ModularInternal is IModularInternal {
    using AddressLib for address;

    // Constants for managing address and selector masks
    bytes32 private constant CLEAR_ADDRESS_MASK =
        bytes32(uint256(0xffffffffffffffffffffffff));
    bytes32 private constant CLEAR_SELECTOR_MASK =
        bytes32(uint256(0xffffffff << 224));

    /**
     * @dev Internal function to retrieve all facets (modules) currently used in the contract.
     * @return diamondFacets An array of Facet structs, each representing a facet and its function selectors.
     */
    function _facets() internal view returns (Facet[] memory diamondFacets) {
        AppStorage.Layout storage l = AppStorage.layout();

        // Initialize arrays to store facets and selectors
        diamondFacets = new Facet[](l.selectorCount);
        uint8[] memory numFacetSelectors = new uint8[](l.selectorCount);
        uint256 numFacets;
        uint256 selectorIndex;

        // Iterate over selector slots to retrieve selectors and their corresponding facets
        for (uint256 slotIndex; selectorIndex < l.selectorCount; slotIndex++) {
            bytes32 slot = l.selectorSlots[slotIndex];

            for (
                uint256 selectorSlotIndex;
                selectorSlotIndex < 8;
                selectorSlotIndex++
            ) {
                selectorIndex++;

                if (selectorIndex > l.selectorCount) {
                    break;
                }

                bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));
                address facet = address(bytes20(l.facets[selector]));

                bool continueLoop;

                // Check if the facet is already listed and add the selector to it
                for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                    if (diamondFacets[facetIndex].target == facet) {
                        diamondFacets[facetIndex].selectors[
                            numFacetSelectors[facetIndex]
                        ] = selector;
                        require(numFacetSelectors[facetIndex] < 255);
                        numFacetSelectors[facetIndex]++;
                        continueLoop = true;
                        break;
                    }
                }

                if (continueLoop) {
                    continue;
                }

                // If the facet is new, add it to the array
                diamondFacets[numFacets].target = facet;
                diamondFacets[numFacets].selectors = new bytes4[](
                    l.selectorCount
                );
                diamondFacets[numFacets].selectors[0] = selector;
                numFacetSelectors[numFacets] = 1;
                numFacets++;
            }
        }

        // Trim the selectors array to the correct length
        for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
            uint256 numSelectors = numFacetSelectors[facetIndex];
            bytes4[] memory selectors = diamondFacets[facetIndex].selectors;

            assembly {
                mstore(selectors, numSelectors)
            }
        }

        // Trim the facets array to the correct length
        assembly {
            mstore(diamondFacets, numFacets)
        }
    }

    /**
     * @dev Internal function to retrieve all function selectors for a specific facet (module).
     * @param facet The address of the facet to query.
     * @return selectors An array of function selectors associated with the specified facet.
     */
    function _facetFunctionSelectors(
        address facet
    ) internal view returns (bytes4[] memory selectors) {
        AppStorage.Layout storage l = AppStorage.layout();

        selectors = new bytes4[](l.selectorCount);

        uint256 numSelectors;
        uint256 selectorIndex;

        // Iterate over selector slots to retrieve selectors for the specified facet
        for (uint256 slotIndex; selectorIndex < l.selectorCount; slotIndex++) {
            bytes32 slot = l.selectorSlots[slotIndex];

            for (
                uint256 selectorSlotIndex;
                selectorSlotIndex < 8;
                selectorSlotIndex++
            ) {
                selectorIndex++;

                if (selectorIndex > l.selectorCount) {
                    break;
                }

                bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));

                if (facet == address(bytes20(l.facets[selector]))) {
                    selectors[numSelectors] = selector;
                    numSelectors++;
                }
            }
        }

        // Trim the selectors array to the correct length
        assembly {
            mstore(selectors, numSelectors)
        }
    }

    /**
     * @dev Internal function to retrieve all facet addresses currently used by the contract.
     * @return addresses An array of facet addresses.
     */
    function _facetAddresses()
        internal
        view
        returns (address[] memory addresses)
    {
        AppStorage.Layout storage l = AppStorage.layout();

        addresses = new address[](l.selectorCount);
        uint256 numFacets;
        uint256 selectorIndex;

        // Iterate over selector slots to retrieve all facet addresses
        for (uint256 slotIndex; selectorIndex < l.selectorCount; slotIndex++) {
            bytes32 slot = l.selectorSlots[slotIndex];

            for (
                uint256 selectorSlotIndex;
                selectorSlotIndex < 8;
                selectorSlotIndex++
            ) {
                selectorIndex++;

                if (selectorIndex > l.selectorCount) {
                    break;
                }

                bytes4 selector = bytes4(slot << (selectorSlotIndex << 5));
                address facet = address(bytes20(l.facets[selector]));

                bool continueLoop;

                // Check if the facet address is already listed
                for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                    if (facet == addresses[facetIndex]) {
                        continueLoop = true;
                        break;
                    }
                }

                if (continueLoop) {
                    continue;
                }

                // If the facet address is new, add it to the array
                addresses[numFacets] = facet;
                numFacets++;
            }
        }

        // Trim the addresses array to the correct length
        assembly {
            mstore(addresses, numFacets)
        }
    }

    /**
     * @dev Internal function to retrieve the facet address associated with a specific function selector.
     * @param selector The function selector to query.
     * @return facet The address of the facet implementing the function.
     */
    function _facetAddress(
        bytes4 selector
    ) internal view returns (address facet) {
        facet = address(bytes20(AppStorage.layout().facets[selector]));
    }

    /**
     * @dev Internal function to apply changes to the contract's facets (modules).
     * @param facetCuts An array of facet cuts specifying the changes to apply.
     * @param target An optional address to call after applying the changes.
     * @param data Optional calldata to execute after the facet cuts.
     */
    function _diamondCut(
        FacetCut[] memory facetCuts,
        address target,
        bytes memory data
    ) internal virtual {
        AppStorage.Layout storage l = AppStorage.layout();

        unchecked {
            uint256 originalSelectorCount = l.selectorCount;
            uint256 selectorCount = originalSelectorCount;
            bytes32 selectorSlot = 0;

            // If there are existing selectors, retrieve the last selector slot
            if (selectorCount & 7 > 0) {
                selectorSlot = l.selectorSlots[selectorCount >> 3];
            }

            // Iterate through each facet cut and apply the specified action
            for (uint256 i; i < facetCuts.length; i++) {
                FacetCut memory facetCut = facetCuts[i];
                FacetCutAction action = facetCut.action;

                if (facetCut.selectors.length == 0)
                    revert SelectorNotSpecified();

                if (action == FacetCutAction.ADD) {
                    (selectorCount, selectorSlot) = _addFacetSelectors(
                        l,
                        selectorCount,
                        selectorSlot,
                        facetCut
                    );
                } else if (action == FacetCutAction.REPLACE) {
                    _replaceFacetSelectors(l, facetCut);
                } else if (action == FacetCutAction.REMOVE) {
                    (selectorCount, selectorSlot) = _removeFacetSelectors(
                        l,
                        selectorCount,
                        selectorSlot,
                        facetCut
                    );
                }
            }

            // Update the selector count and slots in storage
            if (selectorCount != originalSelectorCount) {
                l.selectorCount = uint16(selectorCount);
            }

            if (selectorCount & 7 > 0) {
                l.selectorSlots[selectorCount >> 3] = selectorSlot;
            }

            emit DiamondCut(facetCuts, target, data);
            _initialize(target, data);
        }
    }

    /**
     * @dev Internal function to add selectors to a facet.
     * @param l The layout storage of the application.
     * @param selectorCount The current selector count.
     * @param selectorSlot The current selector slot.
     * @param facetCut The facet cut specifying the selectors to add.
     * @return The updated selector count and selector slot.
     */
    function _addFacetSelectors(
        AppStorage.Layout storage l,
        uint256 selectorCount,
        bytes32 selectorSlot,
        FacetCut memory facetCut
    ) internal returns (uint256, bytes32) {
        unchecked {
            if (facetCut.target.isContract()) {
                if (facetCut.target == address(this)) {
                    revert SelectorIsImmutable();
                }
            } else if (facetCut.target != address(this)) {
                revert TargetHasNoCode();
            }

            // Iterate through each selector in the facet cut and add it to the storage
            for (uint256 i; i < facetCut.selectors.length; i++) {
                bytes4 selector = facetCut.selectors[i];
                bytes32 oldFacet = l.facets[selector];

                if (address(bytes20(oldFacet)) != address(0))
                    revert SelectorAlreadyAdded();

                l.facets[selector] =
                    bytes20(facetCut.target) |
                    bytes32(selectorCount);
                uint256 selectorInSlotPosition = (selectorCount & 7) << 5;

                selectorSlot =
                    (selectorSlot &
                        ~(CLEAR_SELECTOR_MASK >> selectorInSlotPosition)) |
                    (bytes32(selector) >> selectorInSlotPosition);

                if (selectorInSlotPosition == 224) {
                    l.selectorSlots[selectorCount >> 3] = selectorSlot;
                    selectorSlot = 0;
                }

                selectorCount++;
            }

            return (selectorCount, selectorSlot);
        }
    }

    /**
     * @dev Internal function to remove selectors from a facet.
     * @param l The layout storage of the application.
     * @param selectorCount The current selector count.
     * @param selectorSlot The current selector slot.
     * @param facetCut The facet cut specifying the selectors to remove.
     * @return The updated selector count and selector slot.
     */
    function _removeFacetSelectors(
        AppStorage.Layout storage l,
        uint256 selectorCount,
        bytes32 selectorSlot,
        FacetCut memory facetCut
    ) internal returns (uint256, bytes32) {
        unchecked {
            if (facetCut.target != address(0))
                revert RemoveTargetNotZeroAddress();

            uint256 selectorSlotCount = selectorCount >> 3;
            uint256 selectorInSlotIndex = selectorCount & 7;

            // Iterate through each selector in the facet cut and remove it from the storage
            for (uint256 i; i < facetCut.selectors.length; i++) {
                bytes4 selector = facetCut.selectors[i];
                bytes32 oldFacet = l.facets[selector];

                if (address(bytes20(oldFacet)) == address(0))
                    revert SelectorNotFound();

                if (address(bytes20(oldFacet)) == address(this))
                    revert SelectorIsImmutable();

                if (selectorSlot == 0) {
                    selectorSlotCount--;
                    selectorSlot = l.selectorSlots[selectorSlotCount];
                    selectorInSlotIndex = 7;
                } else {
                    selectorInSlotIndex--;
                }

                bytes4 lastSelector;
                uint256 oldSelectorsSlotCount;
                uint256 oldSelectorInSlotPosition;

                {
                    lastSelector = bytes4(
                        selectorSlot << (selectorInSlotIndex << 5)
                    );

                    if (lastSelector != selector) {
                        l.facets[lastSelector] =
                            (oldFacet & CLEAR_ADDRESS_MASK) |
                            bytes20(l.facets[lastSelector]);
                    }

                    delete l.facets[selector];
                    uint256 oldSelectorCount = uint16(uint256(oldFacet));
                    oldSelectorsSlotCount = oldSelectorCount >> 3;
                    oldSelectorInSlotPosition = (oldSelectorCount & 7) << 5;
                }

                if (oldSelectorsSlotCount != selectorSlotCount) {
                    bytes32 oldSelectorSlot = l.selectorSlots[
                        oldSelectorsSlotCount
                    ];

                    oldSelectorSlot =
                        (oldSelectorSlot &
                            ~(CLEAR_SELECTOR_MASK >>
                                oldSelectorInSlotPosition)) |
                        (bytes32(lastSelector) >> oldSelectorInSlotPosition);

                    l.selectorSlots[oldSelectorsSlotCount] = oldSelectorSlot;
                } else {
                    selectorSlot =
                        (selectorSlot &
                            ~(CLEAR_SELECTOR_MASK >>
                                oldSelectorInSlotPosition)) |
                        (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                }

                if (selectorInSlotIndex == 0) {
                    delete l.selectorSlots[selectorSlotCount];
                    selectorSlot = 0;
                }
            }

            selectorCount = (selectorSlotCount << 3) | selectorInSlotIndex;

            return (selectorCount, selectorSlot);
        }
    }

    /**
     * @dev Internal function to replace selectors in a facet.
     * @param l The layout storage of the application.
     * @param facetCut The facet cut specifying the selectors to replace.
     */
    function _replaceFacetSelectors(
        AppStorage.Layout storage l,
        FacetCut memory facetCut
    ) internal {
        unchecked {
            if (!facetCut.target.isContract()) revert TargetHasNoCode();

            // Iterate through each selector in the facet cut and replace it in the storage
            for (uint256 i; i < facetCut.selectors.length; i++) {
                bytes4 selector = facetCut.selectors[i];
                bytes32 oldFacet = l.facets[selector];
                address oldFacetAddress = address(bytes20(oldFacet));

                if (oldFacetAddress == address(0)) revert SelectorNotFound();
                if (oldFacetAddress == address(this))
                    revert SelectorIsImmutable();
                if (oldFacetAddress == facetCut.target)
                    revert ReplaceTargetIsIdentical();

                l.facets[selector] =
                    (oldFacet & CLEAR_ADDRESS_MASK) |
                    bytes20(facetCut.target);
            }
        }
    }

    /**
     * @dev Internal function to set the fallback address for the contract.
     * @param fallbackAddress The fallback address to set.
     */
    function _setFallbackAddress(address fallbackAddress) internal {
        AppStorage.layout().fallbackAddress = fallbackAddress;
    }

    /**
     * @dev Internal function to mark the base initialization of the contract.
     *      This flag can be used to track whether the base contract has been initialized.
     */
    function _base_initialized() internal {
        AppStorage.layout().initialized = true;
    }

    /**
     * @dev Internal function to retrieve the implementation address for the current function call.
     * @return implementation The address of the implementation contract.
     */
    function _getImplementation()
        internal
        view
        returns (address implementation)
    {
        AppStorage.Layout storage ls = AppStorage.layout();
        implementation = address(bytes20(ls.facets[msg.sig]));
        if (implementation == address(0)) {
            implementation = ls.fallbackAddress;
        }
    }

    /**
     * @dev Private function to initialize a target contract with specific calldata.
     *      This function is typically used after applying a diamond cut to initialize new facets.
     * @param target The address of the target contract.
     * @param data The calldata to execute for initialization.
     */
    function _initialize(address target, bytes memory data) private {
        if ((target == address(0)) != (data.length == 0))
            revert InvalidInitializationParameters();

        if (target != address(0)) {
            if (target != address(this)) {
                if (!target.isContract()) revert TargetHasNoCode();
            }

            (bool success, ) = target.delegatecall(data);

            if (!success) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }
}
