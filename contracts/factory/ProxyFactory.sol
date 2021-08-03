// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

library ProxyFactory {
    /* functions */

    function _create(address logic, bytes memory data) internal returns (address proxy) {
        // deploy
        proxy = Clones.clone(logic);

        // init
        if (data.length > 0) {
            (bool success, bytes memory err) = proxy.call(data);
            require(success, string(err));
        }
    }

    function _create2(address logic, bytes memory data, bytes32 salt) internal returns (address proxy) {
        // deploy
        proxy = Clones.cloneDeterministic(logic, salt);

        // init
        if (data.length > 0) {
            (bool success, bytes memory err) = proxy.call(data);
            require(success, string(err));
        }
    }
}
