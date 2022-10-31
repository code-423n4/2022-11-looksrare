// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";
import {IERC1155} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1155.sol";
import {SeaportProxy} from "../../contracts/proxies/SeaportProxy.sol";
import {ERC20EnabledLooksRareAggregator} from "../../contracts/ERC20EnabledLooksRareAggregator.sol";
import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {IProxy} from "../../contracts/interfaces/IProxy.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {BasicOrder, FeeData, TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";
import {SeaportProxyTestHelpers} from "./SeaportProxyTestHelpers.sol";

/**
 * @notice Seaport multiple currencies execution in one transaction tests
 */
contract SeaportProxyMultipleCurrenciesTest is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    LooksRareAggregator private aggregator;
    ERC20EnabledLooksRareAggregator private erc20EnabledAggregator;
    SeaportProxy private seaportProxy;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL, 15_447_813);

        aggregator = new LooksRareAggregator();
        erc20EnabledAggregator = new ERC20EnabledLooksRareAggregator(address(aggregator));
        seaportProxy = new SeaportProxy(SEAPORT, address(aggregator));
        aggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);
        vm.deal(_buyer, INITIAL_ETH_BALANCE);
        deal(USDC, _buyer, INITIAL_USDC_BALANCE);
        // Forking from mainnet and the deployed addresses might have balance
        vm.deal(address(aggregator), 0);
        vm.deal(address(seaportProxy), 0);

        aggregator.approve(SEAPORT, USDC, type(uint256).max);
        aggregator.setERC20EnabledLooksRareAggregator(address(erc20EnabledAggregator));
    }

    function testExecuteAtomic() public asPrankedUser(_buyer) {
        _testExecute(true);
    }

    function testExecuteNonAtomic() public asPrankedUser(_buyer) {
        _testExecute(false);
    }

    function testExecuteWithExcessUSDCAtomic() public asPrankedUser(_buyer) {
        _testExecuteWithExcessUSDC(true);
    }

    function testExecuteWithExcessUSDCNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteWithExcessUSDC(false);
    }

    function testExecuteWithFeesAtomic() public {
        vm.deal(_protocolFeeRecipient, 0);
        deal(USDC, _protocolFeeRecipient, 0);
        aggregator.setFee(address(seaportProxy), 250, _protocolFeeRecipient);
        vm.startPrank(_buyer);
        _testExecuteWithFees(true);
        vm.stopPrank();
    }

    function testExecuteWithFeesNonAtomic() public {
        vm.deal(_protocolFeeRecipient, 0);
        deal(USDC, _protocolFeeRecipient, 0);
        aggregator.setFee(address(seaportProxy), 250, _protocolFeeRecipient);
        vm.startPrank(_buyer);
        _testExecuteWithFees(false);
        vm.stopPrank();
    }

    function _testExecute(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(isAtomic);

        uint256 usdcAmount = tradeData[0].orders[0].price;
        uint256 ethAmount = tradeData[0].orders[1].price;

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = usdcAmount;
        tokenTransfers[0].currency = USDC;

        IERC20(USDC).approve(address(erc20EnabledAggregator), usdcAmount);

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        erc20EnabledAggregator.execute{value: ethAmount}(tokenTransfers, tradeData, _buyer, isAtomic);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 2);
        assertEq(IERC721(BAYC).ownerOf(9996), _buyer);
        assertEq(IERC721(BAYC).ownerOf(5509), _buyer);

        assertEq(address(_buyer).balance, INITIAL_ETH_BALANCE - ethAmount);
        assertEq(IERC20(USDC).balanceOf(_buyer), INITIAL_USDC_BALANCE - usdcAmount);
        assertEq(IERC20(USDC).allowance(_buyer, address(erc20EnabledAggregator)), 0);
    }

    function _testExecuteWithFees(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(isAtomic);

        tradeData[0].maxFeeBp = 250;

        uint256 usdcAmount = (tradeData[0].orders[0].price * 10250) / 10000;
        uint256 ethAmount = (tradeData[0].orders[1].price * 10250) / 10000;

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = usdcAmount;
        tokenTransfers[0].currency = USDC;

        IERC20(USDC).approve(address(erc20EnabledAggregator), usdcAmount);

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        erc20EnabledAggregator.execute{value: ethAmount}(tokenTransfers, tradeData, _buyer, isAtomic);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 2);
        assertEq(IERC721(BAYC).ownerOf(9996), _buyer);
        assertEq(IERC721(BAYC).ownerOf(5509), _buyer);

        assertEq(address(_buyer).balance, INITIAL_ETH_BALANCE - ethAmount);
        assertEq(address(_protocolFeeRecipient).balance, ethAmount - tradeData[0].orders[1].price);

        assertEq(IERC20(USDC).balanceOf(_buyer), INITIAL_USDC_BALANCE - usdcAmount);
        assertEq(IERC20(USDC).allowance(_buyer, address(erc20EnabledAggregator)), 0);
        assertEq(IERC20(USDC).balanceOf(_protocolFeeRecipient), usdcAmount - tradeData[0].orders[0].price);
    }

    function _testExecuteWithExcessUSDC(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData(isAtomic);

        uint256 excess = 100e6;

        uint256 usdcAmount = tradeData[0].orders[0].price + excess;
        uint256 ethAmount = tradeData[0].orders[1].price;

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = usdcAmount;
        tokenTransfers[0].currency = USDC;

        IERC20(USDC).approve(address(erc20EnabledAggregator), usdcAmount);

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        erc20EnabledAggregator.execute{value: ethAmount}(tokenTransfers, tradeData, _buyer, isAtomic);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 2);
        assertEq(IERC721(BAYC).ownerOf(9996), _buyer);
        assertEq(IERC721(BAYC).ownerOf(5509), _buyer);

        assertEq(address(_buyer).balance, INITIAL_ETH_BALANCE - ethAmount);
        assertEq(IERC20(USDC).balanceOf(_buyer), INITIAL_USDC_BALANCE - tradeData[0].orders[0].price);
        assertEq(IERC20(USDC).allowance(_buyer, address(erc20EnabledAggregator)), 0);

        assertEq(IERC20(USDC).balanceOf(address(aggregator)), 0);
        assertEq(IERC20(USDC).balanceOf(address(erc20EnabledAggregator)), 0);
        assertEq(IERC20(USDC).balanceOf(address(seaportProxy)), 0);
    }

    function _generateTradeData(bool isAtomic) private view returns (ILooksRareAggregator.TradeData[] memory) {
        BasicOrder memory orderOne = validBAYCId9996Order();
        BasicOrder memory orderTwo = validBAYCId5509Order();
        BasicOrder[] memory orders = new BasicOrder[](2);
        orders[0] = orderOne;
        orders[1] = orderTwo;

        bytes[] memory ordersExtraData = new bytes[](2);
        {
            bytes memory orderOneExtraData = validBAYCId9996OrderExtraData();
            bytes memory orderTwoExtraData = validBAYCId5509OrderExtraData();
            ordersExtraData[0] = orderOneExtraData;
            ordersExtraData[1] = orderTwoExtraData;
        }

        bytes memory extraData = isAtomic
            ? validMultipleItemsSameCollectionMultipleCurrenciesExtraData()
            : new bytes(0);
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
