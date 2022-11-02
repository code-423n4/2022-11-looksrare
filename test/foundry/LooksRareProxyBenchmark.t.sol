// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ILooksRareExchange} from "@looksrare/contracts-exchange-v1/contracts/interfaces/ILooksRareExchange.sol";
import {OrderTypes} from "@looksrare/contracts-exchange-v1/contracts/libraries/OrderTypes.sol";
import {IERC721} from "../../contracts/interfaces/IERC721.sol";
import {LooksRareProxy} from "../../contracts/proxies/LooksRareProxy.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {V0Aggregator} from "../../contracts/prototype/V0Aggregator.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {IProxy} from "../../contracts/interfaces/IProxy.sol";
import {BasicOrder, TokenTransfer, FeeData} from "../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";
import {LooksRareProxyTestHelpers} from "./LooksRareProxyTestHelpers.sol";

/**
 * @notice LooksRareProxy benchmark (1. direct 2. through the prototype aggregator 3. through the actual aggregator)
 */
contract LooksRareProxyBenchmarkTest is TestParameters, TestHelpers, LooksRareProxyTestHelpers {
    V0Aggregator private v0Aggregator;
    LooksRareAggregator private aggregator;
    LooksRareProxy private looksRareProxy;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 15_282_897);
        vm.deal(_buyer, 200 ether);
    }

    function testExecuteDirectlySingleOrder() public asPrankedUser(_buyer) {
        ILooksRareExchange looksRare = ILooksRareExchange(LOOKSRARE_V1);

        OrderTypes.MakerOrder memory makerAsk;
        {
            makerAsk.isOrderAsk = true;
            makerAsk.signer = 0x2137213d50207Edfd92bCf4CF7eF9E491A155357;
            makerAsk.collection = BAYC;
            makerAsk.tokenId = 7139;
            makerAsk.price = 81.8 ether;
            makerAsk.amount = 1;
            makerAsk.strategy = LOOKSRARE_STRATEGY_FIXED_PRICE;
            makerAsk.nonce = 0;
            makerAsk.minPercentageToAsk = 9550;
            makerAsk.currency = WETH;
            makerAsk.startTime = 1659632508;
            makerAsk.endTime = 1662186976;

            makerAsk.v = 28;
            makerAsk.r = 0xe669f75ee8768c3dc4a7ac11f2d301f9dbfced5c1f3c13c7f445ad84d326db4b;
            makerAsk.s = 0x0f2da0827bac814c4ed782b661ef40dcb2fa71141ef8239a5e5f1038e117549c;
        }

        OrderTypes.TakerOrder memory takerBid;
        {
            takerBid.isOrderAsk = false;
            takerBid.taker = _buyer;
            takerBid.price = 81.8 ether;
            takerBid.tokenId = 7139;
            takerBid.minPercentageToAsk = 9550;
        }

        uint256 gasRemaining = gasleft();
        looksRare.matchAskWithTakerBidUsingETHAndWETH{value: 81.8 ether}(takerBid, makerAsk);
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("LooksRare single NFT purchase through the proxy consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(7139), _buyer);
    }

    function testExecuteThroughAggregatorSingleOrder() public asPrankedUser(_buyer) {
        _aggregatorSetUp();

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);
        BasicOrder[] memory validOrders = validBAYCOrders();
        BasicOrder[] memory orders = new BasicOrder[](1);
        orders[0] = validOrders[0];

        bytes[] memory ordersExtraData = new bytes[](1);
        ordersExtraData[0] = abi.encode(orders[0].price, 9550, 0, LOOKSRARE_STRATEGY_FIXED_PRICE);

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(looksRareProxy),
            selector: LooksRareProxy.execute.selector,
            value: orders[0].price,
            maxFeeBp: 0,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: ""
        });

        uint256 gasRemaining = gasleft();
        aggregator.execute{value: orders[0].price}(tokenTransfers, tradeData, _buyer, _buyer, false);
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("LooksRare single NFT purchase through the aggregator consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(7139), _buyer);
    }

    function testExecuteThroughV0AggregatorSingleOrder() public asPrankedUser(_buyer) {
        _v0AggregatorSetUp();

        BasicOrder[] memory validOrders = validBAYCOrders();
        BasicOrder[] memory orders = new BasicOrder[](1);
        orders[0] = validOrders[0];

        bytes[] memory ordersExtraData = new bytes[](1);
        ordersExtraData[0] = abi.encode(orders[0].price, 9550, 0, LOOKSRARE_STRATEGY_FIXED_PRICE);

        bytes memory data = abi.encodeWithSelector(
            LooksRareProxy.execute.selector,
            orders,
            ordersExtraData,
            "",
            _buyer,
            true
        );

        V0Aggregator.TradeData[] memory tradeData = new V0Aggregator.TradeData[](1);
        tradeData[0] = V0Aggregator.TradeData({proxy: address(looksRareProxy), data: data, value: orders[0].price});

        uint256 gasRemaining = gasleft();
        v0Aggregator.execute{value: orders[0].price}(tradeData);
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("LooksRare single NFT purchase through the V0 aggregator consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(7139), _buyer);
    }

    function testExecuteThroughAggregatorTwoOrdersAtomic() public asPrankedUser(_buyer) {
        _testExecuteThroughAggregatorTwoOrders(true);
    }

    function testExecuteThroughAggregatorTwoOrdersNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteThroughAggregatorTwoOrders(false);
    }

    function testExecuteThroughV0AggregatorTwoOrders() public asPrankedUser(_buyer) {
        _v0AggregatorSetUp();

        BasicOrder[] memory orders = validBAYCOrders();

        bytes[] memory ordersExtraData = new bytes[](2);
        ordersExtraData[0] = abi.encode(orders[0].price, 9550, 0, LOOKSRARE_STRATEGY_FIXED_PRICE);
        ordersExtraData[1] = abi.encode(orders[1].price, 8500, 50, LOOKSRARE_STRATEGY_FIXED_PRICE);

        bytes memory data = abi.encodeWithSelector(
            LooksRareProxy.execute.selector,
            orders,
            ordersExtraData,
            "",
            _buyer,
            true
        );

        uint256 totalPrice = orders[0].price + orders[1].price;

        V0Aggregator.TradeData[] memory tradeData = new V0Aggregator.TradeData[](1);
        tradeData[0] = V0Aggregator.TradeData({proxy: address(looksRareProxy), data: data, value: totalPrice});

        uint256 gasRemaining = gasleft();
        v0Aggregator.execute{value: totalPrice}(tradeData);
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("LooksRare multiple NFT purchase through the V0 aggregator consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(7139), _buyer);
        assertEq(IERC721(BAYC).ownerOf(3939), _buyer);
    }

    function _aggregatorSetUp() private {
        aggregator = new LooksRareAggregator();
        looksRareProxy = new LooksRareProxy(LOOKSRARE_V1, address(aggregator));

        // Since we are forking mainnet, we have to make sure it has 0 ETH.
        vm.deal(address(looksRareProxy), 0);

        aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
    }

    function _v0AggregatorSetUp() private {
        v0Aggregator = new V0Aggregator();
        looksRareProxy = new LooksRareProxy(LOOKSRARE_V1, address(v0Aggregator));

        // Since we are forking mainnet, we have to make sure it has 0 ETH.
        vm.deal(address(looksRareProxy), 0);

        v0Aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
    }

    function _testExecuteThroughAggregatorTwoOrders(bool isAtomic) private {
        _aggregatorSetUp();

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);
        BasicOrder[] memory orders = validBAYCOrders();

        bytes[] memory ordersExtraData = new bytes[](2);
        ordersExtraData[0] = abi.encode(orders[0].price, 9550, 0, LOOKSRARE_STRATEGY_FIXED_PRICE);
        ordersExtraData[1] = abi.encode(orders[1].price, 8500, 50, LOOKSRARE_STRATEGY_FIXED_PRICE);

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        uint256 value = orders[0].price + orders[1].price;
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(looksRareProxy),
            selector: LooksRareProxy.execute.selector,
            value: value,
            maxFeeBp: 0,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: ""
        });

        uint256 gasRemaining = gasleft();
        aggregator.execute{value: value}(tokenTransfers, tradeData, _buyer, _buyer, isAtomic);
        uint256 gasConsumed = gasRemaining - gasleft();
        if (isAtomic) {
            emit log_named_uint(
                "(Atomic) LooksRare multiple NFT purchase through the aggregator consumed: ",
                gasConsumed
            );
        } else {
            emit log_named_uint(
                "(Non-atomic) LooksRare multiple NFT purchase through the aggregator consumed: ",
                gasConsumed
            );
        }

        assertEq(IERC721(BAYC).ownerOf(7139), _buyer);
        assertEq(IERC721(BAYC).ownerOf(3939), _buyer);
        assertEq(address(_buyer).balance, 200 ether - value);
    }
}
