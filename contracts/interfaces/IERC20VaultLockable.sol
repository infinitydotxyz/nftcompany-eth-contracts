// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {IERC20Vault} from "./IERC20Vault.sol";
interface IERC20VaultLockable is IERC20Vault {
    /* user events */

    event ERC20Locked(address delegate, address token, uint256 amount);
    event ERC20Unlocked(address delegate, address token, uint256 amount);

    /* user functions */

    function lockERC20(
        address token,
        uint256 amount,
        bytes calldata permission
    ) external;

    function unlockERC20(
        address token,
        uint256 amount,
        bytes calldata permission
    ) external;

    /* getter functions */

    function verifyERC20Balances() external view returns (bool validity);
}