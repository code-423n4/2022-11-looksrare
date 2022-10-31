// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";
import {SeaportProxy} from "../../contracts/proxies/SeaportProxy.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {BasicOrder, TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {SeaportProxyTestHelpers} from "./SeaportProxyTestHelpers.sol";

abstract contract TestParameters {
    address internal constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address internal constant _buyer = address(1);
    address internal constant _protocolFeeRecipient = address(2);
    string internal constant MAINNET_RPC_URL = "https://rpc.ankr.com/eth";
    uint256 internal constant INITIAL_ETH_BALANCE = 200 ether;
    event Sweep(address indexed sweeper);
}

/**
 * @notice SeaportProxy additional execution tests (fees, refund, atomic fail/partial success)
 */
contract SeaportProxyERC721Test is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    LooksRareAggregator private aggregator;
    SeaportProxy private seaportProxy;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL, 15_300_884);

        aggregator = new LooksRareAggregator();
        seaportProxy = new SeaportProxy(SEAPORT, address(aggregator));
        aggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);
        vm.deal(_buyer, INITIAL_ETH_BALANCE);
        // Forking from mainnet and the deployed addresses might have balance
        vm.deal(address(aggregator), 0);
        vm.deal(address(seaportProxy), 0);
    }

    function testExecuteRefundFromLooksRareAggregatorAtomic() public asPrankedUser(_buyer) {
        _testExecuteRefundFromLooksRareAggregator(true);
    }

    function testExecuteRefundFromLooksRareAggregatorNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteRefundFromLooksRareAggregator(false);
    }

    function testExecuteRefundFromSeaportProxyAtomic() public asPrankedUser(_buyer) {
        _testExecuteRefundFromSeaportProxy(true);
    }

    function testExecuteRefundFromSeaportProxyNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteRefundFromSeaportProxy(false);
    }

    function testExecuteWithFeesAtomic() public {
        vm.deal(_protocolFeeRecipient, 0);
        aggregator.setFee(address(seaportProxy), 250, _protocolFeeRecipient);
        vm.startPrank(_buyer);
        _testExecuteWithFees(true);
        vm.stopPrank();
    }

    function testExecuteWithFeesNonAtomic() public {
        vm.deal(_protocolFeeRecipient, 0);
        aggregator.setFee(address(seaportProxy), 250, _protocolFeeRecipient);
        vm.startPrank(_buyer);
        _testExecuteWithFees(false);
        vm.stopPrank();
    }

    function testExecuteAtomicFail() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();

        vm.warp(block.timestamp + tradeData[0].orders[1].endTime + 1);

        vm.expectRevert(0xd5da9a1b); // NoSpecifiedOrdersAvailable
        aggregator.execute{value: tradeData[0].orders[0].price + tradeData[0].orders[1].price}(
            new TokenTransfer[](0),
            tradeData,
            _buyer,
            _buyer,
            true
        );
    }

    function testExecutePartialSuccess() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();

        // Do not pay for the 2nd order
        tradeData[0].orders[1].price = 0;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: tradeData[0].orders[0].price}(
            new TokenTransfer[](0),
            tradeData,
            _buyer,
            _buyer,
            false
        );

        assertEq(IERC721(BAYC).balanceOf(_buyer), 1);
        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
        assertEq(address(_buyer).balance, INITIAL_ETH_BALANCE - tradeData[0].orders[0].price);
    }

    function _testExecuteRefundFromLooksRareAggregator(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();
        uint256 totalPrice = tradeData[0].orders[0].price + tradeData[0].orders[1].price;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: totalPrice + 1 ether}(new TokenTransfer[](0), tradeData, _buyer, _buyer, isAtomic);

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
        assertEq(IERC721(BAYC).ownerOf(8498), _buyer);
        assertEq(address(_buyer).balance, INITIAL_ETH_BALANCE - totalPrice);
    }

    function _testExecuteRefundFromSeaportProxy(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();

        // Overpay
        tradeData[0].orders[0].price = 100 ether;
        tradeData[0].orders[1].price = 100 ether;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: INITIAL_ETH_BALANCE}(new TokenTransfer[](0), tradeData, _buyer, _buyer, isAtomic);

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
        assertEq(IERC721(BAYC).ownerOf(8498), _buyer);
        assertEq(address(_buyer).balance, 31.22 ether);
    }

    function _testExecuteWithFees(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();
        uint256 totalPriceBeforeFee = tradeData[0].orders[0].price + tradeData[0].orders[1].price;
        uint256 totalPriceWithFees = (tradeData[0].orders[0].price * 10250) /
            10000 +
            (tradeData[0].orders[1].price * 10250) /
            10000;

        tradeData[0].maxFeeBp = 250;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: totalPriceWithFees}(new TokenTransfer[](0), tradeData, _buyer, _buyer, isAtomic);

        assertEq(IERC721(BAYC).ownerOf(2518), _buyer);
        assertEq(IERC721(BAYC).ownerOf(8498), _buyer);
        assertEq(address(_buyer).balance, INITIAL_ETH_BALANCE - totalPriceWithFees);
        assertEq(address(_protocolFeeRecipient).balance, totalPriceWithFees - totalPriceBeforeFee);
    }

    function _generateTradeData() private view returns (ILooksRareAggregator.TradeData[] memory) {
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

        return tradeData;
    }
}
