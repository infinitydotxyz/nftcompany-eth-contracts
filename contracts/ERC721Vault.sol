// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IERC721Vault} from "./interfaces/IERC721Vault.sol";
import {EIP712} from "./utils/EIP712.sol";
import {ERC1271} from "./utils/ERC1271.sol";
import {OwnableByERC721} from "./utils/OwnableByERC721.sol";

/// @title ERC20 Vault
/// @dev Contract that can hold ETH and ERC721 tokens. Instances are ownable by an NFT.
contract ERC721Vault is
    IVault,
    IERC721Vault,
    EIP712("Vault", "1.0.0"),
    ERC1271,
    OwnableByERC721,
    Initializable,
    IERC721Receiver
{
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    string public constant VERSION = "1.0.0";

    /* storage */

    uint256 internal _nonce;

    EnumerableSet.AddressSet internal _vaultERC721Types;
    // nft type to id mapping
    mapping(address => EnumerableSet.UintSet) internal _vaultERC721s;

    /* initialization function */

    /**
        @dev Should be called by a NFT minting contract as part of the mint function.
     */
    function initialize() external override initializer {
        OwnableByERC721._setNFT(msg.sender);
    }

    /**
        @dev Fallback function that allows the contract to receive ETH. 
     */
    receive() external payable {}

    /* internal overrides */

    function _getOwner() internal view override(ERC1271) returns (address ownerAddress) {
        return OwnableByERC721.owner();
    }

    /* overrides */

    /**
        @dev Function that gets called on receipt of an ERC721 token.
        @param operator Address of the operator
        @param from Address of the sender
        @param tokenId Id of the ERC721
        @param data Any additional data
        @return The bytes representing the onERC721Received selector 
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
       emit ERC721Received(operator, from, tokenId, data);
       return IERC721Receiver.onERC721Received.selector;
    }

    /* getter functions */

    /** 
        @dev Calculates permission using EIP712.
        @param eip712TypeHash EIP712 function signature.
        @param delegate Beneficiary of the permission.
        @param token Address of ERC721 contract that minted this token.
        @param tokenId Id of the ERC721 token.
        @param nonce Random data to prevent reusing of permission multiple times. Contract nonce could be a good candidate.
        @return permissionHash Hash of the calculated permission
    */
    function getPermissionHash(
        bytes32 eip712TypeHash,
        address delegate,
        address token,
        uint256 tokenId,
        uint256 nonce
    ) public view override returns (bytes32 permissionHash) {
        return EIP712._hashTypedDataV4(keccak256(abi.encode(eip712TypeHash, delegate, token, tokenId, nonce)));
    }

    function getNonce() external view override returns (uint256 nonce) {
        return _nonce;
    }

    function owner() public view override(IVault, OwnableByERC721) returns (address ownerAddress) {
        return OwnableByERC721.owner();
    }

    function getNumERC721TypesInVault() public view override returns (uint256 count) {
        return _vaultERC721Types.length();
    }
    function getERC721TypeInVaultAt(uint index) public view override returns (address token) {
        return _vaultERC721Types.at(index);
    }

    function getERC721VaultBalance(address token) public view override returns (uint256 balance) {
        return _vaultERC721s[token].length();
    }

    function getERC721InVaultAt(address token, uint index) public view override returns (uint256 tokenId) {
        return _vaultERC721s[token].at(index);
    }

    /* user functions */

    /** 
        @dev Transfer ERC721 tokens out of the vault. Access control: only owner. Token transfer: transfer any ERC721 token.
        @param token Address of ERC721 contract that minted this token.
        @param to Address of the recipient.
        @param tokenId Id of the ERC721 token.
    */
    function transferERC721(
        address token,
        address to,
        uint256 tokenId
    ) external override onlyOwner {
        // validate ownership
        require(
            IERC721(token).ownerOf(tokenId) == address(this),
            "ERC721Vault: vault not owner of nft"
        );

        _vaultERC721s[token].remove(tokenId);
        if (_vaultERC721s[token].length() == 0) {
            _vaultERC721Types.remove(token);
        }

        // perform transfer
        IERC721(token).safeTransferFrom(address(this), to, tokenId);
    }

    /// @dev Transfer ETH out of the vault.
    /// @param to Address of the recipient
    /// @param amount Amount of ETH to transfer
    function transferETH(address to, uint256 amount) external payable override onlyOwner {
        // perform transfer
        TransferHelper.safeTransferETH(to, amount);
    }
}
