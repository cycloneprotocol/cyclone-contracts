pragma solidity >=0.5.0 <0.8.0;

import "../math/SafeMath.sol";
import "../token/IMintableToken.sol";
import "../uniswapv2/IRouter.sol";

contract MockUniswapV2Router is IRouter {
    using SafeMath for uint256;

    uint256[] public amountsIn;
    IMintableToken public lpToken;
    constructor(address _lpToken) public {
        lpToken = IMintableToken(_lpToken);
    }

    function setAmountsIn(uint256[] memory _amounts) public {
        require(_amounts.length == 2);
        amountsIn = _amounts;
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256
    ) external returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "liquidity cannot be zero");
        require(amountsIn[0] >= amountAMin && amountsIn[1] >= amountBMin, "invalid amounts");
        require(lpToken.transferFrom(msg.sender, address(this), liquidity), "failed to transfer lp token");
        require(lpToken.burn(liquidity), "failed to burn lp token");
        require(IMintableToken(tokenA).mint(to, amountsIn[0]), "failed to mint tokenA");
        require(IMintableToken(tokenB).mint(to, amountsIn[1]), "failed to mint tokenB");
        return (amountsIn[0], amountsIn[1]);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountsIn[1].mul(amountIn).div(amountsIn[0]);
        require(amounts[1] >= amountOutMin, "invalid amount out");
        require(path.length == 2, "invalid path length");
        IMintableToken token0 = IMintableToken(path[0]);
        IMintableToken token1 = IMintableToken(path[1]);
        require(token0.transferFrom(msg.sender, address(this), amounts[0]), "failed to transfer token");
        require(token0.burn(amounts[0]), "failed to burn token");
        require(token1.mint(to, amounts[1]), "failed to mint token");
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256
    ) external payable returns (uint[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountsIn[0].mul(amountOut).div(amountsIn[1]);
        amounts[1] = amountOut;
        require(msg.value >= amounts[0], "invalid amount in");
        require(path.length == 2, "invalid path length");
        IMintableToken token1 = IMintableToken(path[1]);
        require(token1.mint(to, amounts[1]), "failed to mint token");
        if (msg.value - amounts[0] > 0) {
            (bool success,) = msg.sender.call.value(msg.value - amounts[0])("");
            require(success, 'failed to return change');
        }
    }

    function getAmountsIn(uint256, address[] calldata) external view returns (uint256[] memory amounts) {
        return amountsIn;
    }
}