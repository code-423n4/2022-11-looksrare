// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OwnableTwoSteps} from "../../contracts/OwnableTwoSteps.sol";
import {IERC721} from "../../contracts/interfaces/IERC721.sol";
import {LooksRareProxy} from "../../contracts/proxies/LooksRareProxy.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {TokenRescuer} from "../../contracts/TokenRescuer.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {IProxy} from "../../contracts/interfaces/IProxy.sol";
import {BasicOrder, FeeData, TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {CollectionType} from "../../contracts/libraries/OrderEnums.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";
import {TokenRescuerTest} from "./TokenRescuer.t.sol";
import {LooksRareProxyTestHelpers} from "./LooksRareProxyTestHelpers.sol";

/**
 * @notice LooksRareProxy tests, tests involving actual executions live in other tests
 */
contract LooksRareProxyTest is TestParameters, TestHelpers, TokenRescuerTest, LooksRareProxyTestHelpers {
    LooksRareAggregator private aggregator;
    LooksRareProxy private looksRareProxy;
    TokenRescuer private tokenRescuer;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 15_282_897);

        aggregator = new LooksRareAggregator();
        looksRareProxy = new LooksRareProxy(LOOKSRARE_V1, address(aggregator));
        aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);

        tokenRescuer = TokenRescuer(address(looksRareProxy));
        vm.deal(_buyer, 200 ether);

        // Forking from mainnet and the deployed addresses might have balance
        vm.deal(address(aggregator), 0);
        vm.deal(address(looksRareProxy), 0);
    }

    function testExecuteAtomicFail() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        // Pay less for order 0
        tradeData[0].orders[0].price -= 0.1 ether;
        uint256 value = tradeData[0].orders[0].price + tradeData[0].orders[1].price;

        vm.expectRevert("Strategy: Execution invalid");
        aggregator.execute{value: value}(tokenTransfers, tradeData, _buyer, _buyer, true);
    }

    function testExecutePartialSuccess() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        // Pay less for order 0
        tradeData[0].orders[0].price -= 0.1 ether;
        uint256 value = tradeData[0].orders[0].price + tradeData[0].orders[1].price;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: value}(tokenTransfers, tradeData, _buyer, _buyer, false);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 1);
        assertEq(IERC721(BAYC).ownerOf(3939), _buyer);
        assertEq(address(_buyer).balance, 200 ether - tradeData[0].orders[1].price);
    }

    function testExecuteRefundExtraPaid() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        tradeData[0].value += 0.1 ether;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: tradeData[0].value}(tokenTransfers, tradeData, _buyer, _buyer, false);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 2);
        assertEq(IERC721(BAYC).ownerOf(7139), _buyer);
        assertEq(IERC721(BAYC).ownerOf(3939), _buyer);
        assertEq(address(_buyer).balance, 200 ether - tradeData[0].orders[0].price - tradeData[0].orders[1].price);
    }

    function testExecuteZeroOrders() public asPrankedUser(_buyer) {
        BasicOrder[] memory orders = new BasicOrder[](0);
        bytes[] memory ordersExtraData = new bytes[](0);

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(looksRareProxy),
            selector: LooksRareProxy.execute.selector,
            value: 0,
            maxFeeBp: 0,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: ""
        });

        vm.expectRevert(IProxy.InvalidOrderLength.selector);
        aggregator.execute{value: 0}(tokenTransfers, tradeData, _buyer, _buyer, true);
    }

    function testExecuteOrdersLengthMismatch() public asPrankedUser(_buyer) {
        BasicOrder[] memory orders = validBAYCOrders();

        bytes[] memory ordersExtraData = new bytes[](1);
        ordersExtraData[0] = abi.encode(orders[0].price, 9550, 0, LOOKSRARE_STRATEGY_FIXED_PRICE);

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);

        uint256 value = orders[0].price + orders[1].price;

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(looksRareProxy),
            selector: LooksRareProxy.execute.selector,
            value: value,
            maxFeeBp: 0,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: ""
        });

        vm.expectRevert(IProxy.InvalidOrderLength.selector);
        aggregator.execute{value: value}(tokenTransfers, tradeData, _buyer, _buyer, true);
    }

    function testRescueETH() public {
        _testRescueETH(tokenRescuer);
    }

    function testRescueETHNotOwner() public {
        _testRescueETHNotOwner(tokenRescuer);
    }

    function testRescueETHInsufficientAmount() public {
        _testRescueETHInsufficientAmount(tokenRescuer);
    }

    function testRescueERC20() public {
        _testRescueERC20(tokenRescuer);
    }

    function testRescueERC20NotOwner() public {
        _testRescueERC20NotOwner(tokenRescuer);
    }

    function testRescueERC20InsufficientAmount() public {
        _testRescueERC20InsufficientAmount(tokenRescuer);
    }

    function _generateTradeData() private view returns (ILooksRareAggregator.TradeData[] memory tradeData) {
        BasicOrder[] memory orders = validBAYCOrders();

        bytes[] memory ordersExtraData = new bytes[](2);
        ordersExtraData[0] = abi.encode(orders[0].price, 9550, 0, LOOKSRARE_STRATEGY_FIXED_PRICE);
        ordersExtraData[1] = abi.encode(orders[1].price, 8500, 50, LOOKSRARE_STRATEGY_FIXED_PRICE);

        tradeData = new ILooksRareAggregator.TradeData[](1);
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
    }
}
