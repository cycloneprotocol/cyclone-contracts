pragma solidity ^0.5.0;

interface IMimoFactory {
    event NewExchange(address indexed token, address indexed exchange);

    function createExchange(address token) external returns (address payable);

    function getExchange(address token) external view returns (address payable);

    function getToken(address token) external view returns (address);

    function getTokenWihId(uint256 token_id) external view returns (address);
}
