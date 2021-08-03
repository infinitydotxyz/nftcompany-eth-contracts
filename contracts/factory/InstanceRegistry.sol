// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IInstanceRegistry {
    /* events */

    event InstanceAdded(address instance);
    event InstanceRemoved(address instance);

    /* view functions */

    function isInstance(address instance) external view returns (bool validity);

    function instanceCount() external view returns (uint256 count);

    function instanceAt(uint256 index) external view returns (address instance);
}

/** @title Instance Registry
    @notice A simple contract to keep track of instances created from a particular type
    @dev This contract is meant to be used via inheritance by child contracts
*/
contract InstanceRegistry is IInstanceRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* storage */

    EnumerableSet.AddressSet private _instanceSet;

    /* view functions */

    /**
        @dev Checks if the passed address is an instance
        @param instance Address of the instance
        @return validity True if the passed address is an instance, false otherwise
    */
    function isInstance(address instance) external view override returns (bool validity) {
        return _instanceSet.contains(instance);
    }

    /**
        @dev Returns the number of instances created of a type
        @return count Number of instances of this type
    */
    function instanceCount() external view override returns (uint256 count) {
        return _instanceSet.length();
    }

    /**
        @dev Fetches the instance at the given index
        @param index Index into the instance set
        @return instance Address of the instance
    */
    function instanceAt(uint256 index) external view override returns (address instance) {
        return _instanceSet.at(index);
    }

    /* admin functions */

    /**
        @dev Registers an instance by adding it to the instance set. Access control limited to only child contracts. Inheriting child contract should call this method
                        from an access controlled function. Typically, such a function would use
                        a modifier like onlyAdmin or onlyOwner.
        @param instance Address of the instance
    */
    function _register(address instance) internal {
        require(_instanceSet.add(instance), "InstanceRegistry: already registered");
        emit InstanceAdded(instance);
    }
}
