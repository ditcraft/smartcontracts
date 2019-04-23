# ditCraft Smart Contracts
As the corner-stone of ditCraft, the smart contracts serve the most important purpose of the implementation. Nameley these are the **KNWToken, KNWVoting and the ditCoordinator**.

## Working with the project
This repository contains a truffle v5 project. Feel free to insert your favorite provider into the `truffle-config.js` in order to deploy it. The config is preconfigured to read a 12-word mnemonic from a `.walletsecret` file in the main directory and an infura API key in the form of `v3/<api_key>` in a `.infurakey` file in the same location. In order to get the gist of what happens during the deployment a look into the `migrations/2_main_migration.js` file is suggested.

## Deployed Contracts
The contracts are currently deployed on the [PoA Network Sokol testnet](https://blockscout.com/poa/sokol) for development and testing purposes. Since we have a live and a demo mode of the client, the smart contracts of these modes are working separately.

Note: *You will need some POA to interact with the contracts. You can obtain some test POA from the official [Sokol faucet](https://faucet-sokol.herokuapp.com/).*

### Live Contracts
- ditCoordinator: [0x049e4E2b99A6004a73a6c6E61d57f3b576f30aB6](https://blockscout.com/poa/sokol/address/0x049e4e2b99a6004a73a6c6e61d57f3b576f30ab6)
- KNWToken: [0x79B71d6d295E23b36D8495756432085BAA357915](https://blockscout.com/poa/sokol/address/0x79B71d6d295E23b36D8495756432085BAA357915)
- KNWVoting: [0xA31B6EdEc93DC69C91795e2A6EbeC90F2058b32D](https://blockscout.com/poa/sokol/address/0xA31B6EdEc93DC69C91795e2A6EbeC90F2058b32D)

### Demo Contracts
- ditCoordinator: [0xf5Df1fa5Fbb7DCE71E2C7ceaC7D5632593cc6d15](https://blockscout.com/poa/sokol/address/0xf5Df1fa5Fbb7DCE71E2C7ceaC7D5632593cc6d15)
- KNWToken: [0x19D29D553296F662bcE6ebBC9c14D53A24C49E7b](https://blockscout.com/poa/sokol/address/0x19D29D553296F662bcE6ebBC9c14D53A24C49E7b)
- KNWVoting: [0xb5787F497DEAB27ebA96bf0E132B7A9AFD3b2E7D](https://blockscout.com/poa/sokol/address/0xb5787F497DEAB27ebA96bf0E132B7A9AFD3b2E7D) 

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