pragma solidity <0.6 >=0.4.24;

import "../Cyclone.sol";
import "../token/IERC20.sol";
import "./IMimoFactory.sol";
import "./IMimoExchange.sol";

contract ERC20Cyclone is Cyclone {
  IERC20 public xrc20Token;
  IMimoExchange public xrc20Exchange;
  IMimoExchange public mimoExchange;
  constructor(
    IVerifier _verifier,
    IMintableToken _cyctoken,
    IMimoFactory _mimoFactory,
    IAeolus _aeolus,
    uint256 _initDenomination,
    uint256 _denominationRound,
    uint32 _merkleTreeHeight,
    address _operator,
    IERC20 _xrc20Token
  ) Cyclone(_verifier, _cyctoken, _aeolus, _initDenomination, _denominationRound, _merkleTreeHeight, _operator) public {
    xrc20Token = _xrc20Token;
    xrc20Exchange = IMimoExchange(_mimoFactory.getExchange(address(_xrc20Token)));
    mimoExchange = IMimoExchange(_mimoFactory.getExchange(address(_cyctoken)));
  }

  function getDepositParameters() external view returns (uint256, uint256) {
    uint256 denomination = _getDepositDenomination();
    return (denomination, _weightedAmount(_cycPerDenomination(denomination).mul(cashbackRate), numOfShares).div(10000));
  }

  function _getDepositDenomination() private view returns (uint256) {
    if (numOfShares > 0) {
      return xrc20Token.balanceOf(address(this)).div(numOfShares).add(denominationRound - 1).div(denominationRound).mul(denominationRound);
    }
    return initDenomination + xrc20Token.balanceOf(address(this));
  }

  function getWithdrawDenomination() external view returns (uint256) {
    return _getWithdrawDenomination();
  }

  function _getWithdrawDenomination() private view returns (uint256) {
    if (numOfShares > 0) {
      return xrc20Token.balanceOf(address(this)).div(numOfShares).div(denominationRound).mul(denominationRound);
    }
    return initDenomination + xrc20Token.balanceOf(address(this));
  }

  function _cycPerDenomination(uint256 denomination) internal view returns (uint256) {
    uint256 cycPrice;
    if (
      address(xrc20Exchange).balance != 0 &&
      address(mimoExchange).balance != 0 &&
      xrc20Token.balanceOf(address(xrc20Exchange)) != 0 &&
      cycToken.balanceOf(address(mimoExchange)) != 0
    ) {
      cycPrice = oneCYC.mul(address(xrc20Exchange).balance)
        .mul(cycToken.balanceOf(address(mimoExchange)))
        .div(xrc20Token.balanceOf(address(xrc20Exchange)))
        .div(address(mimoExchange).balance);
    }
    if (cycPrice < minCYCPrice) {
      cycPrice = minCYCPrice;
    }
    if (cycPrice == 0) {
      return 0;
    }
    return denomination.mul(oneCYC).div(cycPrice);
  }

  function _processDeposit(uint256 _minCashbackAmount) internal returns (uint256) {
    require(msg.value == 0, "Coin value is supposed to be 0 for ERC20 instance");
    uint256 denomination = _getDepositDenomination();
    _safeXRC20TransferFrom(msg.sender, address(this), denomination);
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
    require(msg.value == _refund, "Incorrect refund amount received by the contract");
    uint256 denomination = _getWithdrawDenomination();
    uint256 xrc20ToSell = denomination.mul(withdrawLpIR).add(_weightedAmount(denomination.mul(buybackRate), numOfShares.sub(1))).div(10000);
    if (xrc20ToSell != 0) {
      require(xrc20Token.approve(address(xrc20Exchange), xrc20ToSell), "failed to approve xrc20 token to xrc20 exchanges");
      // ERC20(sell) => iotx(buy) => iotx(sell)=> CYC token(buy)
      uint256 iotxToBuy = xrc20Exchange.getTokenToIotxInputPrice(xrc20ToSell);
      uint256 cycBought = xrc20Exchange.tokenToTokenSwapInput(
        xrc20ToSell,
        mimoExchange.getIotxToTokenInputPrice(iotxToBuy),
        iotxToBuy,
        block.timestamp.mul(2),
        address(cycToken)
      );
      uint256 lpIncentive = cycBought.mul(withdrawLpIR).div(withdrawLpIR.add(buybackRate));
      aeolus.addReward(lpIncentive);
      require(cycToken.burn(cycBought.sub(lpIncentive)), "burn failure");
    }
    _safeXRC20Transfer(_recipient, denomination.mul(10000 - apIncentiveRate).div(10000).sub(xrc20ToSell).sub(_fee));
    if (_fee > 0) {
      _safeXRC20Transfer(_relayer, _fee);
    }

    if (_refund > 0) {
      (bool success, ) = _recipient.call.value(_refund)("");
      if (!success) {
        // let's return _refund back to the relayer
        _relayer.transfer(_refund);
      }
    }

    return (denomination, xrc20ToSell);
  }

  function _safeXRC20TransferFrom(address _from, address _to, uint256 _amount) internal {
    // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')))
    (bool success, bytes memory data) = address(xrc20Token).call(abi.encodeWithSelector(0x23b872dd, _from, _to, _amount));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "failed to call transferFrom");
  }

  function _safeXRC20Transfer(address _to, uint256 _amount) internal {
    // bytes4(keccak256(bytes('transfer(address,uint256)')))
    (bool success, bytes memory data) = address(xrc20Token).call(abi.encodeWithSelector(0xa9059cbb, _to, _amount));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "failed to call transfer");
  }
}
