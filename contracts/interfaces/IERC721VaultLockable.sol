// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {IERC721Vault} from "./IERC721Vault.sol";
interface IERC721VaultLockable is IERC721Vault {
    /* user events */

    event ERC721Locked(address delegate, address token, uint256 tokenId);
    event ERC721Unlocked(address delegate, address token, uint256 tokenId);

    /* user functions */

    function lockERC721(
        address token,
        uint256 tokenId,
        bytes calldata permission
    ) external;

    function unlockERC721(
        address token,
        uint256 tokenId,
        bytes calldata permission
    ) external;

    /* getter functions */

    function getNumERC721TypesLocked() external view returns (uint256 count);

    function getERC721TypeLockedAt(uint index) external view returns (address token);

    function getERC721LockedBalance(address token) external view returns (uint256 balance);

    function getERC721LockedAt(address token, uint index) external view returns (uint256 tokenId);

    function verifyERC721Balances() external view returns (bool validity);

}