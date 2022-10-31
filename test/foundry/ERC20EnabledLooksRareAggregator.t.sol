// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20EnabledLooksRareAggregator} from "../../contracts/ERC20EnabledLooksRareAggregator.sol";
import {IERC20EnabledLooksRareAggregator} from "../../contracts/interfaces/IERC20EnabledLooksRareAggregator.sol";
import {ILooksRareAggregator} from "../../contracts/interfaces/ILooksRareAggregator.sol";
import {TokenTransfer} from "../../contracts/libraries/OrderStructs.sol";
import {MockERC20} from "./utils/MockERC20.sol";
import {TestHelpers} from "./TestHelpers.sol";
import {TestParameters} from "./TestParameters.sol";

/**
 * @notice ERC20EnabledLooksRareAggregator tests, tests involving actual executions live in other tests
 */
contract ERC20EnabledLooksRareAggregatorTest is TestParameters, TestHelpers {
    ERC20EnabledLooksRareAggregator private erc20EnabledLooksRareAggregator;
    MockERC20 private erc20;
    uint256 private constant amount = 1 ether;

    function setUp() public {
        erc20EnabledLooksRareAggregator = new ERC20EnabledLooksRareAggregator(_fakeAggregator);
        erc20 = new MockERC20();

        erc20.mint(_buyer, amount);
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](1);
        tokenTransfers[0].amount = amount;
        tokenTransfers[0].currency = address(erc20);

        vm.prank(_buyer);
        erc20.approve(address(erc20EnabledLooksRareAggregator), amount);
    }

    function testBuyZeroTokenTransfers() public {
        TokenTransfer[] memory tokenTransfers = new TokenTransfer[](0);
        ILooksRareAggregator.TradeData[] memory tradeData = new ILooksRareAggregator.TradeData[](1);
        vm.expectRevert(IERC20EnabledLooksRareAggregator.UseLooksRareAggregatorDirectly.selector);
        erc20EnabledLooksRareAggregator.execute(tokenTransfers, tradeData, _buyer, false);
    }
}
