// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Deployment} from "./Deployment.s.sol";

contract GoerliDeployment is Deployment {
    address private constant LOOKSRARE = 0xD112466471b5438C1ca2D218694200e49d81D047;
    address private constant SEAPORT = 0x00000000006c3852cbEf3e08E8dF289169EdE581;

    function run() public {
        if (block.chainid != 5) revert WrongChain();
        _run(LOOKSRARE, SEAPORT);
    }
}
