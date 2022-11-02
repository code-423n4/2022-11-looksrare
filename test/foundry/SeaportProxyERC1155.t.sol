// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC1155} from "../../contracts/interfaces/IERC1155.sol";
import {SeaportProxy} from "../../contracts/proxies/SeaportProxy.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {BasicOrder, TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {SeaportProxyTestHelpers} from "./SeaportProxyTestHelpers.sol";

abstract contract TestParameters {
    address internal constant _buyer = address(1);
    address internal constant _protocolFeeRecipient = address(2);
    string internal constant MAINNET_RPC_URL = "https://rpc.ankr.com/eth";
    uint256 internal constant INITIAL_ETH_BALANCE = 1 ether;
    event Sweep(address indexed sweeper);
}

/**
 * @notice SeaportProxy ERC1155 tests (fees, refund, atomic fail/partial success)
 */
contract SeaportProxyERC1155Test is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    LooksRareAggregator private aggregator;
    SeaportProxy private seaportProxy;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL, 15_320_038);

        aggregator = new LooksRareAggregator();
        seaportProxy = new SeaportProxy(SEAPORT, address(aggregator));
        aggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);
        vm.deal(_buyer, INITIAL_ETH_BALANCE);
        // Forking from mainnet and the deployed addresses might have balance
        vm.deal(address(aggregator), 0);
        vm.deal(address(seaportProxy), 0);
    }

    function testExecuteAtomic() public asPrankedUser(_buyer) {
        _testExecute(true);
    }

    function testExecuteNonAtomic() public asPrankedUser(_buyer) {
        _testExecute(false);
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

    function testExecuteAtomicFail() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(true);
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        // Not paying for the second order
        tradeData[0].orders[1].price = 0;
        tradeData[0].value = tradeData[0].orders[0].price;

        vm.expectRevert(0x1a783b8d); // InsufficientEtherSupplied
        aggregator.execute{value: tradeData[0].value}(tokenTransfers, tradeData, _buyer, _buyer, true);
    }

    function testExecutePartialSuccess() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(false);
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        // Not paying for the second order
        tradeData[0].orders[1].price = 0;
        tradeData[0].value = tradeData[0].orders[0].price;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);

        aggregator.execute{value: tradeData[0].value}(tokenTransfers, tradeData, _buyer, _buyer, false);
        assertEq(IERC1155(CITY_DAO).balanceOf(_buyer, 42), 1);
        assertEq(_buyer.balance, 0.702 ether);
    }

    function _testExecute(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(isAtomic);
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);

        aggregator.execute{value: tradeData[0].value}(tokenTransfers, tradeData, _buyer, _buyer, isAtomic);
        assertEq(IERC1155(CITY_DAO).balanceOf(_buyer, 42), 2);
        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - tradeData[0].value);
    }

    function _testExecuteRefundFromLooksRareAggregator(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(isAtomic);
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);

        aggregator.execute{value: tradeData[0].value + 0.1 ether}(tokenTransfers, tradeData, _buyer, _buyer, isAtomic);
        assertEq(IERC1155(CITY_DAO).balanceOf(_buyer, 42), 2);
        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - tradeData[0].value);
    }

    function _testExecuteRefundFromSeaportProxy(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(isAtomic);
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        // Overpay
        tradeData[0].orders[0].price = 0.5 ether;
        tradeData[0].orders[1].price = 0.5 ether;
        tradeData[0].value = 1 ether;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);

        aggregator.execute{value: tradeData[0].value}(tokenTransfers, tradeData, _buyer, _buyer, isAtomic);
        assertEq(IERC1155(CITY_DAO).balanceOf(_buyer, 42), 2);
        assertEq(_buyer.balance, 0.303 ether);
    }

    function _generateTradeData(bool isAtomic)
        private
        view
        returns (ILooksRareAggregator.TradeData[] memory tradeData)
    {
        BasicOrder[] memory orders = validCityDaoOrders();
        bytes[] memory ordersExtraData = validCityDaoOrdersExtraData();
        bytes memory extraData = isAtomic ? validMultipleItemsSameCollectionExtraData() : new bytes(0);

        tradeData = new ILooksRareAggregator.TradeData[](1);
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
    }
}
