// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import {IRageQuit} from "./interfaces/IRageQuit.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IVaultLockable} from "./interfaces/IVaultLockable.sol";
import {IERC20VaultLockable} from "./interfaces/IERC20VaultLockable.sol";
import {EIP712} from "./utils/EIP712.sol";
import {ERC1271} from "./utils/ERC1271.sol";
import {OwnableByERC721} from "./utils/OwnableByERC721.sol";

/// @title ERC20 Vault Lockable
/// @dev Contract that can hold ETH and ERC20 tokens and lock them. Instances are ownable by an NFT.
contract ERC20VaultLockable is
    IVaultLockable,
    IERC20VaultLockable,
    EIP712("Vault", "1.0.0"),
    ERC1271,
    OwnableByERC721,
    Initializable
{
    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.Bytes32Set;

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
    bytes32 public constant LOCK_TYPEHASH =
        keccak256("LockERC20(address delegate,address token,uint256 amount,uint256 nonce)");
    bytes32 public constant UNLOCK_TYPEHASH =
        keccak256("UnlockERC20(address delegate,address token,uint256 amount,uint256 nonce)");
    string public constant VERSION = "1.0.0";

    /* storage */

    uint256 internal _nonce;
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

    /* pure functions */

    /** 
        @dev Calculates lockID.
        @param delegate Delegate that will operate on the contract.
        @param token Token on which the delegate will operate on.
        @return lockID The calculated lockID
    */
    function calculateLockID(address delegate, address token) public pure override returns (bytes32 lockID) {
        return keccak256(abi.encodePacked(delegate, token));
    }

    /* getter functions */

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

    function getLockSetCount() external view override returns (uint256 count) {
        return _lockSet.length();
    }

    function getLockAt(uint256 index) external view override returns (LockData memory lockData) {
        return _locks[_lockSet.at(index)];
    }

    function getBalanceDelegated(address token, address delegate) external view override returns (uint256 balance) {
        return _locks[calculateLockID(delegate, token)].balance;
    }

    /** 
        @dev Fetches the highest balance locked by a delegate for the given token.
        @param token The locked token
        @return balance The highest locked balance
    */
    function getHighestBalanceLocked(address token) public view override returns (uint256 balance) {
        uint256 count = _lockSet.length();
        for (uint256 index; index < count; index++) {
            LockData storage _lockData = _locks[_lockSet.at(index)];
            if (_lockData.token == token && _lockData.balance > balance)
                balance = _lockData.balance;
        }
        return balance;
    }

    /** 
        @dev Sanity check to make sure that locked balance is not greater than the total balance Rarely used.
        @return validity True or false
    */
    function verifyERC20Balances() external view override returns (bool validity) {
        // iterate over all token locks and validate sufficient balance
        uint256 count = _lockSet.length();
        for (uint256 index; index < count; index++) {
            // fetch storage lock reference
            LockData storage _lockData = _locks[_lockSet.at(index)];
            // if insufficient balance return false
            if (IERC20(_lockData.token).balanceOf(address(this)) < _lockData.balance) return false;
        }
        // if sufficient balance return true
        return true;
    }

    /* user functions */

    /** @dev Lock ERC20 tokens in the vault. Access control: called by delegate with signed permission from owner
        State machine: anytime
        State scope: insert or update _locks, increase _nonce
        Token transfer: none
        @param token Address of token being locked
        @param amount Amount of tokens being locked
        @param permission Permission signature payload
    */
    function lockERC20(
        address token,
        uint256 amount,
        bytes calldata permission
    ) external override onlyValidSignature(getPermissionHash(LOCK_TYPEHASH, msg.sender, token, amount, _nonce), permission) {
        // get lock id
        bytes32 lockID = calculateLockID(msg.sender, token);

        // add lock to storage
        if (_lockSet.contains(lockID)) {
            // if lock already exists, increase amount
            _locks[lockID].balance = _locks[lockID].balance.add(amount);
        } else {
            // if does not exist, create new lock
            // add lock to set
            assert(_lockSet.add(lockID));
            // add lock data to storage
            _locks[lockID] = LockData(msg.sender, token, amount);
        }

        // validate sufficient balance
        require(
            IERC20(token).balanceOf(address(this)) >= _locks[lockID].balance,
            "Vault: insufficient balance"
        );

        // increase nonce
        _nonce += 1;

        // emit event
        emit ERC20Locked(msg.sender, token, amount);
    }

    /** @dev Unlock ERC20 tokens in the vault. Access control: called by delegate with signed permission from owner
        State machine: after valid lock from delegate
        State scope: remove or update _locks, increase _nonce
        Token transfer: none
        @param token Address of token being unlocked
        @param amount Amount of tokens being unlocked
        @param permission Permission signature payload
    */
    function unlockERC20(
        address token,
        uint256 amount,
        bytes calldata permission
    ) external override onlyValidSignature(getPermissionHash(UNLOCK_TYPEHASH, msg.sender, token, amount, _nonce), permission) {
        // get lock id
        bytes32 lockID = calculateLockID(msg.sender, token);

        // validate existing lock
        require(_lockSet.contains(lockID), "Vault: missing lock");

        // update lock data
        if (_locks[lockID].balance > amount) {
            // subtract amount from lock balance
            _locks[lockID].balance = _locks[lockID].balance.sub(amount);
        } else {
            // delete lock data
            delete _locks[lockID];
            assert(_lockSet.remove(lockID));
        }

        // increase nonce
        _nonce += 1;

        // emit event
        emit ERC20Unlocked(msg.sender, token, amount);
    }


    /** @dev Forcibly cancel delegate lock. This function will attempt to notify the delegate of the rage quit using
        a fixed amount of gas. Access control: only owner
        State machine: after valid lock from delegate
        State scope: remove item from _locks
        Token transfer: none
        @param delegate Address of delegate
        @param token Address of token being unlocked
        @return notified Whether delegate contract is notified
        @return error Error string
    */
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

    /// @dev Transfer ERC20 tokens out of vault. Access control: only owner
    /// State machine: when balance >= max(lock) + amount
    /// State scope: none
    /// Token transfer: transfer any token
    /// @param token Address of token being transferred
    /// @param to Address of the recipient
    /// @param amount Amount of tokens to transfer
    function transferERC20(
        address token,
        address to,
        uint256 amount
    ) external override onlyOwner {
        // check for sufficient balance
        require(
            IERC20(token).balanceOf(address(this)) >= getHighestBalanceLocked(token).add(amount),
            "Vault: insufficient balance"
        );
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
