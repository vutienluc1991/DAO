// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

// Since DAOs smart contract need to be unchangable then i dont use upgradable proxy here
// Normal DAO that support charity by transfer native EVM token to address
// Voting power based on the native amount the contributer given the smart contract
contract DAO is AccessControl {

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR");
    uint256 public constant minAmountGovernor = 10; // Need to stake more than 10 native to become governor
    uint32 constant minimumVotingPeriod = 2 weeks;

    uint256 public governanceProposalNonce;
    uint256 public charityProposalNonce;
    uint256 public governanceStaked;
    uint256 public availableBalance;
    uint256 public totalContribution;
    uint256 public totalContributors;
    uint256 public pendingBalance;
    uint256 public numOfProposals;
    
    uint8 private theshold = 66; // Need to reach this percentage of aggrement ending vote automatically
    uint8 private maxSingleVotePercentage = 10; // if they contributes morethan 10% of the totalContribution their vote is worth at max 10 percent
    uint8 private minimumNeedToReachWhenEnding = 33; // Minimum need to reach when voting period end

    // For governance election
    struct GovernanceProposal{
        uint256 id;
        address candidateAddress;
        uint256 livePeriod;
        uint256 votesFor;
        uint256 countVotesFor;
        uint256 votesAgainst;
        uint256 countVotesAgainst;
        string description;
        bool finished;
        address proposer;
        bool votingPassed;
    }

    // For doing charity
    struct CharityProposal {
        uint256 id;
        uint256 amount;
        uint256 livePeriod;
        uint256 votesFor;
        uint256 countVotesFor;
        uint256 votesAgainst;
        uint256 countVotesAgainst;
        uint256 totalVoted;
        string description;
        address payable charityAddress;
        address proposer;
        address governor;
        bool finished;
        bool votingPassed;
    }
    mapping(uint256 => GovernanceProposal) private governanceProposals;
    mapping(uint256 => CharityProposal) private charityProposals;
    mapping(address => uint256) private contributors;
    mapping(address => uint256) private governors;

    mapping(address => mapping(uint256 => bool)) public voteHolder;

    
    // // mapping(address => uint256) private stakeholders;
    event ContributionReceived(address fromAddress, uint256 amount);
    // event governorAdded(address governor, uint256 stakedAmount);

    // // event addGovernanceProposal(address )
    event NewCharityProposal(uint256 proposalId, address indexed proposer, uint256 amount);
    event CharityPropsalFinish(
        uint256 indexed proposalId,
        address indexed receiverAddress,
        uint256 amount,
        bool votingPassed
    );
    event PropsalTransfered(
        uint256 indexed proposalId,
        address indexed receiverAddress,
        uint256 amount
    );
    
    modifier onlyGovernor(string memory message){
        // require(hasR);
        require(hasRole(GOVERNOR_ROLE, msg.sender), message);
        _;
    }
    modifier notGovernor(string memory message){
        // require(hasR);
        require(!hasRole(GOVERNOR_ROLE, msg.sender), message);
        _;
    }

    modifier votable(uint256 proposalId){
        CharityProposal storage proposal = charityProposals[proposalId];
        require(voteHolder[msg.sender][proposalId] == false, 'Already voted');
        require(proposal.livePeriod > block.timestamp, "Voting Ended");
        require(!proposal.finished, "Already finished");
        _;
    }
    // modifier onlyStakeholder(string memory message) {
    //     require(hasRole(STAKEHOLDER_ROLE, msg.sender), message);
    //     _;
    // }

    modifier onlyContributor(string memory message) {
        require(contributors[msg.sender] > 0, message);
        _;
    }

    modifier canFinish(uint256 proposalId){
        CharityProposal storage proposal = charityProposals[proposalId];
        require(proposal.livePeriod < block.timestamp, "Not finish yet");
        require(!proposal.finished, "Already finished");
        _;
    }

    constructor() public{
        // Todo: add your configuration in here
    }

    // throw when  receiving random ether
    receive() external payable {
        revert();
    }
    fallback() external payable{
        revert();
    }

    // stake to become governor
    function stakeGovernor(uint256 amount) 
    external payable
    notGovernor("Already the governor!!!")
    {
        require(msg.value == amount, "Native token send not equal to amount");
        require(amount > minAmountGovernor * 10**18, "Staked token has to be more than min amount");
        governors[msg.sender] = amount;
        governanceStaked += amount;
        _setupRole(GOVERNOR_ROLE, msg.sender);
    }

    function contribute(uint amount) external payable{
        require(msg.value == amount, "Native token send not equal to amount");
        require(msg.value > 10**16, "Need to contribute more than 0.01");
        availableBalance += amount;
        if(contributors[msg.sender] == 0){
            totalContributors += 1;
        }
        contributors[msg.sender] += amount;
        totalContribution += amount;
        emit ContributionReceived(msg.sender, msg.value);

    }


    function createProposal(
        string calldata description,
        address charityAddress,
        uint256 amount
    )
        external
        onlyContributor("Only contributors are allowed to create proposals")
    {
        require(availableBalance - pendingBalance > amount, "could not create any charity proposal due to inefficient balance");
        uint256 proposalId = charityProposalNonce++;
        CharityProposal storage proposal = charityProposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = payable(msg.sender);
        proposal.description = description;
        proposal.charityAddress = payable(charityAddress);
        proposal.amount = amount;
        proposal.livePeriod = block.timestamp + minimumVotingPeriod;

        pendingBalance += amount;

        emit NewCharityProposal(proposalId, msg.sender, amount);
    }

    function voteProposal(uint256 proposalId, bool supportProposal)
        external
        onlyContributor("Only contributors are allowed to vote")
        votable(proposalId)
    {
        CharityProposal storage proposal = charityProposals[proposalId];

        uint256 voteValue = contributors[msg.sender];
        uint256 maxValue = totalContribution * maxSingleVotePercentage / 100;
        if(voteValue > maxValue){
            voteValue = maxValue;
        }

        if (supportProposal){
            proposal.votesFor += voteValue;
            proposal.countVotesFor++;
        }
        else{
            proposal.votesAgainst += voteValue;
            proposal.countVotesAgainst++;
        } 

        voteHolder[msg.sender][proposalId] = true;
    }

    

    function finishProposal(uint256 proposalId)
        external
        canFinish(proposalId)
        onlyGovernor("Only gonvernors are allowed to make payments")
    {   
        // Finish if it has reached certain threshold or at the end end of the live period 
        CharityProposal storage proposal = charityProposals[proposalId];
        uint256 valueTransfer = 0;
        // Todo: update more secured algorithm
        if( (proposal.votesFor > proposal.votesAgainst 
                && 
             proposal.votesFor * 100 / totalContribution > theshold)
            ||
            (proposal.countVotesFor > proposal.countVotesAgainst 
                &&
             proposal.countVotesFor * 100 / totalContributors > minimumNeedToReachWhenEnding
            )
        ){
            emit PropsalTransfered(proposalId, proposal.charityAddress, proposal.amount);
            emit CharityPropsalFinish(proposalId, proposal.charityAddress, proposal.amount, true);
            valueTransfer = proposal.amount;
        }
        else{
            emit CharityPropsalFinish(proposalId, proposal.charityAddress, 0, false);
        }
        pendingBalance -= proposal.amount;

        proposal.finished = true;
        proposal.governor = msg.sender;

        if(valueTransfer > 0){
            proposal.charityAddress.transfer(valueTransfer);
            availableBalance -= valueTransfer;
        }
    }

    function getProposals()
        public
        view
        returns (CharityProposal[] memory props)
    {
        props = new CharityProposal[](numOfProposals);

        for (uint256 index = 0; index < numOfProposals; index++) {
            props[index] = charityProposals[index];
        }
    }

    function getProposal(uint256 proposalId)
        public
        view
        returns (CharityProposal memory)
    {
        return charityProposals[proposalId];
    }

    function isContributor(address user) public view returns (bool){

        if(contributors[user] > 0) return true;
        return false;
    }


    function hasVoted(address user, uint256 proposalId) public view returns (bool){
        return voteHolder[user][proposalId];
    }

    function getContributionPercentageX100(address user) public view returns (uint256){
        // percentage * 100, example: 4% => return 400
        return contributors[user]*100*100/totalContribution;
    }

    // Todo
    // Func Un-stake proposal when governor want to withdraw
    // func Revoke governor proposal when governor has been doing someing bad and give all staked to charity pool
    // func temporary disable governor when subspisous
    
}