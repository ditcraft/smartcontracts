var KNWToken = artifacts.require("./KNWToken.sol");
var KNWVoting = artifacts.require("./KNWVoting.sol");
var ditDemoCoordinator = artifacts.require("./demo_contracts/ditDemoCoordinator.sol");
var ditToken = artifacts.require("MintableERC20");
var SafeMath = artifacts.require("./libraries/SafeMath.sol");

var lastKNWVoting = "0x0000000000000000000000000000000000000000";
var lastDitCoordinator = "0x0000000000000000000000000000000000000000";
var ditTokenContract = "0x60a3803759bdabe6960bdcf8a165fc4bc0ea4e66";

module.exports = async function(deployer) {
  await deployer.deploy(SafeMath);
  await deployer.link(SafeMath, KNWToken);
  let knwTokenInstance = await deployer.deploy(KNWToken);
  
  if(ditTokenContract == "0x0000000000000000000000000000000000000000") {
    await deployer.link(SafeMath, ditToken);
    await deployer.deploy(ditToken);
    ditTokenContract = ditToken.address;
  }

  await deployer.link(SafeMath, KNWVoting);
  let votingInstance = await deployer.deploy(KNWVoting, KNWToken.address, lastKNWVoting);
  await deployer.link(SafeMath, ditDemoCoordinator);
  await deployer.deploy(ditDemoCoordinator, KNWToken.address, KNWVoting.address, lastDitCoordinator, ditTokenContract);
  
  console.log("\n   Post-Deployment Calls")
  console.log("   ----------------------");
  await knwTokenInstance.authorizeAddress(KNWVoting.address);
  console.log("   > Post-Deployment Call 1/2 done");
  await votingInstance.addDitCoordinator(ditDemoCoordinator.address);
  console.log("   > Post-Deployment Call 2/2 done\n");

  console.log("\n   Constructor arguments")
  console.log("   ----------------------");
  console.log("   > KNWVoting:") 
  console.log("   > (" + KNWToken.address + ", " + lastKNWVoting + ")")
  console.log("   > ditCoordinator:")
  console.log("   > (" + KNWToken.address + ", " + KNWVoting.address + ", " + lastDitCoordinator + ", " + ditTokenContract + ")")


  console.log("\n   Contracts")
  console.log("   ----------------------");
  console.log("   > KNWToken: " + KNWToken.address)
  console.log("   > KNWVoting: " + KNWVoting.address)
  console.log("   > ditToken: " + ditTokenContract)
  console.log("   > ditCoordinator: " + ditDemoCoordinator.address + "\n")
};