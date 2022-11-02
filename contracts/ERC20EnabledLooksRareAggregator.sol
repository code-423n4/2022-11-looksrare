// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LowLevelERC20Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC20Transfer.sol";
import {IERC20EnabledLooksRareAggregator} from "./interfaces/IERC20EnabledLooksRareAggregator.sol";
import {ILooksRareAggregator} from "./interfaces/ILooksRareAggregator.sol";
import {TokenTransfer} from "./libraries/OrderStructs.sol";

/**
 * @title ERC20EnabledLooksRareAggregator
 * @notice This contract allows NFT sweepers to buy NFTs from different marketplaces using ERC20 tokens
 *         by passing high-level structs + low-level bytes as calldata.
 * @author LooksRare protocol team (👀,💎)
 */
contract ERC20EnabledLooksRareAggregator is IERC20EnabledLooksRareAggregator, LowLevelERC20Transfer {
    ILooksRareAggregator public immutable aggregator;

    /**
     * @param _aggregator LooksRareAggregator's address
     */
    constructor(address _aggregator) {
        aggregator = ILooksRareAggregator(_aggregator);
    }

    /**
     * @inheritdoc IERC20EnabledLooksRareAggregator
     */
    function execute(
        TokenTransfer[] calldata tokenTransfers,
        ILooksRareAggregator.TradeData[] calldata tradeData,
        address recipient,
        bool isAtomic
    ) external payable {
        if (tokenTransfers.length == 0) revert UseLooksRareAggregatorDirectly();
        _pullERC20Tokens(tokenTransfers, msg.sender);
        aggregator.execute{value: msg.value}(tokenTransfers, tradeData, msg.sender, recipient, isAtomic);
    }

    function _pullERC20Tokens(TokenTransfer[] calldata tokenTransfers, address source) private {
        uint256 tokenTransfersLength = tokenTransfers.length;
        for (uint256 i; i < tokenTransfersLength; ) {
            _executeERC20TransferFrom(
                tokenTransfers[i].currency,
                source,
                address(aggregator),
                tokenTransfers[i].amount
            );
            unchecked {
                ++i;
            }
        }
    }
}
