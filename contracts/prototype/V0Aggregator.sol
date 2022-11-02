// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OwnableTwoSteps} from "../OwnableTwoSteps.sol";
import {TokenReceiver} from "../TokenReceiver.sol";
import {TokenRescuer} from "../TokenRescuer.sol";

/**
 * @title V0Aggregator
 * @notice This contract allows NFT sweepers to buy NFTs from different marketplaces
 *         by passing bytes as calldata.
 * @author LooksRare protocol team (👀,💎)
 */
contract V0Aggregator is TokenRescuer, TokenReceiver {
    struct TradeData {
        address proxy;
        bytes data;
        uint256 value;
    }

    mapping(address => mapping(bytes4 => bool)) private _proxyFunctionSelectors;

    event FunctionAdded(address indexed proxy, bytes4 selector);
    event FunctionRemoved(address indexed proxy, bytes4 selector);
    event Sweep(address indexed sweeper);

    error InvalidFunction();
    error InvalidOrderLength();

    function execute(TradeData[] calldata tradeData) external payable {
        uint256 tradeCount = tradeData.length;
        if (tradeCount == 0) revert InvalidOrderLength();

        for (uint256 i; i < tradeCount; ) {
            bytes calldata data = tradeData[i].data;
            bytes4 selector;

            assembly {
                selector := calldataload(data.offset)
            }

            address proxy = tradeData[i].proxy;
            if (!_proxyFunctionSelectors[proxy][selector]) revert InvalidFunction();

            (bool success, bytes memory returnData) = proxy.delegatecall(data);

            if (!success) {
                if (returnData.length > 0) {
                    assembly {
                        let returnDataSize := mload(returnData)
                        revert(add(32, returnData), returnDataSize)
                    }
                }
            }

            unchecked {
                ++i;
            }
        }

        _returnETHIfAny();

        emit Sweep(msg.sender);
    }

    function addFunction(address proxy, bytes4 selector) external onlyOwner {
        _proxyFunctionSelectors[proxy][selector] = true;
        emit FunctionAdded(proxy, selector);
    }

    function removeFunction(address proxy, bytes4 selector) external onlyOwner {
        delete _proxyFunctionSelectors[proxy][selector];
        emit FunctionRemoved(proxy, selector);
    }
}
