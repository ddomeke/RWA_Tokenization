// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract SwapEthToUsdt {
    ISwapRouter public immutable swapRouter;

    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // Arbitrum üzerindeki USDT adresi
    uint24 public constant poolFee = 3000; // Uniswap V3 havuz ücreti (%0.3)

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter;
    }

    /// @notice ETH'yi USDT'ye çevir
    /// @param amountOutMinimum Minimum alınacak USDT miktarı
    /// @param deadline İşlem için son tarih (Unix timestamp)
    function swapEthForUsdt(uint256 amountOutMinimum, uint256 deadline) external payable {
        require(msg.value > 0, "ETH gonderilmedi");

        // Swap için parametreleri ayarla
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(0), // ETH
                tokenOut: USDT,
                fee: poolFee,
                recipient: msg.sender,
                deadline: deadline,
                amountIn: msg.value,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0 // Fiyat limit yok
            });

        // Swap işlemini başlat
        swapRouter.exactInputSingle{ value: msg.value }(params);
    }

    // Fonksiyon kontratın ETH alabilmesi için gerekli
    receive() external payable {}
}
