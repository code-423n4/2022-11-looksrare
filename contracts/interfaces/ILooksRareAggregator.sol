// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicOrder, TokenTransfer} from "../libraries/OrderStructs.sol";

interface ILooksRareAggregator {
    struct TradeData {
        address proxy; // The marketplace proxy's address
        bytes4 selector; // The marketplace proxy's function selector
        uint256 value; // The amount of ETH passed to the proxy during the function call
        uint256 maxFeeBp; // The maximum fee basis point the buyer is willing to pay
        BasicOrder[] orders; // Orders to be executed by the marketplace
        bytes[] ordersExtraData; // Extra data for each order, specific for each marketplace
        bytes extraData; // Extra data specific for each marketplace
    }

    /**
     * @notice Execute NFT sweeps in different marketplaces in a single transaction
     * @param tokenTransfers Aggregated ERC20 token transfers for all markets
     * @param tradeData Data object to be passed downstream to each marketplace's proxy for execution
     * @param originator The address that originated the transaction, hardcoded as msg.sender if it is called directly
     * @param recipient The address to receive the purchased NFTs
     * @param isAtomic Flag to enable atomic trades (all or nothing) or partial trades
     */
    function execute(
        TokenTransfer[] calldata tokenTransfers,
        TradeData[] calldata tradeData,
        address originator,
        address recipient,
        bool isAtomic
    ) external payable;

    /**
     * @dev Emitted when erc20EnabledLooksRareAggregator is set
     */
    event ERC20EnabledLooksRareAggregatorSet();

    /**
     * @dev Emitted when fee is updated
     * @param proxy Proxy to apply the fee to
     * @param bp Fee basis point
     * @param recipient Fee recipient
     */
    event FeeUpdated(address proxy, uint256 bp, address recipient);

    /**
     * @notice Emitted when a marketplace proxy's function is enabled.
     * @param proxy The marketplace proxy's address
     * @param selector The marketplace proxy's function selector
     */
    event FunctionAdded(address indexed proxy, bytes4 selector);

    /**
     * @notice Emitted when a marketplace proxy's function is disabled.
     * @param proxy The marketplace proxy's address
     * @param selector The marketplace proxy's function selector
     */
    event FunctionRemoved(address indexed proxy, bytes4 selector);

    /**
     * @notice Emitted when execute is complete
     * @param sweeper The address that submitted the transaction
     */
    event Sweep(address indexed sweeper);

    error AlreadySet();
    error FeeTooHigh();
    error InvalidFunction();
    error InvalidOrderLength();
    error TradeExecutionFailed();
    error UseERC20EnabledLooksRareAggregator();
    error ZeroAddress();
}
