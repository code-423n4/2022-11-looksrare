// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGemSwap {
    struct TradeDetails {
        uint256 marketId;
        uint256 value;
        bytes tradeData;
    }

    function batchBuyWithETH(TradeDetails[] memory tradeDetails) external payable;
}
