const { expectRevert, time } = require('@openzeppelin/test-helpers');
const ethers = require('ethers');
const CycloneToken = artifacts.require('CycloneToken');
const CoinCyclone = artifacts.require('CoinCyclone');
const Timelock = artifacts.require('Timelock');
const GovernorAlpha = artifacts.require('GovernorAlpha');
const Hasher = artifacts.require('Hasher');
const Verifier = artifacts.require('Verifier');
const MimoFactory = artifacts.require('MimoFactory');
const MimoExchange = artifacts.require('MimoExchange');
const Aeolus = artifacts.require('Aeolus');

function encodeParameters(types, values) {
    const abi = new ethers.utils.AbiCoder();
    return abi.encode(types, values);
}

contract('Governor', ([cycOperator, initialLP, alice, bob]) => {
    it('should work', async () => {
        // deploy cyclone token 
        this.cycToken = await CycloneToken.new(cycOperator, initialLP, { from: cycOperator });
        await this.cycToken.addMinter(cycOperator, { from: cycOperator });
        await this.cycToken.delegate(initialLP, { from: initialLP });
        this.cycToken.mint(bob, '4000000000000000000000', {from: cycOperator}) // 4000 CYC 
        await this.cycToken.delegate(bob, { from: bob });

        // deploy timelock
        this.timelock = await Timelock.new(alice, time.duration.days(2), { from: alice });
        this.gov = await GovernorAlpha.new(this.timelock.address, this.cycToken.address, alice, 100, { from: alice });
        await this.timelock.setPendingAdmin(this.gov.address, { from: alice });
        await this.gov.__acceptAdmin({ from: alice });

        // deploy Mimos
        this.mimoFactory = await MimoFactory.new();
        this.poolToken = new MimoExchange(await this.mimoFactory.getExchange(this.cycToken.address));

        // deploy Aeolus
        this.als = await Aeolus.new(this.cycToken.address, this.poolToken.address, { from: alice });

        // deploy CoinCyclone
        this.hasher = await Hasher.new({from: alice});
        this.verifier = await Verifier.new({from: alice});
        await CoinCyclone.link("Hasher", this.hasher.address);
        this.cyclone = await CoinCyclone.new(
            this.verifier.address, 
            this.cycToken.address,
            this.mimoFactory.address,  
            this.als.address,  
            "1000000000000000000",
            "10000000000",
            20,
            this.timelock.address,
            { from: alice }
        );

        // test "updateTax" through Governor
        await expectRevert(
            this.cyclone.updateConfig('100', '200', '300', '400', '500', '1000000000000000000', 5, { from: alice }),
            'Only Governance DAO can call this function.',
        );
        await expectRevert(
            this.gov.propose(
                [this.cyclone.address], ['0'], ['updateConfig(uint256,uint256,uint256,uint256,uint256,uint256,uint256)'],
                [encodeParameters(['uint256', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256'], ['100', '200', '300', '400', '500', '1000000000000000000', 5])],
                'Update tax to 100',
                { from: alice },
            ),
            'GovernorAlpha::propose: proposer votes below proposal threshold',
        );
        await this.gov.propose(
            [this.cyclone.address], ['0'], ['updateConfig(uint256,uint256,uint256,uint256,uint256,uint256,uint256)'],
            [encodeParameters(['uint256', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256'], ['100', '200', '300', '400', '500', '1000000000000000000', 5])],
            'Update tax to 100',
            { from: initialLP },
        );
        await time.advanceBlock();
        await this.gov.castVote('1', true, { from: bob });
        await expectRevert(this.gov.queue('1'), "GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        console.log("Advancing 100 blocks. Will take a while...");
        for (let i = 0; i < 100; ++i) {
            await time.advanceBlock();
        }
        await this.gov.queue('1');
        await expectRevert(this.gov.execute('1'), "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        await time.increase(time.duration.days(3));
        assert.equal((await this.cyclone.depositLpIR()).toString(), '0');
        assert.equal((await this.cyclone.cashbackRate()).toString(), '0');
        assert.equal((await this.cyclone.withdrawLpIR()).toString(), '0');
        assert.equal((await this.cyclone.buybackRate()).toString(), '0');
        assert.equal((await this.cyclone.apIncentiveRate()).toString(), '0');
        assert.equal((await this.cyclone.minCYCPrice()).toString(), '0');
        assert.equal((await this.cyclone.maxNumOfShares()).toString(), '0');
        await this.gov.execute('1');
        assert.equal((await this.cyclone.depositLpIR()).toString(), '100');
        assert.equal((await this.cyclone.cashbackRate()).toString(), '200');
        assert.equal((await this.cyclone.withdrawLpIR()).toString(), '300');
        assert.equal((await this.cyclone.buybackRate()).toString(), '400');
        assert.equal((await this.cyclone.apIncentiveRate()).toString(), '500');
        assert.equal((await this.cyclone.minCYCPrice()).toString(), '1000000000000000000');
        assert.equal((await this.cyclone.maxNumOfShares()).toString(), '5');
    });
});