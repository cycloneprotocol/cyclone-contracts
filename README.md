# Cyclone

Cyclone is a multi-chain, non-custodial, privacy-preserving protocol. Cyclone applies zkSNARKs to enable transactional privacy by breaking the on-chain link between depositor and recipient addresses. It uses a smart contract that accepts coins/tokens deposits, which can be withdrawn by a different address. Whenever an asset is withdrawn from Cyclone, there is no way to link the withdrawal to the deposit for absolute privacy.

Cyclone's zkSNARKs is based on the trusted code and implementation of tornado.cash, which works great on Ethereum except:
- The degree of privacy it provides is proportional to the anonymity set in each of its pools, the size of which are stagnated without a properly designed incentive mechanism;
- It only supports Ethereum and no other blockchains;
- Decentralized governance is missing to evolve the protocol itself.

Cyclone is built to address these problems and aims to provide enhanced economic incentives, multi-chain capability and decentralized governance via the $CYC token -- the core parts of its token economics are mint-n-burn, anonymity mining, and liquidity mining. 

Cyclone is launching first on [IoTeX](https://iotex.io) as it is a fast and feature-rich blockchain with necessary ecosystem components and a healthy community. After that, Cyclone will launch on Ethereum, Polkadot and other mainstream public blockchains. $CYC will be the unified token for all instances of Cyclone Protocol.
&nbsp;

## Why it is privacy-preserving?

**TLDR: Almost the same as Tornado!**

![](https://github.com/tornadocash/tornado-core/raw/master/docs/diagram.png)

To make a deposit user generates a secret and sends its hash (called a commitment) along with the deposit amount to the Tornado smart contract. The contract accepts the deposit and adds the commitment to its list of deposits.

Later, the user decides to make a withdrawal. To do that, the user should provide proof that he or she possesses a secret to an unspent commitment from the smart contract’s list of deposits. zkSNARKs technology allows that to happen without revealing which exact deposit corresponds to this secret. The smart contract will check the proof, and transfer deposited funds to the address specified for withdrawal. An external observer will be unable to determine which deposit this withdrawal came from.

You can read more about [tornado-cash](https://tornado.cash/)'s medium article and [cryptographic review](https://tornado.cash/Tornado_cryptographic_review.pdf).


## How $CYC works?
$CYC is the token used to incentivize participants (liquidity providers for anonymity and trading as well as community participants) into Cyclone.
- Total supply of $CYC is limited by the max num of deposits for each pools
- Initial Supply: 2,021 for the community
- Mint-n-Burn
    - Everyone can mint CYC tokens if deposits coins/tokens to anonymity pools
    - CYC tokens are burned when one withdraws coins/tokens from anonymity pools
- Anonymity Mining: Coins/tokens are rewarded to ones who deposit coins/tokens into anonymity pools and keep them there for a while
- Liquidity Mining: CYC is rewarded to users who provides liquidity for CYC on DEX (Decentralized Exchanges) such as mimo
- Decentralized Governance will be enforced after launch, CYC will be used to govern the Cyclone Protocol.

## Fair and safe launch
We advocate "fair launch" meaning **no $CYC tokens were pre-mined or pre-allocated**, and this asset was not given an initial valuation. To activate the community and bootstrap the liquidity [mimo](https://mimo.finance), 2,021 $CYC tokens are minted during the launch and are airdropped to the community!

We value "safe launch" too - therefore, we use the exact zkSNARKs part from Tornado's [implementation](https://github.com/tornadocash/tornado-core/releases/tag/v2.1) which has been [audited](https://tornado.cash/Tornado_circuit_audit.pdf) by [authorities](https://tornado.cash/Tornado_solidity_audit.pdf). In addition, we directly use the result from Tornado's `Trusted Setup MPC` which is [successful](https://ceremony.tornado.cash/) and running [great](https://medium.com/@tornado.cash/the-biggest-trusted-setup-ceremony-in-the-world-3c6ab9c8fffa#43d9) on [Ethereum](https://medium.com/@tornado.cash/tornado-cash-trusted-setup-ceremony-b846e1e00be1).

## Contract Address on MainNet

- Cyclone Token: `io1f4acssp65t6s90egjkzpvrdsrjjyysnvxgqjrh`

- Timelock: `io10jv5lvagcgyvzagdlymagucyp3sy9ykktkudth`

- GovernorAlpha: `io1w8n28wr5dpc2uh3pzvx4n402h0l2agmu67a26x`

- Aeolus:  `io1j2rwjfcm7jt7cwdnlkh0203chlrtfnc59424xc`

- Hasher: `io1pfq0g3ye7pp0gamtw4hj9kskunn3ue7400wdm5`

- Verifier: `io1rn3z2c9hc3fxnukwa0cl69hdveh0uy8mar8vqr`

- Pool 1 (Squid): `io15w9kwskwl9tn7luhcwrj0rarzjp988pafg07uf` 

- Pool 2 (Dolphin): `io1wcd67wk36e3r8eku8scv7g7azsfnqs7z3e38xg` 

- Pool 3 (Shark): `io1v667xgkux8uv0gell53ew5tr090c69k85deezn` 

- Pool 4 (Whale): `io1wnaks7kectrkxk5v4d7mh97jkqjl4p0690jxfx` 

