# ditCraft Smart Contracts
As the corner-stone of ditCraft, the smart contracts serve the most important purpose of the implementation. Nameley these are the **KNWToken, KNWVoting, ditCoordinator and the ditContract**s.

## Working with the project
This repository contains a truffle v5 project. Feel free to insert your favorite provider into the `truffle-config.js` in order to deploy it. The config is preconfigured to read a 12-word mnemonic from a `.walletsecret` file in the main directory and an infura API key in the form of `v3/<api_key>` in a `.infurakey` file in the same location. In order to get the gist of what happens during the deployment a look into the `migrations/2_main_migration.js` file is suggested.

## Deployed Contracts
The contracts are currently deployed on the [Rinkeby Ethereum testnet](https://www.rinkeby.io) for development and testing purposes.
- ditCoordinator: [0x60F01B8F86Aa3D1a61d1E1730B49BaeE09D8d72c](https://rinkeby.etherscan.io/address/0x60F01B8F86Aa3D1a61d1E1730B49BaeE09D8d72c)
- KNWToken: [0xcB789c095551b0ad6D539B0EAB931E616e8e0ff6](https://rinkeby.etherscan.io/address/0xcB789c095551b0ad6D539B0EAB931E616e8e0ff6)
- KNWVoting: [0x736ccEa99dF2eF910453A084505861AfffDF170f](https://rinkeby.etherscan.io/address/0x736ccEa99dF2eF910453A084505861AfffDF170f)

Note: *You will need some ETH to interact with the contracts. You can obtain some test ETH from the official [Rinkeby faucet](https://faucet.rinkeby.io).*


## Contract Description
### KNWToken
The KNWToken is a modified version of the ERC20 token, comparable to the [ERC888 proposal](https://github.com/ethereum/EIPs/issues/888). It has the following external interfaces:

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
 - `lockTokens(address, label)`
	 - locks and returns the remaining free amount of KNW tokens for a certain label of a certain address to be used in a vote (*this function can only be called by the KNWVoting Contract*)
 - `unlockTokens(address, label, amount)`
	 - unlocks specified amount of KNW tokens for a certain label of a certain address that were used in a vote (*this function can only be called by the KNWVoting Contract*)
 - `mint(address, label, winningPercentage, mintingMethod)` 
	 - will mint new KNWTokens for the specified address according to the specified method and the winningPercentage of the vote (*this function can only be called by the KNWVoting Contract*)
 - `burn(address, label, amount)` 
	 - will burn KNWTokens of the specified address according to the specified method and the winningPercentage of the vote (*this function can only be called by the KNWVoting Contract*)

Note that this Contract doesn't have transfer functions, as KNW tokens are not transferable. 

### KNWVoting
KNWVoting is a highly modified version of the [PLCR Voting scheme by Mike Goldin](https://github.com/ConsenSys/PLCRVoting). It has the following external interfaces:

 - `startPoll(address, knowledgeLabel, commitDuration, revealDuration, stake)`
	 -  starts a new poll according to the provided settings
 - `commitVote(pollID, address, hash)`
	 -  commits a vote hash\* (this alss triggers the locking of KNW tokens)
 - `revealVote(pollID, address, choice, salt)`
	 - reveals the committed vote to the public
 - `resolveVote(pollID)`
	 - resolves the vote, calculated the outcome and returns the reward to the calling contract (also triggers the minting/burning of KNW tokens)

Note that all of the functions that start or interact with votes can only be called via ditContracts.
\* = The vote is committed with hash = (choice|salt) where choice = {0, 1} and salt = {0, 2^256-1}

### ditCoordinator
The ditCoordinator contract is the central piece of this architecture. It has the following external interfaces:

 - `getRepository(repository)`
	 -  returns information about a repository (including the address of its ditContract)
 - `initRepository(repository, knowledge_labels, voteSettings)`
	 -  creates a ditContract for a new repository with the specified settings

### ditContract
The ditContracts are the controlling instance for every repository. This is the point of interaction for the users with the repository/votes. It has the following external interfaces:

 - `proposeCommit(label)`
	 -  initiates a new proposal and thus starts a new vote
 - `voteOnProposal(proposalID, voteHash)` (also triggers the locking of KNW tokens)
	 -  votes on a proposal with the concealed/hashed vote
 - `openVoteOnProposal(proposalID, choice, salt)`
	 - opens the concealed vote on a proposal and reveals it to the public
 - `finalizeVote(proposalID)`
	 finalizes the vote for the individual calling participant and claims the reward for this proposals' vote (also triggers the minting/burning of KNW tokens)
	 