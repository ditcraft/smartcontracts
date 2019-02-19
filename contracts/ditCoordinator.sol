pragma solidity ^0.4.25;

import "./ditContract.sol";

interface KNWTokenContract {
    function setVotingAddress(address _newVotingAddress) external;
}

/**
 * @title ditCoordinator
 *
 * @dev Implementation of the ditCoordinator contract, managing the access of
 * repositories to the ditcraft ecosystem. Allows users to retrieve the address
 * of ditContracts for repositories or otherwise deploy one.
 */
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

    /**
     * @dev Creats a new ditCraft-based repository
     * @param _repository The name of the repository
     * @param _label1 The first knowledge label of this repository (see KNWToken)
     * @param _label2 The second knowledge label of this repository (see KNWToken)
     * @param _label3 The third knowledge label of this repository (see KNWToken)
     * @param _voteSettings A uint256 array (with a length of three) containing the necessary 
     * voting majority, the minting and the burning method
     * @return The address of the newly deployed ditContract
     */
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

    /**
     * @dev Gets a ditCraft-based repositories ditContract address
     * @param _repository The name of the repository
     * @return The address of the deployed ditContract
     */
    function getRepository(string _repository) external view returns (address repositoryAddress) {
        require(bytes(_repository).length > 0, "Name of the repository can't be empty");
        return repositories[_repository].ditContract;
    }
}