pragma solidity 0.4.25;

import "./libraries/SafeMath.sol";

interface ditContractInterface {
    event CommitProposal(uint256 indexed proposal, address indexed who, string label);
    event Vote(uint256 indexed proposal, address indexed who, string label, uint256 stake, uint256 numberOfVotes);
    event Reveal(uint256 indexed proposal, address indexed who, string label, bool accept, uint256 numberOfVotes);
    event ProposalResolved(uint256 indexed proposal, string label, bool accepted);

    function proposeCommit(uint256 _knowledgeLabelIndex) external payable;
    function voteOnProposal(uint256 _proposalID, bytes32 _voteHash) external payable;
    function revealVoteOnProposal(uint256 _proposalID, uint256 _voteOption, uint256 _voteSalt) external;
    function resolveVote(uint256 _proposalID) external;
    function proposalHasPassed(uint256 _proposalID) external view returns (bool hasPassed);
}

interface KNWVotingContract {
    function setCoordinatorAddress(address _newCoordinatorAddress) external;
    function setTokenAddress(address _newKNWTokenAddress) external;
    function addDitContract(address _newContract, uint256 _majority, uint256 _mintingMethod, uint256 _burningMethod) external;
    function startPoll(address _address, string _knowledgeLabel, uint256 _commitDuration, uint256 _revealDuration, uint256 _proposersStake) external returns (uint256 pollID);
    function commitVote(uint256 _pollID, address _address, bytes32 _secretHash) external returns (uint256 numVotes);
    function revealVote(uint256 _pollID, address _address, uint256 _voteOption, uint256 _salt) external;
    function resolvePoll(uint256 _pollID) external returns (bool votePassed);
    function resolveVote(uint256 _pollID, uint256 _voteOption, address _address) external view returns (uint256 reward);
}

contract ditContract is ditContractInterface {
    using SafeMath for uint256;

    address public KNWVotingAddress;
    address public ditCoordinatorAddress;

    KNWVotingContract vote;
    
    string public repository;
    string[] public knowledgeLabels;
    uint256 public currentProposalID;

    uint256 constant public DEFAULT_COMMIT_DURATION = 60*5;
    uint256 constant public DEFAULT_REVEAL_DURATION = 60*5;

    struct commitProposal {
        uint256 KNWVoteID;
        string knowledgeLabel;
        address proposer;
        bool isResolved;
        bool proposalAccepted;
        uint256 requiredStake;
        uint256 totalStake;
        mapping (address => voteChoice) voteDetails;
    }

    struct voteChoice {
        uint256 stake;
        uint256 numberOfVotes;
        uint256 voteChoice;
    }

    mapping (uint256 => commitProposal) public proposals;
   
    constructor(address _KNWVotingAddress, address _ditCoordinatorAddress, string memory _repository, string memory _label1, string memory _label2, string memory _label3) public {
        require(_KNWVotingAddress != address(0) && _ditCoordinatorAddress != address (0), "KNWVoting and ditCoordinator address can't be empty");
        
        // Setting the KNWVote and ditCoordinator addresses
        KNWVotingAddress = _KNWVotingAddress;
        ditCoordinatorAddress = _ditCoordinatorAddress;
        vote = KNWVotingContract(KNWVotingAddress);

        // Setting the repository name
        repository = _repository;

        currentProposalID = 0;

        // Setting the knowledge-labels
        if(bytes(_label1).length > 0) {
            knowledgeLabels.push(_label1);
        }
        if(bytes(_label2).length > 0) {
            knowledgeLabels.push(_label2);
        }
        if(bytes(_label2).length > 0) {
            knowledgeLabels.push(_label3);
        }
        require(knowledgeLabels.length > 0, "Provide at least one Knowledge Label");
    }

    // Proposing a new commit for the repository
    function proposeCommit(uint256 _knowledgeLabelIndex) external payable {
        require(msg.value > 0, "Value of the transaction can not be zero");
        require(_knowledgeLabelIndex <= knowledgeLabels.length-1, "Knowledge-Label index is not correct");

        currentProposalID = currentProposalID.add(1);

        // Creating a new proposal
        proposals[currentProposalID] = commitProposal({
            KNWVoteID: vote.startPoll(msg.sender, knowledgeLabels[_knowledgeLabelIndex], DEFAULT_COMMIT_DURATION, DEFAULT_REVEAL_DURATION, msg.value),
            knowledgeLabel: knowledgeLabels[_knowledgeLabelIndex],
            proposer: msg.sender,
            isResolved: false,
            proposalAccepted: false,
            requiredStake: msg.value,
            totalStake: 0
        });

        // Since the proposer is not allowed to vote in his own proposal,
        // his stake is manually added
        proposals[currentProposalID].voteDetails[msg.sender].stake = msg.value;
        proposals[currentProposalID].totalStake = proposals[currentProposalID].totalStake.add(msg.value);

        emit CommitProposal(currentProposalID, msg.sender, knowledgeLabels[_knowledgeLabelIndex]);
    }

    // Casting a vote for a proposed commit
    function voteOnProposal(uint256 _proposalID, bytes32 _voteHash) public payable {
        require(msg.value == proposals[_proposalID].requiredStake, "Value of the transaction doesn't match the required stake");
        require(msg.sender != proposals[_proposalID].proposer, "The proposer is not allowed to vote in a proposal");
        
        // Increasing the total stake of this proposal (necessary for security purposes during the payout)
        proposals[_proposalID].totalStake = proposals[_proposalID].totalStake.add(msg.value);
        // Saving the stake that the voter is commiting
        proposals[_proposalID].voteDetails[msg.sender].stake = msg.value;

        // The vote contract returns the number of votes that the voter has in this vote (including the KNW influence)
        uint256 numberOfVotes = vote.commitVote(proposals[_proposalID].KNWVoteID, msg.sender, _voteHash);
        require(numberOfVotes > 0, "Voting contract returned an invalid amount of votes");

        proposals[_proposalID].voteDetails[msg.sender].numberOfVotes = numberOfVotes;

        emit Vote(_proposalID, msg.sender, proposals[_proposalID].knowledgeLabel, msg.value, numberOfVotes);
    }

    // Revealing a vote for a proposed commit
    function revealVoteOnProposal(uint256 _proposalID, uint256 _voteOption, uint256 _voteSalt) external {
        vote.revealVote(proposals[_proposalID].KNWVoteID, msg.sender, _voteOption, _voteSalt);
        
        // Saving the option of the voter
        proposals[_proposalID].voteDetails[msg.sender].voteChoice = _voteOption;
        emit Reveal(_proposalID, msg.sender, proposals[_proposalID].knowledgeLabel, (_voteOption == 1), proposals[_proposalID].voteDetails[msg.sender].numberOfVotes);
    }

    // Resolving a vote
    // Note: the first caller will automatically resolve the proposal
    function resolveVote(uint256 _proposalID) public {
        // If the proposal hasn't been resolved this will be done by the first caller
        if(!proposals[_proposalID].isResolved) {
            proposals[_proposalID].proposalAccepted = vote.resolvePoll(proposals[_proposalID].KNWVoteID);
            proposals[_proposalID].isResolved = true;
            emit ProposalResolved(_proposalID, proposals[_proposalID].knowledgeLabel, proposals[_proposalID].proposalAccepted);
        }
        require(proposals[_proposalID].voteDetails[msg.sender].numberOfVotes > 0 || proposals[_proposalID].proposer == msg.sender, "Only participants of the vote are able to resolve the vote");
        require(proposals[_proposalID].voteDetails[msg.sender].stake > 0, "Only participants who haven't already resolved the vote are able to do so");

        // The vote contract returns the amount of ETH that the participant will receive
        uint256 value = vote.resolveVote(proposals[_proposalID].KNWVoteID, proposals[_proposalID].voteDetails[msg.sender].voteChoice, msg.sender);
        
        // If the value is greater than zero, it will be transferred to the caller
        if(value > 0) {
            msg.sender.transfer(value);
        }

        proposals[_proposalID].voteDetails[msg.sender].stake = 0;
        proposals[_proposalID].totalStake = proposals[_proposalID].totalStake.sub(value);
    }

    function getRequiredStake(uint256 _proposalID) external view returns (uint256 requiredStake) {
        return proposals[_proposalID].requiredStake;
    }

    // Returns whether a proposal has passed or not
    function proposalHasPassed(uint256 _proposalID) external view returns (bool hasPassed) {
        require(proposals[_proposalID].isResolved, "Proposal hasn't been resolved");
        return proposals[_proposalID].proposalAccepted;
    }

    // Helper function: converting bytes32 to string
    function bytes32ToString(bytes32 x) internal pure returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint i = 0; i < charCount; i++) {
            bytesStringTrimmed[i] = bytesString[i];
        }
        return string(bytesStringTrimmed);
    }
}