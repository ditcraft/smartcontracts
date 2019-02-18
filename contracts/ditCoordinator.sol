pragma solidity ^0.4.25;

import "./ditContract.sol";

interface KNWTokenContract {
    function setVotingAddress(address _newVotingAddress) external;
}

contract ditCoordinator {
    using SafeMath for uint256;
    
    struct ditRepository {
        string repository;
        address ditContract;
        uint256 votingMajority;
        uint256 mintingMethod;
        uint256 burningMethod;
    }

    address public KNWVotingAddress;
    address public KNWTokenAddress;

    KNWVotingContract KNWVote;
    KNWTokenContract KNWToken;

    mapping (string => ditRepository) repositories;

    constructor(address _KNWTokenAddress, address _KNWVotingAddress) public {
        require(_KNWVotingAddress != address(0) && _KNWTokenAddress != address(0), "KNWVoting and KNWToken address can't be empty");
        KNWVotingAddress = _KNWVotingAddress;
        KNWVote = KNWVotingContract(KNWVotingAddress);
        KNWTokenAddress = _KNWTokenAddress;
        KNWToken = KNWTokenContract(KNWTokenAddress);
    }

    // Creating a new dit-based repository
    function initRepository(string _repository, string _label1, string _label2, string _label3, uint256[3] _voteSettings) external returns (address newDitContract) {
        require(bytes(_repository).length > 0, "Name of the repository can't be empty");
        require(repositories[_repository].ditContract == address(0), "Repository can't already have a ditContract");
        
        // Deploying a new ditContract according to the provided settings
        newDitContract = address(new ditContract(KNWVotingAddress, address(this), _repository, _label1, _label2, _label3));

        // Storing the new dit-based repository
        repositories[_repository] = ditRepository({
            repository: _repository,
            ditContract: newDitContract,
            votingMajority: _voteSettings[0],
            mintingMethod: _voteSettings[1],
            burningMethod: _voteSettings[2]
        });

        // Enabling the new ditContract to use the voting contract
        KNWVote.addDitContract(newDitContract, _voteSettings[0], _voteSettings[1], _voteSettings[2]);

        return newDitContract;
    }

    // Returns a dit-based repository
    function getRepository(string _repository) external view returns (address repositoryAddress) {
        require(bytes(_repository).length > 0, "Name of the repository can't be empty");
        return repositories[_repository].ditContract;
    }
}