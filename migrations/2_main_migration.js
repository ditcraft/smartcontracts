var KNWToken = artifacts.require("./KNWToken.sol");
var KNWVoting = artifacts.require("./KNWVoting.sol");
var ditCoordinator = artifacts.require("./ditCoordinator.sol");
var SafeMath = artifacts.require("./libraries/SafeMath.sol");

module.exports = async function(deployer) {
  await deployer.deploy(SafeMath);
  await deployer.link(SafeMath, KNWToken);
  let tokenInstance = await deployer.deploy(KNWToken);
  await deployer.link(SafeMath, KNWVoting);
  let votingInstance = await deployer.deploy(KNWVoting, KNWToken.address, "0x0000000000000000000000000000000000000000");
  await deployer.link(SafeMath, ditCoordinator);
  await deployer.deploy(ditCoordinator, KNWToken.address, KNWVoting.address, "0x0000000000000000000000000000000000000000");
  await tokenInstance.addVotingContract(KNWVoting.address);
  console.log("\n   Post-Deployment Calls")
  console.log("   ----------------------");
  console.log("   > Post-Deployment Call 1/2 done");
  await votingInstance.addDitCoordinatorAddress(ditCoordinator.address);
  console.log("   > Post-Deployment Call 2/2 done\n");
};