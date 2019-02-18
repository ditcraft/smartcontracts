var KNWToken = artifacts.require("./KNWToken.sol");
var KNWVoting = artifacts.require("./KNWVoting.sol");
var ditCoordinator = artifacts.require("./ditCoordinator.sol");
var SafeMath = artifacts.require("./libraries/SafeMath.sol");

module.exports = async function(deployer) {
  await deployer.deploy(SafeMath);
  await deployer.link(SafeMath, KNWToken);
  let tokenInstance = await deployer.deploy(KNWToken);
  await deployer.link(SafeMath, KNWVoting);
  let votingInstance = await deployer.deploy(KNWVoting);
  await deployer.link(SafeMath, ditCoordinator);
  await deployer.deploy(ditCoordinator, KNWToken.address, KNWVoting.address);
  await tokenInstance.setVotingAddress(KNWVoting.address);
  console.log("\n   Post-Deployment Calls")
  console.log("   ----------------------");
  console.log("   > Post-Deployment Call 1/3 done");
  await votingInstance.setCoordinatorAddress(ditCoordinator.address);
  console.log("   > Post-Deployment Call 2/3 done");
  await votingInstance.setTokenAddress(KNWToken.address);
  console.log("   > Post-Deployment Call 3/3 done\n");
};