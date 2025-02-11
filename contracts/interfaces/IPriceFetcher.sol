// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";


interface IPriceFetcher {
    function getFexsePrice() external view returns (uint256 price);
    function getGasPriceInUSDT(uint256 gasUsed) external view returns (uint256);
}
