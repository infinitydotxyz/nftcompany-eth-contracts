// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;
interface IERC20Vault {

    function transferERC20(
        address token,
        address to,
        uint256 amount
    ) external;
}