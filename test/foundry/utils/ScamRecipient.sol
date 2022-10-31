// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ILooksRareAggregator} from "../../../contracts/interfaces/ILooksRareAggregator.sol";
import {SeaportProxy} from "../../../contracts/proxies/SeaportProxy.sol";
import {BasicOrder, TokenTransfer} from "../../../contracts/libraries/OrderStructs.sol";
import {SeaportProxyTestHelpers} from "../SeaportProxyTestHelpers.sol";

contract ScamRecipient is SeaportProxyTestHelpers {
    address private constant SCAM_BENEFICIARY = address(69420);

    ILooksRareAggregator private immutable aggregator;
    address private immutable seaportProxy;

    constructor(address _aggregator, address _seaportProxy) {
        aggregator = ILooksRareAggregator(_aggregator);
        seaportProxy = _seaportProxy;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);
        BasicOrder[] memory orders = validCityDaoOrders();
        bytes[] memory ordersExtraData = validCityDaoOrdersExtraData();
        bytes memory extraData = new bytes(0);

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: orders[0].price + orders[1].price,
            maxFeeBp: 0,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: extraData
        });

        aggregator.execute(tokenTransfers, tradeData, address(this), SCAM_BENEFICIARY, false);

        return this.onERC1155Received.selector;
    }

    receive() external payable {}
}
