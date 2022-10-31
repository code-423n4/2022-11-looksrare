// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "solmate/src/tokens/ERC721.sol";

contract MockERC721 is ERC721("MockERC721", "MockERC721") {
    function mint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "tokenURI";
    }
}
