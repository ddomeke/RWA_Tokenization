// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../core/abstracts/ModularInternal.sol";

/**
 * @title SwapModule
 * @dev A contract to perform FEXSE/token1 swaps using Uniswap V3 protocol.
 */
contract SwapModule is ModularInternal {
    using AppStorage for AppStorage.Layout;

    ISwapRouter public immutable swapRouter;
    address public immutable token1;
    uint24 public immutable poolFee; // %0.5 = 500

    event Swapped(
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    address immutable _this;

    /**
     * @dev Constructor to initialize the swap module with required addresses and pool fee.
     * @param _swapRouter Address of the Uniswap V3 SwapRouter contract.
     * @param _token1 Address of the token1 token contract.
     * @param _poolFee Pool fee for the Uniswap V3 pool (e.g., 500 for 0.5%).
     */
    constructor(
        address _swapRouter,
        address _token1,
        uint24 _poolFee
    ) {
        require(_swapRouter != address(0), "Invalid swap router address");
        require(_token1 != address(0), "Invalid token1 token address");

        _this = address(this);
        _grantRole(ADMIN_ROLE, msg.sender);

        swapRouter = ISwapRouter(_swapRouter);
        token1 = _token1;
        poolFee = _poolFee;
    }

    /**
     * @dev Returns an array of ⁠ FacetCut ⁠ structs, which define the functions (selectors)
     *      provided by this module. This is used to register the module's functions
     *      with the modular system.
     * @return FacetCut[] Array of ⁠ FacetCut ⁠ structs representing function selectors.
     */
    function moduleFacets() external view returns (FacetCut[] memory) {
        uint256 selectorIndex = 0;
        bytes4[] memory selectors = new bytes4[](2);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.swaptoken1ToFexse.selector;
        selectors[selectorIndex++] = this.swapFexseTotoken1.selector;
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
     * @dev Swaps token1 for FEXSE and transfers the FEXSE tokens to the msg.sender.
     * @param token1Amount The amount of token1 to swap.
     * @param amountOutMinimum The minimum amount of FEXSE expected to be received.
     * @return amountOut The amount of FEXSE tokens received.
     */
    function swaptoken1ToFexse(
        uint256 token1Amount,
        uint256 amountOutMinimum
    ) external returns (uint256 amountOut) {
        require(token1Amount > 0, "Amount must be greater than zero");

        AppStorage.Layout storage data = AppStorage.layout();

        IFexse fexseToken = data.fexseToken;

        // Transfers token1 from the user to the contract
        IERC20(token1).transferFrom(msg.sender, address(this), token1Amount);

        // Approves the Uniswap Router to spend token1
        IERC20(token1).approve(address(swapRouter), token1Amount);

        // Defines the swap parameters for Uniswap V3
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: address(fexseToken),
                fee: poolFee,
                recipient: address(this), // Tokens will be sent to the contract first
                deadline: block.timestamp + 300, // Transaction must be executed within 5 minutes
                amountIn: token1Amount,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap on Uniswap
        amountOut = swapRouter.exactInputSingle(params);

        // Transfers the swapped FEXSE tokens to the user
        require(
            fexseToken.transfer(msg.sender, amountOut),
            "FEXSE transfer failed"
        );

        emit Swapped(msg.sender, token1, address(fexseToken), token1Amount, amountOut);
    }

    /**
     * @dev Swaps FEXSE for token1 and transfers the token1 tokens to the msg.sender.
     * @param fexseAmount The amount of FEXSE to swap.
     * @param amountOutMinimum The minimum amount of token1 expected to be received.
     * @return amountOut The amount of token1 tokens received.
     */
    function swapFexseTotoken1(
        uint256 fexseAmount,
        uint256 amountOutMinimum
    ) external returns (uint256 amountOut) {
        require(fexseAmount > 0, "Amount must be greater than zero");

        AppStorage.Layout storage data = AppStorage.layout();

        IFexse fexseToken = data.fexseToken;

        // Transfers FEXSE from the user to the contract
        IERC20(fexseToken).transferFrom(msg.sender, address(this), fexseAmount);

        // Approves the Uniswap Router to spend FEXSE
        IERC20(fexseToken).approve(address(swapRouter), fexseAmount);

        // Defines the swap parameters for Uniswap V3
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(fexseToken),
                tokenOut: token1,
                fee: poolFee,
                recipient: address(this), // Tokens will be sent to the contract first
                deadline: block.timestamp + 300, // Transaction must be executed within 5 minutes
                amountIn: fexseAmount,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap on Uniswap
        amountOut = swapRouter.exactInputSingle(params);

        // Transfers the swapped token1 tokens to the user
        require(
            IERC20(token1).transfer(msg.sender, amountOut),
            "token1 transfer failed"
        );

        emit Swapped(msg.sender, address(fexseToken), token1, fexseAmount, amountOut);
    }
}
