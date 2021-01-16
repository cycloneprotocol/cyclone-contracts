pragma solidity <6.0 >=0.4.0;

import "../Cyclone.sol";


contract TestCycloneDelegate {
    Cyclone public cyclone; 
    constructor(Cyclone _cyclone) public {
        cyclone = _cyclone;
    }

    function deposit(bytes32 _commitment) public payable {
        cyclone.deposit(_commitment, 0);
    }

    function withdraw(bytes memory _proof, bytes32 _root, bytes32 _nullifierHash, address payable _recipient, address payable _relayer, uint256 _fee, uint256 _refund) public payable  {
        cyclone.withdraw(_proof, _root, _nullifierHash, _recipient, _relayer, _fee, _refund);
    }
}