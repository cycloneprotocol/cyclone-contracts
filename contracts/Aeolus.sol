pragma solidity <0.6 >=0.4.24;


import "./token/IERC20.sol";
import "./token/SafeERC20.sol";
import "./math/SafeMath.sol";
import "./ownership/Whitelist.sol";
import "./token/IMintableToken.sol";


// Aeolus is the master of Cyclone tokens. He can make CYC and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CYC is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract Aeolus is Whitelist {
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
    IERC20 lpToken;
    // Accumulated CYCs per share, times 1e12. See below.
    uint256 public accCYCPerShare;
    // Last block reward block height
    uint256 public lastRewardBlock;
    // Reward per block
    uint256 public rewardPerBlock;

    // The Cyclone TOKEN
    IMintableToken public cycToken;

    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;

    event RewardAdded(uint256 amount, bool isBlockReward);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(IMintableToken _cycToken, IERC20 _lpToken) public {
        cycToken = _cycToken;
        lastRewardBlock = block.number;
        lpToken = _lpToken;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        updateBlockReward();
        rewardPerBlock = _rewardPerBlock;
    }

    // View function to see pending reward on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        if (rewardPerBlock == 0) {
            return 0;
        }
        uint256 lpSupply = lpToken.balanceOf(address(this));
        if (block.number <= lastRewardBlock || lpSupply == 0) {
            return 0;
        }
        return user.amount.mul(
            accCYCPerShare.add(block.number.sub(lastRewardBlock).mul(rewardPerBlock).mul(1e12).div(lpSupply))
        ).div(1e12).sub(user.rewardDebt);
    }

    // Add reward variables to be up-to-date.
    function addReward(uint256 _amount) public onlyWhitelisted {
        uint256 lpSupply = lpToken.balanceOf(address(this));
        if (lpSupply == 0 || _amount == 0) {
            return;
        }
        require(cycToken.mint(address(this), _amount), "failed to mint");
        emit RewardAdded(_amount, false);
        accCYCPerShare = accCYCPerShare.add(_amount.mul(1e12).div(lpSupply));
    }

    // Update reward variables to be up-to-date.
    function updateBlockReward() public {
        if (block.number <= lastRewardBlock || rewardPerBlock == 0) {
            return;
        }
        uint256 lpSupply = lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 reward = block.number.sub(lastRewardBlock).mul(rewardPerBlock);
        require(cycToken.mint(address(this), reward), "failed to mint");
        emit RewardAdded(reward, true);
        lastRewardBlock = block.number;
        accCYCPerShare = accCYCPerShare.add(reward.mul(1e12).div(lpSupply));
    }

    // Deposit LP tokens to Aeolus for CYC allocation.
    function deposit(uint256 _amount) public {
        updateBlockReward();
        UserInfo storage user = userInfo[msg.sender];
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(accCYCPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safeCYCTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(accCYCPerShare).div(1e12);
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw LP tokens from Aeolus.
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updateBlockReward();
        uint256 pending = user.amount.mul(accCYCPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safeCYCTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(accCYCPerShare).div(1e12);
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
        uint256 cycBalance = cycToken.balanceOf(address(this));
        if (_amount > cycBalance) {
            require(cycToken.transfer(_to, cycBalance), "failed to transfer cyc token");
        } else {
            require(cycToken.transfer(_to, _amount), "failed to transfer cyc token");
        }
    }
}
