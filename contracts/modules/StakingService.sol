// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
/**
 * @file StakingService.sol
 * @dev This file contains the implementation of the StakingService contract.
 *
 * The contract imports the following modules:
 * - IERC20: Interface for the ERC20 standard as defined in the EIP.
 * - ReentrancyGuard: Provides protection against reentrant calls.
 * - Ownable: Provides basic authorization control functions.
 * - AccessControl: Provides role-based access control mechanisms.
 */

import "../token/ERC20/IERC20.sol";
import "../core/abstracts/ModularInternal.sol";

/**
 * @title StakingService
 * @dev This contract provides staking services and inherits from AccessControl, ReentrancyGuard, and Ownable.
 * AccessControl: Provides role-based access control mechanisms.
 * ReentrancyGuard: Protects against reentrant calls.
 * Ownable: Provides basic authorization control functions.
 */
contract StakingService is ModularInternal {
    using AppStorage for AppStorage.Layout;

    IERC20 public governenceToken;
    uint256 public rewardRate;
    uint256 public totalStakedAmount;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event ProposalCreated(uint256 id, string description, uint256 deadline);
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id, bool success);
    event governenceTokenUpdated(address oldToken, address newToken);

    address immutable _this;

    /**
     * @dev Constructor for the StakingService contract.
     * @param _governenceToken The address of the governance token contract.
     *
     * Requirements:
     * - `_governenceToken` must not be the zero address.
     *
     * Initializes the contract by setting the governance token address and
     * transferring ownership to the deployer of the contract.
     */
    constructor(address _governenceToken) {
        require(
            _governenceToken != address(0),
            "Invalid _governenceToken token address"
        );

        _this = address(this);
        governenceToken = IERC20(_governenceToken);
    }

    /**
     * @dev Returns an array of ⁠ FacetCut ⁠ structs, which define the functions (selectors)
     *      provided by this module. This is used to register the module's functions
     *      with the modular system.
     * @return FacetCut[] Array of ⁠ FacetCut ⁠ structs representing function selectors.
     */
    function moduleFacets() external view returns (FacetCut[] memory) {
        uint256 selectorIndex = 0;
        bytes4[] memory selectors = new bytes4[](3);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.stake.selector;
        selectors[selectorIndex++] = this.unstake.selector;
        selectors[selectorIndex++] = this.setGovernenceToken.selector;

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
     * @notice Allows a user to stake a specified amount of tokens for a certain lock duration.
     * @dev The function is non-reentrant to prevent reentrancy attacks.
     * @param amount The amount of tokens to stake. Must be greater than 0.
     * @param _lockDuration The duration (in seconds) for which the tokens will be locked.
     * @dev The amount must be greater than 0.
     * @dev The transfer of tokens from the user to the contract must succeed.
     * @dev Emits a {Staked} event when tokens are successfully staked.
     */
    function stake(
        uint256 amount,
        uint256 _lockDuration
    ) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            governenceToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        AppStorage.Layout storage data = AppStorage.layout();
        Stake storage userStake = data.stakes[msg.sender];

        userStake.amount += amount;
        userStake.rewardDebt += (amount * rewardRate) / 1000;
        userStake.lockTime = block.timestamp + _lockDuration;

        totalStakedAmount += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Allows a user to unstake their tokens and claim any rewards.
     * @dev This function is protected by the nonReentrant modifier to prevent reentrancy attacks.
     * @dev The function checks if the user has staked tokens and if the lock time has passed.
     * @dev It transfers the staked amount and any rewards to the user and emits an Unstaked event.
     * @dev The user's stake is deleted from the stakes mapping and the total staked amount is updated.
     * @dev The user must have staked tokens.
     * @dev The current block timestamp must be greater than or equal to the user's lock time.
     * @dev The transfer of tokens to the user must succeed.
     * @dev Emits an {Unstaked} event when a user successfully unstakes their tokens.
     */
    function unstake() external nonReentrant {
        AppStorage.Layout storage data = AppStorage.layout();
        Stake storage userStake = data.stakes[msg.sender];

        require(userStake.amount > 0, "No tokens staked");
        require(
            block.timestamp >= userStake.lockTime,
            "Tokens are still locked"
        );

        uint256 amountToWithdraw = userStake.amount;
        uint256 reward = userStake.rewardDebt;

        delete data.stakes[msg.sender];
        totalStakedAmount -= amountToWithdraw;

        require(
            governenceToken.transfer(msg.sender, amountToWithdraw + reward),
            "Transfer failed"
        );

        emit Unstaked(msg.sender, amountToWithdraw);
    }

    /**
     * @notice Sets the governance token contract address.
     * @dev This function can only be called by the owner and is protected against reentrancy.
     * @param _governenceToken The address of the new governance token contract.
     * Requirements:
     * - `_governenceToken` must not be the zero address.
     * Emits a {governenceTokenUpdated} event.
     */
    function setGovernenceToken(
        IERC20 _governenceToken
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(
            address(_governenceToken) != address(0),
            "Invalid _fexseToken address"
        );

        address oldContract = address(governenceToken);
        governenceToken = _governenceToken;

        emit governenceTokenUpdated(oldContract, address(_governenceToken));
    }
}
