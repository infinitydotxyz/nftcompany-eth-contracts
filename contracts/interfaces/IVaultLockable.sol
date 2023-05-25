// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {IVault} from "./IVault.sol";
interface IVaultLockable is IVault {
    /* user events */

    event RageQuit(address delegate, address token, bool notified, string reason);

    /* data types */

    struct LockData {
        address delegate;
        address token;
        uint256 balance;
    }

    /* user functions */

    function rageQuit(address delegate, address token) external returns (bool notified, string memory error);

    /* pure functions */

    function calculateLockID(address delegate, address token)
        external
        pure
        returns (bytes32 lockID);

    /* getter functions */

    function getLockSetCount() external view returns (uint256 count);

    function getLockAt(uint256 index) external view returns (LockData memory lockData);

    function getBalanceDelegated(address token, address delegate)
        external
        view
        returns (uint256 balance);

    function getHighestBalanceLocked(address token) external view returns (uint256 balance);
}