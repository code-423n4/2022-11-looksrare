// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Deployment} from "./Deployment.s.sol";

contract MainnetDeployment is Deployment {
    address private constant LOOKSRARE = 0x59728544B08AB483533076417FbBB2fD0B17CE3a;
    address private constant SEAPORT = 0x00000000006c3852cbEf3e08E8dF289169EdE581;

    function run() public {
        if (block.chainid != 1) revert WrongChain();
        _run(LOOKSRARE, SEAPORT);
    }
}
