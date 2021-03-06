const KNWToken = artifacts.require("KNWToken");
const KNWVoting = artifacts.require("KNWVoting");
const ditCoordinator = artifacts.require("ditCoordinator");

module.exports = async function(callback) {
    console.log("------ start ------");

    let voteMajority = 50;
    let no_open = false;
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
                case "no_open": 
                    no_open = true;
                    console.log("last doesn't open activated");
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
    let knowledgeIDs = [ 0, 1 ];
    let accounts = await web3.eth.getAccounts();
    let repoName = web3.utils.soliditySha3("github.com/testRepo" + randomNumber);
    let topic = "This is a test proposal topic with 140 letters to test everthing in order to make sure that nothing will break, 0123456789012345678901234567"
    let headHash = web3.utils.soliditySha3(topic);
    console.log("Repository: " + "github.com/testRepo" + randomNumber);
    console.log("Hash: " + repoName)

    // Instances
    let ditCoordinatorInstance = await ditCoordinator.deployed();
    let KNWVotingInstance = await KNWVoting.deployed();
    let KNWTokenInstance = await KNWToken.deployed();

    let passedKYC = await ditCoordinatorInstance.passedKYC(accounts[0])
    if(!passedKYC) {
        for(var i = 0; i < 6; i++) { 
            await ditCoordinatorInstance.passKYC(accounts[i])
        }
        console.log("Passed KYC for all accounts")
        await KNWTokenInstance.addNewLabel("JavaScript")
        await KNWTokenInstance.addNewLabel("Golang")
        console.log("Added two new Knowledge-Lables to the KNWToken contract")

    }
    // Creating a new repository
    if(!no_new) {
        await ditCoordinatorInstance.initRepository("github.com/testRepo" + randomNumber, knowledgeIDs, voteMajority, {from: accounts[0]});
        console.log("initRepo done");
    }

    console.log("------ addresses ------");
    console.log("Coordinator: " + ditCoordinatorInstance.address);
    console.log("KNWToken: " + KNWTokenInstance.address);
    console.log("KNWVoting: " + KNWVotingInstance.address);
    console.log("------ vote starts ------");

    // Proposing a commit
    // let randomEthValue = (Math.random() * 0.001 + 0.0001);
    let randomEthValue = 0.00001;
    let USED_STAKE =  web3.utils.toWei(randomEthValue.toString(), 'ether');
    console.log("Stake will be " + randomEthValue + " ETH")
    
    let freeKNWBalance = await KNWTokenInstance.freeBalanceOfID(accounts[0], knowledgeIDs[0]);
    await ditCoordinatorInstance.proposeCommit(repoName, headHash, topic, knowledgeIDs[0], freeKNWBalance, 60, {from: accounts[0], value: USED_STAKE});
    
    console.log("proposed commit")

    let proposalID = await ditCoordinatorInstance.getCurrentProposalID(repoName);
    console.log("proposalID: " + proposalID);

    let voteID = await ditCoordinatorInstance.getKNWVoteIDFromProposalID(repoName, proposalID);
    console.log("voteID: " + proposalID);

    // Voting on the proposal
    // (Starting at 1 since the initiatior already voted with his proposal)
    for(var i = 1; i < 6; i++) {
        let freeKNWBalance = await KNWTokenInstance.freeBalanceOfID(accounts[i], knowledgeIDs[0]);
        ditCoordinatorInstance.voteOnProposal(
            repoName,
            proposalID, 
            web3.utils.keccak256(web3.eth.abi.encodeParameters(['uint256','uint256'], [choices[i], salts[i]])),
            freeKNWBalance,
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
    process.stdout.write("waiting for opening phase");
    var waitingForReveal = true;
    while(waitingForReveal) {
        process.stdout.write(".");
        let isRevealActive = await KNWVotingInstance.openPeriodActive(voteID, {from: accounts[0]});
        if(isRevealActive) {
            waitingForReveal = false;
        } else {
            await timeout(5000);
        }
    }
    console.log("\nopening phase active");

    // Revealing votes
    for(var i = 1; i < 6; i++) {
        if(no_open && i == 5) { break; } 
        ditCoordinatorInstance.openVoteOnProposal(repoName, proposalID, choices[i], salts[i], {from: accounts[i]});
    }  

    // Waiting for openings
    process.stdout.write("waiting for openings");
    var waitingForReveals = true;
    while(waitingForReveals) {
        process.stdout.write(".");
        let success = false;
        for(var i = 1; i < 6; i++) {
            success = await KNWVotingInstance.didOpen(accounts[i], voteID);
            if(no_open && i == 5) { success = true; } 
            if(!success) { break };
        }
        if(success) {
            waitingForReveals = false;
        } else {
            await timeout(2000);
        }
    }
    console.log("\nall votes opened");

    // Waiting for the opening phase to end (= end of vote)
    process.stdout.write("waiting for vote to end");
    var waitingForEnd = true;
    while(waitingForEnd) {
        process.stdout.write(".");
        let hasPollEnded = await KNWVotingInstance.voteEnded(voteID, {from: accounts[0]});
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
        knwBalanceBefore.push((await KNWTokenInstance.balanceOfID(accounts[i], knowledgeIDs[0])).toString(10));
    }

    // Retrieving the number of votes
    let numVotes = []
    for(var i = 0; i <= 5; i++) {
        numVotes.push((await KNWVotingInstance.getAmountOfVotes(accounts[i], voteID)).toString(10));
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
        ditCoordinatorInstance.finalizeVote(repoName, proposalID, {from: accounts[i]});
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
        knwBalanceAfter.push((await KNWTokenInstance.balanceOfID(accounts[i], knowledgeIDs[0])).toString(10));
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