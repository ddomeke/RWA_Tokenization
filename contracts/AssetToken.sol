// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Pausable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAssetToken} from "./IAssetToken.sol";
import {IRWATokenization} from "./IRWATokenization.sol";
import "hardhat/console.sol";



contract AssetToken is IAssetToken, ERC1155, Ownable, ERC1155Pausable, ERC1155Supply {

    IRWATokenization public rwaContract;

    modifier onlyOwnerOrRWAContract() {
        require(msg.sender == owner() || msg.sender == address(rwaContract), "Not authorized");
        _;
    }

    constructor(
        address initialOwner,
        string memory uri_,
        address _rwaContract
    )
        ERC1155(uri_)
        Ownable(initialOwner)
    {
        rwaContract = IRWATokenization(_rwaContract);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwnerOrRWAContract {
        _mint(account, id, amount, data);
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
        require(address(rwaContract).code.length > 0, "Target address is not a contract");

        super._update(from, to, ids, values);
        
        //console.log("rwaContract", rwaContract);

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