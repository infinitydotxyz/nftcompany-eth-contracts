// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;
interface IERC721Vault {
    /* user events */

    event ERC721Received(address operator, address from, uint256 tokenId, bytes data);

    /* user functions */

    function transferERC721(
        address token,
        address to,
        uint256 tokenId
    ) external;

    /* getter functions */

    function getNumERC721TypesInVault() external view returns (uint256 count);

    function getERC721TypeInVaultAt(uint index) external view returns (address token);

    function getERC721VaultBalance(address token) external view returns (uint256 balance);

    function getERC721InVaultAt(address token, uint index) external view returns (uint256 tokenId);
}