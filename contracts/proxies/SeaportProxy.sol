// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";

import {CollectionType} from "../libraries/OrderEnums.sol";
import {BasicOrder, FeeData} from "../libraries/OrderStructs.sol";
import {ItemType, OrderType} from "../libraries/seaport/ConsiderationEnums.sol";
import {AdvancedOrder, CriteriaResolver, OrderParameters, OfferItem, ConsiderationItem, FulfillmentComponent, AdditionalRecipient} from "../libraries/seaport/ConsiderationStructs.sol";
import {IProxy} from "../interfaces/IProxy.sol";
import {SeaportInterface} from "../interfaces/SeaportInterface.sol";
import {TokenRescuer} from "../TokenRescuer.sol";

/**
 * @title SeaportProxy
 * @notice This contract allows NFT sweepers to batch buy NFTs from Seaport
 *         by passing high-level structs + low-level bytes as calldata.
 * @author LooksRare protocol team (👀,💎)
 */
contract SeaportProxy is IProxy, TokenRescuer {
    SeaportInterface public immutable marketplace;
    address public immutable aggregator;

    error TradeExecutionFailed();

    struct ExtraData {
        FulfillmentComponent[][] offerFulfillments; // Contains the order and item index of each offer item
        FulfillmentComponent[][] considerationFulfillments; // Contains the order and item index of each consideration item
    }

    struct OrderExtraData {
        uint120 numerator; // A fraction to attempt to fill
        uint120 denominator; // The total size of the order
        OrderType orderType; // Seaport order type
        address zone; // A zone can cancel the order or restrict who can fulfill the order depending on the type
        bytes32 zoneHash; // An arbitrary 32-byte value that will be supplied to the zone when fulfilling restricted orders that the zone can utilize when making a determination on whether to authorize the order
        uint256 salt; // An arbitrary source of entropy for the order
        bytes32 conduitKey; // A bytes32 value that indicates what conduit, if any, should be utilized as a source for token approvals when performing transfers
        AdditionalRecipient[] recipients; // Recipients of consideration items
    }

    /**
     * @param _marketplace Seaport's address
     * @param _aggregator LooksRareAggregator's address
     */
    constructor(address _marketplace, address _aggregator) {
        marketplace = SeaportInterface(_marketplace);
        aggregator = _aggregator;
    }

    /**
     * @notice Execute Seaport NFT sweeps in a single transaction
     * @param orders Orders to be executed by Seaport
     * @param ordersExtraData Extra data for each order
     * @param extraData Extra data for the whole transaction
     * @param recipient The address to receive the purchased NFTs
     * @param isAtomic Flag to enable atomic trades (all or nothing) or partial trades
     * @param feeBp Fee basis point to pay for the trade, set by the aggregator
     * @param feeRecipient Fee recipient for the trade, set by the aggregator
     */
    function execute(
        BasicOrder[] calldata orders,
        bytes[] calldata ordersExtraData,
        bytes calldata extraData,
        address recipient,
        bool isAtomic,
        uint256 feeBp,
        address feeRecipient
    ) external payable override {
        if (address(this) != aggregator) revert InvalidCaller();

        uint256 ordersLength = orders.length;
        if (ordersLength == 0 || ordersLength != ordersExtraData.length) revert InvalidOrderLength();

        if (isAtomic) {
            _executeAtomicOrders(orders, ordersExtraData, extraData, recipient, feeBp, feeRecipient);
        } else {
            _executeNonAtomicOrders(orders, ordersExtraData, recipient, feeBp, feeRecipient);
        }
    }

    /**
     * @dev If fulfillAvailableAdvancedOrders fails, the ETH paid to Seaport
     *      is refunded to the proxy contract. The proxy then has to refund
     *      the ETH back to the user through _returnETHIfAny.
     */
    receive() external payable {}

    function _executeAtomicOrders(
        BasicOrder[] calldata orders,
        bytes[] calldata ordersExtraData,
        bytes calldata extraData,
        address recipient,
        uint256 feeBp,
        address feeRecipient
    ) private {
        uint256 ordersLength = orders.length;
        AdvancedOrder[] memory advancedOrders = new AdvancedOrder[](ordersLength);
        ExtraData memory extraDataStruct = abi.decode(extraData, (ExtraData));

        uint256 ethValue;

        for (uint256 i; i < ordersLength; ) {
            OrderExtraData memory orderExtraData = abi.decode(ordersExtraData[i], (OrderExtraData));
            advancedOrders[i].parameters = _populateParameters(orders[i], orderExtraData);
            advancedOrders[i].numerator = orderExtraData.numerator;
            advancedOrders[i].denominator = orderExtraData.denominator;
            advancedOrders[i].signature = orders[i].signature;

            if (orders[i].currency == address(0)) ethValue += orders[i].price;

            unchecked {
                ++i;
            }
        }

        (bool[] memory availableOrders, ) = marketplace.fulfillAvailableAdvancedOrders{value: ethValue}(
            advancedOrders,
            new CriteriaResolver[](0),
            extraDataStruct.offerFulfillments,
            extraDataStruct.considerationFulfillments,
            bytes32(0),
            recipient,
            ordersLength
        );

        for (uint256 i; i < availableOrders.length; ) {
            if (!availableOrders[i]) revert TradeExecutionFailed();
            unchecked {
                ++i;
            }
        }

        if (feeRecipient != address(0)) _handleFees(orders, feeBp, feeRecipient);
    }

    function _handleFees(
        BasicOrder[] calldata orders,
        uint256 feeBp,
        address feeRecipient
    ) private {
        address lastOrderCurrency;
        uint256 fee;
        uint256 ordersLength = orders.length;

        for (uint256 i; i < ordersLength; ) {
            address currency = orders[i].currency;
            uint256 orderFee = (orders[i].price * feeBp) / 10000;

            if (currency == lastOrderCurrency) {
                fee += orderFee;
            } else {
                if (fee > 0) _transferFee(fee, lastOrderCurrency, feeRecipient);

                lastOrderCurrency = currency;
                fee = orderFee;
            }

            unchecked {
                ++i;
            }
        }

        if (fee > 0) _transferFee(fee, lastOrderCurrency, feeRecipient);
    }

    function _transferFee(
        uint256 fee,
        address lastOrderCurrency,
        address recipient
    ) private {
        if (lastOrderCurrency == address(0)) {
            _transferETH(recipient, fee);
        } else {
            _executeERC20DirectTransfer(lastOrderCurrency, recipient, fee);
        }
    }

    function _executeNonAtomicOrders(
        BasicOrder[] calldata orders,
        bytes[] calldata ordersExtraData,
        address recipient,
        uint256 feeBp,
        address feeRecipient
    ) private {
        uint256 fee;
        address lastOrderCurrency;
        for (uint256 i; i < orders.length; ) {
            OrderExtraData memory orderExtraData = abi.decode(ordersExtraData[i], (OrderExtraData));
            AdvancedOrder memory advancedOrder;
            advancedOrder.parameters = _populateParameters(orders[i], orderExtraData);
            advancedOrder.numerator = orderExtraData.numerator;
            advancedOrder.denominator = orderExtraData.denominator;
            advancedOrder.signature = orders[i].signature;

            address currency = orders[i].currency;
            uint256 price = orders[i].price;

            try
                marketplace.fulfillAdvancedOrder{value: currency == address(0) ? price : 0}(
                    advancedOrder,
                    new CriteriaResolver[](0),
                    bytes32(0),
                    recipient
                )
            {
                if (feeRecipient != address(0)) {
                    uint256 orderFee = (price * feeBp) / 10000;
                    if (currency == lastOrderCurrency) {
                        fee += orderFee;
                    } else {
                        if (fee > 0) _transferFee(fee, lastOrderCurrency, feeRecipient);

                        lastOrderCurrency = currency;
                        fee = orderFee;
                    }
                }
            } catch {}

            unchecked {
                ++i;
            }
        }

        if (fee > 0) _transferFee(fee, lastOrderCurrency, feeRecipient);
    }

    function _populateParameters(BasicOrder calldata order, OrderExtraData memory orderExtraData)
        private
        pure
        returns (OrderParameters memory parameters)
    {
        uint256 recipientsLength = orderExtraData.recipients.length;

        parameters.offerer = order.signer;
        parameters.zone = orderExtraData.zone;
        parameters.zoneHash = orderExtraData.zoneHash;
        parameters.salt = orderExtraData.salt;
        parameters.conduitKey = orderExtraData.conduitKey;
        parameters.orderType = orderExtraData.orderType;
        parameters.startTime = order.startTime;
        parameters.endTime = order.endTime;
        parameters.totalOriginalConsiderationItems = recipientsLength;

        OfferItem[] memory offer = new OfferItem[](1);
        // Seaport enums start with NATIVE and ERC20 so plus 2
        offer[0].itemType = ItemType(uint8(order.collectionType) + 2);
        offer[0].token = order.collection;
        offer[0].identifierOrCriteria = order.tokenIds[0];
        uint256 amount = order.amounts[0];
        offer[0].startAmount = amount;
        offer[0].endAmount = amount;
        parameters.offer = offer;

        ConsiderationItem[] memory consideration = new ConsiderationItem[](recipientsLength);
        for (uint256 j; j < recipientsLength; ) {
            // We don't need to assign value to identifierOrCriteria as it is always 0.
            uint256 recipientAmount = orderExtraData.recipients[j].amount;
            consideration[j].startAmount = recipientAmount;
            consideration[j].endAmount = recipientAmount;
            consideration[j].recipient = payable(orderExtraData.recipients[j].recipient);
            consideration[j].itemType = order.currency == address(0) ? ItemType.NATIVE : ItemType.ERC20;
            consideration[j].token = order.currency;

            unchecked {
                ++j;
            }
        }
        parameters.consideration = consideration;
    }
}
