// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "../../contracts/interfaces/IERC20.sol";
import {IERC721} from "../../contracts/interfaces/IERC721.sol";
import {IERC1155} from "../../contracts/interfaces/IERC1155.sol";
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
 * @notice Seaport multiple currencies with fees (random execution order) execution in one transaction tests
 */
contract SeaportProxyMultipleCurrenciesRandomOrderFeesTest is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    LooksRareAggregator private aggregator;
    ERC20EnabledLooksRareAggregator private erc20EnabledAggregator;
    SeaportProxy private seaportProxy;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 15_491_323);

        aggregator = new LooksRareAggregator();
        erc20EnabledAggregator = new ERC20EnabledLooksRareAggregator(address(aggregator));
        seaportProxy = new SeaportProxy(SEAPORT, address(aggregator));
        aggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);
        vm.deal(_buyer, INITIAL_ETH_BALANCE);
        deal(USDC, _buyer, INITIAL_USDC_BALANCE);
        // Forking from mainnet and the deployed addresses might have balance
        vm.deal(address(aggregator), 0);
        vm.deal(address(seaportProxy), 0);
        vm.deal(_protocolFeeRecipient, 0);
        deal(USDC, _protocolFeeRecipient, 0);

        aggregator.approve(SEAPORT, USDC, type(uint256).max);
        aggregator.setERC20EnabledLooksRareAggregator(address(erc20EnabledAggregator));
        aggregator.setFee(address(seaportProxy), 250, _protocolFeeRecipient);
    }

    // USDC - USDC - ETH - ETH
    function testExecuteUSDCThenETHAtomic() public asPrankedUser(_buyer) {
        _testExecuteUSDCThenETH(true);
    }

    function testExecuteUSDCThenETHNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteUSDCThenETH(false);
    }

    // ETH - ETH - USDC - USDC
    function testExecuteETHThenUSDCAtomic() public asPrankedUser(_buyer) {
        _testExecuteETHThenUSDC(true);
    }

    function testExecuteETHThenUSDCNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteETHThenUSDC(false);
    }

    // ETH - USDC - ETH - USDC
    function testExecuteETHUSDCAlternateAtomic() public asPrankedUser(_buyer) {
        _testExecuteETHUSDCAlternate(true);
    }

    function testExecuteETHUSDCAlternateNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteETHUSDCAlternate(false);
    }

    // USDC - ETH - USDC - ETH
    function testExecuteUSDCETHAlternateAtomic() public asPrankedUser(_buyer) {
        _testExecuteUSDCETHAlternate(true);
    }

    function testExecuteUSDCETHAlternateNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteUSDCETHAlternate(false);
    }

    function _testExecuteUSDCThenETH(bool isAtomic) private {
        BasicOrder[] memory orders = new BasicOrder[](4);
        orders[0] = validBAYCId9948Order();
        orders[1] = validBAYCId8350Order();
        orders[2] = validBAYCId9357Order();
        orders[3] = validBAYCId9477Order();

        bytes[] memory ordersExtraData = new bytes[](4);
        {
            ordersExtraData[0] = validBAYCId9948OrderExtraData();
            ordersExtraData[1] = validBAYCId8350OrderExtraData();
            ordersExtraData[2] = validBAYCId9357OrderExtraData();
            ordersExtraData[3] = validBAYCId9477OrderExtraData();
        }

        bytes memory extraData = isAtomic
            ? validMultipleItemsSameCollectionMultipleCurrenciesOneAfterAnotherExtraData()
            : new bytes(0);
        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        uint256 ethAmount = ((orders[2].price + orders[3].price) * 10250) / 10000;
        uint256 usdcAmount = ((orders[0].price + orders[1].price) * 10250) / 10000;
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: ethAmount,
            maxFeeBp: 250,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: extraData
        });

        IERC20(USDC).approve(address(erc20EnabledAggregator), usdcAmount);

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = usdcAmount;
        tokenTransfers[0].currency = USDC;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        erc20EnabledAggregator.execute{value: ethAmount}(tokenTransfers, tradeData, _buyer, isAtomic);

        _assertBuyerBAYCOwnership();

        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - ethAmount);
        assertEq(_protocolFeeRecipient.balance, ethAmount - orders[2].price - orders[3].price);
        assertEq(IERC20(USDC).balanceOf(_buyer), INITIAL_USDC_BALANCE - usdcAmount);
        assertEq(IERC20(USDC).allowance(_buyer, address(erc20EnabledAggregator)), 0);
    }

    function _testExecuteETHThenUSDC(bool isAtomic) private {
        BasicOrder[] memory orders = new BasicOrder[](4);
        orders[0] = validBAYCId9357Order();
        orders[1] = validBAYCId9477Order();
        orders[2] = validBAYCId9948Order();
        orders[3] = validBAYCId8350Order();

        bytes[] memory ordersExtraData = new bytes[](4);
        {
            ordersExtraData[0] = validBAYCId9357OrderExtraData();
            ordersExtraData[1] = validBAYCId9477OrderExtraData();
            ordersExtraData[2] = validBAYCId9948OrderExtraData();
            ordersExtraData[3] = validBAYCId8350OrderExtraData();
        }

        bytes memory extraData = isAtomic
            ? validMultipleItemsSameCollectionMultipleCurrenciesOneAfterAnotherExtraData()
            : new bytes(0);
        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        uint256 ethAmount = ((orders[0].price + orders[1].price) * 10250) / 10000;
        uint256 usdcAmount = ((orders[2].price + orders[3].price) * 10250) / 10000;
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: ethAmount,
            maxFeeBp: 250,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: extraData
        });

        IERC20(USDC).approve(address(erc20EnabledAggregator), usdcAmount);

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = usdcAmount;
        tokenTransfers[0].currency = USDC;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        erc20EnabledAggregator.execute{value: ethAmount}(tokenTransfers, tradeData, _buyer, isAtomic);

        _assertBuyerBAYCOwnership();

        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - ethAmount);
        assertEq(_protocolFeeRecipient.balance, ethAmount - orders[0].price - orders[1].price);
        assertEq(IERC20(USDC).balanceOf(_buyer), INITIAL_USDC_BALANCE - usdcAmount);
        assertEq(IERC20(USDC).allowance(_buyer, address(erc20EnabledAggregator)), 0);
    }

    function _testExecuteETHUSDCAlternate(bool isAtomic) private {
        BasicOrder[] memory orders = new BasicOrder[](4);
        orders[0] = validBAYCId9357Order();
        orders[1] = validBAYCId9948Order();
        orders[2] = validBAYCId9477Order();
        orders[3] = validBAYCId8350Order();

        bytes[] memory ordersExtraData = new bytes[](4);
        {
            ordersExtraData[0] = validBAYCId9357OrderExtraData();
            ordersExtraData[1] = validBAYCId9948OrderExtraData();
            ordersExtraData[2] = validBAYCId9477OrderExtraData();
            ordersExtraData[3] = validBAYCId8350OrderExtraData();
        }

        bytes memory extraData = isAtomic
            ? validMultipleItemsSameCollectionMultipleCurrenciesAlternateExtraData()
            : new bytes(0);
        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        uint256 ethAmount = ((orders[0].price + orders[2].price) * 10250) / 10000;
        uint256 usdcAmount = ((orders[1].price + orders[3].price) * 10250) / 10000;
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: ethAmount,
            maxFeeBp: 250,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: extraData
        });

        IERC20(USDC).approve(address(erc20EnabledAggregator), usdcAmount);

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = usdcAmount;
        tokenTransfers[0].currency = USDC;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        erc20EnabledAggregator.execute{value: ethAmount}(tokenTransfers, tradeData, _buyer, isAtomic);

        _assertBuyerBAYCOwnership();

        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - ethAmount);
        assertEq(_protocolFeeRecipient.balance, ethAmount - orders[0].price - orders[2].price);
        assertEq(IERC20(USDC).balanceOf(_buyer), INITIAL_USDC_BALANCE - usdcAmount);
        assertEq(IERC20(USDC).allowance(_buyer, address(erc20EnabledAggregator)), 0);
    }

    function _testExecuteUSDCETHAlternate(bool isAtomic) private {
        BasicOrder[] memory orders = new BasicOrder[](4);
        orders[0] = validBAYCId9948Order();
        orders[1] = validBAYCId9357Order();
        orders[2] = validBAYCId8350Order();
        orders[3] = validBAYCId9477Order();

        bytes[] memory ordersExtraData = new bytes[](4);
        {
            ordersExtraData[0] = validBAYCId9948OrderExtraData();
            ordersExtraData[1] = validBAYCId9357OrderExtraData();
            ordersExtraData[2] = validBAYCId8350OrderExtraData();
            ordersExtraData[3] = validBAYCId9477OrderExtraData();
        }

        bytes memory extraData = isAtomic
            ? validMultipleItemsSameCollectionMultipleCurrenciesAlternateExtraData()
            : new bytes(0);
        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        uint256 ethAmount = ((orders[1].price + orders[3].price) * 10250) / 10000;
        uint256 usdcAmount = ((orders[0].price + orders[2].price) * 10250) / 10000;
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: ethAmount,
            maxFeeBp: 250,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: extraData
        });

        IERC20(USDC).approve(address(erc20EnabledAggregator), usdcAmount);

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = usdcAmount;
        tokenTransfers[0].currency = USDC;

        vm.expectEmit(true, true, false, false);
        emit Sweep(_buyer);
        erc20EnabledAggregator.execute{value: ethAmount}(tokenTransfers, tradeData, _buyer, isAtomic);

        _assertBuyerBAYCOwnership();

        assertEq(_buyer.balance, INITIAL_ETH_BALANCE - ethAmount);
        assertEq(_protocolFeeRecipient.balance, ethAmount - orders[1].price - orders[3].price);
        assertEq(IERC20(USDC).balanceOf(_buyer), INITIAL_USDC_BALANCE - usdcAmount);
        assertEq(IERC20(USDC).allowance(_buyer, address(erc20EnabledAggregator)), 0);
    }

    function _assertBuyerBAYCOwnership() private {
        assertEq(IERC721(BAYC).balanceOf(_buyer), 4);
        assertEq(IERC721(BAYC).ownerOf(9948), _buyer);
        assertEq(IERC721(BAYC).ownerOf(8350), _buyer);
        assertEq(IERC721(BAYC).ownerOf(9357), _buyer);
        assertEq(IERC721(BAYC).ownerOf(9477), _buyer);
    }
}
