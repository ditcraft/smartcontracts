const KNWToken = artifacts.require("KNWToken");

module.exports = function(deployer, network, accounts) {
    deployer.deploy(KNWToken, accounts[0]);
  };

contract("KNWToken", async accounts => {
    const label1 = 'solidity';
    const label2 = 'javascript';
    let catchRevert = require("./exceptions.js").catchRevert;

    it("account1 should have zero balance", async () => {
        let instance = await KNWToken.deployed();
        let balance = await instance.balanceOfLabel.call(accounts[1], label1);
        assert.equal(balance.toNumber(), 0);
    });

    it("account1 should have zero balance", async () => {
        let instance = await KNWToken.deployed();
        let balance = await instance.balanceOfLabel.call(accounts[1], label2);
        assert.equal(balance.toNumber(), 0);
    });

    it("mint should not work", async () => {
        let instance = await KNWToken.deployed();
        await catchRevert(instance.mint(accounts[1], label1, 123, {from: accounts[1]}));
    });

    it("mint should work", async () => {
        let instance = await KNWToken.deployed();
        await instance.mint(accounts[1], label1, 123, {from: accounts[0]});
        let balance1 = await instance.balanceOfLabel.call(accounts[1], label1);
        assert.equal(balance1.toNumber(), 123);
        let balance2 = await instance.balanceOfLabel.call(accounts[1], label2);
        assert.equal(balance2.toNumber(), 0);
        await instance.mint(accounts[1], label1, 77, {from: accounts[0]});
        let balance3 = await instance.balanceOfLabel.call(accounts[1], label1);
        assert.equal(balance3.toNumber(), 200);
        let balance4 = await instance.balanceOfLabel.call(accounts[1], label2);
        assert.equal(balance4.toNumber(), 0);
        await instance.mint(accounts[1], label2, 123, {from: accounts[0]});
        let balance5 = await instance.balanceOfLabel.call(accounts[1], label1);
        assert.equal(balance5.toNumber(), 200);
        let balance6 = await instance.balanceOfLabel.call(accounts[1], label2);
        assert.equal(balance6.toNumber(), 123);
        let totalSupply = await instance.totalSupply.call();
        assert.equal(totalSupply.toNumber(), 323);
        let totalLabelSupply = await instance.totalLabelSupply.call(label1);
        assert.equal(totalLabelSupply.toNumber(), 200);
    });

    it("burn should not work", async () => {
        let instance = await KNWToken.deployed();
        await catchRevert(instance.burn(accounts[1], label1, 123, {from: accounts[1]}));
    });

    it("burn should work", async () => {
        let instance = await KNWToken.deployed();
        await instance.burn(accounts[1], label1, 50, {from: accounts[0]});
        let balance1 = await instance.balanceOfLabel.call(accounts[1], label1);
        assert.equal(balance1.toNumber(), 150);
        let balance2 = await instance.balanceOfLabel.call(accounts[1], label2);
        assert.equal(balance2.toNumber(), 123);
        let totalSupply = await instance.totalSupply.call();
        assert.equal(totalSupply.toNumber(), 273);
        let totalLabelSupply1 = await instance.totalLabelSupply.call(label1);
        assert.equal(totalLabelSupply1.toNumber(), 150);
        let totalLabelSupply2 = await instance.totalLabelSupply.call(label2);
        assert.equal(totalLabelSupply2.toNumber(), 123);
    });

    it("label array should be correct", async () => {
        let instance = await KNWToken.deployed();
        let labels1 = await instance.labelsOfAddress.call(accounts[1]);
        assert.equal(labels1[0], label1);
        assert.equal(labels1[1], label2);
        assert.equal(labels1.length, 2)
        let labels2 = await instance.labelsOfAddress.call(accounts[2]);
        assert.equal(labels2.length, 0)
    });
});