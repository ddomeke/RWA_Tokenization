// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @file FexsePriceFetcher.sol
 * @notice This contract is responsible for fetching price data from Uniswap V3 pools.
 *
 * @dev This contract imports the following:
 * - IUniswapV3Pool: Interface for interacting with Uniswap V3 pools.
 * - IUniswapV3Factory: Interface for interacting with the Uniswap V3 factory.
 * - ModularInternal: Abstract contract providing internal modular functionality.
 *
 * @author [Your Name]
 */
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../core/abstracts/ModularInternal.sol";

/**
 * @title FexsePriceFetcher
 * @dev This contract is a module that fetches price data. It inherits from the ModularInternal contract.
 */
contract FexsePriceFetcher is ModularInternal {
    using AppStorage for AppStorage.Layout;

    address public immutable fexseToken;
    address public immutable token1;
    uint24 public immutable fee;

    address immutable _this;

    address public constant factory =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;

    /**
     * @dev Constructor for the FexsePriceFetcher contract.
     * @param _fexseToken The address of the Fexse token.
     * @param _token1 The address of the first token.
     * @param _fee The fee associated with the token pair.
     *
     * Requirements:
     * - `_fexseToken` cannot be the zero address.
     * - `_token1` cannot be the zero address.
     *
     * Initializes the contract by setting the Fexse token address, the first token address, and the fee.
     * Grants the `ADMIN_ROLE` to the deployer of the contract.
     */
    constructor(address _fexseToken, address _token1, uint24 _fee) {
        require(_fexseToken != address(0), "Invalid _fexseToken address");
        require(_token1 != address(0), "Invalid token1 token address");

        _this = address(this);
        _grantRole(ADMIN_ROLE, msg.sender);

        fexseToken = _fexseToken;
        token1 = _token1;
        fee = _fee;
    }

    /**
     * @notice Returns an array of FacetCut structs representing the module facets.
     * @dev This function constructs an array of FacetCut structs with a single element.
     *      It sets the function selector for `getFexsePrice` and assigns it to the FacetCut.
     * @return facetCuts An array of FacetCut structs containing the module facets.
     */
    function moduleFacets() external view returns (FacetCut[] memory) {
        uint256 selectorIndex = 0;
        bytes4[] memory selectors = new bytes4[](1);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.getFexsePrice.selector;
        // Create a FacetCut array with a single element
        FacetCut[] memory facetCuts = new FacetCut[](1);

        // Set the facetCut target, action, and selectors
        facetCuts[0] = FacetCut({
            target: _this,
            action: FacetCutAction.ADD,
            selectors: selectors
        });
        return facetCuts;
    }

    /**
     * @notice Fetches the current price of the Fexse token from a Uniswap V3 pool.
     * @dev This function retrieves the pool address from the Uniswap V3 factory,
     *      gets the slot0 data from the pool, and calculates the price based on the sqrtPriceX96 value.
     *      If token1 is the same as token0 in the pool, the price is inverted to adjust the decimals.
     * @return price The current price of the Fexse token.
     * @dev The pool must exist, otherwise the function will revert with "Pool does not exist".
     */
    function getFexsePrice() external view returns (uint256 price) {
        // Get the pool address
        address pool = IUniswapV3Factory(factory).getPool(
            fexseToken,
            token1,
            fee
        );
        require(pool != address(0), "Pool does not exist");

        // Get the slot0 data
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

        // Calculate the price
        unchecked {
            price =
                (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) /
                (1 << 192);
        }

        // If token1 is token0, invert the price
        if (IUniswapV3Pool(pool).token0() == token1) {
            price = (1e18 * 1e18) / price; // Adjust decimals
        }
    }
}
