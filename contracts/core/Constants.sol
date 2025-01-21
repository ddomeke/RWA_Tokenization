// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @file Constants.sol
 * @dev This file contains constant definitions and imports required for the RWATokenization project.
 *
 * Imports:
 * - IERC20: Interface for the ERC20 standard as defined in the EIP.
 * - IAssetToken: Interface for asset token functionalities specific to this project.
 */
import "../token/ERC20/IERC20.sol";
import {IAssetToken} from "../interfaces/IAssetToken.sol";

/**
 * @dev Constants and data structures used in the RWATokenization contracts.
 */

// Roles
/**
 * @dev Role identifier for the admin role.
 */
bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

/**
 * @dev Role identifier for the compliance officer role.
 */
bytes32 constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");

/**
 * @dev Role identifier for the payment manager role.
 */
bytes32 constant PAYMENT_MANAGER_ROLE = keccak256("PAYMENT_MANAGER_ROLE");

// Asset struct
/**
 * @dev Struct to store asset information.
 * @param id Unique ID for the asset.
 * @param totalTokens Total number of tokens representing the asset.
 * @param tokenPrice Price per token in USDT (scaled by 10^18 for precision).
 * @param totalProfit Total profit accumulated by the asset.
 * @param profitPeriod Total profit accumulated by the asset.
 * @param lastDistributed Last distribution timestamp.
 * @param uri URI for metadata.
 * @param tokenContract Contract address of the asset token.
 * @param tokenHolders List of token holders for profit sharing.
 * @param userTokenInfo Mapping of user addresses to their token information.
 */
struct Asset {
    uint256 id;
    uint256 totalTokens;
    uint256 tokenPrice;
    uint256 totalProfit;
    uint256 profitPeriod;
    uint256 lastDistributed;
    uint256 tokenLowerLimit;
    string uri;
    IAssetToken tokenContract;
    address[] tokenHolders;
    mapping(address => UserTokenInfo) userTokenInfo;
}

// UserTokenInfo struct
/**
 * @dev Struct to store information about a user's holdings in an asset.
 * @param holdings User's holdings in the asset.
 * @param pendingProfits Pending profits for the user.
 * @param tokensForSale Number of tokens put for sale by the user.
 * @param salePrices Sale price set by the user.
 */
struct UserTokenInfo {
    uint256 holdings;
    uint256 pendingProfits;
    uint256 tokensForSale;
    uint256 salePrices;
}

// Proposal struct
/**
 * @dev Struct to store information about a governance proposal.
 * @param id Unique ID for the proposal.
 * @param governanceToken Governance token used for voting.
 * @param description Description of the proposal.
 * @param forVotes Number of votes in favor of the proposal.
 * @param againstVotes Number of votes against the proposal.
 * @param minimumQuorum Minimum number of votes required for the proposal to be valid.
 * @param executed Whether the proposal has been executed.
 * @param deadline Deadline for voting on the proposal.
 * @param voters Mapping of voter addresses to their voting status.
 */
struct Proposal {
    uint256 id;
    IERC20 governanceToken;
    string description;
    uint256 forVotes;
    uint256 againstVotes;
    uint256 minimumQuorum;
    bool executed;
    uint256 deadline;
    mapping(address => bool) voters;
}

/**
 * @dev Represents a stake in the system.
 * @param amount The amount of tokens staked.
 * @param rewardDebt The amount of rewards debt associated with the stake.
 * @param lockTime The time until which the stake is locked.
 */
struct Stake {
    uint256 amount;
    uint256 rewardDebt;
    uint256 lockTime;
}
