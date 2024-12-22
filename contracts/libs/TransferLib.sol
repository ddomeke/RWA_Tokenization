// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

library TransferLib {
    error TxFailed();

    function _transfer(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));

        if (!success) revert TxFailed();
    }

    function _transfer(
        address token,
        address to,
        uint256 value
    ) internal returns (bool, bytes memory) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );

        _checkResponse(success, data);

        return (success, data);
    }

    function _transferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal returns (bool, bytes memory) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                value
            )
        );

        _checkResponse(success, data);

        return (success, data);
    }

    function _approve(
        address token,
        address to,
        uint256 value
    ) internal returns (bool, bytes memory) {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, to, value)
        );

        _checkResponse(success, data);

        return (success, data);
    }

    function _checkResponse(bool status, bytes memory data) internal pure {
        if (!(status && (data.length == 0 || abi.decode(data, (bool)))))
            revert TxFailed();
    }
}
