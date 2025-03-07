// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @file PriceFetcher.sol
 * @notice This file contains the implementation of the PriceFetcher module.
 * @dev This module is responsible for fetching price data for the RWA tokenization project.
 *
 * @import ModularInternal.sol - Provides internal modular functionalities.
 * @import IPriceFetcher.sol - Interface for the PriceFetcher module.
 */
import "../core/abstracts/ModularInternal.sol";
import "../interfaces/IPriceFetcher.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/**
 * @title PriceFetcher
 * @dev This contract is a module that fetches price data. It inherits from the ModularInternal contract.
 */
contract PriceFetcher is ModularInternal {
    using AppStorage for AppStorage.Layout;

    address public immutable fexseToken;
    address public immutable token1;
    uint24 public immutable fee;

    address immutable _this;



    /**
     * @dev Constructor for the PriceFetcher contract.
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
        bytes4[] memory selectors = new bytes4[](2);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.getFexsePrice.selector;
        selectors[selectorIndex++] = this.getGasPriceInUSDT.selector;
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

    function getFexsePrice() external view returns (uint256 price) {
        // Get the pool address
        // address pool = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984).getPool(
        //     fexseToken,
        //     token1,
        //     fee
        // );
        // require(pool != address(0), "Pool does not exist");

        // //console.log("Pool address: ", pool);

        // // Get the slot0 data
        // (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        // require(sqrtPriceX96 > 0, "Uninitialized pool or no liquidity");

        // // Calculate the price
        // unchecked {
        //     price = (((uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) *
        //         10 ** 18) / (1 << 192));
        // }

        // //console.log(" price", price);

        // // If token1 is token0, invert the price
        // if (IUniswapV3Pool(pool).token0() == token1) {
        //     price = (1e18 * 1e18) / price; // Adjust decimals
        // }

        price = (45 * 10 ** 3);
    }

    function getGasPriceInUSDT(uint256 gasUsed) external view returns (uint256) {
        uint256 gasPrice = tx.gasprice;

        uint256 gasFeeinETH = gasPrice * gasUsed;

        (, int256 Price, , , ) = AggregatorV3Interface(0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46).latestRoundData();
        require(Price > 0, "Invalid ETH price");

        uint256 gasPriceInUSDT = (gasFeeinETH * 10 ** 6) / uint256(Price);

        return gasPriceInUSDT;
    }
}