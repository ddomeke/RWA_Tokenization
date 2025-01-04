// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/abstracts/ModularInternal.sol";

contract RWA_DAO is ModularInternal {
    using AppStorage for AppStorage.Layout;

    address public appAddress;

    event ProposalCreated(
        uint256 id,
        address governanceToken,
        string description,
        uint256 deadline
    );
    event Voted(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id, bool success);
    event GovernanceTokenUpdated(
        uint256 id,
        address oldToken,
        address newToken
    );

    address immutable _this;

    constructor(address _appAddress) {
        require(_appAddress != address(0), "Invalid RWA contract address");
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

    function createProposal(
        uint256 proposalId,
        address governanceTokenAddress,
        uint256 proposalDuration,
        uint256 minimumQuorum,
        string memory description
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(governanceTokenAddress != address(0), "Invalid token address");

        AppStorage.Layout storage data = AppStorage.layout();
        require(
            data.proposals[proposalId].id == 0,
            "Proposal with this ID already exists"
        );

        Proposal storage newProposal = data.proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.governanceToken = IERC20(governanceTokenAddress);
        newProposal.description = description;
        newProposal.deadline = block.timestamp + proposalDuration;
        newProposal.minimumQuorum = minimumQuorum;

        emit ProposalCreated(
            proposalId,
            governanceTokenAddress,
            description,
            newProposal.deadline
        );
    }

    function vote(
        uint256 proposalId,
        bool support
    ) external nonReentrant {
        AppStorage.Layout storage data = AppStorage.layout();
        Proposal storage proposal = data.proposals[proposalId];

        require(
            proposal.governanceToken.balanceOf(msg.sender) > 0,
            "Not a governance token holder"
        );

        require(block.timestamp <= proposal.deadline, "Voting period ended");
        require(!proposal.voters[msg.sender], "Already voted");

        uint256 voterBalance = proposal.governanceToken.balanceOf(msg.sender);

        if (support) {
            proposal.forVotes += voterBalance;
        } else {
            proposal.againstVotes += voterBalance;
        }

        proposal.voters[msg.sender] = true;
        emit Voted(proposalId, msg.sender, support);
    }

    function executeProposal(
        uint256 proposalId
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Proposal storage proposal = data.proposals[proposalId];

        require(block.timestamp > proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(
            proposal.forVotes >= proposal.minimumQuorum,
            "Minimum quorum not reached"
        );

        proposal.executed = true;

        // sample execute action on the RWA Tokenization contract
        (bool success, ) = appAddress.call(
            abi.encodeWithSignature(
                "distributeProfit(uint256,uint256)",
                1,
                1000
            )
        );

        emit ProposalExecuted(proposalId, success);
    }

    function updateMinimumQuorum(
        uint256 proposalId,
        uint256 newQuorum
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Proposal storage proposal = data.proposals[proposalId];

        require(newQuorum > 0, "Quorum must be greater than zero");
        proposal.minimumQuorum = newQuorum;
    }

    function updateProposalDuration(
        uint256 proposalId,
        uint256 newDuration
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Proposal storage proposal = data.proposals[proposalId];

        require(newDuration > 0, "Duration must be greater than zero");
        proposal.deadline = newDuration;
    }

    function updateGovernanceToken(
        uint256 proposalId,
        address newGovernanceToken
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        require(
            newGovernanceToken != address(0),
            "Invalid governance token address"
        );

        AppStorage.Layout storage data = AppStorage.layout();
        Proposal storage proposal = data.proposals[proposalId];

        address oldToken = address(proposal.governanceToken);
        proposal.governanceToken = IERC20(newGovernanceToken);

        emit GovernanceTokenUpdated(proposalId, oldToken, newGovernanceToken);
    }

    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint256 id,
            address governanceToken,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            bool executed,
            uint256 deadline
        )
    {
        AppStorage.Layout storage data = AppStorage.layout();
        Proposal storage proposal = data.proposals[proposalId];

        return (
            proposal.id,
            address(proposal.governanceToken),
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.deadline
        );
    }
}
