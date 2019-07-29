# ditCraft Smart Contracts
As the corner-stone of ditCraft, the smart contracts serve the most important purpose of the implementation. Nameley these are the **KNWToken, KNWVoting and the ditCoordinator**.

## Working with the project
This repository contains a truffle v5 project. Feel free to insert your favorite provider into the `truffle-config.js` in order to deploy it. The config is preconfigured to read a 12-word mnemonic from a `.walletsecret` file in the main directory. In order to get the gist of what happens during the deployment a look into the `migrations/2_main_migration.js` file is suggested.

## Deployed Contracts
The contracts are deployed on the [PoA xDai network](https://blockscout.com/poa/dai). Since we have a live and a demo mode of the client, the smart contracts of these modes are working separately.

### Live Contracts
- ditCoordinator: [0x4BB184D45e8e3a6dC6684fda7110894cd6226f16](https://blockscout.com/poa/dai/address/0x4BB184D45e8e3a6dC6684fda7110894cd6226f16)
- KNWToken: [0x4568b5966bd66ADc5b407d3813eBc1dD37e04217](https://blockscout.com/poa/dai/address/0x4568b5966bd66ADc5b407d3813eBc1dD37e04217)
- KNWVoting: [0x821bC531E95636d73539d7E9E54f7fB8b5c761eF](https://blockscout.com/poa/dai/address/0x821bC531E95636d73539d7E9E54f7fB8b5c761eF)

### Demo Contracts
- ditCoordinator: [0x9A65c773A216a4F4748B1D65C0fB039d9F2b223D](https://blockscout.com/poa/dai/address/0x9A65c773A216a4F4748B1D65C0fB039d9F2b223D)
- KNWToken: [0xf1ffDa403dEB83A9891B010C8cE6AEF2e196fdd3](https://blockscout.com/poa/dai/address/0xf1ffDa403dEB83A9891B010C8cE6AEF2e196fdd3)
- KNWVoting: [0xB872E9eA8E218f5A62fD8572506513f98e2d1445](https://blockscout.com/poa/dai/address/0xB872E9eA8E218f5A62fD8572506513f98e2d1445) 

## Contract Description
### KNWToken
The KNWToken is a modified version of the ERC20 token, comparable to the [ERC1155](https://github.com/ethereum/EIPs/issues/1155) or [ERC1178 proposals](https://github.com/ethereum/EIPs/issues/1179). It has the following external interfaces:

 - `totalsupply()` 
	- returns the total count of KNW tokens
 - `totalIDSupply(id)` 
	 - returns the total count of KNW tokens for a certain id
 - `balanceOfID(address, id)` 
	 - returns the count of KNW tokens for a certain id of a certain address
 - `freeBalanceOfID(address, id)`
	 - returns the free (non-locked) count of KNW tokens for a certain id of a certain address
 - `labelOfID(id)` 
	 - returns the string representation of an id
- `amountOfIDs()`
	 - returns the amount of ids that exist 
 - `lockTokens(address, id, amount)`
	 - locks and returns the specified amount of KNW tokens for a certain id of a certain address to be used in a vote (*this function can only be called by a KNWVoting Contract*)
 - `unlockTokens(address, id, amount)`
	 - unlocks specified amount of KNW tokens for a certain id of a certain address that were used in a vote (*this function can only be called by a KNWVoting Contract*)
 - `mint(address, id, amount)` 
	 - will mint new KNWTokens for the specified address (*this function can only be called by a KNWVoting Contract*)
 - `burn(address, id, amount)` 
	 - will burn KNWTokens of the specified address (*this function can only be called by a KNWVoting Contract*)

Note that this contract doesn't have transfer functions, as KNW tokens are not transferable. 

### KNWVoting
KNWVoting is a highly modified version of the [PLCR Voting scheme by Mike Goldin](https://github.com/ConsenSys/PLCRVoting). It has the following external interfaces:

 - `startVote(repository, address, knowledgeID, voteDuration, stake, numberOfKNW)`
	 -  starts a new poll according to the provided settings
 - `commitVote(pollID, address, hash, numberOfKNW)`
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

 - `initRepository(repository, []knowledgeIDs, neededMajority)`
	 -  initializes a new repository with the specified settings
 - `repositoryIsInitialized(repository)`
	 -  inidicates whether a repository has been initialized
 - `proposeCommit(repository, description, identifier, knowledgeID, amountOfKNW, voteDuration)`
	 -  initiates a new proposal and thus starts a new vote with the specified settings
 - `voteOnProposal(repository, proposalID, voteHash, amountOfKNW)` (also triggers the locking of KNW tokens)
	 -  votes on a proposal with the concealed/hashed vote
 - `openVoteOnProposal(repository, proposalID, choice, salt)`
	 - opens the concealed vote on a proposal and reveals it to the public
 - `finalizeVote(repository, proposalID)`
	 finalizes the vote for the individual calling participant and claims the reward for this proposals' vote (also triggers the minting/burning of KNW tokens)