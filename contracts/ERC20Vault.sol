// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IERC20Vault} from "./interfaces/IERC20Vault.sol";
import {EIP712} from "./utils/EIP712.sol";
import {ERC1271} from "./utils/ERC1271.sol";
import {OwnableByERC721} from "./utils/OwnableByERC721.sol";

/// @title ERC20 Vault
/// @dev Contract that can hold ETH and ERC20 tokens. Instances are ownable by an NFT.
contract ERC20Vault is
    IVault,
    IERC20Vault,
    EIP712("Vault", "1.0.0"),
    ERC1271,
    OwnableByERC721,
    Initializable
{
    using SafeMath for uint256;

    string public constant VERSION = "1.0.0";

    /* storage */

    uint256 internal _nonce;

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

    /* getter functions */

    /** 
        @dev Calculates permission using EIP712.
        @param eip712TypeHash EIP712 function signature.
        @param delegate Beneficiary of the permission.
        @param token Address of token.
        @param amount Amount of the token for which permission to spend is being granted.
        @param nonce Random data to prevent reusing of permission multiple times. Contract nonce could be a good candidate.
        @return permissionHash Hash of the calculated permission
    */
    function getPermissionHash(
        bytes32 eip712TypeHash,
        address delegate,
        address token,
        uint256 amount,
        uint256 nonce
    ) public view override returns (bytes32 permissionHash) {
        return EIP712._hashTypedDataV4(keccak256(abi.encode(eip712TypeHash, delegate, token, amount, nonce)));
    }

    function getNonce() external view override returns (uint256 nonce) {
        return _nonce;
    }

    function owner() public view override(IVault, OwnableByERC721) returns (address ownerAddress) {
        return OwnableByERC721.owner();
    }

    /* user functions */

    /** 
        @dev Transfer ERC20 tokens out of the vault. Access control: only owner. Token transfer: transfer any ERC20 token.
        @param token Address of token being transferred.
        @param to Address of the recipient.
        @param amount Amount of tokens to transfer.
    */
    function transferERC20(
        address token,
        address to,
        uint256 amount
    ) external override onlyOwner {
        // check for sufficient balance
        require(IERC20(token).balanceOf(address(this)) >= amount, "ERC20Vault: insufficient balance");
        // perform transfer
        TransferHelper.safeTransfer(token, to, amount);
    }

    /// @dev Transfer ETH out of the vault.
    /// @param to Address of the recipient
    /// @param amount Amount of ETH to transfer
    function transferETH(address to, uint256 amount) external payable override onlyOwner {
        // perform transfer
        TransferHelper.safeTransferETH(to, amount);
    }
}
