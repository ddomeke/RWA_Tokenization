// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @file RWA_DAO.sol
 * @notice This file is part of the RWATokenization project and is located at /c:/Users/duran/RWATokenization/contracts/modules/.
 * @dev This contract imports the ModularInternal abstract contract from the core/abstracts directory.
 */
import "../core/abstracts/ModularInternal.sol";

/**
 * @title RWA_DAO
 * @dev This contract is a part of the RWA Tokenization project and extends the ModularInternal contract.
 * It is responsible for managing the DAO (Decentralized Autonomous Organization) functionalities within the RWA ecosystem.
 */
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

    /**
     * @dev Constructor for the RWA_DAO contract.
     * @param _appAddress The address of the RWA contract. Must not be the zero address.
     *
     * Requirements:
     * - `_appAddress` must not be the zero address.
     *
     * Initializes the contract by setting the `_appAddress`, storing the contract's own address,
     * and granting the `ADMIN_ROLE` to both the deployer and the `_appAddress`.
     */
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

    /**
     * @notice Creates a new proposal.
     * @dev Only callable by an account with the ADMIN_ROLE. Uses nonReentrant modifier to prevent reentrancy attacks.
     * @param proposalId The unique identifier for the proposal.
     * @param governanceTokenAddress The address of the governance token contract.
     * @param proposalDuration The duration (in seconds) for which the proposal will be active.
     * @param minimumQuorum The minimum number of votes required for the proposal to be considered valid.
     * @param description A brief description of the proposal.
     * @dev governanceTokenAddress must not be the zero address.
     * @dev A proposal with the given proposalId must not already exist.
     * @dev Emits a ProposalCreated event when a new proposal is created.
     */
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

    /**
     * @notice Casts a vote on a proposal.
     * @dev This function allows a governance token holder to vote on a proposal.
     *      The voter can either support or oppose the proposal.
     * @param proposalId The ID of the proposal to vote on.
     * @param support A boolean indicating whether the voter supports the proposal (true) or opposes it (false).
     * @dev The caller must hold governance tokens.
     * @dev The voting period must not have ended.
     * @dev The caller must not have already voted on the proposal.
     * @dev Emits a Voted event when a vote is successfully cast.
     */
    function vote(uint256 proposalId, bool support) external nonReentrant {
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

    /**
     * @notice Executes a proposal if it meets the required conditions.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures the voting period has ended, the proposal has not been executed,
     * and the proposal has met the minimum quorum.
     * @param proposalId The ID of the proposal to execute.
     * Emits a {ProposalExecuted} event indicating the success of the execution.
     */
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

    /**
     * @notice Updates the minimum quorum required for a specific proposal.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures that the new quorum is greater than zero.
     * @param proposalId The ID of the proposal to update.
     * @param newQuorum The new minimum quorum value to set.
     */
    function updateMinimumQuorum(
        uint256 proposalId,
        uint256 newQuorum
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Proposal storage proposal = data.proposals[proposalId];

        require(newQuorum > 0, "Quorum must be greater than zero");
        proposal.minimumQuorum = newQuorum;
    }

    /**
     * @notice Updates the duration of an existing proposal.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures the new duration is greater than zero and updates the proposal's deadline.
     * The function is protected against reentrancy attacks.
     * @param proposalId The ID of the proposal to update.
     * @param newDuration The new duration for the proposal.
     */
    function updateProposalDuration(
        uint256 proposalId,
        uint256 newDuration
    ) external nonReentrant onlyRole(ADMIN_ROLE) {
        AppStorage.Layout storage data = AppStorage.layout();
        Proposal storage proposal = data.proposals[proposalId];

        require(newDuration > 0, "Duration must be greater than zero");
        proposal.deadline = newDuration;
    }

    /**
     * @notice Updates the governance token for a specific proposal.
     * @dev This function can only be called by an account with the ADMIN_ROLE.
     * It ensures the new governance token address is not the zero address.
     * Emits a {GovernanceTokenUpdated} event.
     * @param proposalId The ID of the proposal to update.
     * @param newGovernanceToken The address of the new governance token.
     */
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

    /**
     * @notice Retrieves the details of a specific proposal by its ID.
     * @param proposalId The ID of the proposal to retrieve.
     * @return id The ID of the proposal.
     * @return governanceToken The address of the governance token associated with the proposal.
     * @return description A brief description of the proposal.
     * @return forVotes The number of votes in favor of the proposal.
     * @return againstVotes The number of votes against the proposal.
     * @return executed A boolean indicating whether the proposal has been executed.
     * @return deadline The deadline timestamp for voting on the proposal.
     */
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
