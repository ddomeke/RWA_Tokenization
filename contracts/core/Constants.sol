// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {IAssetToken} from "../interfaces/IAssetToken.sol";

    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 constant PAYMENT_MANAGER_ROLE = keccak256("PAYMENT_MANAGER_ROLE");

    // Asset struct to store asset information
    struct Asset {
        uint256 id; // Unique ID for the asset
        uint256 totalTokens; // Total number of tokens representing the asset
        uint256 tokenPrice; // Price per token in USDT (scaled by 10^18 for precision)
        uint256 totalProfit; // Total profit accumulated by the asset
        uint256 profitPeriod; // Total profit accumulated by the asset
        uint256 lastDistributed; // Last distribution timestamp
        string uri; // URI for metadata
        IAssetToken tokenContract;
        address[] tokenHolders; // List of token holders for profit sharing
        mapping(address => UserTokenInfo) userTokenInfo;
    }

    struct UserTokenInfo {
        uint256 holdings; // User's holdings in the asset
        uint256 pendingProfits; // Pending profits for the user
        uint256 tokensForSale; // Number of tokens put for sale by the user
        uint256 salePrices; // Sale price set by the user
    }

    struct Proposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        uint256 deadline;
        mapping(address => bool) voters;
    }
