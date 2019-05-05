# ditCraft Smart Contracts
As the corner-stone of ditCraft, the smart contracts serve the most important purpose of the implementation. Nameley these are the **KNWToken, KNWVoting and the ditCoordinator**.

## Working with the project
This repository contains a truffle v5 project. Feel free to insert your favorite provider into the `truffle-config.js` in order to deploy it. The config is preconfigured to read a 12-word mnemonic from a `.walletsecret` file in the main directory. In order to get the gist of what happens during the deployment a look into the `migrations/2_main_migration.js` file is suggested.

## Deployed Contracts
The contracts are deployed on the [PoA xDai network](https://blockscout.com/poa/dai). Since we have a live and a demo mode of the client, the smart contracts of these modes are working separately.

### Live Contracts
- ditCoordinator: [0x429e37f14462bdfca0f1168dae24f66f61e6b04c](https://blockscout.com/poa/dai/address/0x429e37f14462bdfca0f1168dae24f66f61e6b04c)
- KNWToken: [0x508B1890a00BfdB348d1B7D335bE2029B69a5B92](https://blockscout.com/poa/dai/address/0x508B1890a00BfdB348d1B7D335bE2029B69a5B92)
- KNWVoting: [0x991f901E1Fc151D13ba8C0E27a7f8c6ea3C524Cb](https://blockscout.com/poa/dai/address/0x991f901E1Fc151D13ba8C0E27a7f8c6ea3C524Cb)

### Demo Contracts
- ditCoordinator: [0x1dc6f1edd14b0b5d24305a0cfb6d4f0a5de3b4f6](https://blockscout.com/poa/dai/address/0x1dc6f1edd14b0b5d24305a0cfb6d4f0a5de3b4f6)
- KNWToken: [0x6081aa30758e9D752fd7d8E7729220A80771e835](https://blockscout.com/poa/dai/address/0x6081aa30758e9D752fd7d8E7729220A80771e835)
- KNWVoting: [0x74F9c8Eeb2F0665858efD038007BbcF08075994D](https://blockscout.com/poa/dai/address/0x74F9c8Eeb2F0665858efD038007BbcF08075994D) 

## Contract Description
### KNWToken
The KNWToken is a modified version of the ERC20 token, comparable to the [ERC888](https://github.com/ethereum/EIPs/issues/888) or [ERC1155 proposals](https://github.com/ethereum/EIPs/issues/1155). It has the following external interfaces:

 - `totalsupply()` 
	- returns the total count of KNW tokens
 - `totalLabelSupply(label)` 
	 - returns the total count of KNW tokens for a certain label
 - `balanceOfLabel(address, label)` 
	 - returns the count of KNW tokens for a certain label of a certain address
 - `freeBalanceOfLabel(address, label)`
	 - returns the free (non-locked) count of KNW tokens for a certain label of a certain address
 - `labelsOfAddress(address)` 
	 - returns the labels that a certain address has a token count for
 - `lockTokens(address, label, amount)`
	 - locks and returns the specified amount of KNW tokens for a certain label of a certain address to be used in a vote (*this function can only be called by a KNWVoting Contract*)
 - `unlockTokens(address, label, amount)`
	 - unlocks specified amount of KNW tokens for a certain label of a certain address that were used in a vote (*this function can only be called by a KNWVoting Contract*)
 - `mint(address, label, amount)` 
	 - will mint new KNWTokens for the specified address (*this function can only be called by a KNWVoting Contract*)
 - `burn(address, label, amount)` 
	 - will burn KNWTokens of the specified address (*this function can only be called by a KNWVoting Contract*)

Note that this contract doesn't have transfer functions, as KNW tokens are not transferable. 

### KNWVoting
KNWVoting is a highly modified version of the [PLCR Voting scheme by Mike Goldin](https://github.com/ConsenSys/PLCRVoting). It has the following external interfaces:

 - `startVote(address, knowledgeLabel, commitDuration, revealDuration, stake, amountOfKNW)`
	 -  starts a new poll according to the provided settings
 - `commitVote(pollID, address, hash, amountOfKNW)`
	 -  commits a vote hash\* (this also triggers the locking of KNW tokens)
 - `openVote(pollID, address, choice, salt)`
	 - opens the commitment and reveals the vote to the public
 - `endVote(pollID)`
	 - resolves the poll and calculated the outcome 
-  `finalizeVote(pollID, choice, address)`
	 - finalizes the individuals vote and returns the reward to the calling contract (also triggers the minting/burning of KNW tokens)

Note that all of the functions that start or interact with votes can only be called by the ditCoordinator.
\* = The vote is committed with hash = (choice|salt) where choice = {0, 1} and salt = {0, 2^256-1}

### ditCoordinator
The ditCoordinator contract is the central piece of this architecture. It has the following external interfaces:

 - `initRepository(repository, knowledge_labels, neededMajority)`
	 -  initializes a new repository with the specified settings
 - `repositoryIsInitialized(repository)`
	 -  inidicates whether a repository has been initialized
 - `proposeCommit(repository, label, amountOfKNW, voteDuration)`
	 -  initiates a new proposal and thus starts a new vote with the specified settings
 - `voteOnProposal(repository, proposalID, voteHash, amountOfKNW)` (also triggers the locking of KNW tokens)
	 -  votes on a proposal with the concealed/hashed vote
 - `openVoteOnProposal(repository, proposalID, choice, salt)`
	 - opens the concealed vote on a proposal and reveals it to the public
 - `finalizeVote(repository, proposalID)`
	 finalizes the vote for the individual calling participant and claims the reward for this proposals' vote (also triggers the minting/burning of KNW tokens)