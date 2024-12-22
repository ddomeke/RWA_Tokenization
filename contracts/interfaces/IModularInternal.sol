// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IModularInternal {
    error InvalidInitializationParameters();
    error ImplementationIsNotContract();
    error RemoveTargetNotZeroAddress();
    error ReplaceTargetIsIdentical();
    error SelectorAlreadyAdded();
    error SelectorIsImmutable();
    error SelectorNotFound();
    error SelectorNotSpecified();
    error TargetHasNoCode();
    error InvalidInterface();

    event DiamondCut(FacetCut[] facetCuts, address target, bytes data);

    enum FacetCutAction {
        ADD,
        REPLACE,
        REMOVE
    }

    struct Facet {
        address target;
        bytes4[] selectors;
    }

    struct FacetCut {
        address target;
        FacetCutAction action;
        bytes4[] selectors;
    }
}
