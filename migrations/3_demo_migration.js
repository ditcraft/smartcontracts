var KNWToken = artifacts.require("./KNWToken.sol");
var KNWVoting = artifacts.require("./KNWVoting.sol");
var ditDemoCoordinator = artifacts.require("./demo_contracts/ditDemoCoordinator.sol");
var ditToken = artifacts.require("./demo_contracts/ditToken.sol");
var SafeMath = artifacts.require("./libraries/SafeMath.sol");

module.exports = async function(deployer) {
  await deployer.deploy(SafeMath);
  await deployer.link(SafeMath, KNWToken);
  let knwTokenInstance = await deployer.deploy(KNWToken);
  await deployer.link(SafeMath, ditToken);
  await deployer.deploy(ditToken);
  await deployer.link(SafeMath, KNWVoting);
  let votingInstance = await deployer.deploy(KNWVoting);
  await deployer.link(SafeMath, ditDemoCoordinator);
  await deployer.deploy(ditDemoCoordinator, KNWToken.address, KNWVoting.address, ditToken.address);
  await knwTokenInstance.setVotingAddress(KNWVoting.address);
  console.log("\n   Post-Deployment Calls")
  console.log("   ----------------------");
  console.log("   > Post-Deployment Call 1/3 done");
  await votingInstance.setCoordinatorAddress(ditDemoCoordinator.address);
  console.log("   > Post-Deployment Call 2/3 done");
  await votingInstance.setTokenAddress(KNWToken.address);
  console.log("   > Post-Deployment Call 3/3 done\n");
};