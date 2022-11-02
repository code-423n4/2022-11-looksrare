// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        _mint(account, id, amount, data);
    }

    function uri(uint256) public pure override returns (string memory) {
        return "uri";
    }
}
