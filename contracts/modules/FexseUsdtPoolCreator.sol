// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @file FexseUsdtPoolCreator.sol
 * @notice This contract is responsible for creating and managing USDT pools.
 *
 * @dev This contract imports several interfaces and contracts:
 * - IERC721Metadata from OpenZeppelin: Interface for ERC721 metadata functions.
 * - INonfungiblePositionManager from Uniswap V3 Periphery: Interface for managing non-fungible positions.
 * - IUniswapV3Factory from Uniswap V3 Core: Interface for the Uniswap V3 factory.
 * - ModularInternal: Abstract contract for modular internal functionality.
 * - console from Hardhat: Used for debugging purposes.
 */
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../core/abstracts/ModularInternal.sol";
import "hardhat/console.sol";

/**
 * @title FexseUsdtPoolCreator
 * @dev This contract is a module that extends the ModularInternal contract. It is responsible for creating and managing USDT pools within the Fexse ecosystem.
 */
contract FexseUsdtPoolCreator is ModularInternal {
    address public immutable fexseToken; // Address of the FEXSE token
    address public immutable token1; // Address of the token1 token
    uint24 public immutable poolFee; // Pool fee, e.g., 500 for 0.5%

    address immutable _this;

    address public constant factory =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public constant positionManager =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    event PoolCreated(address indexed pool);
    event LiquidityAdded(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amountFexse,
        uint256 amounttoken1
    );

    /**
     * @dev Constructor to initialize the contract with required addresses and pool fee.
     * @param _fexseToken Address of the FEXSE token.
     * @param _token1 Address of the token1 token.
     * @param _poolFee Fee tier for the pool (e.g., 500 for 0.5%).
     */
    constructor(address _fexseToken, address _token1, uint24 _poolFee) {
        require(_fexseToken != address(0), "Invalid FEXSE token address");
        require(_token1 != address(0), "Invalid token1 token address");

        _this = address(this);
        _grantRole(ADMIN_ROLE, msg.sender);

        fexseToken = _fexseToken;
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
        selectors[selectorIndex++] = this.createPool.selector;
        selectors[selectorIndex++] = this.addLiquidity.selector;
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
     * @dev Creates a FEXSE/token1 pool if it doesn't already exist.
     * @param initialPriceX96 Initial price of the pool in sqrtPriceX96 format.
     */
    function createPool(
        uint160 initialPriceX96
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        // Check if the pool already exists
        address pool = IUniswapV3Factory(factory).getPool(
            fexseToken,
            token1,
            poolFee
        );
        require(pool == address(0), "Pool already exists");

        // Create the pool
        pool = INonfungiblePositionManager(positionManager)
            .createAndInitializePoolIfNecessary(
                fexseToken,
                token1,
                poolFee,
                initialPriceX96
            );

        console.log("initialPriceX96 :", initialPriceX96);
        console.log("pool :", pool);

        emit PoolCreated(pool);
    }

    /**
     * @dev Adds liquidity to the FEXSE/token1 pool.
     * @param amountFexse Desired amount of FEXSE tokens to add as liquidity.
     * @param amounttoken1 Desired amount of token1 tokens to add as liquidity.
     * @param lowerTick Lower tick boundary for the liquidity position.
     * @param upperTick Upper tick boundary for the liquidity position.
     */
    function addLiquidity(
        uint256 amountFexse,
        uint256 amounttoken1,
        int24 lowerTick,
        int24 upperTick
    )
        external
        nonReentrant
        onlyRole(ADMIN_ROLE)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amountFexseUsed,
            uint256 amounttoken1Used
        )
    {
        require(amountFexse > 0, "FEXSE amount must be greater than zero");
        require(amounttoken1 > 0, "token1 amount must be greater than zero");

        // Approve the position manager to spend the tokens
        IERC20(fexseToken).approve(positionManager, amountFexse * 20);
        IERC20(token1).approve(positionManager, amounttoken1 * 20);

        // Transfer tokens from the sender to this contract
        IERC20(fexseToken).transferFrom(msg.sender, address(this), amountFexse);
        IERC20(token1).transferFrom(msg.sender, address(this), amounttoken1);

        console.log("msg.sender :", msg.sender);

        // Add liquidity using NonfungiblePositionManager
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: fexseToken,
                token1: token1,
                fee: poolFee,
                tickLower: lowerTick,
                tickUpper: upperTick,
                amount0Desired: amountFexse,
                amount1Desired: amounttoken1,
                amount0Min: 0, //(amountFexse * 90) / 100, //0, // Slippage control, set to 0 for simplicity
                amount1Min: 0, //(amounttoken1 * 90) / 100, //0, // Slippage control, set to 0 for simplicity
                recipient: msg.sender,
                deadline: block.timestamp + 300
            });

        (
            tokenId,
            liquidity,
            amountFexseUsed,
            amounttoken1Used
        ) = INonfungiblePositionManager(positionManager).mint(params);

        console.log("amountFexseUsed :", amountFexseUsed);
        console.log("amounttoken1Used :", amounttoken1Used);
        console.log("liquidity :", liquidity);

        // Refund unused tokens
        if (amountFexse > amountFexseUsed) {
            IERC20(fexseToken).transfer(
                msg.sender,
                amountFexse - amountFexseUsed
            );
        }
        if (amounttoken1 > amounttoken1Used) {
            IERC20(token1).transfer(
                msg.sender,
                amounttoken1 - amounttoken1Used
            );
        }

        emit LiquidityAdded(
            tokenId,
            liquidity,
            amountFexseUsed,
            amounttoken1Used
        );
    }

    //function collectAllFees(uint256 tokenId)
    //     external
    //     returns (uint256 amount0, uint256 amount1)
    // {
    //     INonfungiblePositionManager.CollectParams memory params =
    //     INonfungiblePositionManager.CollectParams({
    //         tokenId: tokenId,
    //         recipient: address(this),
    //         amount0Max: type(uint128).max,
    //         amount1Max: type(uint128).max
    //     });

    //     (amount0, amount1) = nonfungiblePositionManager.collect(params);
    // }

    // function increaseLiquidityCurrentRange(
    //     uint256 tokenId,
    //     uint256 amount0ToAdd,
    //     uint256 amount1ToAdd
    // ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
    //     dai.transferFrom(msg.sender, address(this), amount0ToAdd);
    //     weth.transferFrom(msg.sender, address(this), amount1ToAdd);

    //     dai.approve(address(nonfungiblePositionManager), amount0ToAdd);
    //     weth.approve(address(nonfungiblePositionManager), amount1ToAdd);

    //     INonfungiblePositionManager.IncreaseLiquidityParams memory params =
    //     INonfungiblePositionManager.IncreaseLiquidityParams({
    //         tokenId: tokenId,
    //         amount0Desired: amount0ToAdd,
    //         amount1Desired: amount1ToAdd,
    //         amount0Min: 0,
    //         amount1Min: 0,
    //         deadline: block.timestamp
    //     });

    //     (liquidity, amount0, amount1) =
    //         nonfungiblePositionManager.increaseLiquidity(params);
    // }

    // function decreaseLiquidityCurrentRange(uint256 tokenId, uint128 liquidity)
    //     external
    //     returns (uint256 amount0, uint256 amount1)
    // {
    //     INonfungiblePositionManager.DecreaseLiquidityParams memory params =
    //     INonfungiblePositionManager.DecreaseLiquidityParams({
    //         tokenId: tokenId,
    //         liquidity: liquidity,
    //         amount0Min: 0,
    //         amount1Min: 0,
    //         deadline: block.timestamp
    //     });

    //     (amount0, amount1) =
    //         nonfungiblePositionManager.decreaseLiquidity(params);
    // }
}
