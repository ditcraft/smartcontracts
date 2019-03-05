pragma solidity 0.4.25;

import "./libraries/SafeMath.sol";

interface KNWTokenContract {
    function balanceOfLabel(address _account, string _label) external view returns (uint256);
    function freeBalanceOfLabel(address _account, string _label) external view returns (uint256);
    function lockTokens(address _account, string _label) external returns (uint256 numberOfTokens);
    function unlockTokens(address _account, string _label, uint256 _numberOfTokens) external;
    function mint(address _account, string _label, uint256 _winningPercentage, uint256 _mintingMethod) external;
    function burn(address _account, string _label, uint256 _numberOfTokens, uint256 _winningPercentage, uint256 _burningMethod) external;
}

// originally based on: https://github.com/ConsenSys/PLCRVoting/blob/master/contracts/PLCRVoting.sol
contract KNWVoting {
    using SafeMath for uint;

    struct KNWVote {
        address initiatingContract;     // Initiating ditContract
        string knowledgeLabel;          // Knowledge-Label that will be used
        uint256 commitEndDate;          // End-Timestamp of the commit phase
        uint256 revealEndDate;          // End-Timestamp of the reveal phase
        uint256 voteQuorum;             // Percent needed in order to pass
        uint256 votesFor;               // Votes in favor of the proposal
        uint256 votesAgainst;           // Votes against the proposal
        uint256 votesUnrevealed;        // Votes that haven't been revealed yet
        uint256 winningPercentage;      // After the vote: percentage of the winning side
        uint256 participantsFor;        // Participants who votes for the proposal 
        uint256 participantsAgainst;    // Participants who votes against the proposal 
        uint256 participantsUnrevealed; // Participants who haven't revealed their yet
        bool isResolved;                // Inidicating whether the vote has been resolved (finished) yet
        mapping(address => Participant) participant;
    }

    struct Stake {
        uint256 proposersStake;     // Stake of the proposer that will be the limit of the voters stakes
        uint256 proposersReward;    // Calculated end-reward of the proposer
        uint256 returnPool;         // Pool of ETH that will be returned to the voting participants
        uint256 rewardPool;         // Pool of ETH that will be rewarded to the voting participants on the winning side
    } 

    struct Participant {
        bool didCommit;         // Inidicates whether a participant has commited a vote
        bool didReveal;         // Inidicates whether a participant has revealed his vote
        bool isProposer;        // Inidicates whether a participant is the proposer of this vote
        uint256 numKNW;         // Count of KNW that a participant uses in this vote
        uint256 numVotes;       // Count of votes that a participant has in this vote
        uint256 commitHash;     // The hashed vote of a participant
    }

    // ditContract that are interacting with this contract are stored in this struct
    struct ditContractSettings {
        bool authorized;
        uint256 burningMethod;
        uint256 mintingMethod;
        uint256 majority;
    }

    // address of the dit Coordinator Contract
    address public ditCoordinatorAddress;

    // address of the KNWToken Contract
    address public KNWTokenAddress;

    // KNWToken Contract
    KNWTokenContract token;
    
    // maps the addresses of contracts that are allowed to call this contracts functions
    mapping (address => ditContractSettings) ditContracts;

    // nonce of the current poll
    uint256 constant public INITIAL_POLL_NONCE = 0;
    uint256 public pollNonce;

    // maps pollID to Poll struct
    mapping(uint256 => KNWVote) public pollMap;
    mapping(uint256 => Stake) public stakeMap; 

    constructor() public {
        pollNonce = INITIAL_POLL_NONCE;
    }

    // Setting the address of the ditCoordinator contract
    function setCoordinatorAddress(address _newCoordinatorAddress) external {
        require(_newCoordinatorAddress != address(0) && ditCoordinatorAddress == address(0), "ditCoordinator address can only be set if it's not empty and hasn't already been set");
        ditCoordinatorAddress = _newCoordinatorAddress;
        ditContracts[ditCoordinatorAddress].authorized = true;
    }

    // Setting the address of the KNWToken contract
    function setTokenAddress(address _newKNWTokenAddress) external {
        require(_newKNWTokenAddress != address(0) && KNWTokenAddress == address(0), "KNWToken address can only be set if it's not empty and hasn't already been set");
        KNWTokenAddress = _newKNWTokenAddress;
        token = KNWTokenContract(KNWTokenAddress);
    }

    // Adding a new ditContracts address that will be allowed to use this contract    
    function addDitContract(address _newContract, uint256 _majority, uint256 _mintingMethod, uint256 _burningMethod) external {
        require(msg.sender == ditCoordinatorAddress, "Only the ditCoordinator can call this");
        ditContracts[_newContract].authorized = true;
        ditContracts[_newContract].majority = _majority;
        ditContracts[_newContract].mintingMethod = _mintingMethod;
        ditContracts[_newContract].burningMethod = _burningMethod;
    }
    
    // Removing a ditContract address that won't be allowed to use this contract anymore
    function removeDitContract(address _obsoleteContract) external {
        require(msg.sender == ditCoordinatorAddress, "Only the ditCoordinator can call this");
        ditContracts[_obsoleteContract].authorized = false;
    }

    // Starts a new poll
    function startPoll(address _address, string _knowledgeLabel, uint256 _commitDuration, uint256 _revealDuration, uint256 _proposersStake) external calledByDitContract(msg.sender) returns (uint256 pollID) {
        pollNonce = pollNonce.add(1);

        // Calculating the timestamps for the commit and reveal phase
        uint256 commitEndDate = block.timestamp.add(_commitDuration);
        uint256 revealEndDate = commitEndDate.add(_revealDuration);

        // Creating a new poll
        pollMap[pollNonce] = KNWVote({
            initiatingContract: msg.sender,
            knowledgeLabel: _knowledgeLabel,
            commitEndDate: commitEndDate,
            revealEndDate: revealEndDate,
            voteQuorum: ditContracts[msg.sender].majority,
            votesFor: 0,
            votesAgainst: 0,
            votesUnrevealed: 0,
            winningPercentage: 0,
            participantsFor: 0,
            participantsAgainst: 0,
            participantsUnrevealed: 0,
            isResolved: false
        });

        stakeMap[pollNonce] = Stake({
            proposersStake: _proposersStake,
            proposersReward: 0,
            returnPool: 0,
            rewardPool: 0
        });
        
        pollMap[pollNonce].participant[_address].isProposer = true;

        // Locking and storing the amount of KNW that the proposer has for this label
        uint256 numKNW = token.lockTokens(_address, pollMap[pollNonce].knowledgeLabel);
        pollMap[pollNonce].participant[_address].numKNW = numKNW;
        
        return pollNonce;
    }

    // Commits a vote using hash of choice and secret salt to conceal vote until reveal
    function commitVote(uint256 _pollID, address _address, bytes32 _secretHash) external calledByInitiatingDitContract(_pollID, msg.sender) returns (uint256 numVotes) {
        require(_pollID != 0, "pollID can't be zero");
        require(commitPeriodActive(_pollID), "Commit period has to be active");
        require(!didCommit(_address, _pollID), "Can't commit more than one vote");

        // Preventing participants from committing a secretHash of 0
        require(_secretHash != 0, "Can't vote with a zero hash");

        // msg.value of the callers vote transaction was checked in the calling ditContract
        numVotes = stakeMap[_pollID].proposersStake;
        
        // Returns the amount of free KNWTokens that are now used and locked for this vote
        uint256 numKNW = token.lockTokens(_address, pollMap[_pollID].knowledgeLabel);
        pollMap[_pollID].participant[_address].numKNW = numKNW;

        // Calculation of vote weight due to KNW influence
        // Vote_Weight = Vote_Weight  + (Vote_Weight * KNW_Balance)
        // Note: If KNW_Balance is > 1 the square-root of numKNW will be used
        // If KNW_Balance is <= 1 the untouched KNW_Balance will be used
        uint256 sqrtOfKNW = (numKNW.div(10**12)).sqrt();
        if(sqrtOfKNW >= numKNW.div(10**15)) {
            sqrtOfKNW = numKNW.div(10**15);
        }
        numVotes = numVotes.add((sqrtOfKNW.mul(numVotes)).div(10**3));

        pollMap[_pollID].participant[_address].numVotes = numVotes;
        pollMap[_pollID].participant[_address].commitHash = uint256(_secretHash);
        pollMap[_pollID].participant[_address].didCommit = true;

        // Adding the number of tokens and votes to the count of unrevealed tokens and votes
        pollMap[_pollID].votesUnrevealed = pollMap[_pollID].votesUnrevealed.add(numVotes);
        pollMap[_pollID].participantsUnrevealed = pollMap[_pollID].participantsUnrevealed.add(1);
        
        return numVotes;
    }

    // Reveals the vote with the option and the salt used to generate the commitHash
    function revealVote(uint256 _pollID, address _address, uint256 _voteOption, uint256 _salt) external calledByInitiatingDitContract(_pollID, msg.sender) {
        require(revealPeriodActive(_pollID), "Reveal period has to be active");
        require(pollMap[_pollID].participant[_address].didCommit, "Participant has to have a vote commited");
        require(!pollMap[_pollID].participant[_address].didReveal, "Can't reveal a vote more than once");

        // Comparing the commited hash with the one that is calculated from option and salt
        require(keccak256(abi.encodePacked(_voteOption, _salt)) == bytes32(pollMap[_pollID].participant[_address].commitHash), "Choice and Salt have to be the same as in the votehash");

        uint256 numVotes = pollMap[_pollID].participant[_address].numVotes;

        // remove the participants tokens from the unrevealed tokens
        pollMap[_pollID].votesUnrevealed = pollMap[_pollID].votesUnrevealed.sub(numVotes);
        pollMap[_pollID].participantsUnrevealed = pollMap[_pollID].participantsUnrevealed.sub(1);
        
        // add the tokens to the according counter
        if (_voteOption == 1) {
            pollMap[_pollID].votesFor = pollMap[_pollID].votesFor.add(numVotes);
            pollMap[_pollID].participantsFor = pollMap[_pollID].participantsFor.add(1);
        } else {
            pollMap[_pollID].votesAgainst = pollMap[_pollID].votesAgainst.add(numVotes);
            pollMap[_pollID].participantsAgainst = pollMap[_pollID].participantsAgainst.add(1);
        }

        pollMap[_pollID].participant[_address].didReveal = true;
    }

    // Resolves a poll and calculates the outcome
    function resolvePoll(uint256 _pollID) external calledByInitiatingDitContract(_pollID, msg.sender) returns (bool votePassed) {
        require(pollEnded(_pollID), "Poll has to have ended");

        uint256 totalVotes = pollMap[_pollID].votesFor.add(pollMap[_pollID].votesAgainst);
        uint256 participants = pollMap[_pollID].participantsAgainst.add(pollMap[_pollID].participantsFor).add(pollMap[_pollID].participantsUnrevealed);
        
        // In case of no participants we define the reward directly to prevent division by zero (participants)
        if(participants == 0) {
            stakeMap[_pollID].proposersReward = stakeMap[_pollID].proposersStake;
            pollMap[_pollID].winningPercentage = 0;
            pollMap[_pollID].isResolved = true;
            return false;
        }

        // The return pool is the amount of ETH that will be returned to the participants
        stakeMap[_pollID].returnPool = participants.mul(stakeMap[_pollID].proposersStake.sub((stakeMap[_pollID].proposersStake.div(participants))));

        uint256 opposingVoters = 0;
        votePassed = isPassed(_pollID);

        if(votePassed) {
            // If the vote passed, the netStake of the opposing and unrevealed voters will be added to the reward pool
            pollMap[_pollID].winningPercentage = pollMap[_pollID].votesFor.mul(100).div(totalVotes);
            opposingVoters = pollMap[_pollID].participantsAgainst.add(pollMap[_pollID].participantsUnrevealed);
            stakeMap[_pollID].proposersReward = stakeMap[_pollID].proposersStake;
        } else {
            if(pollMap[_pollID].votesFor != pollMap[_pollID].votesAgainst) {
                // If the vote didn't pass, the netStake of the opposing and unrevealed voters will be added to the reward pool
                pollMap[_pollID].winningPercentage = pollMap[_pollID].votesAgainst.mul(100).div(totalVotes);
                opposingVoters = pollMap[_pollID].participantsFor.add(pollMap[_pollID].participantsUnrevealed);
                
                // Adding the proposers stake to the reward pool
                stakeMap[_pollID].rewardPool = stakeMap[_pollID].proposersStake;
            } else {
                // If the vote ended in a draw, the netStake of the unrevealed voters will be added to the reward pool
                pollMap[_pollID].winningPercentage = 50;                 
                opposingVoters = pollMap[_pollID].participantsUnrevealed;
                stakeMap[_pollID].proposersReward = stakeMap[_pollID].proposersStake;
            }
        }
        
        if(stakeMap[_pollID].returnPool > 0) {
            stakeMap[_pollID].rewardPool = stakeMap[_pollID].rewardPool.add((opposingVoters.mul((stakeMap[_pollID].proposersStake.sub((stakeMap[_pollID].returnPool.div(participants)))))));
        }
        
        pollMap[_pollID].isResolved = true;
        
        // In case of a passed vote or a draw, the proposer will also get a share of the reward
        if(stakeMap[_pollID].proposersReward > 0) {
            uint256 winnersReward = stakeMap[_pollID].rewardPool.div(((participants.sub(opposingVoters)).add(1)));
            stakeMap[_pollID].proposersReward = stakeMap[_pollID].proposersReward.add(winnersReward);
            stakeMap[_pollID].rewardPool = stakeMap[_pollID].rewardPool.sub(winnersReward);
        }
        
        return votePassed;
    }

    // Calculates the return (and possible reward) for a single participant
    function calculateStakeReturn(uint256 _pollID, bool _votedForRightOption, bool _refund) internal view returns(uint256) {
        uint256 participants = pollMap[_pollID].participantsAgainst.add(pollMap[_pollID].participantsFor).add(pollMap[_pollID].participantsUnrevealed);
        uint256 totalReturn = 0;

        // "refund" is the case when a vote ends in a draw (or noone participates)
        if(!_refund) {
            uint256 basicReturn = stakeMap[_pollID].returnPool.div(participants);
            totalReturn = basicReturn;
            if(_votedForRightOption) {
                uint256 likeMindedVoters = 0;
                if(isPassed(_pollID)) {
                    likeMindedVoters = pollMap[_pollID].participantsFor;
                } else {
                    likeMindedVoters = pollMap[_pollID].participantsAgainst;
                }
                
                // splitting the total amount between the like-minded voters to calculate the return/reward for the caller
                totalReturn = (totalReturn.add(getNetStake(_pollID))).add((stakeMap[_pollID].rewardPool.div(likeMindedVoters))); 
            }
        } else {
            // if the vote ended in a draw (or noone participated)
            totalReturn = stakeMap[_pollID].proposersStake;
            if(pollMap[_pollID].participantsUnrevealed > 0 && pollMap[_pollID].participantsUnrevealed < participants) {
                // adding the netStake of unrevealed votes to the reward
                totalReturn = stakeMap[_pollID].proposersStake.add((pollMap[_pollID].participantsUnrevealed.mul(stakeMap[_pollID].proposersStake)).div((participants.sub(pollMap[_pollID].participantsUnrevealed))));
            }
        }

        return totalReturn;
    }
    
    // Allowing participants who voted according to what the right decision was to claim their "reward" after the vote ended
    function resolveVote(uint256 _pollID, uint256 _voteOption, address _address) external calledByInitiatingDitContract(_pollID, msg.sender) returns (uint256 reward) {
        KNWVote storage poll = pollMap[_pollID];
        // vote needs to be resolved and only participants who revealed their vote
        require(poll.isResolved, "Poll has to be resolved");

        if(poll.participant[_address].numKNW > 0) {
            token.unlockTokens(_address, poll.knowledgeLabel, poll.participant[_address].numKNW);
        }
    
        bool votePassed = isPassed(_pollID);
        bool votedRight = (_voteOption == (votePassed ? 1 : 0));

        if(poll.participant[_address].isProposer) {
            // the proposer is a special participant that is handled separately
            if(votePassed) {
                token.mint(_address, poll.knowledgeLabel, poll.winningPercentage, ditContracts[poll.initiatingContract].mintingMethod);
            } else if(stakeMap[_pollID].proposersReward == 0) {
                // proposers reward is only zero if he lost the vote on the proposal, otherwise it was a draw
                token.burn(_address, poll.knowledgeLabel, poll.participant[_address].numKNW, poll.winningPercentage, ditContracts[poll.initiatingContract].burningMethod);
            }
            reward = stakeMap[_pollID].proposersReward;
        } else if(didReveal(_address, _pollID)) {
            // If vote ended 50:50
            if(!votePassed && poll.votesFor == poll.votesAgainst) {
                // participants get refunded and unrevealed tokens will be distributed evenly
                reward = calculateStakeReturn(_pollID, votedRight, true);
            // If vote ended regularly
            } else {
                // calculcate the reward (their tokens plus (if they voted right) their share of the tokens of the losing side)
                reward = calculateStakeReturn(_pollID, votedRight, false);
                // participants who voted for the winning option 
                if(votedRight) {
                    token.mint(_address, poll.knowledgeLabel, poll.winningPercentage, ditContracts[poll.initiatingContract].mintingMethod);
                // participants who votes for the losing option
                } else {
                    token.burn(_address, poll.knowledgeLabel, poll.participant[_address].numKNW, poll.winningPercentage, ditContracts[poll.initiatingContract].burningMethod);
                }
            }
        // participants who didn't reveal but participated are assumed to have voted for the losing option
        } else if (!didReveal(_address, _pollID) && didCommit(_address, _pollID)){
            reward = calculateStakeReturn(_pollID, false, false);
            token.burn(_address, poll.knowledgeLabel, poll.participant[_address].numKNW, poll.winningPercentage, ditContracts[poll.initiatingContract].burningMethod);
        // participants who didn't participate at all
        } else {
            revert("Not a participant of the vote");
        }

        return reward;
    }

    // Determines if vote has passed
    function isPassed(uint256 _pollID) public view returns (bool passed) {
        require(pollEnded(_pollID), "Poll has to have ended");

        KNWVote memory poll = pollMap[_pollID];
        return (100 * poll.votesFor) > (poll.voteQuorum * (poll.votesFor + poll.votesAgainst));
    }
    
    // Determines if a vote is resolved
    function isResolved(uint256 _pollID) public view returns (bool resolved) {
        return pollMap[_pollID].isResolved;
    }

    // Voting-Helper functions
    // Determines if vote is over
    function pollEnded(uint256 _pollID) public view returns (bool ended) {
        require(pollExists(_pollID), "Poll has to exist");

        return isExpired(pollMap[_pollID].revealEndDate);
    }

    // Checks if an expiration date has been reached
    function isExpired(uint256 _terminationDate) public view returns (bool expired) {
        return (block.timestamp > _terminationDate);
    }

    // Checks if the commit period is still active for the specified vote
    function commitPeriodActive(uint256 _pollID) public view returns (bool active) {
        require(pollExists(_pollID), "Poll has to exist");

        return !isExpired(pollMap[_pollID].commitEndDate);
    }

    // Checks if the reveal period is still active for the specified vote
    function revealPeriodActive(uint256 _pollID) public view returns (bool active) {
        require(pollExists(_pollID), "Poll has to exist");

        return !isExpired(pollMap[_pollID].revealEndDate) && !commitPeriodActive(_pollID);
    }

    // Checks if participant has committed for specified vote
    function didCommit(address _address, uint256 _pollID) public view returns (bool committed) {
        require(pollExists(_pollID), "Poll has to exist");

        return pollMap[_pollID].participant[_address].didCommit;
    }

    // Checks if participant has revealed for specified vote
    function didReveal(address _address, uint256 _pollID) public view returns (bool revealed) {
        require(pollExists(_pollID), "Poll has to exist");

        return pollMap[_pollID].participant[_address].didReveal;
    }

    // Checks if a vote exists
    function pollExists(uint256 _pollID) public view returns (bool exists) {
        return (_pollID != 0 && _pollID <= pollNonce);
    }

    // Returns the gross amount of ETH that a participant currently has to stake for a poll
    function getGrossStake(uint256 _pollID) public view returns (uint256 grossStake) {
        return stakeMap[_pollID].proposersStake;
    }

    // Returns the net amount of ETH that a participant currently has to stake for a poll
    function getNetStake(uint256 _pollID) public view returns (uint256 netStake) {
        uint256 participants = pollMap[_pollID].participantsAgainst.add(pollMap[_pollID].participantsFor).add(pollMap[_pollID].participantsUnrevealed);
        if(participants > 0) {
            return stakeMap[_pollID].proposersStake.div(participants);
        }
        return stakeMap[_pollID].proposersStake;

    }

    // Returns the number of KNW tokens that a participant used for a poll
    function getNumKNW(address _address, uint256 _pollID) public view returns (uint256 numKNW) {
        return pollMap[_pollID].participant[_address].numKNW;
    }

    // Returns the number of votes that a participant has in a poll
    function getNumVotes(address _address, uint256 _pollID) public view returns (uint256 numVotes) {
        return pollMap[_pollID].participant[_address].numVotes;
    }

    // Generates an identifier which associates a participant and a vote together
    function attrUUID(address _address, uint256 _pollID) internal pure returns (bytes32 UUID) {
        return keccak256(abi.encodePacked(_address, _pollID));
    }
    
    // Modifier: function can only be called by a listed dit contract
    modifier calledByDitContract (address _address) {
        require(ditContracts[_address].authorized == true, "Only a ditContract is allow to call this");
        _;
    }

    // Modifier: function can only be called by the initiaiting dit contract
    modifier calledByInitiatingDitContract (uint256 _pollID, address _address) {
        require(pollMap[_pollID].initiatingContract == _address, "Only the initiating contract is allow to call this");
        _;
    }
}