// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IModularInternal.sol";
import "./IERC165.sol";

interface IModular is IModularInternal, IERC165 {
    fallback() external payable;

    receive() external payable;

    function facets() external view returns (Facet[] memory diamondFacets);

    function facetFunctionSelectors(
        address facet
    ) external view returns (bytes4[] memory selectors);

    function facetAddresses()
        external
        view
        returns (address[] memory addresses);

    function facetAddress(
        bytes4 selector
    ) external view returns (address facet);

    function getFallbackAddress()
        external
        view
        returns (address fallbackAddress);

    function setFallbackAddress(address fallbackAddress) external;

    function diamondCut(
        FacetCut[] calldata facetCuts,
        address target,
        bytes calldata data
    ) external;

    function installModule(address moduleAddress) external;
}
