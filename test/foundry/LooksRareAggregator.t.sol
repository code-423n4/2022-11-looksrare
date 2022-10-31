// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LooksRareAggregator} from "../../contracts/LooksRareAggregator.sol";
import {ERC20EnabledLooksRareAggregator} from "../../contracts/ERC20EnabledLooksRareAggregator.sol";
import {LooksRareProxy} from "../../contracts/proxies/LooksRareProxy.sol";
import {TokenRescuer} from "../../contracts/TokenRescuer.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {BasicOrder, TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";
import {MockERC20} from "./utils/MockERC20.sol";
import {MockERC721} from "./utils/MockERC721.sol";
import {MockERC1155} from "./utils/MockERC1155.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";
import {TokenRescuerTest} from "./TokenRescuer.t.sol";

/**
 * @notice LooksRareAggregator tests, tests involving actual executions live in other tests
 */
contract LooksRareAggregatorTest is TestParameters, TestHelpers, TokenRescuerTest {
    LooksRareAggregator private aggregator;
    LooksRareProxy private looksRareProxy;
    TokenRescuer private tokenRescuer;

    function setUp() public {
        aggregator = new LooksRareAggregator();
        tokenRescuer = TokenRescuer(address(aggregator));
        looksRareProxy = new LooksRareProxy(LOOKSRARE_V1, address(aggregator));
    }

    function testSetERC20EnabledLooksRareAggregator() public {
        assertEq(address(aggregator.erc20EnabledLooksRareAggregator()), address(0));
        vm.expectEmit(true, false, false, false);
        emit ERC20EnabledLooksRareAggregatorSet();
        address erc20EnabledLooksRareAggregator = address(new ERC20EnabledLooksRareAggregator(address(aggregator)));
        aggregator.setERC20EnabledLooksRareAggregator(erc20EnabledLooksRareAggregator);
        assertEq(address(aggregator.erc20EnabledLooksRareAggregator()), erc20EnabledLooksRareAggregator);
    }

    function testSetERC20EnabledLooksRareAggregatorAlreadySet() public {
        address erc20EnabledLooksRareAggregator = address(new ERC20EnabledLooksRareAggregator(address(aggregator)));
        aggregator.setERC20EnabledLooksRareAggregator(erc20EnabledLooksRareAggregator);
        assertEq(address(aggregator.erc20EnabledLooksRareAggregator()), erc20EnabledLooksRareAggregator);

        vm.expectRevert(ILooksRareAggregator.AlreadySet.selector);
        aggregator.setERC20EnabledLooksRareAggregator(erc20EnabledLooksRareAggregator);
    }

    function testSetERC20EnabledLooksRareAggregatorNotOwner() public {
        address erc20EnabledLooksRareAggregator = address(new ERC20EnabledLooksRareAggregator(address(aggregator)));
        vm.prank(_notOwner);
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        aggregator.setERC20EnabledLooksRareAggregator(erc20EnabledLooksRareAggregator);
    }

    function testAddFunction() public {
        assertTrue(!aggregator.supportsProxyFunction(address(looksRareProxy), LooksRareProxy.execute.selector));
        vm.expectEmit(true, true, false, true);
        emit FunctionAdded(address(looksRareProxy), LooksRareProxy.execute.selector);
        aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
        assertTrue(aggregator.supportsProxyFunction(address(looksRareProxy), LooksRareProxy.execute.selector));
    }

    function testAddFunctionNotOwner() public {
        vm.prank(_notOwner);
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
    }

    function testRemoveFunction() public {
        assertTrue(!aggregator.supportsProxyFunction(address(looksRareProxy), LooksRareProxy.execute.selector));
        aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
        assertTrue(aggregator.supportsProxyFunction(address(looksRareProxy), LooksRareProxy.execute.selector));

        vm.expectEmit(true, true, false, true);
        emit FunctionRemoved(address(looksRareProxy), LooksRareProxy.execute.selector);
        aggregator.removeFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
        assertTrue(!aggregator.supportsProxyFunction(address(looksRareProxy), LooksRareProxy.execute.selector));
    }

    function testRemoveFunctionNotOwner() public {
        aggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);

        vm.prank(_notOwner);
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        aggregator.removeFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
    }

    function testApprove() public {
        MockERC20 erc20 = new MockERC20();
        uint256 amount = type(uint256).max;
        assertEq(erc20.allowance(address(aggregator), address(looksRareProxy)), 0);
        aggregator.approve(address(looksRareProxy), address(erc20), amount);
        assertEq(erc20.allowance(address(aggregator), address(looksRareProxy)), amount);
    }

    function testApproveNotOwner() public {
        MockERC20 erc20 = new MockERC20();
        vm.prank(_buyer);
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        aggregator.approve(address(erc20), address(looksRareProxy), type(uint256).max);
    }

    function testRescueETH() public {
        _testRescueETH(tokenRescuer);
    }

    function testRescueETHNotOwner() public {
        _testRescueETHNotOwner(tokenRescuer);
    }

    function testRescueERC20() public {
        _testRescueERC20(tokenRescuer);
    }

    function testRescueERC20NotOwner() public {
        _testRescueERC20NotOwner(tokenRescuer);
    }

    function testRescueERC721() public {
        MockERC721 mockERC721 = new MockERC721();
        mockERC721.mint(address(aggregator), 0);
        aggregator.rescueERC721(address(mockERC721), _luckyUser, 0);
        assertEq(mockERC721.balanceOf(address(_luckyUser)), 1);
        assertEq(mockERC721.balanceOf(address(aggregator)), 0);
        assertEq(mockERC721.ownerOf(0), _luckyUser);
    }

    function testRescueERC721NotOwner() public {
        MockERC721 mockERC721 = new MockERC721();
        mockERC721.mint(address(aggregator), 0);
        vm.prank(_luckyUser);
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        aggregator.rescueERC721(address(mockERC721), _luckyUser, 0);
        assertEq(mockERC721.balanceOf(address(_luckyUser)), 0);
        assertEq(mockERC721.balanceOf(address(aggregator)), 1);
        assertEq(mockERC721.ownerOf(0), address(aggregator));
    }

    function testRescueERC1155() public {
        MockERC1155 mockERC1155 = new MockERC1155();
        mockERC1155.mint(address(aggregator), 0, 2, "");
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        aggregator.rescueERC1155(address(mockERC1155), _luckyUser, tokenIds, amounts);
        assertEq(mockERC1155.balanceOf(address(_luckyUser), 0), 2);
        assertEq(mockERC1155.balanceOf(address(aggregator), 0), 0);
    }

    function testRescueERC1155NotOwner() public {
        MockERC1155 mockERC1155 = new MockERC1155();
        mockERC1155.mint(address(aggregator), 0, 2, "");
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        vm.prank(_luckyUser);
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        aggregator.rescueERC1155(address(mockERC1155), _luckyUser, tokenIds, amounts);
        assertEq(mockERC1155.balanceOf(address(_luckyUser), 0), 0);
        assertEq(mockERC1155.balanceOf(address(aggregator), 0), 2);
    }

    function testExecuteZeroOrders() public {
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);
        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](0);
        vm.expectRevert(ILooksRareAggregator.InvalidOrderLength.selector);
        aggregator.execute(tokenTransfers, tradeData, _buyer, _buyer, false);
    }

    function testExecuteZeroRecipient() public {
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);
        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        vm.expectRevert(ILooksRareAggregator.ZeroAddress.selector);
        aggregator.execute(tokenTransfers, tradeData, _buyer, address(0), false);
    }

    function testBuyWithERC20ButMsgSenderIsNotERC20EnabledLooksRareAggregator() public {
        MockERC20 erc20 = new MockERC20();
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = 1 ether;
        tokenTransfers[0].currency = address(erc20);

        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);

        vm.expectRevert(ILooksRareAggregator.UseERC20EnabledLooksRareAggregator.selector);
        aggregator.execute(tokenTransfers, tradeData, _buyer, _buyer, false);
    }

    function testSetFee() public {
        aggregator.setFee(address(looksRareProxy), 10000, _notOwner);
    }

    function testSetFeeNotOwner() public {
        vm.prank(_notOwner);
        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        aggregator.setFee(address(looksRareProxy), 10000, _notOwner);
    }

    function testSetFeeTooHigh() public {
        vm.expectRevert(ILooksRareAggregator.FeeTooHigh.selector);
        aggregator.setFee(address(looksRareProxy), 10001, _notOwner);
    }
}
