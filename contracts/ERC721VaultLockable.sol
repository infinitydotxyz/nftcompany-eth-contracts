// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import {IRageQuit} from "./interfaces/IRageQuit.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IVaultLockable} from "./interfaces/IVaultLockable.sol";
import {IERC721VaultLockable} from "./interfaces/IERC721VaultLockable.sol";
import {EIP712} from "./utils/EIP712.sol";
import {ERC1271} from "./utils/ERC1271.sol";
import {OwnableByERC721} from "./utils/OwnableByERC721.sol";

/// @title ERC721 Vault Lockable
/// @dev Contract that can hold ETH and ERC721 tokens and lock them. Instances are ownable by an NFT.
contract ERC721VaultLockable is
    IVaultLockable,
    IERC721VaultLockable,
    EIP712("Vault", "1.0.0"),
    ERC1271,
    OwnableByERC721,
    Initializable,
    IERC721Receiver
{
    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    /* constant */

    // Hardcoding a gas limit for rageQuit() is required to prevent gas DOS attacks
    // the gas requirement cannot be determined at runtime by querying the delegate
    // as it could potentially be manipulated by a malicious delegate who could force
    // the calls to revert.
    // The gas limit could alternatively be set upon vault initialization or creation
    // of a lock, but the gas consumption trade-offs are not favorable.
    // Ultimately, to avoid a need for fixed gas limits, the EVM would need to provide
    // an error code that allows for reliably catching out-of-gas errors on remote calls.
    uint256 public constant RAGEQUIT_GAS = 500000;
    bytes32 public constant LOCK_ERC721_TYPEHASH =
        keccak256("LockERC721(address delegate,address token,uint256 tokenId,uint256 nonce)");
    bytes32 public constant UNLOCK_ERC721_TYPEHASH =
        keccak256("UnlockERC721(address delegate,address token,uint256 tokenId,uint256 nonce)");
    string public constant VERSION = "1.0.0";

    /* storage */

    uint256 internal _nonce;

    EnumerableSet.AddressSet internal _vaultERC721Types;
    // nft type to id mapping
    mapping(address => EnumerableSet.UintSet) internal _vaultERC721s;

    EnumerableSet.AddressSet internal _lockedERC721Types;
    // nft type to id mapping
    mapping(address => EnumerableSet.UintSet) internal _lockedERC721s;
    mapping(bytes32 => LockData) internal _locks;
    EnumerableSet.Bytes32Set internal _lockSet;

    /* initialization function */

    function initialize() external override initializer {
        OwnableByERC721._setNFT(msg.sender);
    }

    /* ether receive */

    receive() external payable {}

    /* internal overrides */

    function _getOwner() internal view override(ERC1271) returns (address ownerAddress) {
        return OwnableByERC721.owner();
    }

    /* overrides */

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
       emit ERC721Received(operator, from, tokenId, data);
       return IERC721Receiver.onERC721Received.selector;
    }

    /* pure functions */

    function calculateLockID(address delegate, address token) public pure override returns (bytes32 lockID) {
        return keccak256(abi.encodePacked(delegate, token));
    }

    /* getter functions */

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

    function getLockSetCount() external view override returns (uint256 count) {
        return _lockSet.length();
    }

    function getLockAt(uint256 index) external view override returns (LockData memory lockData) {
        return _locks[_lockSet.at(index)];
    }

    function getBalanceDelegated(address token, address delegate) external view override returns (uint256 balance) {
        return _locks[calculateLockID(delegate, token)].balance;
    }

    function getHighestBalanceLocked(address token) public view override returns (uint256 balance) {
        uint256 count = _lockSet.length();
        for (uint256 index; index < count; index++) {
            LockData storage _lockData = _locks[_lockSet.at(index)];
            if (_lockData.token == token && _lockData.balance > balance)
                balance = _lockData.balance;
        }
        return balance;
    }

    function getNumERC721TypesLocked() public view override returns (uint256 count) {
        return _lockedERC721Types.length();
    }
    function getERC721TypeLockedAt(uint index) public view override returns (address token) {
        return _lockedERC721Types.at(index);
    }

    function getERC721LockedBalance(address token) public view override returns (uint256 balance) {
        return _lockedERC721s[token].length();
    }

    function getERC721LockedAt(address token, uint index) public view override returns (uint256 tokenId) {
        return _lockedERC721s[token].at(index);
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

    function verifyERC721Balances() external view override returns (bool validity) {
        // iterate over all token locks and validate sufficient balance
        uint256 count = _lockSet.length();
        for (uint256 index; index < count; index++) {
            // fetch storage lock reference
            LockData storage _lockData = _locks[_lockSet.at(index)];
            // if insufficient balance return false
            if (IERC721(_lockData.token).balanceOf(address(this)) < _lockData.balance) return false;
        }
        // if sufficient balance return true
        return true;
    }

    /* user functions */

    function lockERC721(
        address token,
        uint256 tokenId,
        bytes calldata permission
    ) external override onlyValidSignature(getPermissionHash(LOCK_ERC721_TYPEHASH, msg.sender, token, tokenId, _nonce), permission) {
        // sanity check, can't lock self
        require(
            address(uint160(tokenId)) != address(this),
            "ERC721VaultLockable: can't self lock"
        );

        // validate ownership
        require(
            IERC721(token).ownerOf(tokenId) == address(this),
            "Vault: vault not owner of nft"
        );

        require(
            !_lockedERC721s[token].contains(tokenId),
            "NFT already locked"
        );

        _lockedERC721Types.add(token);
        _lockedERC721s[token].add(tokenId);

        // get lock id
        bytes32 lockID = calculateLockID(msg.sender, token);

        // add lock to storage
        if (_lockSet.contains(lockID)) {
            // if lock already exists, increase amount by 1
            _locks[lockID].balance = _locks[lockID].balance.add(1);
        } else {
            // if does not exist, create new lock
            // add lock to set
            assert(_lockSet.add(lockID));
            // add lock data to storage
            _locks[lockID] = LockData(msg.sender, token, 1);
        }

        // increase nonce
        _nonce += 1;

        // emit event
        emit ERC721Locked(msg.sender, token, tokenId);
    }

    function unlockERC721(
        address token,
        uint256 tokenId,
        bytes calldata permission
    ) external override onlyValidSignature(getPermissionHash(UNLOCK_ERC721_TYPEHASH, msg.sender, token, tokenId, _nonce), permission) {
        // validate ownership
        require(
            IERC721(token).ownerOf(tokenId) == address(this),
            "Vault: vault not owner of nft"
        );

        require(
            _lockedERC721s[token].contains(tokenId),
            "NFT not locked"
        );

        _lockedERC721s[token].remove(tokenId);
        if (_lockedERC721s[token].length() == 0) {
            _lockedERC721Types.remove(token);
        }

        _vaultERC721Types.add(token);
        _vaultERC721s[token].add(tokenId);

        // get lock id
        bytes32 lockID = calculateLockID(msg.sender, token);

        // validate existing lock
        require(_lockSet.contains(lockID), "Vault: missing lock");

        // update lock data
        if (_locks[lockID].balance > 1) {
            // subtract 1 from lock balance
            _locks[lockID].balance = _locks[lockID].balance.sub(1);
        } else {
            // delete lock data
            delete _locks[lockID];
            assert(_lockSet.remove(lockID));
        }

        // increase nonce
        _nonce += 1;

        // emit event
        emit ERC721Unlocked(msg.sender, token, tokenId);
    }

    /// @dev Forcibly cancel delegate lock. This function will attempt to notify the delegate of the rage quit using a 
    /// fixed amount of gas. Access control: only owner
    /// State machine: after valid lock from delegate
    /// State scope: remove item from _locks
    /// Token transfer: none
    /// @param delegate Address of delegate
    /// @param token Address of token being unlocked
    
    function rageQuit(address delegate, address token) external override onlyOwner returns (bool notified, string memory error) {
        // get lock id
        bytes32 lockID = calculateLockID(delegate, token);

        // validate existing lock
        require(_lockSet.contains(lockID), "Vault: missing lock");

        // attempt to notify delegate
        if (delegate.isContract()) {
            // check for sufficient gas
            require(gasleft() >= RAGEQUIT_GAS, "Vault: insufficient gas");

            // attempt rageQuit notification
            try IRageQuit(delegate).rageQuit{gas: RAGEQUIT_GAS}() {
                notified = true;
            } catch Error(string memory res) {
                notified = false;
                error = res;
            } catch (bytes memory) {
                notified = false;
            }
        }

        // update lock storage
        assert(_lockSet.remove(lockID));
        delete _locks[lockID];

        // emit event
        emit RageQuit(delegate, token, notified, error);
    }

    function transferERC721(
        address token,
        address to,
        uint256 tokenId
    ) external override onlyOwner {
        // validate ownership
        require(
            IERC721(token).ownerOf(tokenId) == address(this),
            "ERC721VaultLockable: vault not owner of nft"
        );
        require(
            !_lockedERC721s[token].contains(tokenId),
            "NFT is locked. Unlock first."
        );

        _vaultERC721s[token].remove(tokenId);
        if (_vaultERC721s[token].length() == 0) {
            _vaultERC721Types.remove(token);
        }

        // perform transfer
        IERC721(token).safeTransferFrom(address(this), to, tokenId);
    }

    /// @param to Address of the recipient
    /// @param amount Amount of ETH to transfer
    function transferETH(address to, uint256 amount) external payable override onlyOwner {
        // perform transfer
        TransferHelper.safeTransferETH(to, amount);
    }
}
