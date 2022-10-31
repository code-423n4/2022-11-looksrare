// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BasicOrder} from "../libraries/OrderStructs.sol";

interface IProxy {
    error InvalidCaller();
    error InvalidOrderLength();
    error ZeroAddress();

    /**
     * @notice Execute NFT sweeps in a single transaction
     * @param orders Orders to be executed
     * @param ordersExtraData Extra data for each order
     * @param extraData Extra data for the whole transaction
     * @param recipient The address to receive the purchased NFTs
     * @param isAtomic Flag to enable atomic trades (all or nothing) or partial trades
     * @param feeBp Fee basis point to pay for the trade, set by the aggregator
     * @param feeRecipient Fee recipient for the trade, set by the aggregator
     */
    function execute(
        BasicOrder[] calldata orders,
        bytes[] calldata ordersExtraData,
        bytes calldata extraData,
        address recipient,
        bool isAtomic,
        uint256 feeBp,
        address feeRecipient
    ) external payable;
}
