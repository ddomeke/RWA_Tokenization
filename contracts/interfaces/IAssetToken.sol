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

    //function getLockedTokens(address account, uint256 id) external;

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 id,
    //     uint256 value,
    //     bytes memory data
    // ) public;

    // function safeBatchTransferFrom(
    //     address from,
    //     address to,
    //     uint256[] memory ids,
    //     uint256[] memory values,
    //     bytes memory data
    // ) public;

    // function supportsInterface(bytes4 interfaceId) public;

}
