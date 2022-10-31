// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {LowLevelERC20Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC20Transfer.sol";
import {LowLevelETH} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelETH.sol";

/**
 * @title TokenRescuer
 * @notice This contract contains functions to move tokens
 * @author LooksRare protocol team (👀,💎)
 */
contract TokenRescuer is OwnableTwoSteps, LowLevelETH, LowLevelERC20Transfer {
    error InsufficientAmount();

    /**
     * @notice Rescue the contract's trapped ETH
     * @dev Must be called by the current owner
     * @param to Send the contract's ETH balance to this address
     */
    function rescueETH(address to) external onlyOwner {
        uint256 withdrawAmount = address(this).balance - 1;
        if (withdrawAmount == 0) revert InsufficientAmount();
        _transferETH(to, withdrawAmount);
    }

    /**
     * @notice Rescue any of the contract's trapped ERC20 tokens
     * @dev Must be called by the current owner
     * @param currency The address of the ERC20 token to rescue from the contract
     * @param to Send the contract's specified ERC20 token balance to this address
     */
    function rescueERC20(address currency, address to) external onlyOwner {
        uint256 withdrawAmount = IERC20(currency).balanceOf(address(this)) - 1;
        if (withdrawAmount == 0) revert InsufficientAmount();
        _executeERC20DirectTransfer(currency, to, withdrawAmount);
    }
}
