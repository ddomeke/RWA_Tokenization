// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../core/abstracts/ModularInternal.sol";

contract FexsePriceFetcher is ModularInternal{
    using AppStorage for AppStorage.Layout;

    address public immutable fexseToken;
    address public immutable usdtToken;
    uint24 public immutable fee;

    address immutable _this;

    address public constant factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    constructor(
        address _fexseToken,
        address _usdtToken,
        uint24 _fee
    ) {
        require(_fexseToken != address(0), "Invalid _fexseToken address");
        require(_usdtToken != address(0), "Invalid USDT token address");

        _this = address(this);
        _grantRole(ADMIN_ROLE, msg.sender);

        fexseToken = _fexseToken;
        usdtToken = _usdtToken;
        fee = _fee;
    }
    /**
     * @dev Returns an array of ⁠ FacetCut ⁠ structs, which define the functions (selectors)
     *      provided by this module. This is used to register the module's functions
     *      with the modular system.
     * @return FacetCut[] Array of ⁠ FacetCut ⁠ structs representing function selectors.
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
     * @dev Fetches the current price of FEXSE in USDT.
     * @return price The price of 1 FEXSE in USDT.
     */
    function getFexsePrice() external view returns (uint256 price) {
        // Get the pool address
        address pool = IUniswapV3Factory(factory).getPool(fexseToken, usdtToken, fee);
        require(pool != address(0), "Pool does not exist");

        // Get the slot0 data
        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();

        // Calculate the price
        price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (1 << 192);

        // If USDT is token0, invert the price
        if (IUniswapV3Pool(pool).token0() == usdtToken) {
            price = (1e18 * 1e18) / price; // Adjust decimals
        }
    }
}