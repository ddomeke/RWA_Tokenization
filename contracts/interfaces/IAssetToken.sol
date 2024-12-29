// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {IERC1155} from "../token/ERC1155/IERC1155.sol";


interface IAssetToken is IERC1155 {

    function lockTokens(address account, uint256 id, uint256 amount) external;
    function unlockTokens(address account, uint256 id, uint256 amount) external;
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
    function setURI(string memory newuri) external;
    function pause() external;
    function unpause() external;


}