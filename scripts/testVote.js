const KNWToken = artifacts.require("KNWToken");
const KNWVoting = artifacts.require("KNWVoting");
const ditCoordinator = artifacts.require("ditCoordinator");
const ditContract = artifacts.require("ditContract");

module.exports = async function(callback) {
    console.log("------ start ------");

    let voteSettings = [50,0,0];
    let no_reveal = false;
    let randomNumber = Math.floor(Math.random() * 10000);
    let no_new = false;
    let choices = [1, 1, 1, 1, 0, 0]
    let salts = [
        0,
        Math.floor(Math.random() * 1000),
        Math.floor(Math.random() * 1000),
        Math.floor(Math.random() * 1000),
        Math.floor(Math.random() * 1000),
        Math.floor(Math.random() * 1000)]

    if(process.argv[4] != "--network") {
        var currentArgument = process.argv[4];
        var currentIndex = 4;
        while(currentArgument != "--network") {
            switch(process.argv[currentIndex]) {
                case "choice=all_right": 
                    choices = [1, 1, 1, 1, 1, 1]; 
                    console.log("choice all right activated");
                    break;
                case "choice=even": 
                    choices = [1, 1, 1, 0, 0, 0]; 
                    console.log("choice even activated");
                    break;
                case "choice=all_wrong": 
                    choices = [1, 0, 0, 0, 0, 0]; 
                    console.log("choice all wrong activated");
                    break;
                case "no_reveal": 
                    no_reveal = true;
                    console.log("last doesn't reveal activated");
                    break;
                case "no_new":
                    randomNumber = process.argv[currentIndex+1];
                    no_new = true;
                    currentIndex++;
                    console.log("skipping init, using testRepo" + randomNumber);
                    break;
                default:
                console.log("command '" + process.argv[currentIndex] + "' unknown")
            }
            
            currentIndex++;
            currentArgument = process.argv[currentIndex];
        }
        console.log("------ initialisation ------");
    } 

    // Config
    let label1 = "golang";
    let label2 = "c";
    let label3 = "java"; 
    let accounts = await web3.eth.getAccounts();
    let repoName = "testRepo" + randomNumber;
    console.log("Repository: " + repoName);

    // Instances
    let ditCoordinatorInstance = await ditCoordinator.deployed();
    let KNWVotingInstance = await KNWVoting.deployed();
    let KNWTokenInstance = await KNWToken.deployed();

    // Creating a new repository
    if(!no_new) {
        await ditCoordinatorInstance.initRepository(repoName, label1, label2, label3, voteSettings, {from: accounts[0]});
        console.log("initRepo done");
    }

    let ditContractAddress = await ditCoordinatorInstance.getRepository(repoName);
    let ditContractInstance = await ditContract.at(ditContractAddress);

    console.log("------ addresses ------");
    console.log("Coordinator: " + ditCoordinatorInstance.address);
    console.log("Contract: " + ditContractInstance.address);
    console.log("KNWToken: " + KNWTokenInstance.address);
    console.log("KNWVoting: " + KNWVotingInstance.address);
    console.log("------ vote starts ------");

    // Proposing a commit
    //let randomEthValue = (Math.random() * 0.01 + 0.001);
    let randomEthValue = 0.01
    let USED_STAKE =  web3.utils.toWei(randomEthValue.toString(), 'ether');
    await ditContractInstance.proposeCommit(0, {from: accounts[0], value: USED_STAKE});
    console.log("proposed commit")

    let proposalID = await ditContractInstance.currentProposalID.call();
    console.log("proposalID: " + proposalID);

    let voteID = (await ditContractInstance.proposals(proposalID)).KNWVoteID;
    
    // Voting on the proposal
    // (Starting at 1 since the initiatior already voted with his proposal)
    for(var i = 1; i < 6; i++) {
        ditContractInstance.voteOnProposal(
            proposalID, 
            web3.utils.keccak256(web3.eth.abi.encodeParameters(['uint256','uint256'], [choices[i], salts[i]])), 
            {from: accounts[i], value: USED_STAKE})
    }

    // Watiing for the votes
    process.stdout.write("waiting for votes");
    var waitingForVotes = true;
    while(waitingForVotes) {
        process.stdout.write(".");
        let success = false;
        for(var i = 1; i < 6; i++) {
            success = await KNWVotingInstance.didCommit(accounts[i], voteID);
            if(!success) { break };
        }
        if(success) {
            waitingForVotes = false;
        } else {
            await timeout(2000);
        }
    }
    console.log("\nall votes committed");

    // Waiting for the commit phase to end
    process.stdout.write("waiting for reveal phase");
    var waitingForReveal = true;
    while(waitingForReveal) {
        process.stdout.write(".");
        let isRevealActive = await KNWVotingInstance.revealPeriodActive(voteID, {from: accounts[0]});
        if(isRevealActive) {
            waitingForReveal = false;
        } else {
            await timeout(5000);
        }
    }
    console.log("\nreveal phase active");

    // Revealing votes
    for(var i = 1; i < 6; i++) {
        if(no_reveal && i == 5) { break; } 
        ditContractInstance.revealVoteOnProposal(proposalID, choices[i], salts[i], {from: accounts[i]});
    }  

    // Waiting for reveals
    process.stdout.write("waiting for reveals");
    var waitingForReveals = true;
    while(waitingForReveals) {
        process.stdout.write(".");
        let success = false;
        for(var i = 1; i < 6; i++) {
            success = await KNWVotingInstance.didReveal(accounts[i], voteID);
            if(no_reveal && i == 5) { success = true; } 
            if(!success) { break };
        }
        if(success) {
            waitingForReveals = false;
        } else {
            await timeout(2000);
        }
    }
    console.log("\nall votes revealed");

    // Waiting for the reveal phase to end (= end of vote)
    process.stdout.write("waiting for vote to end");
    var waitingForEnd = true;
    while(waitingForEnd) {
        process.stdout.write(".");
        let hasPollEnded = await KNWVotingInstance.pollEnded(voteID, {from: accounts[0]});
        if(hasPollEnded) {
            waitingForEnd = false;
        } else {
            await timeout(5000);
        }
    }
    console.log("\nvote ended")

    // Retrieving the KNW balances
    let knwBalanceBefore = []
    for(var i = 0; i <= 5; i++) {
        knwBalanceBefore.push((await KNWTokenInstance.balanceOfLabel(accounts[i], label1)).toString(10));
    }

    // Retrieving the number of votes
    let numVotes = []
    for(var i = 0; i <= 5; i++) {
        numVotes.push((await KNWVotingInstance.getNumVotes(accounts[i], voteID)).toString(10));
    }

    // Retrieving the netStake
    let netStake = (await KNWVotingInstance.getNetStake(voteID)).toString(10);

    // Retrieving the ETH balance (for checking whether a claim happend or not)
    let ethBalanceBefore = []
    for(var i = 0; i <= 5; i++) {
        ethBalanceBefore.push((await web3.eth.getBalance(accounts[i])).toString(10));
    }

    // Claiming the reward
    for(var i = 0; i <= 5; i++) {
        ditContractInstance.resolveVote(proposalID, {from: accounts[i]});
    }

    // Waiting for the claims
    process.stdout.write("waiting for claims");
    var waitingForClaims = true;
    while(waitingForClaims) {
        process.stdout.write(".");
        let success = false;
        for(var i = 0; i < 6; i++) {
            // If balance changed a transaction was executed successfully
            let balance = (await web3.eth.getBalance(accounts[i])).toString(10);
            if(balance != ethBalanceBefore[i]) { 
                success = true; 
            } else {
                success = false;
            }
            if(!success) { break };
        }
        if(success) {
            waitingForClaims = false;
        } else {
            await timeout(2000);
        }
    }
    console.log("\nall rewards claimed");

    // Retrieving the KNW balances again to compare
    let knwBalanceAfter = []
    for(var i = 0; i < 6; i++) {
        knwBalanceAfter.push((await KNWTokenInstance.balanceOfLabel(accounts[i], label1)).toString(10));
    }

    console.log("------ results ------")
    console.log("NetStake was: " + web3.utils.fromWei(netStake))
    for(var i = 0; i < 6; i++) {
        let stake = web3.utils.fromWei(USED_STAKE);
        let votes = web3.utils.fromWei(numVotes[i]);
        let knwBefore = web3.utils.fromWei(knwBalanceBefore[i]);
        let knwAfter = web3.utils.fromWei(knwBalanceAfter[i]);
        console.log("[" + i + "] Stake of " + 
        stake + " ETH resulted in " + 
        votes + " numVotes (" + 
        (votes/stake).toFixed(3) + " times increased). KNW Balance from " + 
        parseFloat(knwBefore).toFixed(3) + " to " + 
        parseFloat(knwAfter).toFixed(3) + " (changed by " + 
        (knwAfter-knwBefore).toFixed(3) + ").");
    }

    console.log("------ done ------");
    process.exit(0);
};

function timeout(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}