// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script} from "forge-std/Script.sol";
import {ERC20EnabledLooksRareAggregator} from "../contracts/ERC20EnabledLooksRareAggregator.sol";
import {LooksRareAggregator} from "../contracts/LooksRareAggregator.sol";
import {LooksRareProxy} from "../contracts/proxies/LooksRareProxy.sol";
import {SeaportProxy} from "../contracts/proxies/SeaportProxy.sol";

contract Deployment is Script {
    ERC20EnabledLooksRareAggregator internal erc20EnabledLooksRareAggregator;
    LooksRareAggregator internal looksRareAggregator;
    LooksRareProxy internal looksRareProxy;
    SeaportProxy internal seaportProxy;

    error WrongChain();

    function _run(address looksrare, address seaport) internal {
        vm.startBroadcast();

        looksRareAggregator = new LooksRareAggregator();

        erc20EnabledLooksRareAggregator = new ERC20EnabledLooksRareAggregator(address(looksRareAggregator));
        looksRareAggregator.setERC20EnabledLooksRareAggregator(address(erc20EnabledLooksRareAggregator));

        _deployLooksRareProxy(looksrare);
        _deploySeaportProxy(seaport);

        vm.stopBroadcast();
    }

    function _deployLooksRareProxy(address marketplace) private {
        looksRareProxy = new LooksRareProxy(marketplace);
        looksRareAggregator.addFunction(address(looksRareProxy), LooksRareProxy.execute.selector);
    }

    function _deploySeaportProxy(address marketplace) private {
        seaportProxy = new SeaportProxy(marketplace);
        looksRareAggregator.addFunction(address(seaportProxy), SeaportProxy.execute.selector);
    }
}
