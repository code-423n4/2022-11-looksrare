// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC1155} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1155.sol";
import {LooksRareProxy} from "../../contracts/proxies/LooksRareProxy.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {BasicOrder, TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";
import {LooksRareProxyTestHelpers} from "./LooksRareProxyTestHelpers.sol";

/**
 * @notice LooksRareProxy ERC1155 tests
 */
contract LooksRareProxyERC1155Test is TestParameters, TestHelpers, LooksRareProxyTestHelpers {
    LooksRareAggregator private aggregator;
    LooksRareProxy private looksRareProxy;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL, 15_877_290);

        aggregator = new LooksRareAggregator();
        looksRareProxy = new LooksRareProxy(LOOKSRARE_V1, address(aggregator));
        aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);

        vm.deal(_buyer, 1 ether);

        // Forking from mainnet and the deployed addresses might have balance
        vm.deal(address(aggregator), 0);
        vm.deal(address(looksRareProxy), 0);
    }

    function testExecuteAtomic() public asPrankedUser(_buyer) {
        _testExecute(true);
    }

    function testExecuteNonAtomic() public asPrankedUser(_buyer) {
        _testExecute(false);
    }

    function _testExecute(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        aggregator.execute{value: tradeData[0].orders[0].price}(tokenTransfers, tradeData, _buyer, _buyer, isAtomic);

        assertEq(IERC1155(0x5150B29a431eCe5eB0e62085535b8aaC8df193bE).balanceOf(_buyer, 1), 1);
        assertEq(_buyer.balance, 0.99 ether);
    }

    function _generateTradeData() private view returns (ILooksRareAggregator.TradeData[] memory tradeData) {
        BasicOrder[] memory orders = new BasicOrder[](1);
        orders[0] = validSlicesOrder();

        bytes[] memory ordersExtraData = new bytes[](1);
        ordersExtraData[0] = abi.encode(orders[0].price, 9800, 13678, LOOKSRARE_STRATEGY_FIXED_PRICE_V1B);

        tradeData = new ILooksRareAggregator.TradeData[](1);
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(looksRareProxy),
            selector: LooksRareProxy.execute.selector,
            value: orders[0].price,
            maxFeeBp: 0,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: ""
        });
    }
}
