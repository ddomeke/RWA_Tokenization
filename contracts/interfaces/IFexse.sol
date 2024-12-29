// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {IERC20} from "../token/ERC20/IERC20.sol";


interface IFexse is IERC20 {

    function lock(address owner,uint256 amount) external;
    function unlock(address owner,uint256 amount) external;
}