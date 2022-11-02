// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
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
 * @notice SeaportProxy ERC721 USDC orders with fees tests
 */
contract SeaportProxyERC721USDCTest is TestParameters, TestHelpers, SeaportProxyTestHelpers {
    LooksRareAggregator private aggregator;
    ERC20EnabledLooksRareAggregator private erc20EnabledAggregator;
    SeaportProxy private seaportProxy;

    function setUp() public {
        vm.createSelectFork(MAINNET_RPC_URL, 15_491_323);

        aggregator = new LooksRareAggregator();
        erc20EnabledAggregator = new ERC20EnabledLooksRareAggregator(address(aggregator));
        seaportProxy = new SeaportProxy(SEAPORT, address(aggregator));
        aggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);

        deal(USDC, _buyer, INITIAL_USDC_BALANCE);

        aggregator.approve(SEAPORT, USDC, type(uint256).max);
        aggregator.setFee(address(seaportProxy), 250, _protocolFeeRecipient);
        aggregator.setERC20EnabledLooksRareAggregator(address(erc20EnabledAggregator));
    }

    function testExecuteWithFeesAtomic() public asPrankedUser(_buyer) {
        _testExecuteWithFees(true);
    }

    function testExecuteWithFeesNonAtomic() public asPrankedUser(_buyer) {
        _testExecuteWithFees(false);
    }

    function _testExecuteWithFees(bool isAtomic) private {
        ILooksRareAggregator.TradeData[] memory tradeData = _generateTradeData();
        uint256 totalPrice = (tradeData[0].orders[0].price * 10250) /
            10000 +
            (tradeData[0].orders[1].price * 10250) /
            10000;
        IERC20(USDC).approve(address(erc20EnabledAggregator), totalPrice);

        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].currency = USDC;
        tokenTransfers[0].amount = totalPrice;

        erc20EnabledAggregator.execute(tokenTransfers, tradeData, _buyer, isAtomic);

        assertEq(IERC721(BAYC).balanceOf(_buyer), 2);
        assertEq(IERC721(BAYC).ownerOf(9948), _buyer);
        assertEq(IERC721(BAYC).ownerOf(8350), _buyer);
        assertEq(IERC20(USDC).balanceOf(_buyer), INITIAL_USDC_BALANCE - totalPrice);
    }

    function _generateTradeData() private view returns (ILooksRareAggregator.TradeData[] memory) {
        BasicOrder memory orderOne = validBAYCId9948Order();
        BasicOrder memory orderTwo = validBAYCId8350Order();
        BasicOrder[] memory orders = new BasicOrder[](2);
        orders[0] = orderOne;
        orders[1] = orderTwo;

        bytes[] memory ordersExtraData = new bytes[](2);
        {
            bytes memory orderOneExtraData = validBAYCId9948OrderExtraData();
            bytes memory orderTwoExtraData = validBAYCId8350OrderExtraData();
            ordersExtraData[0] = orderOneExtraData;
            ordersExtraData[1] = orderTwoExtraData;
        }

        bytes memory extraData = validMultipleItemsSameCollectionExtraData();
        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        tradeData[0] = ILooksRareAggregator.TradeData({
            proxy: address(seaportProxy),
            selector: SeaportProxy.execute.selector,
            value: 0,
            maxFeeBp: 250,
            orders: orders,
            ordersExtraData: ordersExtraData,
            extraData: extraData
        });

        return tradeData;
    }
}
