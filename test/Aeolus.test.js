const { expectRevert, time } = require('@openzeppelin/test-helpers');
const Aeolus = artifacts.require('Aeolus');
const CycloneToken = artifacts.require('CycloneToken');
const ShadowToken = artifacts.require('ShadowToken');

contract('Aeolus', function ([operator, minter,  alice, bob, carol]) {
    beforeEach(async function () {
        this.cycToken = await CycloneToken.new(operator, carol, { from: alice });
        this.lpToken = await ShadowToken.new(minter, this.cycToken.address, "lp token", "lp", 18, { from: alice });
        this.aeolus = await Aeolus.new(this.cycToken.address, this.lpToken.address, { from: alice });
        await this.aeolus.addAddressToWhitelist(operator, { from: alice });
        await this.cycToken.addMinter(this.aeolus.address, {from: operator});
        await this.lpToken.mint(bob, '10000000000', { from: minter });
        assert.equal((await this.lpToken.balanceOf(bob)).valueOf(), '10000000000')
    });

    describe('set block reward', function() {
        it("check initial reward per block", async function() {
            assert.equal((await this.aeolus.rewardPerBlock()).valueOf(), '0');
        });
        it('set block reward from stranger', async function () {
            await expectRevert.unspecified(this.aeolus.setRewardPerBlock('30000000', { from: bob }));
            assert.equal((await this.aeolus.rewardPerBlock()).valueOf(), '0');
        });
        describe("set block reward from a whitelisted address", function() {
            it('set block reward once', async function () {
                await this.aeolus.setRewardPerBlock('30000000', { from: alice });
                assert.equal((await this.aeolus.rewardPerBlock()).valueOf(), '30000000');
            });
            it('set block reward twice', async function () {
                await this.aeolus.setRewardPerBlock('50000000', { from: alice });
                await this.aeolus.setRewardPerBlock('60000000', { from: alice });
                assert.equal((await this.aeolus.rewardPerBlock()).valueOf(), '60000000');
            });
        });
    });

    describe("update block reward", function() {
        it("reward per block is zero", async function() {
            const result = await this.aeolus.updateBlockReward();
            assert.equal(result.receipt.rawLogs.length, 0);
            assert.notEqual(result.receipt.blockNumber, this.aeolus.lastRewardBlock);
        });
        describe("reward per block is not zero", function() {
            beforeEach(async function() {
                await this.aeolus.setRewardPerBlock("123456789", { from: alice });
            });
            it("lp supply is zero", async function() {
                const result = await this.aeolus.updateBlockReward();
                assert.equal(result.receipt.rawLogs.length, 0);
                assert.equal(result.receipt.blockNumber, await this.aeolus.lastRewardBlock());
            });
            it("lp supply is not zero", async function() {
                await this.lpToken.approve(this.aeolus.address, '8000000', { from: bob });
                await this.aeolus.deposit("4000000", { from: bob });
                const result = await this.aeolus.updateBlockReward();
                assert.equal(result.receipt.rawLogs.length, 3);
                assert.equal(result.receipt.logs[0].logIndex, 2);
                assert.equal(result.receipt.logs[0].event, "RewardAdded");
                assert.equal(result.receipt.logs[0].args[0].valueOf(), "123456789");
                assert.equal(result.receipt.logs[0].args[1], true);
                assert.equal(result.receipt.blockNumber, await this.aeolus.lastRewardBlock());
            });
        });
    })

    describe('deposit and withdraw', function() {
        describe('not enough approve lp token', function() {
            it('no approve lp token', async function() {
                await expectRevert.unspecified(this.aeolus.deposit('8000000', { from: bob }));
            });
            it('no approve lp token', async function() {
                await this.lpToken.approve(this.aeolus.address, '7000000', { from: bob });
                await expectRevert.unspecified(this.aeolus.deposit('8000000', { from: bob }));
            });
            it('emergency withdraw', async function() {
                const result = await this.aeolus.emergencyWithdraw({from: bob});
                assert.equal(result.receipt.rawLogs.length, 2);
                assert.equal(result.receipt.logs[0].event, "EmergencyWithdraw");
                assert.equal(result.receipt.logs[0].args[0], bob);
                assert.equal(result.receipt.logs[0].args[1].valueOf(), "0");
            })
        });
        describe('enough approve lp token', function() {
            describe("zero reward per block", function() {
                it("deposit", async function() {
                    await this.lpToken.approve(this.aeolus.address, '8000000', { from: bob });
                    const depositResult = await this.aeolus.deposit('8000000', { from: bob });
                    assert.equal(depositResult.receipt.rawLogs.length, 2);
                });
            });
            describe("non-zero reward per block", function() {
                beforeEach(async function () {
                    await this.aeolus.setRewardPerBlock('4000000', { from: alice });
                    await this.lpToken.approve(this.aeolus.address, '8000000', { from: bob });
                });
                describe('deposit', function() {
                    it('deposit without pending', async function() {
                    });
                    describe('deposit with pending', function() {
                        beforeEach(async function () {
                            assert.equal((await this.aeolus.pendingReward(bob)).valueOf(), "0");
                            assert.equal((await this.lpToken.balanceOf(this.aeolus.address)).valueOf(), '0');
                            const depositResult = await this.aeolus.deposit('8000000', { from: bob });
                            assert.equal(depositResult.receipt.rawLogs.length, 2);
                            assert.equal(depositResult.receipt.logs[0].event, "Deposit");
                            assert.equal(depositResult.receipt.logs[0].args[0], bob);
                            assert.equal(depositResult.receipt.logs[0].args[1].valueOf(), "8000000");
                            assert.equal((await this.lpToken.balanceOf(this.aeolus.address)).valueOf(), '8000000');
                        });
                        it('check pending reward', async function() {
                            await time.advanceBlock();
                            assert.equal((await this.aeolus.pendingReward(bob)).valueOf(), "4000000");
                            assert.equal((await this.aeolus.pendingReward(alice)).valueOf(), "0");
                            await time.advanceBlock();
                            assert.equal((await this.aeolus.pendingReward(bob)).valueOf(), "8000000");
                            assert.equal((await this.aeolus.pendingReward(alice)).valueOf(), "0");
                        });
                        it('withdraw', async function() {
                            const withdrawResult = await this.aeolus.withdraw('4000000', { from: bob });
                            assert.equal(withdrawResult.receipt.rawLogs.length, 6);
                            assert.equal(withdrawResult.receipt.logs[1].event, "Withdraw");
                            assert.equal(withdrawResult.receipt.logs[1].args[0], bob);
                            assert.equal(withdrawResult.receipt.logs[1].args[1].valueOf(), "4000000");
                            assert.equal((await this.lpToken.balanceOf(this.aeolus.address)).valueOf(), '4000000');
                            assert.equal((await this.lpToken.balanceOf(bob)).valueOf(), '9996000000');
                            assert.equal((await this.cycToken.balanceOf(bob)).valueOf(), '4000000');
                        });
                        it('emergency withdraw', async function() {
                            const result = await this.aeolus.emergencyWithdraw({from: bob});
                            assert.equal(result.receipt.rawLogs.length, 2);
                            assert.equal(result.receipt.logs[0].event, "EmergencyWithdraw");
                            assert.equal(result.receipt.logs[0].args[0], bob);
                            assert.equal(result.receipt.logs[0].args[1].valueOf(), "8000000");
                        });
                    });
                });
            });
        });
    });
    describe('add reward', function() {
        it('from a not-whitelisted address', async function() {
            await expectRevert.unspecified(this.aeolus.addReward("300000", { from: bob }));
        });
        describe('from a whitelisted address', function() {
            beforeEach(async function() {
                assert.equal((await this.aeolus.accCYCPerShare()).valueOf(), "0");
            });
            it("no lp supply", async function() {
                const result = await this.aeolus.addReward("300000", { from: operator });
                assert.equal(result.receipt.rawLogs.length, 0);
            });
            describe("with lp supply", function() {
                beforeEach(async function() {
                    await this.lpToken.approve(this.aeolus.address, '8000000', { from: bob });
                    await this.aeolus.deposit('8000000', { from: bob });
                });
                it("zero amount", async function() {
                    const result = await this.aeolus.addReward("0", { from: operator });
                    assert.equal(result.receipt.rawLogs.length, 0);
                });
                it("success operation", async function() {
                    const result = await this.aeolus.addReward("3000", { from: operator });
                    assert.equal(result.receipt.rawLogs.length, 3);
                });
            });
        });
    });
});