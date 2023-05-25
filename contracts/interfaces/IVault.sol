// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;
interface IVault {

    /* initialize function */

    function initialize() external;

    /* user functions */

    function transferETH(address to, uint256 amount) external payable;

    /* getter functions */

    function getNonce() external view returns (uint256 nonce);

    function owner() external view returns (address ownerAddress);

    function getPermissionHash(
        bytes32 eip712TypeHash,
        address delegate,
        address token,
        uint256 data,
        uint256 nonce
    ) external view returns (bytes32 permissionHash);
}