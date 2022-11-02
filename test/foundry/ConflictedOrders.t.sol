// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721} from "../../contracts/interfaces/IERC721.sol";
import {LooksRareProxy} from "../../contracts/proxies/LooksRareProxy.sol";
import {SeaportProxy} from "../../contracts/proxies/SeaportProxy.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {CollectionType} from "../../contracts/libraries/OrderEnums.sol";
import {BasicOrder, TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";
import {SeaportProxyTestHelpers} from "./SeaportProxyTestHelpers.sol";

/**
 * @notice Conflicted orders. e.g. buy the same NFT from 2 marketplaces in one transaction
 */
contract ConflictedOrdersTest is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    LooksRareAggregator private aggregator;
    SeaportProxy private seaportProxy;
    LooksRareProxy private looksRareProxy;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 15_327_113);

        aggregator = new LooksRareAggregator();
        seaportProxy = new SeaportProxy(SEAPORT, address(aggregator));
        aggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);
        looksRareProxy = new LooksRareProxy(LOOKSRARE_V1, address(aggregator));
        aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
        vm.deal(_buyer, INITIAL_ETH_BALANCE);
        // Forking from mainnet and the deployed addresses might have balance
        vm.deal(address(aggregator), 0);
        vm.deal(address(seaportProxy), 0);
        vm.deal(address(looksRareProxy), 0);
    }

    function testExecuteAtomicFail() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(true);

        // Not sure why none of 0x1f003d0a / "BadSignatureV(0)" worked, but I've verified the error in the logs.
        vm.expectRevert();
        aggregator.execute{value: tradeData[0].orders[0].price + tradeData[1].orders[0].price}(
            new TokenTransfer[](0),
            tradeData,
            _buyer,
            _buyer,
            true
        );
    }

    function testExecutePartialSuccess() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(false);

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: tradeData[0].orders[0].price + tradeData[1].orders[0].price}(
            new TokenTransfer[](0),
            tradeData,
            _buyer,
            _buyer,
            false
        );

        assertEq(IERC721(BAYC).balanceOf(_buyer), 1);
        assertEq(IERC721(BAYC).ownerOf(9314), _buyer);
        assertEq(address(_buyer).balance, INITIAL_ETH_BALANCE - tradeData[0].orders[0].price);
    }

    function _generateTradeData(bool isAtomic) private view returns (ILooksRareAggregator.TradeData[] memory) {
        BasicOrder[] memory seaportOrders = new BasicOrder[](1);
        seaportOrders[0] = validBAYCId9314Order();

        bytes[] memory seaportOrdersExtraData = new bytes[](1);
        {
            seaportOrdersExtraData[0] = validBAYCId9314OrderExtraData();
        }

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](2);

        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: seaportOrders[0].price,
            maxFeeBp: 0,
            orders: seaportOrders,
            ordersExtraData: seaportOrdersExtraData,
            extraData: isAtomic ? validSingleBAYCExtraData() : new bytes(0)
        });

        BasicOrder[] memory looksRareOrders = new BasicOrder[](1);
        looksRareOrders[0].signer = 0x3445A938F98EaAeb6AF3ce90e71FC5994a23F897;
        looksRareOrders[0].collection = BAYC;
        looksRareOrders[0].collectionType = CollectionType.ERC721;
        looksRareOrders[0].tokenIds = seaportOrders[0].tokenIds;
        looksRareOrders[0].amounts = seaportOrders[0].amounts;
        looksRareOrders[0].price = 87.95 ether;
        looksRareOrders[0].currency = WETH;
        looksRareOrders[0].startTime = 1659415937;
        looksRareOrders[0].endTime = 1661764279;
        looksRareOrders[0]
            .signature = hex"0ad409048cbf4b75ab2dec2cdb7f57b6e0b1a3490a9230d8146f1eec9185ae1078735b237ff2088320f00204968b1eb396d374dfba9fbc79dedde4a53670f8b000";

        bytes[] memory looksRareOrdersExtraData = new bytes[](1);
        {
            looksRareOrdersExtraData[0] = abi.encode(87.95 ether, 9550, 2, LOOKSRARE_STRATEGY_FIXED_PRICE);
        }

        tradeData[1] = ILooksRareAggregator.TradeData({
            proxy: address(looksRareProxy),
            selector: LooksRareProxy.execute.selector,
            value: looksRareOrders[0].price,
            maxFeeBp: 0,
            orders: looksRareOrders,
            ordersExtraData: looksRareOrdersExtraData,
            extraData: ""
        });

        return tradeData;
    }
}
