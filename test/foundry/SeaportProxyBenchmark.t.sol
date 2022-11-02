// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721} from "../../contracts/interfaces/IERC721.sol";
import {SeaportProxy} from "../../contracts/proxies/SeaportProxy.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {V0Aggregator} from "../../contracts/prototype/V0Aggregator.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {SeaportInterface} from "../../contracts/interfaces/SeaportInterface.sol";
import {IProxy} from "../../contracts/interfaces/IProxy.sol";
import {BasicOrder, TokenTransfer, FeeData} from "../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";
import {SeaportProxyTestHelpers} from "./SeaportProxyTestHelpers.sol";
import {BasicOrderParameters, AdditionalRecipient, AdvancedOrder, OrderParameters, OfferItem, ConsiderationItem, CriteriaResolver} from "../../contracts/libraries/seaport/ConsiderationStructs.sol";
import {BasicOrderType, OrderType, ItemType} from "../../contracts/libraries/seaport/ConsiderationEnums.sol";

/**
 * @notice SeaportProxy benchmark (1. direct 2. through the prototype aggregator 3. through the actual aggregator)
 */
contract SeaportProxyBenchmarkTest is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    V0Aggregator private v0Aggregator;
    LooksRareAggregator private aggregator;
    SeaportProxy private seaportProxy;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 15_300_884);
        vm.deal(_buyer, 100 ether);
    }

    function testExecuteDirectlySingleOrder() public asPrankedUser(_buyer) {
        SeaportInterface seaport = SeaportInterface(SEAPORT);

        BasicOrderParameters memory parameters;
        parameters.considerationToken = address(0);
        parameters.considerationIdentifier = 0;
        parameters.considerationAmount = 79.8 ether;
        parameters.offerer = payable(0x7a277Cf6E2F3704425195caAe4148848c29Ff815);
        parameters.zone = 0x004C00500000aD104D7DBd00e3ae0A5C00560C00;
        parameters.offerToken = BAYC;
        parameters.offerIdentifier = 2518;
        parameters.offerAmount = 1;
        parameters.salt = 70769720963177607;
        parameters.offererConduitKey = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
        parameters.startTime = 1659797236;
        parameters.endTime = 1662475636;
        parameters.basicOrderType = BasicOrderType.ETH_TO_ERC721_FULL_RESTRICTED;
        parameters.totalOriginalAdditionalRecipients = 2;
        parameters
            .signature = hex"27deb8f1923b96693d8d5e1bf9304207e31b9cb49e588e8df5b3926b7547ba444afafe429fb2a17b4b97544d8383f3ad886fc15cab5a91382a56f9d65bb3dc231c";
        parameters.zoneHash = bytes32(0);
        parameters.fulfillerConduitKey = bytes32(0);
        AdditionalRecipient[] memory additionalRecipients = new AdditionalRecipient[](2);
        additionalRecipients[0].amount = 2.1 ether;
        additionalRecipients[0].recipient = payable(OPENSEA_FEES);
        additionalRecipients[1].amount = 2.1 ether;
        additionalRecipients[1].recipient = payable(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1);
        parameters.additionalRecipients = additionalRecipients;

        uint256 gasRemaining = gasleft();
        seaport.fulfillBasicOrder{value: 84 ether}(parameters);
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("Seaport single NFT purchase direct consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
    }

    function testExecuteThroughAggregatorSingleOrder() public {
        _aggregatorSetUp();

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);
        BasicOrder memory order = validBAYCId2518Order();
        BasicOrder[] memory orders = new BasicOrder[](1);
        orders[0] = order;

        bytes memory orderExtraData = validBAYCId2518OrderExtraData();
        bytes[] memory ordersExtraData = new bytes[](1);
        ordersExtraData[0] = orderExtraData;

        bytes memory extraData = validSingleBAYCExtraData();

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: order.price,
            maxFeeBp: 0,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: extraData
        });

        uint256 gasRemaining = gasleft();
        aggregator.execute{value: order.price}(tokenTransfers, tradeData, _buyer, _buyer, true);
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("Seaport single NFT purchase through the aggregator consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
    }

    function testExecuteThroughV0AggregatorSingleOrder() public {
        _v0AggregatorSetUp();

        BasicOrder memory order = validBAYCId2518Order();
        BasicOrder[] memory orders = new BasicOrder[](1);
        orders[0] = order;

        bytes memory orderExtraData = validBAYCId2518OrderExtraData();
        bytes[] memory ordersExtraData = new bytes[](1);
        ordersExtraData[0] = orderExtraData;

        bytes memory extraData = validSingleBAYCExtraData();

        FeeData memory feeData;

        bytes memory data = abi.encodeWithSelector(
            SeaportProxy.execute.selector,
            orders,
            ordersExtraData,
            extraData,
            _buyer,
            true,
            feeData
        );

        V0Aggregator.TradeData[] memory tradeData = new V0Aggregator.TradeData[](1);
        tradeData[0] = V0Aggregator.TradeData({proxy: address(seaportProxy), value: order.price, data: data});

        uint256 gasRemaining = gasleft();
        v0Aggregator.execute{value: order.price}(tradeData);
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("Seaport single NFT purchase through the V0 aggregator consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
    }

    function testExecuteDirectlyTwoOrders() public {
        SeaportInterface seaport = SeaportInterface(SEAPORT);

        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](2);

        OrderParameters memory parametersOne;
        parametersOne.offerer = 0x7a277Cf6E2F3704425195caAe4148848c29Ff815;
        parametersOne.zone = 0x004C00500000aD104D7DBd00e3ae0A5C00560C00;
        parametersOne.zoneHash = bytes32(0);
        parametersOne.salt = 70769720963177607;
        parametersOne.conduitKey = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
        parametersOne.orderType = OrderType.FULL_RESTRICTED;
        parametersOne.startTime = 1659797236;
        parametersOne.endTime = 1662475636;
        parametersOne.totalOriginalConsiderationItems = 3;

        OfferItem[] memory offerOne = new OfferItem[](1);
        offerOne[0].itemType = ItemType.ERC721;
        offerOne[0].token = BAYC;
        offerOne[0].identifierOrCriteria = 2518;
        offerOne[0].startAmount = 1;
        offerOne[0].endAmount = 1;
        parametersOne.offer = offerOne;

        ConsiderationItem[] memory considerationOne = new ConsiderationItem[](3);
        considerationOne[0].recipient = payable(0x7a277Cf6E2F3704425195caAe4148848c29Ff815);
        considerationOne[0].startAmount = 79.8 ether;
        considerationOne[0].endAmount = 79.8 ether;
        considerationOne[1].recipient = payable(OPENSEA_FEES);
        considerationOne[1].startAmount = 2.1 ether;
        considerationOne[1].endAmount = 2.1 ether;
        considerationOne[2].recipient = payable(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1);
        considerationOne[2].startAmount = 2.1 ether;
        considerationOne[2].endAmount = 2.1 ether;
        parametersOne.consideration = considerationOne;

        advancedOrders[0].parameters = parametersOne;
        advancedOrders[0].numerator = 1;
        advancedOrders[0].denominator = 1;
        advancedOrders[0]
            .signature = hex"27deb8f1923b96693d8d5e1bf9304207e31b9cb49e588e8df5b3926b7547ba444afafe429fb2a17b4b97544d8383f3ad886fc15cab5a91382a56f9d65bb3dc231c";

        OrderParameters memory parametersTwo;
        parametersTwo.offerer = 0x72F1C8601C30C6f42CA8b0E85D1b2F87626A0deb;
        parametersTwo.zone = 0x004C00500000aD104D7DBd00e3ae0A5C00560C00;
        parametersTwo.zoneHash = bytes32(0);
        parametersTwo.salt = 90974057687252886;
        parametersTwo.conduitKey = 0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000;
        parametersTwo.orderType = OrderType.FULL_RESTRICTED;
        parametersTwo.startTime = 1659944298;
        parametersTwo.endTime = 1662303030;
        parametersTwo.totalOriginalConsiderationItems = 3;

        OfferItem[] memory offerTwo = new OfferItem[](1);
        offerTwo[0].itemType = ItemType.ERC721;
        offerTwo[0].token = BAYC;
        offerTwo[0].identifierOrCriteria = 8498;
        offerTwo[0].startAmount = 1;
        offerTwo[0].endAmount = 1;
        parametersTwo.offer = offerTwo;

        ConsiderationItem[] memory considerationTwo = new ConsiderationItem[](3);
        considerationTwo[0].recipient = payable(0x72F1C8601C30C6f42CA8b0E85D1b2F87626A0deb);
        considerationTwo[0].startAmount = 80.541 ether;
        considerationTwo[0].endAmount = 80.541 ether;
        considerationTwo[1].recipient = payable(OPENSEA_FEES);
        considerationTwo[1].startAmount = 2.1195 ether;
        considerationTwo[1].endAmount = 2.1195 ether;
        considerationTwo[2].recipient = payable(YUGA_LABS);
        considerationTwo[2].startAmount = 2.1195 ether;
        considerationTwo[2].endAmount = 2.1195 ether;
        parametersTwo.consideration = considerationTwo;

        advancedOrders[1].parameters = parametersTwo;
        advancedOrders[1].numerator = 1;
        advancedOrders[1].denominator = 1;
        advancedOrders[1]
            .signature = hex"fcdc82cba99c19522af3692070e4649ff573d20f2550eb29f7a24b3c39da74bd6a6c5b8444a2139c529301a8da011af414342d304609f896580e12fbd94d387a1b";

        uint256 gasRemaining = gasleft();
        seaport.fulfillAvailableAdvancedOrders{value: 168.78 ether}(
            advancedOrders,
            new CriteriaResolver[](0),
            validMultipleOfferFulfillments(2),
            validMultipleConsiderationFulfillments(),
            bytes32(0),
            _buyer,
            2
        );
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("Seaport multiple NFT purchase direct consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
        assertEq(IERC721(BAYC).ownerOf(8498), _buyer);
    }

    function testExecuteThroughAggregatorTwoOrdersAtomic() public {
        _testExecuteThroughAggregatorTwoOrders(true);
    }

    function testExecuteThroughAggregatorTwoOrdersNonAtomic() public {
        _testExecuteThroughAggregatorTwoOrders(false);
    }

    function testExecuteThroughV0AggregatorTwoOrders() public {
        _v0AggregatorSetUp();

        BasicOrder[] memory orders = new BasicOrder[](2);
        orders[0] = validBAYCId2518Order();
        orders[1] = validBAYCId8498Order();

        bytes memory orderOneExtraData = validBAYCId2518OrderExtraData();
        bytes memory orderTwoExtraData = validBAYCId8498OrderExtraData();
        bytes[] memory ordersExtraData = new bytes[](2);
        ordersExtraData[0] = orderOneExtraData;
        ordersExtraData[1] = orderTwoExtraData;

        bytes memory extraData = validMultipleItemsSameCollectionExtraData();

        V0Aggregator.TradeData[] memory tradeData = new V0Aggregator.TradeData[](1);
        uint256 totalPrice = orders[0].price + orders[1].price;
        FeeData memory feeData;
        bytes memory data = abi.encodeWithSelector(
            SeaportProxy.execute.selector,
            orders,
            ordersExtraData,
            extraData,
            _buyer,
            true,
            feeData
        );
        tradeData[0] = V0Aggregator.TradeData({proxy: address(seaportProxy), value: totalPrice, data: data});

        uint256 gasRemaining = gasleft();
        v0Aggregator.execute{value: totalPrice}(tradeData);
        uint256 gasConsumed = gasRemaining - gasleft();
        emit log_named_uint("Seaport multiple NFT purchase through the V0 aggregator consumed: ", gasConsumed);

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
        assertEq(IERC721(BAYC).ownerOf(8498), _buyer);
    }

    function _aggregatorSetUp() private {
        aggregator = new LooksRareAggregator();
        seaportProxy = new SeaportProxy(SEAPORT, address(aggregator));

        aggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);

        // Since we are forking mainnet, we have to make sure it has 0 ETH.
        vm.deal(address(seaportProxy), 0);
    }

    function _v0AggregatorSetUp() private {
        v0Aggregator = new V0Aggregator();
        seaportProxy = new SeaportProxy(SEAPORT, address(v0Aggregator));

        v0Aggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);

        // Since we are forking mainnet, we have to make sure it has 0 ETH.
        vm.deal(address(seaportProxy), 0);
    }

    function _testExecuteThroughAggregatorTwoOrders(bool isAtomic) public {
        _aggregatorSetUp();

        BasicOrder memory orderOne = validBAYCId2518Order();
        BasicOrder memory orderTwo = validBAYCId8498Order();
        BasicOrder[] memory orders = new BasicOrder[](2);
        orders[0] = orderOne;
        orders[1] = orderTwo;

        bytes[] memory ordersExtraData = new bytes[](2);
        {
            bytes memory orderOneExtraData = validBAYCId2518OrderExtraData();
            bytes memory orderTwoExtraData = validBAYCId8498OrderExtraData();
            ordersExtraData[0] = orderOneExtraData;
            ordersExtraData[1] = orderTwoExtraData;
        }

        bytes memory extraData = validMultipleItemsSameCollectionExtraData();

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        uint256 totalPrice = orders[0].price + orders[1].price;
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: totalPrice,
            maxFeeBp: 0,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: extraData
        });

        uint256 gasRemaining = gasleft();
        aggregator.execute{value: totalPrice}(new TokenTransfer[](0), tradeData, _buyer, _buyer, isAtomic);
        uint256 gasConsumed = gasRemaining - gasleft();

        if (isAtomic) {
            emit log_named_uint(
                "(Atomic) Seaport multiple NFT purchase through the aggregator consumed: ",
                gasConsumed
            );
        } else {
            emit log_named_uint(
                "(Non-atomic) Seaport multiple NFT purchase through the aggregator consumed: ",
                gasConsumed
            );
        }

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
        assertEq(IERC721(BAYC).ownerOf(8498), _buyer);
    }
}
