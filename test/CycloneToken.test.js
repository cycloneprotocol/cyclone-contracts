const { expectRevert } = require('@openzeppelin/test-helpers');
const CycloneToken = artifacts.require('CycloneToken');
const ShadowToken = artifacts.require('ShadowToken');

contract('CycloneToken', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.cycToken = await CycloneToken.new(alice, carol, { from: alice });
        await this.cycToken.addMinter(alice, {from: alice});
    });

    it('should have correct name and symbol and decimal and initial airdrop', async () => {
        const name = await this.cycToken.name();
        const symbol = await this.cycToken.symbol();
        const decimals = await this.cycToken.decimals();
        assert.equal(name.valueOf(), 'Cyclone');
        assert.equal(symbol.valueOf(), 'CYC');
        assert.equal(decimals.valueOf(), '18');

        const CarolBal = await this.cycToken.balanceOf(carol);
        assert.equal(CarolBal.valueOf(), '1200000000000000000000');
    });

    it('should only allow owner to mint token', async () => {
        await this.cycToken.mint(alice, '100', { from: alice });
        await this.cycToken.mint(bob, '1000', { from: alice });
        await expectRevert(
            this.cycToken.mint(carol, '1000', { from: bob }),
            'not the minter',
        );
        const totalSupply = await this.cycToken.totalSupply();
        const aliceBal = await this.cycToken.balanceOf(alice);
        const bobBal = await this.cycToken.balanceOf(bob);
        const carolBal = await this.cycToken.balanceOf(carol);
        assert.equal(totalSupply.toString(), '1200000000000000001100');
        assert.equal(aliceBal.toString(), '100');
        assert.equal(bobBal.toString(), '1000');
        assert.equal(carolBal.toString(), '1200000000000000000000');
    });

    it('should supply token transfers properly', async () => {
        await this.cycToken.mint(alice, '100', { from: alice });
        await this.cycToken.mint(bob, '1000', { from: alice });
        await this.cycToken.transfer(carol, '10', { from: alice });
        await this.cycToken.transfer(carol, '100', { from: bob });
        const totalSupply = await this.cycToken.totalSupply();
        const aliceBal = await this.cycToken.balanceOf(alice);
        const bobBal = await this.cycToken.balanceOf(bob);
        const carolBal = await this.cycToken.balanceOf(carol);
        assert.equal(totalSupply.toString(), '1200000000000000001100');
        assert.equal(aliceBal.toString(), '90');
        assert.equal(bobBal.toString(), '900');
        assert.equal(carolBal.toString(), '1200000000000000000110');
    });

    it('should transfer entails move delegate properly', async () => {
        await this.cycToken.mint(alice, '100', { from: alice });
        await this.cycToken.mint(bob, '10', { from: alice });
        await this.cycToken.delegate(carol, { from: alice });
        await this.cycToken.delegate(alice, { from: bob });
        await this.cycToken.transfer(bob, '100', { from: alice });
        
        const aliceBal = await this.cycToken.balanceOf(alice);
        assert.equal(aliceBal.toString(), '0');
        const carolVotes = await this.cycToken.getCurrentVotes(carol);
        const aliceVotes = await this.cycToken.getCurrentVotes(alice);

        assert.equal(carolVotes.toString(), '0');
        assert.equal(aliceVotes.toString(), '110');
    });

    it('should burnShadowToMint works', async () => {
        this.shadow = await ShadowToken.new(alice, this.cycToken.address, "Cyclone Shadow Token", "CYC-I'", 18, { from: alice });
        await this.cycToken.setShadowToken(this.shadow.address, { from: alice });

        await this.shadow.mint(bob, '100');
        await this.shadow.approve(this.cycToken.address, '100', { from: bob });
        await this.cycToken.burnShadowToMint(bob, '100', {from : bob });

        const shadowBalance = await this.shadow.balanceOf(bob);
        const cycTokenBalance = await this.cycToken.balanceOf(bob);
        assert.equal(shadowBalance.toString(), '0');
        assert.equal(cycTokenBalance.toString(), '100');
    });
  });