pragma solidity 0.5.17;

contract IVerifier {
  function verifyProof(bytes memory _proof, uint256[6] memory _input) public returns(bool);
}