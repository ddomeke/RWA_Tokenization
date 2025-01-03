// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../token/ERC20/IERC20.sol";
import "../utils/EnumerableSet.sol";
import "../core/abstracts/ModularInternal.sol";

contract RWA_DAO is  ModularInternal{
    using AppStorage for AppStorage.Layout;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public governanceToken;
    address public appAddress;

    struct Proposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        uint256 deadline;
        mapping(address => bool) voters;
    }

    uint256 private proposalCounter;
    mapping(uint256 => Proposal) public proposals;
    EnumerableSet.AddressSet private voters;

    uint256 public proposalDuration = 7 days;
    uint256 public minimumQuorum = 100 * 10 ** 18; // Minimum tokens required to execute a proposal

    event ProposalCreated(uint256 id, string description, uint256 deadline);
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id, bool success);
    event GovernanceTokenUpdated(address oldToken, address newToken);
    event RWATokenizationContractUpdated(address oldContract, address newContract);

    address immutable _this;

    modifier onlyTokenHolders() {
        require(
            governanceToken.balanceOf(msg.sender) > 0,
            "Not a governance token holder"
        );
        _;
    }

    constructor(address _governanceToken, address _appAddress) {
        require(_governanceToken != address(0), "Invalid governance token address");
        require(_appAddress != address(0), "Invalid RWA contract address");

        governanceToken = IERC20(_governanceToken);

        _this = address(this);
        appAddress = _appAddress;
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, _appAddress);
    }

        /**
     * @dev Returns an array of ⁠ FacetCut ⁠ structs, which define the functions (selectors)
     *      provided by this module. This is used to register the module's functions
     *      with the modular system.
     * @return FacetCut[] Array of ⁠ FacetCut ⁠ structs representing function selectors.
     */
    function moduleFacets() external view returns (FacetCut[] memory) {
        uint256 selectorIndex = 0;
        bytes4[] memory selectors = new bytes4[](7);

        // Add function selectors to the array
        selectors[selectorIndex++] = this.createProposal.selector;
        selectors[selectorIndex++] = this.vote.selector;
        selectors[selectorIndex++] = this.executeProposal.selector;
        selectors[selectorIndex++] = this.updateMinimumQuorum.selector;
        selectors[selectorIndex++] = this.updateProposalDuration.selector;
        selectors[selectorIndex++] = this.updateGovernanceToken.selector;
        selectors[selectorIndex++] = this.getProposal.selector;

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


    function createProposal(string memory description) external onlyTokenHolders {

        proposalCounter = proposalCounter + 1;
        uint256 proposalId = proposalCounter;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.description = description;
        newProposal.deadline = block.timestamp + proposalDuration;

        emit ProposalCreated(proposalId, description, newProposal.deadline);
    }

    function vote(uint256 proposalId, bool support) external onlyTokenHolders {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp <= proposal.deadline, "Voting period ended");
        require(!proposal.voters[msg.sender], "Already voted");

        uint256 voterBalance = governanceToken.balanceOf(msg.sender);

        if (support) {
            proposal.forVotes += voterBalance;
        } else {
            proposal.againstVotes += voterBalance;
        }

        proposal.voters[msg.sender] = true;
        emit Voted(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external nonReentrant onlyRole(ADMIN_ROLE){
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(
            proposal.forVotes >= minimumQuorum,
            "Minimum quorum not reached"
        );

        proposal.executed = true;

        // Execute action on the RWA Tokenization contract
        (bool success, ) = appAddress.call(
            abi.encodeWithSignature("distributeProfit(uint256,uint256)", 1, 1000)
        );

        emit ProposalExecuted(proposalId, success);
    }

    function updateMinimumQuorum(uint256 newQuorum) external onlyRole(ADMIN_ROLE) {
        require(newQuorum > 0, "Quorum must be greater than zero");
        minimumQuorum = newQuorum;
    }

    function updateProposalDuration(uint256 newDuration) external onlyRole(ADMIN_ROLE) {
        require(newDuration > 0, "Duration must be greater than zero");
        proposalDuration = newDuration;
    }

    function updateGovernanceToken(address newGovernanceToken) external onlyRole(ADMIN_ROLE) {
        require(newGovernanceToken != address(0), "Invalid governance token address");

        address oldToken = address(governanceToken);
        governanceToken = IERC20(newGovernanceToken);

        emit GovernanceTokenUpdated(oldToken, newGovernanceToken);
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            uint256 id,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            bool executed,
            uint256 deadline
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.deadline
        );
    }
}
