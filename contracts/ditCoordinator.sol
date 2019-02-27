pragma solidity 0.4.25;

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
        bytes32 repository;
        address ditContract;
        uint256 votingMajority;
        uint256 mintingMethod;
        uint256 burningMethod;
    }

    address public KNWVotingAddress;
    address public KNWTokenAddress;

    KNWVotingContract KNWVote;
    KNWTokenContract KNWToken;

    mapping (bytes32 => ditRepository) repositories;

    constructor(address _KNWTokenAddress, address _KNWVotingAddress) public {
        require(_KNWVotingAddress != address(0) && _KNWTokenAddress != address(0), "KNWVoting and KNWToken address can't be empty");
        KNWVotingAddress = _KNWVotingAddress;
        KNWVote = KNWVotingContract(KNWVotingAddress);
        KNWTokenAddress = _KNWTokenAddress;
        KNWToken = KNWTokenContract(KNWTokenAddress);
    }

    /**
     * @dev Creats a new ditCraft-based repository
     * @param _repository The descriptor of the repository (e.g. keccak256("github.com/example_repo"))
     * @param _label1 The first knowledge label of this repository (see KNWToken)
     * @param _label2 The second knowledge label of this repository (see KNWToken)
     * @param _label3 The third knowledge label of this repository (see KNWToken)
     * @param _voteSettings A uint256 array (with a length of seven) containing the vote settings: 
     *  [0] = votingMajority in percent (50-100)
     *  [1] = mintingMethod (0 or 1)
     *  [2] = burningMethod (0 or 1)
     *  [3] = minVoteCommitDuration (in seconds)
     *  [4] = maxVoteCommitDuration (in seconds)
     *  [5] = minVoteOpenDuration (in seconds)
     *  [6] = maxVoteOpenDuration (in seconds)
     * @return The address of the newly deployed ditContract
     */
    function initRepository(bytes32 _repository, string _label1, string _label2, string _label3, uint256[7] _voteSettings) external returns (address newDitContract) {
        require(_repository != 0, "Repository descriptor can't be zero");
        require(repositories[_repository].ditContract == address(0), "Repository can't already have a ditContract");
        
        // Deploying a new ditContract according to the provided settings
        newDitContract = address(new ditContract(
            KNWVotingAddress,
            address(this),
            _repository,
            _label1,
            _label2, 
            _label3,
            [_voteSettings[3], _voteSettings[4], _voteSettings[5], _voteSettings[6]]
            ));

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
     * @param _repository The descriptor of the repository (e.g. keccak256("github.com/example_repo"))
     * @return The address of the deployed ditContract
     */
    function getRepository(bytes32 _repository) external view returns (address repositoryAddress) {
        return repositories[_repository].ditContract;
    }
}