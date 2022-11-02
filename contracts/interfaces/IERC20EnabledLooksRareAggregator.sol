// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TokenTransfer} from "../libraries/OrderStructs.sol";
import {ILooksRareAggregator} from "./ILooksRareAggregator.sol";

interface IERC20EnabledLooksRareAggregator {
    /**
     * @notice Execute NFT sweeps in different marketplaces in a single transaction
     * @param tokenTransfers Aggregated ERC20 token transfers for all markets
     * @param tradeData Data object to be passed downstream to each marketplace's proxy for execution
     * @param recipient The address to receive the purchased NFTs
     * @param isAtomic Flag to enable atomic trades (all or nothing) or partial trades
     */
    function execute(
        TokenTransfer[] calldata tokenTransfers,
        ILooksRareAggregator.TradeData[] calldata tradeData,
        address recipient,
        bool isAtomic
    ) external payable;

    error UseLooksRareAggregatorDirectly();
}
