// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721} from "../../contracts/interfaces/IERC721.sol";
import {IERC1155} from "../../contracts/interfaces/IERC1155.sol";
import {SeaportProxy} from "../../contracts/proxies/SeaportProxy.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {IProxy} from "../../contracts/interfaces/IProxy.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {BasicOrder, FeeData, TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";
import {SeaportProxyTestHelpers} from "./SeaportProxyTestHelpers.sol";

/**
 * @notice SeaportProxy ERC721/ERC1155 in one transaction tests
 */
contract SeaportProxyMultipleCollectionTypesTest is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    LooksRareAggregator private aggregator;
    SeaportProxy private seaportProxy;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 15_323_472);

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

    function _testExecute(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(isAtomic);
        uint256 totalPrice = tradeData[0].orders[0].price + tradeData[0].orders[1].price;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: totalPrice}(new TokenTransfer[](0), tradeData, _buyer, _buyer, isAtomic);

        assertEq(IERC721(BAYC).ownerOf(6092), _buyer);
        assertEq(IERC1155(CITY_DAO).balanceOf(_buyer, 42), 1);
        assertEq(address(_buyer).balance, INITIAL_ETH_BALANCE - totalPrice);
    }

    function _generateTradeData(bool isAtomic) private view returns (ILooksRareAggregator.TradeData[] memory) {
        BasicOrder memory orderOne = validBAYCId6092Order();
        BasicOrder memory orderTwo = validCityDaoOrders()[1];
        BasicOrder[] memory orders = new BasicOrder[](2);
        orders[0] = orderOne;
        orders[1] = orderTwo;

        bytes[] memory ordersExtraData = new bytes[](2);
        {
            bytes memory orderOneExtraData = validBAYCId6092OrderExtraData();
            bytes memory orderTwoExtraData = validCityDaoOrdersExtraData()[1];
            ordersExtraData[0] = orderOneExtraData;
            ordersExtraData[1] = orderTwoExtraData;
        }

        bytes memory extraData = isAtomic ? validMultipleCollectionsExtraData() : new bytes(0);
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
