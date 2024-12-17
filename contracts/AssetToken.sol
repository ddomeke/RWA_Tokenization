// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Pausable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAssetToken} from "./IAssetToken.sol";
import {IRWATokenization} from "./IRWATokenization.sol";


contract AssetToken is IAssetToken, ERC1155, Ownable, ERC1155Pausable, ERC1155Supply {

    IRWATokenization public rwaContract;

    constructor(
        address initialOwner, 
        address account, 
        uint256 id, 
        uint256 amount, 
        bytes memory data, 
        string memory uri_,
        address rwaAddress
    )
        ERC1155(uri_)
        Ownable(initialOwner)
    {
        _mint(account, id, amount, data);
        rwaContract = IRWATokenization(rwaAddress); // Store RWATokenization contract reference
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        super._update(from, to, ids, values);

        // Notify external contracts of balance changes
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if (from != address(0)) {
                rwaContract.updateHoldings(from, id, balanceOf(from, id));
            }
            if (to != address(0)) {
                rwaContract.updateHoldings(to, id, balanceOf(to, id));
            }
        }
    }
}