// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/// @dev Library to create clones of a contract. This is used by the NFTCompanyFactory to mint NFTs from a template/extension. 
library ProxyFactory {
    /* functions */

    /** @dev Creates a clone of the given contract
        @param logic Address of the contract to clone
        @param data Any init functions to call
        @return proxy Address of the newly deployed clone
    */
    function _create(address logic, bytes memory data) internal returns (address proxy) {
        // deploy
        proxy = Clones.clone(logic);

        // init
        if (data.length > 0) {
            (bool success, bytes memory err) = proxy.call(data);
            require(success, string(err));
        }
    }

    /** @dev Creates a clone of the given contract with salted deterministic deployment
        @param logic Address of the contract to clone
        @param data Any init functions to call
        @param salt Random salt. Using the same salt and same logic for multiple creates will fail.
        @return proxy Address of the newly deployed clone
    */
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
