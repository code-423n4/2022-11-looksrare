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
 * @notice Multiple markets execution in one transaction tests
 */
contract MultipleMarketsTest is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    LooksRareAggregator private aggregator;
    SeaportProxy private seaportProxy;
    LooksRareProxy private looksRareProxy;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 15_326_566);

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

    function testExecuteAtomic() public asPrankedUser(_buyer) {
        _testExecute(true);
    }

    function testExecuteNonAtomic() public asPrankedUser(_buyer) {
        _testExecute(false);
    }

    function testExecuteMaxFeeBpViolationAtomic() public {
        aggregator.setFee(address(seaportProxy), 250, _protocolFeeRecipient);
        aggregator.setFee(address(looksRareProxy), 250, _protocolFeeRecipient);

        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(true);
        tradeData[0].maxFeeBp = 250;
        tradeData[1].maxFeeBp = 249;
        uint256 totalPrice = (tradeData[0].orders[0].price * 10250) /
            10000 +
            (tradeData[1].orders[0].price * 10249) /
            10000;

        vm.expectRevert(ILooksRareAggregator.FeeTooHigh.selector);
        vm.prank(_buyer);
        aggregator.execute{value: totalPrice}(new TokenTransfer[](0), tradeData, _buyer, _buyer, true);
    }

    function testExecuteMaxFeeBpViolationNonAtomic() public {
        aggregator.setFee(address(seaportProxy), 250, _protocolFeeRecipient);
        aggregator.setFee(address(looksRareProxy), 250, _protocolFeeRecipient);

        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(false);
        tradeData[0].maxFeeBp = 250;
        tradeData[1].maxFeeBp = 249;
        uint256 totalPrice = (tradeData[0].orders[0].price * 10250) /
            10000 +
            (tradeData[1].orders[0].price * 10249) /
            10000;

        vm.prank(_buyer);
        aggregator.execute{value: totalPrice}(new TokenTransfer[](0), tradeData, _buyer, _buyer, false);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 1);
        assertEq(IERC721(BAYC).ownerOf(6092), _buyer);
        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - (tradeData[0].orders[0].price * 10250) / 10000);
    }

    function testExecuteAtomicFail() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(true);
        tradeData[1].orders[0].price -= 0.01 ether;
        uint256 totalPrice = tradeData[0].orders[0].price + tradeData[1].orders[0].price;

        vm.expectRevert("Strategy: Execution invalid");
        aggregator.execute{value: totalPrice}(new TokenTransfer[](0), tradeData, _buyer, _buyer, true);
    }

    function testExecutePartialSuccess() public asPrankedUser(_buyer) {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(false);
        tradeData[1].orders[0].price -= 0.01 ether;
        uint256 totalPrice = tradeData[0].orders[0].price + tradeData[1].orders[0].price;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: totalPrice}(new TokenTransfer[](0), tradeData, _buyer, _buyer, false);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 1);
        assertEq(IERC721(BAYC).ownerOf(6092), _buyer);
        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - tradeData[0].orders[0].price);
    }

    function _testExecute(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(isAtomic);
        uint256 totalPrice = tradeData[0].orders[0].price + tradeData[1].orders[0].price;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        aggregator.execute{value: totalPrice}(new TokenTransfer[](0), tradeData, _buyer, _buyer, isAtomic);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 2);
        assertEq(IERC721(BAYC).ownerOf(6092), _buyer);
        assertEq(IERC721(BAYC).ownerOf(2491), _buyer);
        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - totalPrice);
    }

    function _generateTradeData(bool isAtomic) private view returns (ILooksRareAggregator.TradeData[] memory) {
        BasicOrder[] memory seaportOrders = new BasicOrder[](1);
        seaportOrders[0] = validBAYCId6092Order();

        bytes[] memory seaportOrdersExtraData = new bytes[](1);
        {
            seaportOrdersExtraData[0] = validBAYCId6092OrderExtraData();
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
        looksRareOrders[0].signer = 0xCd46DEe6e832e3ffa3FdC394b8dC673D6CA843dd;
        looksRareOrders[0].collection = BAYC;
        looksRareOrders[0].collectionType = CollectionType.ERC721;
        uint256[] memory looksRareTokenIds = new uint256[](1);
        looksRareTokenIds[0] = 2491;
        looksRareOrders[0].tokenIds = looksRareTokenIds;
        looksRareOrders[0].amounts = seaportOrders[0].amounts;
        looksRareOrders[0].price = 78.69 ether;
        looksRareOrders[0].currency = WETH;
        looksRareOrders[0].startTime = 1660231310;
        looksRareOrders[0].endTime = 1668007269;
        looksRareOrders[0]
            .signature = hex"7b37474f79837ee4e56faf1e766a30a9d9c6ed3a7984457bcb212381f2b6b8f95a641ec95eca31f060a15a3c9ff2d4fbccbf481c766e8630be72b6e3e3aeca561b";

        bytes[] memory looksRareOrdersExtraData = new bytes[](1);
        {
            looksRareOrdersExtraData[0] = abi.encode(looksRareOrders[0].price, 9550, 0, LOOKSRARE_STRATEGY_FIXED_PRICE);
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
