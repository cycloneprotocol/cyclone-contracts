pragma solidity ^0.5.0;

interface IMimoExchange {
    event TokenPurchase(
        address indexed buyer,
        uint256 indexed iotx_sold,
        uint256 indexed tokens_bought
    );
    event IotxPurchase(
        address indexed buyer,
        uint256 indexed tokens_sold,
        uint256 indexed iotx_bought
    );
    event AddLiquidity(
        address indexed provider,
        uint256 indexed iotx_amount,
        uint256 indexed token_amount
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed iotx_amount,
        uint256 indexed token_amount
    );

    /**
     * @notice Convert IOTX to Tokens.
     * @dev User specifies exact input (msg.value).
     * @dev User cannot specify minimum output or deadline.
     */
    function() external payable;

    /**
     * @dev Pricing function for converting between IOTX && Tokens.
     * @param input_amount Amount of IOTX or Tokens being sold.
     * @param input_reserve Amount of IOTX or Tokens (input type) in exchange reserves.
     * @param output_reserve Amount of IOTX or Tokens (output type) in exchange reserves.
     * @return Amount of IOTX or Tokens bought.
     */
    function getInputPrice(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) external view returns (uint256);

    /**
     * @dev Pricing function for converting between IOTX && Tokens.
     * @param output_amount Amount of IOTX or Tokens being bought.
     * @param input_reserve Amount of IOTX or Tokens (input type) in exchange reserves.
     * @param output_reserve Amount of IOTX or Tokens (output type) in exchange reserves.
     * @return Amount of IOTX or Tokens sold.
     */
    function getOutputPrice(
        uint256 output_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) external view returns (uint256);

    /**
     * @notice Convert IOTX to Tokens.
     * @dev User specifies exact input (msg.value) && minimum output.
     * @param min_tokens Minimum Tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of Tokens bought.
     */

    function iotxToTokenSwapInput(uint256 min_tokens, uint256 deadline)
        external
        payable
        returns (uint256);

    /**
     * @notice Convert IOTX to Tokens && transfers Tokens to recipient.
     * @dev User specifies exact input (msg.value) && minimum output
     * @param min_tokens Minimum Tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output Tokens.
     * @return  Amount of Tokens bought.
     */
    function iotxToTokenTransferInput(
        uint256 min_tokens,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256);

    /**
     * @notice Convert IOTX to Tokens.
     * @dev User specifies maximum input (msg.value) && exact output.
     * @param tokens_bought Amount of tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of IOTX sold.
     */
    function iotxToTokenSwapOutput(uint256 tokens_bought, uint256 deadline)
        external
        payable
        returns (uint256);

    /**
     * @notice Convert IOTX to Tokens && transfers Tokens to recipient.
     * @dev User specifies maximum input (msg.value) && exact output.
     * @param tokens_bought Amount of tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output Tokens.
     * @return Amount of IOTX sold.
     */
    function iotxToTokenTransferOutput(
        uint256 tokens_bought,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256);

    /**
     * @notice Convert Tokens to IOTX.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_iotx Minimum IOTX purchased.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of IOTX bought.
     */
    function tokenToIotxSwapInput(
        uint256 tokens_sold,
        uint256 min_iotx,
        uint256 deadline
    ) external returns (uint256);

    /**
     * @notice Convert Tokens to IOTX && transfers IOTX to recipient.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_iotx Minimum IOTX purchased.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output IOTX.
     * @return  Amount of IOTX bought.
     */
    function tokenToIotxTransferInput(
        uint256 tokens_sold,
        uint256 min_iotx,
        uint256 deadline,
        address recipient
    ) external returns (uint256);

    /**
     * @notice Convert Tokens to IOTX.
     * @dev User specifies maximum input && exact output.
     * @param iotx_bought Amount of IOTX purchased.
     * @param max_tokens Maximum Tokens sold.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of Tokens sold.
     */
    function tokenToIotxSwapOutput(
        uint256 iotx_bought,
        uint256 max_tokens,
        uint256 deadline
    ) external returns (uint256);

    /**
     * @notice Convert Tokens to IOTX && transfers IOTX to recipient.
     * @dev User specifies maximum input && exact output.
     * @param iotx_bought Amount of IOTX purchased.
     * @param max_tokens Maximum Tokens sold.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output IOTX.
     * @return Amount of Tokens sold.
     */
    function tokenToIotxTransferOutput(
        uint256 iotx_bought,
        uint256 max_tokens,
        uint256 deadline,
        address recipient
    ) external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (token_addr).
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
     * @param min_iotx_bought Minimum IOTX purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param token_addr The address of the token being purchased.
     * @return Amount of Tokens (token_addr) bought.
     */
    function tokenToTokenSwapInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_iotx_bought,
        uint256 deadline,
        address token_addr
    ) external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (token_addr) && transfers
     *         Tokens (token_addr) to recipient.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
     * @param min_iotx_bought Minimum IOTX purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output IOTX.
     * @param token_addr The address of the token being purchased.
     * @return Amount of Tokens (token_addr) bought.
     */
    function tokenToTokenTransferInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_iotx_bought,
        uint256 deadline,
        address recipient,
        address token_addr
    ) external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (token_addr).
     * @dev User specifies maximum input && exact output.
     * @param tokens_bought Amount of Tokens (token_addr) bought.
     * @param max_tokens_sold Maximum Tokens (token) sold.
     * @param max_iotx_sold Maximum IOTX purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param token_addr The address of the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
    function tokenToTokenSwapOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_iotx_sold,
        uint256 deadline,
        address token_addr
    ) external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (token_addr) && transfers
     *         Tokens (token_addr) to recipient.
     * @dev User specifies maximum input && exact output.
     * @param tokens_bought Amount of Tokens (token_addr) bought.
     * @param max_tokens_sold Maximum Tokens (token) sold.
     * @param max_iotx_sold Maximum IOTX purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output IOTX.
     * @param token_addr The address of the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
    function tokenToTokenTransferOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_iotx_sold,
        uint256 deadline,
        address recipient,
        address token_addr
    ) external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (exchange_addr.token).
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
     * @param min_iotx_bought Minimum IOTX purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param exchange_addr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (exchange_addr.token) bought.
     */
    function tokenToExchangeSwapInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_iotx_bought,
        uint256 deadline,
        address exchange_addr
    ) external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (exchange_addr.token) && transfers
     *         Tokens (exchange_addr.token) to recipient.
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies exact input && minimum output.
     * @param tokens_sold Amount of Tokens sold.
     * @param min_tokens_bought Minimum Tokens (token_addr) purchased.
     * @param min_iotx_bought Minimum IOTX purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output IOTX.
     * @param exchange_addr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (exchange_addr.token) bought.
     */
    function tokenToExchangeTransferInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_iotx_bought,
        uint256 deadline,
        address recipient,
        address exchange_addr
    ) external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (exchange_addr.token).
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies maximum input && exact output.
     * @param tokens_bought Amount of Tokens (token_addr) bought.
     * @param max_tokens_sold Maximum Tokens (token) sold.
     * @param max_iotx_sold Maximum IOTX purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param exchange_addr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
    function tokenToExchangeSwapOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_iotx_sold,
        uint256 deadline,
        address exchange_addr
    ) external returns (uint256);

    /**
     * @notice Convert Tokens (token) to Tokens (exchange_addr.token) && transfers
     *         Tokens (exchange_addr.token) to recipient.
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies maximum input && exact output.
     * @param tokens_bought Amount of Tokens (token_addr) bought.
     * @param max_tokens_sold Maximum Tokens (token) sold.
     * @param max_iotx_sold Maximum IOTX purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output IOTX.
     * @param exchange_addr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (token) sold.
     */
    function tokenToExchangeTransferOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_iotx_sold,
        uint256 deadline,
        address recipient,
        address exchange_addr
    ) external returns (uint256);

    /***********************************|
  |         Getter Functions          |
  |__________________________________*/

    /**
     * @notice external price function for IOTX to Token trades with an exact input.
     * @param iotx_sold Amount of IOTX sold.
     * @return Amount of Tokens that can be bought with input IOTX.
     */
    function getIotxToTokenInputPrice(uint256 iotx_sold)
        external
        view
        returns (uint256);

    /**
     * @notice external price function for IOTX to Token trades with an exact output.
     * @param tokens_bought Amount of Tokens bought.
     * @return Amount of IOTX needed to buy output Tokens.
     */
    function getIotxToTokenOutputPrice(uint256 tokens_bought)
        external
        view
        returns (uint256);

    /**
     * @notice external price function for Token to IOTX trades with an exact input.
     * @param tokens_sold Amount of Tokens sold.
     * @return Amount of IOTX that can be bought with input Tokens.
     */
    function getTokenToIotxInputPrice(uint256 tokens_sold)
        external
        view
        returns (uint256);

    /**
     * @notice external price function for Token to IOTX trades with an exact output.
     * @param iotx_bought Amount of output IOTX.
     * @return Amount of Tokens needed to buy output IOTX.
     */
    function getTokenToIotxOutputPrice(uint256 iotx_bought)
        external
        view
        returns (uint256);

    /**
     * @return Address of Token that is sold on this exchange.
     */
    function tokenAddress() external view returns (address);

    /**
     * @return Address of factory that created this exchange.
     */
    function factoryAddress() external view returns (address);

    /***********************************|
  |        Liquidity Functions        |
  |__________________________________*/

    /**
     * @notice Deposit IOTX && Tokens (token) at current ratio to mint MLP tokens.
     * @dev min_liquidity does nothing when total MLP supply is 0.
     * @param min_liquidity Minimum number of MLP sender will mint if total MLP supply is greater than 0.
     * @param max_tokens Maximum number of tokens deposited. Deposits max amount if total MLP supply is 0.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return The amount of MLP minted.
     */
    function addLiquidity(
        uint256 min_liquidity,
        uint256 max_tokens,
        uint256 deadline
    ) external payable returns (uint256);

    /**
     * @dev Burn MLP tokens to withdraw IOTX && Tokens at current ratio.
     * @param amount Amount of MLP burned.
     * @param min_iotx Minimum IOTX withdrawn.
     * @param min_tokens Minimum Tokens withdrawn.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return The amount of IOTX && Tokens withdrawn.
     */
    function removeLiquidity(
        uint256 amount,
        uint256 min_iotx,
        uint256 min_tokens,
        uint256 deadline
    ) external returns (uint256, uint256);
}
