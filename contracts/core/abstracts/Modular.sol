// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "./ModularInternal.sol";
import "../../interfaces/IModular.sol";
import {IERC165, ERC165} from "../../utils/ERC165.sol";

/**
 * @title Modular
 * @dev This abstract contract implements the base functionalities for a modular smart contract system,
 *      enabling the addition and management of different modules (facets) and handling fallback logic
 *      for delegate calls.
 */
abstract contract Modular is IModular, ModularInternal {
    using AppStorage for *;
    using AddressLib for address;

    /**
     * @dev Constructor initializes the base state of the contract, registers initial facets,
     *      and sets up the deployer's access.
     */
    constructor() {
        // Access the application's storage layout
        AppStorage.Layout storage data = AppStorage.layout();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        // Define an array of function selectors for the initial facets
        bytes4[] memory selectors = new bytes4[](10);
        uint256 selectorIndex = 0;

        // Populate the selectors array with function signatures
        selectors[selectorIndex++] = IModular.getFallbackAddress.selector;
        selectors[selectorIndex++] = IModular.setFallbackAddress.selector;
        selectors[selectorIndex++] = IModular.diamondCut.selector;
        selectors[selectorIndex++] = IModular.facets.selector;
        selectors[selectorIndex++] = IModular.facetFunctionSelectors.selector;
        selectors[selectorIndex++] = IModular.facetAddresses.selector;
        selectors[selectorIndex++] = IModular.facetAddress.selector;
        selectors[selectorIndex++] = IModular.installModule.selector;
        selectors[selectorIndex++] = bytes4(0xd3b86141);
        selectors[selectorIndex++] = IERC165.supportsInterface.selector;

        // Create an array to hold the facet cuts (changes to the contract's functionality)
        FacetCut[] memory facetCuts = new FacetCut[](1);

        // Define the facet cut with the ADD action for the current contract address
        facetCuts[0] = FacetCut({
            target: address(this),
            action: FacetCutAction.ADD,
            selectors: selectors
        });

        // Apply the facet cuts to the diamond storage
        _diamondCut(facetCuts, address(0), "");

        // Set the deployer address and give it full access (hex'ff' for maximum permissions)
        data.deployer = msg.sender;

        // Initialize the base state of the contract
        _base_initialized();
    }

    /**
     * @dev Fallback function that delegates calls to the appropriate implementation contract.
     *      It uses assembly to directly handle the low-level delegatecall and manage the return data.
     */
    fallback() external payable {
        // Get the implementation address for the current function call
        address implementation = _getImplementation();

        // Ensure the implementation address is a contract
        if (!implementation.isContract()) revert ImplementationIsNotContract();

        // Perform the delegate call using inline assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Receive function to accept Ether. This is required for the contract to accept ETH transfers.
     */
    receive() external payable {}

    /**
     * @dev Returns the array of facets (modules) currently installed in the contract.
     * @return diamondFacets The array of facets currently installed.
     */
    function facets() external view returns (Facet[] memory diamondFacets) {
        diamondFacets = _facets();
    }

    /**
     * @dev Returns the array of function selectors associated with a specific facet.
     * @param facet The address of the facet to query.
     * @return selectors The array of function selectors for the given facet.
     */
    function facetFunctionSelectors(
        address facet
    ) external view returns (bytes4[] memory selectors) {
        selectors = _facetFunctionSelectors(facet);
    }

    /**
     * @dev Returns the array of facet addresses currently used by the contract.
     * @return addresses The array of facet addresses.
     */
    function facetAddresses()
        external
        view
        returns (address[] memory addresses)
    {
        addresses = _facetAddresses();
    }

    /**
     * @dev Returns the address of the facet that implements the given function selector.
     * @param selector The function selector to query.
     * @return facet The address of the facet implementing the function.
     */
    function facetAddress(
        bytes4 selector
    ) external view returns (address facet) {
        facet = _facetAddress(selector);
    }

    /**
     * @dev Returns the fallback address currently set for the contract.
     * @return fallbackAddress The fallback address.
     */
    function getFallbackAddress()
        external
        view
        returns (address fallbackAddress)
    {
        fallbackAddress = AppStorage.layout().fallbackAddress;
    }

    /**
     * @dev Sets a new fallback address. This function is authorized and can only be called by an entity with the proper access.
     * @param fallbackAddress The new fallback address to set.
     */
    function setFallbackAddress(
        address fallbackAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFallbackAddress(fallbackAddress);
    }

    /**
     * @dev Modifies the contract's functionality by adding, replacing, or removing facets.
     *      This function is authorized and can only be called by an entity with the proper access.
     * @param facetCuts The array of facet cuts to apply.
     * @param target The address to call with the calldata (if any).
     * @param data The calldata to execute after the facet cut (if any).
     */
    function diamondCut(
        FacetCut[] calldata facetCuts,
        address target,
        bytes calldata data
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _diamondCut(facetCuts, target, data);
    }

    /**
     * @dev Transfers ETH to a specified address. This function is authorized and can only be called by an entity with the proper access.
     * @param asset The asset (ETH) to transfer.
     * @param to The address to transfer to.
     * @param amount The amount of ETH to transfer.
     * @return success A boolean indicating whether the transfer was successful.
     * @return data The returned data from the transfer call.
     */
    function _transferETH(
        address asset,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool, bytes memory) {
        require(asset != address(0), "Invalid asset address");
        require(to != address(0), "Invalid to address");

        (bool success, bytes memory data) = asset.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        return (success, data);
    }

    /**
     * @dev Transfers tokens to a specified address. This function is authorized and can only be called by an entity with the proper access.
     * @param asset The token to transfer.
     * @param to The address to transfer to.
     * @param amount The amount of tokens to transfer.
     * @return success A boolean indicating whether the transfer was successful.
     * @return data The returned data from the transfer call.
     */
    function _transfer(
        address asset,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool, bytes memory) {
        require(asset != address(0), "Invalid asset address");
        require(to != address(0), "Invalid to address");

        (bool success, bytes memory data) = asset.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        return (success, data);
    }

    /**
     * @dev Transfers tokens from a specified address to another address. This function is authorized and can only be called by an entity with the proper access.
     * @param asset The token to transfer.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param amount The amount of tokens to transfer.
     * @return success A boolean indicating whether the transfer was successful.
     * @return data The returned data from the transfer call.
     */
    function _transferFrom(
        address asset,
        address from,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool, bytes memory) {
        require(asset != address(0), "Invalid asset address");
        require(from != address(0), "Invalid from address");
        require(to != address(0), "Invalid to address");

        (bool success, bytes memory data) = asset.call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                amount
            )
        );
        return (success, data);
    }

    /**
     * @dev Event emitted when a module is installed.
     */
    event Installer(FacetCut[] data);

    /**
     * @dev Installs a new module (facet) to the contract. This function is authorized and can only be called by an entity with the proper access.
     * @param moduleAddress The address of the module to install.
     */
    function installModule(
        address moduleAddress
    ) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        require(moduleAddress != address(0), "Invalid moduleAddress address");

        // Call the module's `moduleFacets()` function to get its facets
        (bool success, bytes memory returnData) = moduleAddress.call(
            abi.encodeWithSignature("moduleFacets()")
        );
        require(success, "moduleFacets() call failed");

        // Decode the returned facet cuts and apply them
        FacetCut[] memory facetCuts = new FacetCut[](1);
        facetCuts[0] = abi.decode(returnData, (FacetCut[]))[0];
        _diamondCut(facetCuts, address(0), "");

        // Emit the Installer event to log the installation of the module
        emit Installer(facetCuts);
    }

    /**
     * @dev Rescues any ERC20 tokens accidentally sent to the contract by transferring them to the deployer.
     *      This function can be called by anyone, but it transfers the tokens to the deployer address.
     * @param tokenAddr The address of the ERC20 token to rescue.
     */
    function rescueTokens(
        address tokenAddr
    ) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        uint balance = IERC20(tokenAddr).balanceOf(address(this));
        TransferLib._transfer(tokenAddr, AppStorage.layout().deployer, balance);
    }

    /**
     * @dev Rescues any Ether accidentally sent to the contract by transferring it to the deployer.
     *      This function can be called by anyone, but it transfers the Ether to the deployer address.
     */
    function withdrawEther() external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        uint balance = address(this).balance;
        payable(AppStorage.layout().deployer).transfer(balance);
    }
}
