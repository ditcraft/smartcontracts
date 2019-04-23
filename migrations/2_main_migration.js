var KNWToken = artifacts.require("./KNWToken.sol");
var KNWVoting = artifacts.require("./KNWVoting.sol");
var ditCoordinator = artifacts.require("./ditCoordinator.sol");
var SafeMath = artifacts.require("./libraries/SafeMath.sol");

var lastKNWVoting = "0x0000000000000000000000000000000000000000";
var lastDitCoordinator = "0x0000000000000000000000000000000000000000";

module.exports = async function(deployer) {
  await deployer.deploy(SafeMath);
  await deployer.link(SafeMath, KNWToken);
  let tokenInstance = await deployer.deploy(KNWToken);
  await deployer.link(SafeMath, KNWVoting);
  let votingInstance = await deployer.deploy(KNWVoting, KNWToken.address, lastKNWVoting);
  await deployer.link(SafeMath, ditCoordinator);
  await deployer.deploy(ditCoordinator, KNWToken.address, KNWVoting.address, lastDitCoordinator);
  console.log("\n   Post-Deployment Calls")
  console.log("   ----------------------");
  await tokenInstance.addVotingContract(KNWVoting.address);
  console.log("   > Post-Deployment Call 1/2 done");
  await votingInstance.addDitCoordinator(ditCoordinator.address);
  console.log("   > Post-Deployment Call 2/2 done\n");

  console.log("\n   Constructor arguments")
  console.log("   ----------------------");
  console.log("   > KNWVoting:") 
  console.log("   > (" + KNWToken.address + ", " + lastKNWVoting + ")")
  console.log("   > ditCoordinator:")
  console.log("   > (" + KNWToken.address + ", " + KNWVoting.address + ", " + lastDitCoordinator + ")")


  console.log("\n   Contracts")
  console.log("   ----------------------");
  console.log("   > KNWToken: " + KNWToken.address)
  console.log("   > KNWVoting: " + KNWVoting.address)
  console.log("   > ditCoordinator: " + ditCoordinator.address + "\n")
};