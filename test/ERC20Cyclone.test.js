const { expectRevert, time } = require('@openzeppelin/test-helpers');
const Hasher = artifacts.require('Hasher');
const ERC20Cyclone = artifacts.require('ERC20Cyclone');
const CycloneToken = artifacts.require('CycloneToken');
const Verifier = artifacts.require('Verifier');
const MimoFactory = artifacts.require('MimoFactory');
const MimoExchange = artifacts.require('MimoExchange');
const ShadowToken = artifacts.require('ShadowToken');
const Aeolus = artifacts.require('Aeolus');

const fs = require('fs')
const websnarkUtils = require('websnark/src/utils')
const buildGroth16 = require('websnark/src/groth16')
const stringifyBigInts = require('websnark/tools/stringifybigint').stringifyBigInts
const snarkjs = require('snarkjs')
const bigInt = snarkjs.bigInt
const crypto = require('crypto')
const circomlib = require('circomlib')
const MerkleTree = require('../lib/MerkleTree');

const { randomHex } = require('web3-utils');
const rbigint = (nbytes) => snarkjs.bigInt.leBuff2int(crypto.randomBytes(nbytes))
const pedersenHash = (data) => circomlib.babyJub.unpackPoint(circomlib.pedersenHash.hash(data))[0]
const toFixedHex = (number, length = 32) => '0x' + bigInt(number).toString(16).padStart(length * 2, '0')
const getRandomRecipient = () => rbigint(20)

const initialDenomination = "1000000000000000000";

function generateDeposit() {
    const secret = rbigint(31);
    const nullifier = rbigint(31);
    return {
        secret,
        nullifier,
        commitment: pedersenHash(Buffer.concat([nullifier.leInt2Buff(31), secret.leInt2Buff(31)])),
    };
}

contract('ERC20Cyclone', ([operator, minter, bob, admin, carol, relayer]) => {
    beforeEach(async () => {
        this.verifier = await Verifier.new({ from: admin });
        this.cycToken = await CycloneToken.new(operator, carol, { from: operator });
        // deploy mimos
        this.mimoFactory = await MimoFactory.new();
        const createExchangeResult = await this.mimoFactory.createExchange(this.cycToken.address);
        assert.equal(createExchangeResult.logs[0].args.exchange, await this.mimoFactory.getExchange(this.cycToken.address));
        this.mimoExchange = new MimoExchange(await this.mimoFactory.getExchange(this.cycToken.address));
        this.xrcToken = await ShadowToken.new(minter, this.cycToken.address, "xrc token", "xrc", 18, { from: admin });
        await this.xrcToken.mint(bob, "1000000000000000000000", { from: minter });
        await this.mimoFactory.createExchange(this.xrcToken.address);
        this.xrcExchange = new MimoExchange(await this.mimoFactory.getExchange(this.xrcToken.address));
        // deploy Aeolus
        this.aeolus = await Aeolus.new(this.cycToken.address, this.mimoExchange.address, { from: admin });
        this.hasher = await Hasher.new({ from: admin });
        await ERC20Cyclone.link("Hasher", this.hasher.address);

        this.cyclone = await ERC20Cyclone.new(
            this.verifier.address,
            this.cycToken.address,
            this.mimoFactory.address,
            this.aeolus.address,
            initialDenomination,
            1,
            20,
            admin,
            this.xrcToken.address,
            { from: admin });

        // add minter and whitelist
        await this.cycToken.addMinter(this.cyclone.address, { from: operator });
        await this.cycToken.addMinter(this.aeolus.address, { from: operator });
        await this.aeolus.addAddressToWhitelist(this.cyclone.address, { from: admin });
    });

    describe("update config", () => {
        beforeEach(async () => {
            assert.equal((await this.cyclone.depositLpIR()).valueOf(), 0);
            assert.equal((await this.cyclone.cashbackRate()).valueOf(), 0);
            assert.equal((await this.cyclone.apIncentiveRate()).valueOf(), 0);
            assert.equal((await this.cyclone.minCYCPrice()).valueOf(), 0);
        });
        it('update config from a stranger', async () => {
            await expectRevert.unspecified(this.cyclone.updateConfig(123, 456, 123, 456, 789, initialDenomination, 5, { from: bob }));
        });
        it('invalid rates', async () => {
            await expectRevert(this.cyclone.updateConfig(10001, 0, 0, 0, 0, initialDenomination, 5, { from: admin }), "invalid deposit related rates");
            await expectRevert(this.cyclone.updateConfig(5000, 5001, 0, 0, 0, initialDenomination, 5, { from: admin }), "invalid deposit related rates");
            await expectRevert(this.cyclone.updateConfig(0, 0, 5000, 4000, 1001, initialDenomination, 5, { from: admin }), "invalid withdraw related rates");
            await expectRevert(this.cyclone.updateConfig(0, 0, 10001, 0, 0, initialDenomination, 5, { from: admin }), "invalid withdraw related rates");
            await expectRevert(this.cyclone.updateConfig(0, 0, 5000, 5001, 0, initialDenomination, 5, { from: admin }), "invalid withdraw related rates");
        });
        it('success update config', async () => {
            await this.cyclone.updateConfig(123, 456, 123, 456, 789, "0", 5, { from: admin });
            assert.equal((await this.cyclone.depositLpIR()).valueOf(), 123);
            assert.equal((await this.cyclone.cashbackRate()).valueOf(), 456);
            assert.equal((await this.cyclone.withdrawLpIR()).valueOf(), 123);
            assert.equal((await this.cyclone.buybackRate()).valueOf(), 456);
            assert.equal((await this.cyclone.apIncentiveRate()).valueOf(), 789);
            assert.equal((await this.cyclone.minCYCPrice()).valueOf(), "0");
            assert.equal((await this.cyclone.maxNumOfShares()).valueOf(), 5);
        });
    });

    describe("initial denomination", () => {
        it('get deposit denomination', async () => {
            const values = await this.cyclone.getDepositParameters({ from: admin });
            assert.equal(values[0].valueOf(), initialDenomination);
        });

        it('get withdraw denomination', async () => {
            assert.equal((await this.cyclone.getWithdrawDenomination({ from: admin })).valueOf(), initialDenomination);
        });
    });
    describe("deposit & withdraw", () => {
        let deposit;
        let commitment;
        let denomination;
        let expectedCashback;
        beforeEach(async () => {
            deposit = generateDeposit();
            commitment = deposit.commitment;
            await this.cyclone.updateConfig(100, 600, 100, 600, 500, initialDenomination, 0, { from: admin });
            const values = await this.cyclone.getDepositParameters({ from: bob });
            denomination = values[0];
            expectedCashback = values[1];
        });

        describe("deposit with liquidity", () => {
            beforeEach(async () => {
                const values = await this.cyclone.getDepositParameters({ from: bob });
                await this.cycToken.approve(this.mimoExchange.address, "100000000000000000000", { from: carol });
                await this.mimoExchange.addLiquidity(0, "100000000000000000000", (await time.latest()).toNumber() + 123456789, {from: carol, value: "1000000000000000000"});
                await this.xrcToken.approve(this.xrcExchange.address, "100000000000000000", { from: bob });
                await this.xrcExchange.addLiquidity(0, "100000000000000000", (await time.latest()).toNumber() + 123456789, {from: bob, value: "10000000000000000"});
                await this.xrcToken.approve(this.cyclone.address, values[0].toString(), { from: bob });
                await this.cyclone.deposit(toFixedHex(commitment), 0, { value: 0, from: bob });
            });
            describe("withdraw and integration test", () => {
                let tree;
                let recipient;
                let refund = bigInt(0);
                let fee = bigInt(0);
                let groth16;
                let circuit;
                let provingKey;
                beforeEach(async () => {
                    // for withdraw verification 
                    groth16 = await buildGroth16();
                    circuit = require('../build/circuits/withdraw.json');
                    provingKey = fs.readFileSync('build/circuits/withdraw_proving_key.bin').buffer;
                    tree = new MerkleTree(20, null, 'test');
                    recipient = getRandomRecipient();
                    await tree.insert(commitment);

                    // create valid proof and args to withdraw 
                    const { root, path_elements, path_index } = await tree.path(0);
                    // Circuit input
                    input = stringifyBigInts({
                        // public
                        root,
                        nullifierHash: pedersenHash(deposit.nullifier.leInt2Buff(31)),
                        relayer,
                        recipient,
                        fee,
                        refund,

                        // private
                        nullifier: deposit.nullifier,
                        secret: deposit.secret,
                        pathElements: path_elements,
                        pathIndices: path_index,
                    });

                    const proofData = await websnarkUtils.genWitnessAndProve(groth16, input, circuit, provingKey);
                    proof = websnarkUtils.toSolidityInput(proofData).proof;

                    assert.equal(await this.cyclone.isSpent(toFixedHex(input.nullifierHash)), false);

                    args = [
                        toFixedHex(input.root),
                        toFixedHex(input.nullifierHash),
                        toFixedHex(input.recipient, 20),
                        toFixedHex(input.relayer, 20),
                        toFixedHex(input.fee),
                        toFixedHex(input.refund)
                    ];
                });
                it("withdraw with invalid merkle root", async () => {
                    args[0] = toFixedHex(randomHex(32));
                    await expectRevert(this.cyclone.withdraw(proof, ...args, { from: relayer }), "Cannot find your merkle root");
                });
                it("withdraw with invalid proof", async () => {
                    wrongProof = '0xbeef' + proof.substr(6);
                    await expectRevert(this.cyclone.withdraw(wrongProof, ...args, { from: relayer }), "verifier-proof-element-gte-prime-q");
                });
                it("withdraw with invalid input", async () => {
                    args[5] = toFixedHex(bigInt(1000));
                    await expectRevert(this.cyclone.withdraw(proof, ...args, { from: relayer }), "Invalid withdraw proof");
                });
                it('withdraw should work', async () => {
                    const withdrawDenomination = await this.cyclone.getWithdrawDenomination({ from: admin });
                    assert.equal(withdrawDenomination.toString(), '1000000000000000000'); // 1 IOTX

                    const { logs } = await this.cyclone.withdraw(proof, ...args, { from: relayer });

                    assert.equal(logs[0].event, 'Withdrawal')
                    assert.equal(logs[0].args.nullifierHash, toFixedHex(input.nullifierHash))
                    assert.equal(logs[0].args.denomination, withdrawDenomination.toString())
                    isSpent = await this.cyclone.isSpent(toFixedHex(input.nullifierHash))
                    assert.equal(isSpent, true);

                    balanceCycloneAfter = await web3.eth.getBalance(this.cyclone.address)
                    assert.equal(balanceCycloneAfter.toString(), '0'); 
                    balanceRecipientAfter = await web3.eth.getBalance(toFixedHex(input.recipient, 20))
                    assert.equal(balanceRecipientAfter.toString(), '0'); 
                    assert.equal((await this.cyclone.getWithdrawDenomination({ from: admin })).toString(), '1050000000000000000');
                });
            });
        });
    });
});