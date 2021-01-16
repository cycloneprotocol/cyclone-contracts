pragma solidity 0.5.17;

import "./math/SafeMath.sol";
import "./mimo/IMimoFactory.sol";
import "./mimo/IMimoExchange.sol";
import "./token/IMintableToken.sol";
import "./utils/Address.sol";
import "./zksnarklib/MerkleTreeWithHistory.sol";
import "./zksnarklib/IVerifier.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract IAeolus {
  function addReward(uint256 amount) external;
}

contract Cyclone is MerkleTreeWithHistory, ReentrancyGuard {

  using SafeMath for uint256;

  uint256 public initDenomination; // (10K or 100k or 1M) * 10^18
  uint256 public denominationRound;
  mapping(bytes32 => bool) public nullifierHashes;
  mapping(bytes32 => bool) public commitments; // we store all commitments just to prevent accidental deposits with the same commitment
  IVerifier public verifier;
  IMintableToken public cycToken;
  IMimoExchange public mimoExchange;
  IAeolus public aeolus;        // liquidity mining pool
  address public govDAO;
  uint256 public oneCYC;        // 10 ** cycToken.decimals
  uint256 public numOfShares;
  uint256 public maxNumOfShares;  // 0 stands for unlimited
  uint256 public depositLpIR; // when deposit, a small portion minted CYC is given to the liquidity mining pool
  uint256 public withdrawLpIR; // when withdraw, a small portion of bought CYC is donated to the liquidity mining pool
  uint256 public cashbackRate;  // when deposit, a portion of minted CYC is given to the depositor
  uint256 public buybackRate;  // when withdraw, a portion of bought CYC will be burnt
  uint256 public minCYCPrice; // max amount of CYC minted to the depositor
  uint256 public apIncentiveRate;    // when withdraw, a certain portion is donated to the pool

  modifier onlyGovDAO {
    // Start with an governance DAO address and will transfer to a governance DAO, e.g., Timelock + GovernorAlpha, after launch
    require(msg.sender == govDAO, "Only Governance DAO can call this function.");
    _;
  }

  modifier notContract {
    require(msg.sender == tx.origin && !Address.isContract(msg.sender), "Caller cannot be a contract");
    _;
  }

  event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp, uint256 denomination);
  event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 denomination, uint256 cost, uint256 fee);
  event ConfigUpdated(uint256 depositLpIR, uint256 cashbackRate, uint256 withdrawLpIR, uint256 buybackRate, uint256 apIncentiveRate, uint256 minCYCPrice, uint256 maxNumOfShares);

  /**
    @dev The constructor
    @param _verifier the address of SNARK verifier for this contract
    @param _initDenomination transfer amount for each deposit
    @param _merkleTreeHeight the height of deposits' Merkle Tree
    @param _govDAO governance DAO address
  */
  constructor(
    IVerifier _verifier,
    IMintableToken _cyctoken,
    IMimoFactory _mimoFactory,
    IAeolus _aeolus,
    uint256 _initDenomination,
    uint256 _denominationRound,
    uint32 _merkleTreeHeight,
    address _govDAO
  ) MerkleTreeWithHistory(_merkleTreeHeight) public {
    require(_initDenomination > 0, "initial denomination should be greater than 0");
    require(_denominationRound > 0, "invalid denomination round");
    verifier = _verifier;
    cycToken = _cyctoken;
    govDAO = _govDAO;
    aeolus = _aeolus;
    oneCYC = 10 ** 18;
    initDenomination = _initDenomination;
    denominationRound = _denominationRound;
    mimoExchange = IMimoExchange(_mimoFactory.getExchange(address(_cyctoken)));
    numOfShares = 0;
    maxNumOfShares = 0;
  }

  function getDepositParameters() external view returns (uint256, uint256);

  function getWithdrawDenomination() external view returns (uint256);

  /**
    @dev Deposit funds into the contract. The caller must send (for Coin) or approve (for ERC20) value equal to or `denomination` of this instance.
    @param _commitment the note commitment, which is PedersenHash(nullifier + secret)
    @param _minCashbackAmount is the minimum cashback CYCs
  */
  function deposit(bytes32 _commitment, uint256 _minCashbackAmount) external payable nonReentrant notContract {
    require(!commitments[_commitment], "The commitment has been submitted");
    require(maxNumOfShares == 0 || numOfShares < maxNumOfShares, "hit share limit");
    uint32 insertedIndex = _insert(_commitment);
    commitments[_commitment] = true;
    uint256 denomination = _processDeposit(_minCashbackAmount);
    numOfShares += 1;
    emit Deposit(_commitment, insertedIndex, block.timestamp, denomination);
  }

  /** @dev this function is defined in a child contract */
  function _processDeposit(uint256 _minCashbackAmount) internal returns (uint256);

  function _weightedAmount(uint256 _amount, uint256 _num) public view returns (uint256) {
    // if maxNumOfShares is 0, return _amount
    if (maxNumOfShares == 0) {
      return _amount;
    }
    if (_num.mul(4) < maxNumOfShares) {
      return _amount.mul(maxNumOfShares.sub(_num.mul(2))).div(maxNumOfShares);
    }
    if (_num.mul(2) < maxNumOfShares) {
      return _amount.mul(maxNumOfShares.mul(3).sub(_num.mul(4))).div(maxNumOfShares).div(4);
    }

    return _amount.mul(maxNumOfShares.sub(_num)).div(maxNumOfShares).div(2);
  }

  /**
    @dev Withdraw a deposit from the contract. `proof` is a zkSNARK proof data, and input is an array of circuit public inputs
    `input` array consists of:
      - merkle root of all deposits in the contract
      - hash of unique deposit nullifier to prevent double spends
      - the recipient of funds
      - optional fee that goes to the transaction sender (usually a relay)
  */
  function withdraw(bytes calldata _proof, bytes32 _root, bytes32 _nullifierHash, address payable _recipient, address payable _relayer, uint256 _fee, uint256 _refund) external payable nonReentrant notContract {
    require(!nullifierHashes[_nullifierHash], "The note has been already spent");
    require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one
    require(verifier.verifyProof(_proof, [uint256(_root), uint256(_nullifierHash), uint256(_recipient), uint256(_relayer), _fee, _refund]), "Invalid withdraw proof");

    nullifierHashes[_nullifierHash] = true;
    (uint256 denomination, uint256 cost) = _processWithdraw(_recipient, _relayer, _fee, _refund);
    numOfShares -= 1;
    emit Withdrawal(_recipient, _nullifierHash, _relayer, denomination, cost, _fee);
  }

  /** @dev this function is defined in a child contract */
  function _processWithdraw(address payable _recipient, address payable _relayer, uint256 _fee, uint256 _refund) internal returns (uint256, uint256);

  /** @dev whether a note is already spent */
  function isSpent(bytes32 _nullifierHash) public view returns(bool) {
    return nullifierHashes[_nullifierHash];
  }

  /** @dev whether an array of notes is already spent */
  function isSpentArray(bytes32[] calldata _nullifierHashes) external view returns(bool[] memory spent) {
    spent = new bool[](_nullifierHashes.length);
    for(uint i = 0; i < _nullifierHashes.length; i++) {
      if (isSpent(_nullifierHashes[i])) {
        spent[i] = true;
      }
    }
  }

  /**
    @dev allow governance DAO to update SNARK verification keys. This is needed to
    update keys if tornado.cash update their keys in production.
  */
  function updateVerifier(address _newVerifier) external onlyGovDAO {
    verifier = IVerifier(_newVerifier);
  }

  /** @dev governance DAO can change his address */
  function changeGovDAO(address _newGovDAO) external onlyGovDAO {
    govDAO = _newGovDAO;
  }

  /** @dev governance DAO can update config */
  function updateConfig(uint256 _depositLpIR, uint256 _cashbackRate, uint256 _withdrawLpIR, uint256 _buybackRate, uint256 _apIncentiveRate, uint256 _minCYCPrice, uint256 _maxNumOfShares) external onlyGovDAO {
    require(_depositLpIR + _cashbackRate <= 10000, "invalid deposit related rates");
    require(_withdrawLpIR + _buybackRate + _apIncentiveRate <= 10000, "invalid withdraw related rates");
    depositLpIR = _depositLpIR;
    cashbackRate = _cashbackRate;
    withdrawLpIR = _withdrawLpIR;
    buybackRate = _buybackRate;
    apIncentiveRate = _apIncentiveRate;
    minCYCPrice = _minCYCPrice;
    maxNumOfShares = _maxNumOfShares;
    emit ConfigUpdated(depositLpIR, cashbackRate, withdrawLpIR, buybackRate, apIncentiveRate, minCYCPrice, maxNumOfShares);
  }
}
