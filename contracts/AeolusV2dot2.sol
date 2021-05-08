pragma solidity <0.6 >=0.4.24;

import "./math/SafeMath.sol";
import "./ownership/Ownable.sol";
import "./token/IERC20.sol";
import "./token/IMintableToken.sol";
import "./token/SafeERC20.sol";
import "./uniswapv1/IExchange.sol";

// Aeolus is the master of Cyclone tokens. He can distribute CYC and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CYC is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract AeolusV2dot2 is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of CYCs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * accCYCPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. Update accCYCPerShare and lastRewardBlock
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }


    // Address of LP token contract.
    IERC20 public lpToken;
    // Accumulated CYCs per share, times 1e12. See below.
    uint256 public accCYCPerShare;
    // Last block reward block height
    uint256 public lastRewardBlock;
    // Reward per block
    uint256 public rewardPerBlock;
    // Reward to distribute
    uint256 public rewardToDistribute;
    // Entrance Fee Rate
    uint256 public entranceFeeRate;

    IExchange public exchange;
    // The Cyclone TOKEN
    IMintableToken public cycToken;

    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;

    event RewardAdded(uint256 amount, bool isBlockReward);
    event Deposit(address indexed user, uint256 amount, uint256 fee);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(IMintableToken _cycToken, address payable _exchange) public {
        cycToken = _cycToken;
        lastRewardBlock = block.number;
        lpToken = IERC20(_exchange);
        exchange = IExchange(_exchange);
    }

    function() external payable {
    }

    function setEntranceFeeRate(uint256 _entranceFeeRate) public onlyOwner {
        require(_entranceFeeRate < 10000, "invalid entrance fee rate");
        entranceFeeRate = _entranceFeeRate;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        updateBlockReward();
        rewardPerBlock = _rewardPerBlock;
    }

    function rewardPending() internal view returns (uint256) {
        uint256 reward = block.number.sub(lastRewardBlock).mul(rewardPerBlock);
        uint256 cycBalance = cycToken.balanceOf(address(this)).sub(rewardToDistribute);
        if (cycBalance < reward) {
            return cycBalance;
        }
        return reward;
    }

    // View function to see pending reward on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 acps = accCYCPerShare;
        if (rewardPerBlock > 0) {
            uint256 lpSupply = lpToken.balanceOf(address(this));
            if (block.number > lastRewardBlock && lpSupply > 0) {
                acps = acps.add(rewardPending().mul(1e12).div(lpSupply));
            }
        }

        return user.amount.mul(acps).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables to be up-to-date.
    function updateBlockReward() public {
        if (block.number <= lastRewardBlock || rewardPerBlock == 0) {
            return;
        }
        uint256 lpSupply = lpToken.balanceOf(address(this));
        uint256 reward = rewardPending();
        if (lpSupply == 0 || reward == 0) {
            lastRewardBlock = block.number;
            return;
        }
        rewardToDistribute = rewardToDistribute.add(reward);
        emit RewardAdded(reward, true);
        lastRewardBlock = block.number;
        accCYCPerShare = accCYCPerShare.add(reward.mul(1e12).div(lpSupply));
    }

    // Deposit LP tokens to Aeolus for CYC allocation.
    function deposit(uint256 _amount) public {
        updateBlockReward();
        UserInfo storage user = userInfo[msg.sender];
        uint256 originAmount = user.amount;
        uint256 acps = accCYCPerShare;
        if (originAmount > 0) {
            uint256 pending = originAmount.mul(acps).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeCYCTransfer(msg.sender, pending);
            }
        }
        uint256 feeInCYC = 0;
        if (_amount > 0) {
            lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            uint256 entranceFee = _amount.mul(entranceFeeRate).div(10000);
            if (entranceFee > 0) {
                (uint256 iotxAmount, uint256 cycAmount) = exchange.removeLiquidity(entranceFee, 1, 1, block.timestamp.mul(2));
                feeInCYC = cycAmount.add(exchange.iotxToTokenSwapInput.value(iotxAmount)(1, block.timestamp.mul(2)));
                require(cycToken.burn(feeInCYC), "failed to burn cyc token");
                _amount = _amount.sub(entranceFee);
            }
            user.amount = originAmount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(acps).div(1e12);
        emit Deposit(msg.sender, _amount, feeInCYC);
    }

    // Withdraw LP tokens from Aeolus.
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        uint256 originAmount = user.amount;
        require(originAmount >= _amount, "withdraw: not good");
        updateBlockReward();
        uint256 acps = accCYCPerShare;
        uint256 pending = originAmount.mul(acps).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeCYCTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = originAmount.sub(_amount);
            lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(acps).div(1e12);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    // Safe CYC transfer function, just in case if rounding error causes pool to not have enough CYCs.
    function safeCYCTransfer(address _to, uint256 _amount) internal {
        IMintableToken token = cycToken;
        uint256 cycBalance = token.balanceOf(address(this));
        if (_amount > cycBalance) {
            _amount = cycBalance;
        }
        rewardToDistribute = rewardToDistribute.sub(_amount);
        require(token.transfer(_to, _amount), "failed to transfer cyc token");
    }
}
