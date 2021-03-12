pragma solidity <0.6 >=0.4.24;

import "../ICycloneV2.sol";
import "../math/SafeMath.sol";
import "../token/IERC20.sol";
import "./IRouter.sol";

contract UniswapV2CycloneRouter {
  using SafeMath for uint256;
  IRouter public router;
  address public wrappedCoin;

  constructor(IRouter _router, address _wrappedCoin) public {
    router = _router;
    wrappedCoin = _wrappedCoin;
  }

  function () external payable {}

  function purchaseCost(ICycloneV2 _cyclone) external view returns (uint256) {
    address[] memory paths = new address[](2);
    paths[0] = wrappedCoin;
    paths[1] = address(_cyclone.cycToken());
    uint256[] memory amounts = router.getAmountsIn(_cyclone.cycDenomination(), paths);
    return amounts[0];
  }

  function deposit(ICycloneV2 _cyclone, bytes32 _commitment, bool _buyCYC) external payable {
    uint256 coinAmount = _cyclone.coinDenomination();
    uint256 tokenAmount = _cyclone.tokenDenomination();
    uint256 cycAmount = _cyclone.cycDenomination();
    IERC20 token = _cyclone.token();
    IERC20 cycToken = _cyclone.cycToken();
    require(msg.value >= coinAmount, "UniswapV2CycloneRouter: insufficient coin amount");
    uint256 remainingCoin = msg.value - coinAmount;
    require(token.transferFrom(msg.sender, address(this), tokenAmount), "UniswapV2CycloneRouter: failed to transfer token");
    if (cycAmount > 0) {
      if (_buyCYC) {
        address[] memory path = new address[](2);
        path[0] = wrappedCoin;
        path[1] = address(cycToken);
        uint256[] memory amounts = router.swapETHForExactTokens.value(remainingCoin)(cycAmount, path, address(this), block.timestamp.mul(2));
        require(remainingCoin >= amounts[0], "UniswapV2CycloneRouter: unexpected status");
        remainingCoin -= amounts[0];
      } else {
        require(cycToken.transferFrom(msg.sender, address(this), cycAmount), "UniswapV2CycloneRouter: failed to transfer CYC token");
      }
      require(cycToken.approve(address(_cyclone), cycAmount), "UniswapV2CycloneRouter: failed to approve CYC token allowance");
    }
    if (tokenAmount > 0) {
      require(token.approve(address(_cyclone), tokenAmount), "UniswapV2CycloneRouter: failed to approve allowance");
    }
    _cyclone.deposit.value(coinAmount)(_commitment);
    if (remainingCoin > 0) {
        (bool success,) = msg.sender.call.value(remainingCoin)("");
        require(success, 'UniswapV2CycloneRouter: failed to refund');
    }
  }
}