pragma solidity <0.6 >=0.4.24;

import "../Cyclone.sol";
import "./IMimoFactory.sol";
import "./IMimoExchange.sol";

contract CoinCyclone is Cyclone {
  IMimoExchange public mimoExchange;
  constructor(
    IVerifier _verifier,
    IMintableToken _cyctoken,
    IMimoFactory _mimoFactory,
    IAeolus _aeolus,
    uint256 _initDenomination,
    uint256 _denominationRound,
    uint32 _merkleTreeHeight,
    address _operator
  ) Cyclone(_verifier, _cyctoken, _aeolus, _initDenomination, _denominationRound, _merkleTreeHeight, _operator) public {
    mimoExchange = IMimoExchange(_mimoFactory.getExchange(address(_cyctoken)));
  }

  function getDepositParameters() external view returns (uint256, uint256) {
    uint256 denomination = _getDepositDenomination(address(this).balance);

    return (denomination, _weightedAmount(_cycPerDenomination(denomination).mul(cashbackRate), numOfShares).div(10000));
  }

  function getWithdrawDenomination() external view returns (uint256) {
    return _getWithdrawDenomination();
  }

  function _getWithdrawDenomination() private view returns (uint256) {
    if (numOfShares > 0) {
      return address(this).balance.div(numOfShares).div(denominationRound).mul(denominationRound);
    }
    return initDenomination + address(this).balance;
  }

  function _getDepositDenomination(uint256 totalBalance) private view returns (uint256) {
    if (numOfShares > 0) {
      return totalBalance.div(numOfShares).add(denominationRound - 1).div(denominationRound).mul(denominationRound);
    }
    return initDenomination + totalBalance;
  }

  function _cycPerDenomination(uint256 _denomination) internal view returns (uint256) {
    uint256 cycPrice;
    if (cycToken.balanceOf(address(mimoExchange)) != 0 && address(mimoExchange).balance != 0) {
      cycPrice = address(mimoExchange).balance.mul(oneCYC).div(cycToken.balanceOf(address(mimoExchange)));
    }
    if (cycPrice < minCYCPrice) {
      cycPrice = minCYCPrice;
    }
    if (cycPrice == 0) {
      return 0;
    }
    return _denomination.mul(oneCYC).div(cycPrice);
  }

  function _processDeposit(uint256 _minCashbackAmount) internal returns (uint256) {
    uint256 denomination = _getDepositDenomination(address(this).balance - msg.value); // this is for excluding current msg.value from total balance
    require (msg.value >= denomination, "amount should not be smaller than denomination");
    uint256 remaining = msg.value.sub(denomination);
    if (remaining > 0) {
      (bool success, ) = msg.sender.call.value(remaining)("");
      require(success, "transfer of change failed");
    }
    uint256 cycPerDenomination = _cycPerDenomination(denomination);
    aeolus.addReward(cycPerDenomination.mul(depositLpIR).div(10000));
    uint256 cashbackAmount = _weightedAmount(cycPerDenomination.mul(cashbackRate), numOfShares).div(10000);
    require(cashbackAmount >= _minCashbackAmount, "insufficient cashback amount");
    if (cashbackAmount > 0) {
      require(cycToken.mint(msg.sender, cashbackAmount), "mint failure");
    }

    return denomination;
  }

  function _processWithdraw(address payable _recipient, address payable _relayer, uint256 _fee, uint256 _refund) internal returns (uint256, uint256) {
    // sanity checks
    require(msg.value == 0, "Message value is supposed to be zero for IOTX Cyclone");
    require(_refund == 0, "Refund value is supposed to be zero for IOTX Cyclone");

    uint256 denomination = _getWithdrawDenomination();
    uint256 iotxToSpend = denomination.mul(withdrawLpIR).add(_weightedAmount(denomination.mul(buybackRate), numOfShares.sub(1))).div(10000);
    if (iotxToSpend != 0) {
      uint256 cycBought = mimoExchange.iotxToTokenSwapInput.value(iotxToSpend)(mimoExchange.getIotxToTokenInputPrice(iotxToSpend), block.timestamp.mul(2));
      uint256 lpIncentive = cycBought.mul(withdrawLpIR).div(withdrawLpIR.add(buybackRate));
      aeolus.addReward(lpIncentive);
      require(cycToken.burn(cycBought.sub(lpIncentive)), "burn failure");
    }
    (bool success, ) = _recipient.call.value(denomination.mul(10000 - apIncentiveRate).div(10000).sub(iotxToSpend).sub(_fee))("");
    require(success, "payment to _recipient did not go thru");
    if (_fee > 0) {
      (success, ) = _relayer.call.value(_fee)("");
      require(success, "payment to _relayer did not go thru");
    }

    return (denomination, iotxToSpend);
  }
}
