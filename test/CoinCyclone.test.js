const { expectRevert, time } = require('@openzeppelin/test-helpers');
const BigNumber = require('bignumber.js')
const CycloneToken = artifacts.require('CycloneToken');
const CoinCyclone = artifacts.require('CoinCyclone');
const Hasher = artifacts.require('Hasher');
const Verifier = artifacts.require('Verifier');
const MimoFactory = artifacts.require('MimoFactory');
const MimoExchange = artifacts.require('MimoExchange');
const Aeolus = artifacts.require('Aeolus');
const TestCycloneDelegate = artifacts.require('TestCycloneDelegate');
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
const toFixedHex = (number, length = 32) =>  '0x' + bigInt(number).toString(16).padStart(length * 2, '0')
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

contract('CoinCyclone', function ([cycOperator, initialLP, admin, bob, carol, daddy, relayer]) {
  beforeEach(async function () {
    // deploy cyclone token
    this.cycToken = await CycloneToken.new(cycOperator, initialLP, { from: cycOperator });

    // deploy mimos
    this.mimoFactory = await MimoFactory.new();
    const createExchangeResult = await this.mimoFactory.createExchange(this.cycToken.address);
    assert.equal(createExchangeResult.logs[0].args.exchange, await this.mimoFactory.getExchange(this.cycToken.address));
    this.mimoExchange = new MimoExchange(await this.mimoFactory.getExchange(this.cycToken.address));

    // deploy Aeolus
    this.als = await Aeolus.new(this.cycToken.address, this.mimoExchange.address, { from: admin });

    // deploy CoinCyclone
    this.hasher = await Hasher.new({from: admin});
    this.verifier = await Verifier.new({from: admin});
    await CoinCyclone.link("Hasher", this.hasher.address);
    this.cyclone = await CoinCyclone.new(
      this.verifier.address,
      this.cycToken.address,
      this.mimoFactory.address,
      this.als.address,
      initialDenomination, // 1 IOTX
      "100000000000000",
      20,
      admin,
      { from: admin }
    );
    // add minter and whitelist
    await this.cycToken.addMinter(this.cyclone.address, {from: cycOperator});
    await this.cycToken.addMinter(this.als.address, {from: cycOperator});
    await this.als.addAddressToWhitelist(this.cyclone.address, { from: admin });
  });
  describe("update config", function() {
    beforeEach(async function() {
      assert.equal((await this.cyclone.depositLpIR()).valueOf(), 0);
      assert.equal((await this.cyclone.cashbackRate()).valueOf(), 0);
      assert.equal((await this.cyclone.withdrawLpIR()).valueOf(), 0);
      assert.equal((await this.cyclone.buybackRate()).valueOf(), 0);
      assert.equal((await this.cyclone.apIncentiveRate()).valueOf(), 0);
      assert.equal((await this.cyclone.minCYCPrice()).valueOf(), 0);
    });
    it('update config from a stranger', async function() {
      await expectRevert.unspecified(this.cyclone.updateConfig(123, 456, 123, 456, 789, initialDenomination, 5, { from: bob }));
    });
    it('invalid rates', async function() {
      await expectRevert(this.cyclone.updateConfig(10001, 0, 0, 0, 0, initialDenomination, 0, { from: admin }), "invalid deposit related rates");
      await expectRevert(this.cyclone.updateConfig(5000, 5001, 0, 0, 0, initialDenomination, 0, { from: admin }), "invalid deposit related rates");
      await expectRevert(this.cyclone.updateConfig(0, 0, 10001, 0, 0, initialDenomination, 0, { from: admin }), "invalid withdraw related rates");
      await expectRevert(this.cyclone.updateConfig(0, 0, 5000, 5001, 0, initialDenomination, 0, { from: admin }), "invalid withdraw related rates");
      await expectRevert(this.cyclone.updateConfig(0, 0, 5000, 4000, 1001, initialDenomination, 0, { from: admin }), "invalid withdraw related rates");
    });
    it('success update config', async function() {
      await this.cyclone.updateConfig(123, 456, 123, 456, 789, 10, 5, { from: admin });
      assert.equal((await this.cyclone.depositLpIR()).valueOf(), 123);
      assert.equal((await this.cyclone.cashbackRate()).valueOf(), 456);
      assert.equal((await this.cyclone.withdrawLpIR()).valueOf(), 123);
      assert.equal((await this.cyclone.buybackRate()).valueOf(), 456);
      assert.equal((await this.cyclone.apIncentiveRate()).valueOf(), 789);
      assert.equal((await this.cyclone.minCYCPrice()).valueOf(), "10");
      assert.equal((await this.cyclone.maxNumOfShares()).valueOf(), "5");
    });
  });
  describe("initial denomination", function() {
    it('get deposit denomination', async function () {
      const values = await this.cyclone.getDepositParameters({ from: admin });
      assert.equal(values[0].valueOf(), initialDenomination);
    });
    it('get withdraw denomination', async function () {
      assert.equal((await this.cyclone.getWithdrawDenomination({ from: admin })).valueOf(), initialDenomination);
    });
  });
  describe("deposit & withdraw", function() {
    let deposit;
    let commitment;
    let denomination;
    let expectedCashback;
    beforeEach(async function() {
      deposit = generateDeposit();
      commitment = deposit.commitment;
    });
    describe("deposit without update config", function() {
      beforeEach(async function() {
        const values = await this.cyclone.getDepositParameters({ from: bob });
        denomination = values[0];
        expectedCashback = values[1];
      });
      it("check deposit denomination and expected cashback", async function() {
        assert.equal(denomination, initialDenomination);
        assert.equal(expectedCashback, "0");
      });
      it("deposit with zero cashback and zero lp incentive", async function() {
        assert.equal((await this.cyclone.depositLpIR()).valueOf(), 0);
        assert.equal((await this.cyclone.cashbackRate()).valueOf(), 0);

        await this.cyclone.deposit(toFixedHex(commitment), 0, { value: denomination.toString(), from: bob, gasPrice: 1 });
        assert.equal((await this.cycToken.balanceOf(bob)).valueOf(), "0");
        assert.equal((await this.cycToken.balanceOf(this.mimoExchange.address)).valueOf(), '0');
      });
    });
    describe("deposit with config updated", function() {
      beforeEach(async function() {
        await this.cyclone.updateConfig(100, 600, 100, 600, 500, "1000", 5, { from: admin });
        const values = await this.cyclone.getDepositParameters({ from: bob });
        denomination = values[0];
        expectedCashback = values[1];
      });
      describe("deposit failure cases", function() {
        it("insufficient denomination", async function() {
          await expectRevert(this.cyclone.deposit(toFixedHex(commitment), 0, { value: 0, from: bob, gasPrice: 1 }), "amount should not be smaller than denomination");
        });
        it("insufficient cashback", async function() {
          await expectRevert(this.cyclone.deposit(toFixedHex(commitment), expectedCashback + 100, { value: denomination.toString(), from: bob, gasPrice: 1 }), "insufficient cashback amount.");
        });
        it('duplicate commitments', async function() {
          const depositResult = await this.cyclone.deposit(toFixedHex(commitment), 0, { value: denomination.toString(), from: bob, gasPrice: 1 });
          assert.equal(depositResult.logs[0].event, 'Deposit');
          assert.equal(depositResult.logs[0].args.commitment, toFixedHex(commitment));
          assert.equal(depositResult.logs[0].args.denomination, denomination.toString());
          await expectRevert(this.cyclone.deposit(toFixedHex(commitment), 0, { denomination, from: bob }), "The commitment has been submitted");
        });
        it("sender is contract", async function() {
          const cycloneDelegate = await TestCycloneDelegate.new(this.cyclone.address);
          await expectRevert(cycloneDelegate.deposit(toFixedHex(commitment), { value: denomination.toString(), from: bob, gasPrice : 1}), "Caller cannot be a contract");
        });
      });

      it("deposit without liquidity", async function() {
        const depositResult = await this.cyclone.deposit(toFixedHex(commitment), 0, { value: denomination.toString(), from: bob, gasPrice: 1 });
        assert.equal(depositResult.receipt.rawLogs.length, 3);
        assert.equal(depositResult.logs[0].event, 'Deposit');
        assert.equal(depositResult.logs[0].args.commitment, toFixedHex(commitment));
        assert.equal(depositResult.logs[0].args.denomination, denomination.toString());
        assert.equal(depositResult.receipt.rawLogs[0].address, this.cycToken.address);
        assert.equal(depositResult.receipt.rawLogs[1].address, this.cycToken.address);
        assert.equal(depositResult.receipt.rawLogs[2].address, this.cyclone.address);
      });
      describe("deposit with liquidity", function() {
        beforeEach(async function() {
          // add liquidity 100 CYC and 10 IOTX
          await this.cycToken.approve(this.mimoExchange.address, "100000000000000000000", { from: initialLP });
          await this.mimoExchange.addLiquidity(0, "10000000000000000000", (await time.latest()).toNumber() + 123456789, {from: initialLP, value: "1000000000000000000"});
          assert.equal((await this.cycToken.balanceOf(this.mimoExchange.address)).valueOf(), '10000000000000000000'); // 10 CYC
          assert.equal((await web3.eth.getBalance(this.mimoExchange.address)).valueOf(), '1000000000000000000'); // 1 IOTX
        });
        it("use min cyclone token price", async function() {
          await this.cyclone.updateConfig(100, 600, 100, 600, 500, "2000000000000000000", 5, { from: admin });
          const depositResult = await this.cyclone.deposit(toFixedHex(commitment), 0, { value: denomination.toString(), from: bob, gasPrice: 1});
          assert.equal(depositResult.logs[0].event, 'Deposit');
          assert.equal(depositResult.logs[0].args.commitment, toFixedHex(commitment));
          assert.equal(depositResult.logs[0].args.denomination, denomination.toString());
          assert.equal((await this.cycToken.balanceOf(bob)).valueOf(), '30000000000000000'); // 1000000000000000000 / 2000000000000000000 * 0.06 = 0.3 CYC
        });
        describe("cyclone token price is larger than min cyclone token price", function() {
          beforeEach(async function() {
            const balanceBefore = await web3.eth.getBalance(bob);
            const depositResult = await this.cyclone.deposit(toFixedHex(commitment), 0, { value: denomination.toString(), from: bob, gasPrice: 1});
            const balanceAfter = await web3.eth.getBalance(bob);
            assert.equal(BigNumber(balanceBefore).minus(BigNumber(balanceAfter)).toString(), BigNumber(denomination).plus(BigNumber(depositResult.receipt.gasUsed)).toString()); // (1 + gas)IOTX spent
            assert.equal(depositResult.logs[0].event, 'Deposit');
            assert.equal(depositResult.logs[0].args.commitment, toFixedHex(commitment));
            assert.equal(depositResult.logs[0].args.denomination, denomination.toString());
            assert.equal((await this.cycToken.balanceOf(bob)).valueOf(), '600000000000000000'); // 10 CYC * 0.06 = 0.6 CYC
          });

          it("hit max number of shares", async function() {
            await this.cyclone.updateConfig(100, 600, 100, 600, 500, "2000000000000000000", 1, { from: admin });
            const deposit2 = generateDeposit();
            const values = await this.cyclone.getDepositParameters({ from: carol })
            await expectRevert(this.cyclone.deposit(toFixedHex(deposit2.commitment), 0, {
              value: values[0].valueOf(),
              from: carol,
            }), "hit share limit");
          })

          describe("withdraw and integration test", function() {
            let tree;
            let recipient;
            const refund = bigInt(0);
            const fee = bigInt(0);
            let groth16;
            let circuit;
            let provingKey;
            beforeEach(async function () {
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
            describe("withdraw failure cases", function() {
              it("withdraw with non-zero msg.value", async function() {
                await expectRevert(this.cyclone.withdraw(proof, ...args, { value: '1000', from: relayer }), "Message value is supposed to be zero for IOTX Cyclone");
              });
              it("withdraw with invalid merkle root", async function() {
                args[0] = toFixedHex(randomHex(32));
                await expectRevert(this.cyclone.withdraw(proof, ...args, { from: relayer }), "Cannot find your merkle root");
              });
              it("withdraw with invalid proof", async function() {
                wrongProof = '0xbeef' + proof.substr(6);
                await expectRevert(this.cyclone.withdraw(wrongProof, ...args, { from: relayer }), "verifier-proof-element-gte-prime-q");
              });
              it("withdraw with invalid input", async function() {
                args[5] = toFixedHex(bigInt(1000));
                await expectRevert(this.cyclone.withdraw(proof, ...args, { from: relayer }), "Invalid withdraw proof");
              });
              it("withdraw twice", async function() {
                const withdrawDenomination = await this.cyclone.getWithdrawDenomination({ from: admin });
                assert.equal(withdrawDenomination.toString(), '1000000000000000000'); // 1 IOTX

                await this.cyclone.withdraw(proof, ...args, { from: relayer });
                await expectRevert(this.cyclone.withdraw(proof, ...args, { from: relayer }), "The note has been already spent");
              });
              it("withdraw sender is contract", async function() {
                const cycloneDeleagte = await TestCycloneDelegate.new(this.cyclone.address);
                const withdrawDenomination = await this.cyclone.getWithdrawDenomination({ from: admin });
                assert.equal(withdrawDenomination.toString(), '1000000000000000000'); // 1 IOTX

                await expectRevert(cycloneDeleagte.withdraw(proof, ...args, { from: relayer }), "Caller cannot be a contract");
              });
            });
            describe("successful cases", function() {
              it('1 deposit & 1 withdraw', async function () {
                const withdrawDenomination = await this.cyclone.getWithdrawDenomination({ from: admin });
                assert.equal(withdrawDenomination.toString(), '1000000000000000000'); // 1 IOTX

                const { logs } = await this.cyclone.withdraw(proof, ...args, { from: relayer });

                assert.equal(logs[0].event, 'Withdrawal')
                assert.equal(logs[0].args.nullifierHash, toFixedHex(input.nullifierHash))
                assert.equal(logs[0].args.denomination, withdrawDenomination.toString())
                isSpent = await this.cyclone.isSpent(toFixedHex(input.nullifierHash))
                assert.equal(isSpent, true);

                balanceCycloneAfter = await web3.eth.getBalance(this.cyclone.address)
                assert.equal(balanceCycloneAfter.toString(), '50000000000000000'); // 1 IOTX * 0.05 = 0.05 IOTX

                balanceRecipientAfter = await web3.eth.getBalance(toFixedHex(input.recipient, 20))
                assert.equal(balanceRecipientAfter.toString(), '880000000000000000'); // 1 IOTX * 0.88(1 - depositLpIR + cashbackRate + apIncentiveRate) = 0.88 CYC
              });
              it('2 deposits & 1 withdraw', async function () {
                const deposit2 = generateDeposit();
                await tree.insert(deposit2.commitment);
                const values = await this.cyclone.getDepositParameters({ from: carol })
                await this.cyclone.deposit(toFixedHex(deposit2.commitment), 0, {
                  value: values[0].valueOf(),
                  from: carol,
                });

                const withdrawDenomination = await this.cyclone.getWithdrawDenomination({ from: admin });
                assert.equal(withdrawDenomination.toString(), '1000000000000000000'); // 1 IOTX

                const { logs } = await this.cyclone.withdraw(proof, ...args, { from: relayer });

                assert.equal(logs[0].event, 'Withdrawal');
                assert.equal(logs[0].args.nullifierHash, toFixedHex(input.nullifierHash));
                assert.equal(logs[0].args.denomination, withdrawDenomination.toString());
                assert.equal(await this.cyclone.isSpent(toFixedHex(input.nullifierHash)), true);

                balanceCycloneAfter = await web3.eth.getBalance(this.cyclone.address);
                assert.equal(balanceCycloneAfter.toString(), '1050000000000000000'); // 1 IOTX + 1 IOTX * 0.05 = 1.05 IOTX

                balanceRecipientAfter = await web3.eth.getBalance(toFixedHex(input.recipient, 20))
                assert.equal(balanceRecipientAfter.toString(), '904000000000000000'); // 1 IOTX * 0.88 (1 - depositLpIR - buybackRate * (5 - 1 * 2) / 5 - apIncentiveRate) = 0.88 CYC
              });
              it("3 deposits & 2 withdraws & 2 deposits & 1 withdraw & 1 deposit", async function() {
                // deposit #2 (pool size: 1 + 1)
                const deposit2 = generateDeposit();
                await tree.insert(deposit2.commitment);
                values = await this.cyclone.getDepositParameters({ from: carol })
                assert.equal(values[0].toString(), '1000000000000000000'); // 1 IOTX
                await this.cyclone.deposit(toFixedHex(deposit2.commitment), 0, {
                  value: values[0].valueOf(),
                  from: carol,
                });
                // deposit #3 (pool size: 2 + 1)
                const deposit3 = generateDeposit();
                await tree.insert(deposit3.commitment);
                values = await this.cyclone.getDepositParameters({ from: daddy })
                assert.equal(values[0].toString(), '1000000000000000000'); // 1 IOTX
                await this.cyclone.deposit(toFixedHex(deposit3.commitment), 0, {
                  value: values[0].valueOf(),
                  from: daddy,
                });

                // withdraw #1 (pool size: 3 - 1)
                withdrawDenomination = await this.cyclone.getWithdrawDenomination({ from: admin });
                assert.equal(withdrawDenomination.toString(), '1000000000000000000'); // 1 IOTX
                await this.cyclone.withdraw(proof, ...args, { from: relayer });
                balanceRecipientAfter = await web3.eth.getBalance(toFixedHex(input.recipient, 20))
                assert.equal(balanceRecipientAfter.toString(), '919000000000000000'); // 1 IOTX * 0.88 (1 - depositLpIR - buybackRate * (5 * 3 - 2 * 4) / (4 * 5) - apIncentiveRate) = 0.88 CYC

                // withdraw #2 (pool size: 2 - 1)
                treeResult = await tree.path(1);
                // Circuit input
                input2 = stringifyBigInts({
                  // public
                  root: treeResult.root,
                  nullifierHash: pedersenHash(deposit2.nullifier.leInt2Buff(31)),
                  relayer,
                  recipient,
                  fee,
                  refund,

                  // private
                  nullifier: deposit2.nullifier,
                  secret: deposit2.secret,
                  pathElements: treeResult.path_elements,
                  pathIndices: treeResult.path_index,
                });

                const proofData2 = await websnarkUtils.genWitnessAndProve(groth16, input2, circuit, provingKey);
                proof2 = websnarkUtils.toSolidityInput(proofData2).proof;

                assert.equal(await this.cyclone.isSpent(toFixedHex(input2.nullifierHash)), false);

                args2 = [
                  toFixedHex(input2.root),
                  toFixedHex(input2.nullifierHash),
                  toFixedHex(input2.recipient, 20),
                  toFixedHex(input2.relayer, 20),
                  toFixedHex(input2.fee),
                  toFixedHex(input2.refund)
                ];
                withdrawDenomination = await this.cyclone.getWithdrawDenomination({ from: admin });
                assert.equal(withdrawDenomination.toString(), '1025000000000000000'); // 2.05 / 2 = 1.025 IOTX

                balanceCycloneAfter = await web3.eth.getBalance(this.cyclone.address);
                assert.equal(balanceCycloneAfter.toString(), '2050000000000000000'); 

                await this.cyclone.withdraw(proof2, ...args2, { from: relayer });
                balanceRecipientAfter = await web3.eth.getBalance(toFixedHex(input.recipient, 20))
                assert.equal(balanceRecipientAfter.toString(), '1845600000000000000'); //  0.919 + 1.025 * 0.904 (1 - depositLpIR - buybackRate * (5 - 2) / 5 - apIncentiveRate) = 1.782 CYC

                // deposit #4 (pool size: 1 + 1)
                const deposit4 = generateDeposit();
                await tree.insert(deposit4.commitment);
                values = await this.cyclone.getDepositParameters({ from: bob })
                balanceCycloneAfter = await web3.eth.getBalance(this.cyclone.address);
                assert.equal(balanceCycloneAfter.toString(), '1076250000000000000'); 

                assert.equal(values[0].toString(), '1076300000000000000'); // 2.05 - 1.025 * 0.95 / 1 = 1.0763 IOTX
                await this.cyclone.deposit(toFixedHex(deposit4.commitment), 0, {
                  value: values[0].valueOf(),
                  from: bob,
                });

                // deposit #5 (pool size: 2 + 1)
                const deposit5 = generateDeposit();
                await tree.insert(deposit5.commitment);
                values = await this.cyclone.getDepositParameters({ from: carol })
                assert.equal(values[0].toString(), '1076300000000000000'); // (1.0763 * 2) / 2 = 1.0763 IOTX
                await this.cyclone.deposit(toFixedHex(deposit5.commitment), 0, {
                  value: values[0].valueOf(),
                  from: carol,
                });

                balanceCycloneAfter = await web3.eth.getBalance(this.cyclone.address);
                assert.equal(balanceCycloneAfter.toString(), '3228850000000000000'); 

                // withdraw #3 (pool size: 3 - 1)
                treeResult = await tree.path(2);
                // Circuit input
                input3 = stringifyBigInts({
                  // public
                  root: treeResult.root,
                  nullifierHash: pedersenHash(deposit3.nullifier.leInt2Buff(31)),
                  relayer,
                  recipient,
                  fee,
                  refund,

                  // private
                  nullifier: deposit3.nullifier,
                  secret: deposit3.secret,
                  pathElements: treeResult.path_elements,
                  pathIndices: treeResult.path_index,
                });

                const proofData3 = await websnarkUtils.genWitnessAndProve(groth16, input3, circuit, provingKey);
                proof3 = websnarkUtils.toSolidityInput(proofData3).proof;

                assert.equal(await this.cyclone.isSpent(toFixedHex(input3.nullifierHash)), false);

                args3 = [
                  toFixedHex(input3.root),
                  toFixedHex(input3.nullifierHash),
                  toFixedHex(input3.recipient, 20),
                  toFixedHex(input3.relayer, 20),
                  toFixedHex(input3.fee),
                  toFixedHex(input3.refund)
                ];
                withdrawDenomination = await this.cyclone.getWithdrawDenomination({ from: admin });
                assert.equal(withdrawDenomination.toString(), '1076200000000000000'); // 3.22885 / 3 = 1.0762 IOTX (round down)
                await this.cyclone.withdraw(proof3, ...args3, { from: relayer });

                // deposit #6 (pool size: 2 + 1)
                const deposit6 = generateDeposit();
                await tree.insert(deposit6.commitment);
                values = await this.cyclone.getDepositParameters({ from: daddy })
                assert.equal(values[0].toString(), '1103300000000000000'); //  (3.22885 - 1.0762 * 0.95 ) / 2 =  1.1033 IOTX (round up)
                await this.cyclone.deposit(toFixedHex(deposit6.commitment), 0, {
                  value: values[0].valueOf(),
                  from: daddy,
                });
              });
            });
          });
        });
      });
    });
  });
});
