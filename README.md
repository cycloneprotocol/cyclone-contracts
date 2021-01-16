# Cyclone

Cyclone is a non-custodial Coin and ERC20 privacy-preserving protocol based on zkSNARKs, which is based on the implementation and trust-setup of [tornado.cash](https://tornado.cash/). It improves transaction privacy by breaking the on-chain link between the recipient and destination addresses. It uses a smart contract that accepts Coins deposits that can be withdrawn by a different address. Whenever Coins are withdrawn by the new address, there is no way to link the withdrawal to the deposit, ensuring complete privacy.

Tornado works great on Ethereum but
- The degree of privacy it provides is proportional to the anonymity set in each of its pools, the size of which are stagnated, unfortunately;
- Decentralized governance is missing to evolve this utility to evolve.

Cyclone is built to address these two problems, which aims to provide 100x privacy with self-evolving-ness based on the built-in crypto-economic incentives - which encourages liquidity to be added to the anonymity pool and best ideas get implemented/deployed via decentralized governance.

Cyclone is firstly launched on [IoTeX](https://iotex.io) as it is a decentralized, fast, and feature-rich blockchain with a healthy and great community!

&nbsp;

## Why it is privacy-preserving?

**TLDR: Almost the same as Tornado!**

![](https://github.com/tornadocash/tornado-core/raw/master/docs/diagram.png)

To make a deposit user generates a secret and sends its hash (called a commitment) along with the deposit amount to the Tornado smart contract. The contract accepts the deposit and adds the commitment to its list of deposits.

Later, the user decides to make a withdrawal. To do that, the user should provide proof that he or she possesses a secret to an unspent commitment from the smart contract’s list of deposits. zkSNARKs technology allows that to happen without revealing which exact deposit corresponds to this secret. The smart contract will check the proof, and transfer deposited funds to the address specified for withdrawal. An external observer will be unable to determine which deposit this withdrawal came from.

You can read more about [tornado-cash](https://tornado.cash/)'s medium article and [cryptographic review](https://tornado.cash/Tornado_cryptographic_review.pdf).


## How $CYC works?
$CYC is the token used to incentivize participants (liquidity providers for anonymity and trading as well as community participants) into Cyclone.
- Total supply of $CYC is unlimited
- **Anonymity mining**
-- For each deposit of Coin or ERC20 to the anonymity pool, N $CYC is minted to the sender
-- For each withdraws of Coin or ERC20 from the anonymity pool, M $CYC needs to be sent to the contract and burned
- **Liquidity mining** - Coin-CYC pool tokens from mimo can be staked to mine a total of 1000 Coin per day
- **Decentralized governance** to continuously tune the token economics, grow anonymity pools, add new assets, and go beyond.

## Fair and safe launch
We advocate "fair launch" meaning no $CYC tokens were pre-mined or pre-allocated, and this asset was not given a valuation. To activate the community and bootstrap the liquidity [mimo](https://mimo.finance), 50,000 $CYC tokens are minted during the launch where 40,000 $CYC tokens are sent to [mimo](https://mimo.finance) for AMM and 10,000 tokens are airdropped to the IoTeX community!

We value "safe launch" too - therefore, we use the exact zkSNARKs part from Tornado's [implementation](https://github.com/tornadocash/tornado-core/releases/tag/v2.1) which has been [audited](https://tornado.cash/Tornado_circuit_audit.pdf) by [authorities](https://tornado.cash/Tornado_solidity_audit.pdf). In addition, we directly use the result from Tornado's `Trusted Setup MPC` which is [successful](https://ceremony.tornado.cash/) and running [great](https://medium.com/@tornado.cash/the-biggest-trusted-setup-ceremony-in-the-world-3c6ab9c8fffa#43d9) on [Ethereum](https://medium.com/@tornado.cash/tornado-cash-trusted-setup-ceremony-b846e1e00be1).

## Development

Please read DEV.md for the detailed development guide. 

## Contract Address on MainNet

- Cyclone Token: 

- Timelock:

- GovernorAlpha:

- Aeolus: 

- Hasher: ```io1pfq0g3ye7pp0gamtw4hj9kskunn3ue7400wdm5```

- Verifier: ```io1rn3z2c9hc3fxnukwa0cl69hdveh0uy8mar8vqr```

- CoinCyclone
  - 10K Coins
  - 100K Coins
  - 1M Coins

- ERC20Cyclone
  - 1 Token
  - 100 Tokens
  - 10k Tokens
  - 1M Tokens
