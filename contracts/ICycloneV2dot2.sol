pragma solidity <0.6 >=0.4.24;

import "./token/IERC20.sol";

interface ICycloneV2dot2 {

  function coinDenomination() external view returns (uint256);
  function tokenDenomination() external view returns (uint256);
  function cycDenomination() external view returns (uint256);
  function token() external view returns (IERC20);
  function cycToken() external view returns (IERC20);
  function deposit(bytes32 _commitment) external payable;
  function withdraw(bytes calldata _proof, bytes32 _root, bytes32 _nullifierHash, address payable _recipient, address payable _relayer, uint256 _fee, uint256 _refund) external payable;
  function anonymityFee() external view returns (uint256);
}
