// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingService is ReentrancyGuard, Ownable {

    IERC20 public governenceToken;
    uint256 public rewardRate;
    uint256 public totalStakedAmount;

    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lockTime;
    }

    struct Proposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        uint256 deadline;
    }


    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event ProposalCreated(uint256 id, string description, uint256 deadline);
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id, bool success);
    event governenceTokenContractUpdated(address oldToken, address newToken);

    mapping(address => Stake) public stakes;
    mapping(uint256 => Proposal) public proposals;


    constructor(address _governenceToken) Ownable(msg.sender) {
        require(_governenceToken != address(0), "Invalid _governenceToken token address");
        governenceToken = IERC20(_governenceToken);
    }

    // Stake governenceToken tokens
    function stake(uint256 amount, uint256 _lockDuration) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(governenceToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        Stake storage userStake = stakes[msg.sender];

        userStake.amount += amount;
        userStake.rewardDebt += (amount * rewardRate) / 1000;
        userStake.lockTime = block.timestamp + _lockDuration;

        totalStakedAmount += amount;

        emit Staked(msg.sender, amount);
    }

    // Unstake FEXSE tokens after lock period
    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No tokens staked");
        require(block.timestamp >= userStake.lockTime, "Tokens are still locked");

        uint256 amountToWithdraw = userStake.amount;
        uint256 reward = userStake.rewardDebt;

        delete stakes[msg.sender];
        totalStakedAmount -= amountToWithdraw;

        require(governenceToken.transfer(msg.sender, amountToWithdraw + reward), "Transfer failed");

        emit Unstaked(msg.sender, amountToWithdraw);
    }

    function setGovernenceToken(
        IERC20 _governenceToken
    ) external onlyOwner nonReentrant  {
        require(
            address(_governenceToken) != address(0),
            "Invalid _fexseToken address"
        );

        address oldContract = address(governenceToken);
        governenceToken = _governenceToken;

        emit governenceTokenContractUpdated(oldContract, address(_governenceToken));
    }

}