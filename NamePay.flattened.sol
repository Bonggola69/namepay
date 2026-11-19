// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20 ^0.8.24;

// lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/openzeppelin-contracts/contracts/utils/Pausable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable2Step.sol)

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is specified at deployment time in the constructor for `Ownable`. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// src/NamePay.sol

/// @title NamePay — pay anyone by their Agent ID name (.ai) on BNB Chain
/// @notice Resolves a recipient's Agent ID name to an address through the
/// Agent ID ERC-721 contract and pays them in BNB or an allowlisted token.
/// No fees: the contract takes no cut of any payment. The owner can only
/// manage the token allowlist and pause/unpause; the owner cannot move user
/// funds. Recurring payments use an escrow funded up front, never allowances.
contract NamePay is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Agent ID (SPACE ID) ERC-721 contract on BSC.
    /// @dev Immutable, set from the single constructor argument (spec scheme
    /// A: all dependencies known at deploy time). On BSC mainnet this is
    /// 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F (checksummed; solc 0.8.24
    /// rejects the all-lowercase form as an invalid EIP-55 checksum).
    address public immutable AGENT_ID;
    /// @notice USDT on BSC (fixed constant from the spec).
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    /// @notice USDC on BSC (fixed constant from the spec).
    address public constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    /// @notice Maximum recipients in a single split payment.
    uint256 public constant MAX_SPLIT_RECIPIENTS = 20;
    /// @notice Maximum payments in a single subscription.
    uint256 public constant MAX_SUBSCRIPTION_PAYMENTS = 24;
    /// @notice Minimum interval between subscription payments.
    uint256 public constant MIN_SUBSCRIPTION_PERIOD = 1 days;

    // --- custom errors ---

    error InvalidName();
    error NameNotRegistered();
    error TokenNotAllowed();
    error ZeroAmount();
    error ArrayLengthMismatch();
    error TooManyRecipients();
    error RequestNotFound();
    error NotPayer();
    error NotRequester();
    error RequestNotPayable();
    error WrongPaymentAmount();
    error SubscriptionNotFound();
    error NotSubscriber();
    error SubscriptionNotActive();
    error SubscriptionNotDue();
    error InvalidPeriod();
    error InvalidMaxPayments();
    error InsufficientEscrow();
    // NOTE: two errors beyond the spec's list (see README note in the report):
    // a native-BNB transfer that fails at the call site, and a request expiry
    // that is not in the future. Both have no fitting error in the spec's list.
    error TransferFailed();
    error InvalidExpiry();

    // --- structs / enums ---

    struct PaymentRequest {
        uint256 id;
        address requester;
        address payer;
        address token; // address(0) = BNB
        uint256 amount;
        uint256 expiry;
        RequestStatus status;
        string memo;
    }

    struct Subscription {
        uint256 id;
        address subscriber;
        address payee;
        address token; // address(0) = BNB
        uint256 amountPerPeriod;
        uint256 periodSeconds;
        uint256 maxPayments;
        uint256 paymentsMade;
        uint256 nextPaymentDue;
        SubscriptionStatus status;
    }

    enum RequestStatus {
        Pending,
        Paid,
        Cancelled
    }

    enum SubscriptionStatus {
        Active,
        Completed,
        Cancelled
    }

    // --- events ---

    event PaymentSent(
        address indexed sender,
        string senderName,
        address indexed recipient,
        string recipientName,
        address indexed token,
        uint256 amount,
        string memo
    );
    event SplitPaymentSent(address indexed sender, address indexed token, uint256 totalAmount, uint256 recipientCount);
    event RequestCreated(
        uint256 indexed requestId,
        address indexed requester,
        address indexed payer,
        address token,
        uint256 amount,
        uint256 expiry
    );
    event RequestPaid(uint256 indexed requestId, address indexed payer, uint256 amount);
    event RequestCancelled(uint256 indexed requestId, address indexed requester);
    event SubscriptionCreated(
        uint256 indexed subscriptionId,
        address indexed subscriber,
        address indexed payee,
        address token,
        uint256 amountPerPeriod,
        uint256 periodSeconds,
        uint256 maxPayments
    );
    event SubscriptionExecuted(uint256 indexed subscriptionId, uint256 indexed paymentNumber, uint256 amount);
    event SubscriptionCancelled(uint256 indexed subscriptionId, address indexed subscriber, uint256 refunded);
    event NameRegistered(address indexed account, string name);
    event TokenAllowlistUpdated(address indexed token, bool allowed);

    // --- storage ---

    mapping(address => bool) private _tokenAllowed;
    mapping(address => string) private _names;
    mapping(uint256 => PaymentRequest) private _requests;
    mapping(uint256 => Subscription) private _subscriptions;
    uint256 private _nextRequestId = 1;
    uint256 private _nextSubscriptionId = 1;

    /// @notice Deploys NamePay. The constructor takes exactly one argument,
    /// the Agent ID contract address; USDT/USDC are fixed constants above.
    /// @dev Constructor-only init (spec scheme A): all dependencies are known
    /// at deploy time. On BSC mainnet pass the Agent ID address
    /// 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F.
    /// @param agentId_ Agent ID ERC-721 contract address.
    constructor(address agentId_) Ownable(msg.sender) {
        AGENT_ID = agentId_;
        // Native BNB is always an allowed payment asset (address(0)).
        _tokenAllowed[address(0)] = true;
        _tokenAllowed[USDT] = true;
        _tokenAllowed[USDC] = true;
    }

    // --- views ---

    /// @notice Resolves a name label (e.g. "hanta", without ".ai") to its owner's address.
    /// @param name The name label to resolve.
    /// @return The address that owns the Agent ID name.
    function resolveName(string calldata name) external view returns (address) {
        return _resolveName(name);
    }

    /// @notice Returns the name an account registered for display, or "" if none.
    /// @param account The account to look up.
    /// @return The registered name label, or an empty string.
    function nameOf(address account) external view returns (string memory) {
        return _names[account];
    }

    /// @notice Returns whether a token can be used for payments (address(0) = BNB).
    /// @param token The token address to check.
    /// @return True if the token is allowlisted.
    function isTokenAllowed(address token) external view returns (bool) {
        return _tokenAllowed[token];
    }

    /// @notice Returns a payment request by id.
    /// @param requestId The request id.
    /// @return The stored payment request.
    function getRequest(uint256 requestId) external view returns (PaymentRequest memory) {
        PaymentRequest storage req = _requests[requestId];
        if (req.id == 0) revert RequestNotFound();
        return req;
    }

    /// @notice Returns a subscription by id.
    /// @param subscriptionId The subscription id.
    /// @return The stored subscription.
    function getSubscription(uint256 subscriptionId) external view returns (Subscription memory) {
        Subscription storage sub = _subscriptions[subscriptionId];
        if (sub.id == 0) revert SubscriptionNotFound();
        return sub;
    }

    // --- payments ---

    /// @notice Pays BNB to the owner of a name.
    /// @param name The recipient's name label.
    /// @param memo An optional memo recorded in the event.
    function payBNB(string calldata name, string calldata memo) external payable nonReentrant whenNotPaused {
        if (msg.value == 0) revert ZeroAmount();
        address recipient = _resolveName(name);
        _sendBNB(recipient, msg.value);
        emit PaymentSent(msg.sender, _names[msg.sender], recipient, _names[recipient], address(0), msg.value, memo);
    }

    /// @notice Pays an allowlisted token to the owner of a name.
    /// @param token The token to pay with (must be allowlisted, not address(0)).
    /// @param name The recipient's name label.
    /// @param amount The token amount to pay.
    /// @param memo An optional memo recorded in the event.
    function payToken(address token, string calldata name, uint256 amount, string calldata memo)
        external
        nonReentrant
        whenNotPaused
    {
        if (token == address(0) || !_tokenAllowed[token]) revert TokenNotAllowed();
        if (amount == 0) revert ZeroAmount();
        address recipient = _resolveName(name);
        IERC20(token).safeTransferFrom(msg.sender, recipient, amount);
        emit PaymentSent(msg.sender, _names[msg.sender], recipient, _names[recipient], token, amount, memo);
    }

    // --- payment requests ---

    /// @notice Creates a payment request asking the owner of `payerName` to pay.
    /// @param payerName The name label of the person being asked to pay.
    /// @param token The token requested (address(0) = BNB).
    /// @param amount The amount requested.
    /// @param expiry Unix timestamp after which the request can no longer be paid.
    /// @param memo An optional memo.
    /// @return requestId The id of the created request.
    function createRequest(
        string calldata payerName,
        address token,
        uint256 amount,
        uint256 expiry,
        string calldata memo
    ) external whenNotPaused returns (uint256 requestId) {
        address payer = _resolveName(payerName);
        if (token != address(0) && !_tokenAllowed[token]) revert TokenNotAllowed();
        if (amount == 0) revert ZeroAmount();
        if (expiry <= block.timestamp) revert InvalidExpiry();
        requestId = _nextRequestId++;
        _requests[requestId] = PaymentRequest({
            id: requestId,
            requester: msg.sender,
            payer: payer,
            token: token,
            amount: amount,
            expiry: expiry,
            status: RequestStatus.Pending,
            memo: memo
        });
        emit RequestCreated(requestId, msg.sender, payer, token, amount, expiry);
    }

    /// @notice Pays a pending request. Only the recorded payer can call this.
    /// @param requestId The request id to pay.
    function payRequest(uint256 requestId) external payable nonReentrant whenNotPaused {
        PaymentRequest storage req = _requests[requestId];
        if (req.id == 0) revert RequestNotFound();
        if (msg.sender != req.payer) revert NotPayer();
        if (req.status != RequestStatus.Pending || block.timestamp > req.expiry) revert RequestNotPayable();
        // Checks-effects-interactions: mark Paid before moving funds.
        req.status = RequestStatus.Paid;
        if (req.token == address(0)) {
            if (msg.value != req.amount) revert WrongPaymentAmount();
            _sendBNB(req.requester, req.amount);
        } else {
            IERC20(req.token).safeTransferFrom(msg.sender, req.requester, req.amount);
        }
        emit RequestPaid(requestId, msg.sender, req.amount);
    }

    /// @notice Cancels a pending request. Only the requester can call this.
    /// @param requestId The request id to cancel.
    function cancelRequest(uint256 requestId) external {
        PaymentRequest storage req = _requests[requestId];
        if (req.id == 0) revert RequestNotFound();
        if (msg.sender != req.requester) revert NotRequester();
        if (req.status != RequestStatus.Pending) revert RequestNotPayable();
        req.status = RequestStatus.Cancelled;
        emit RequestCancelled(requestId, msg.sender);
    }

    // --- split payments ---

    /// @notice Splits one BNB payment across up to 20 named recipients.
    /// @param names The recipients' name labels.
    /// @param amounts The BNB amount per recipient; the sum must equal msg.value.
    /// @param memo An optional memo recorded in the events.
    function splitPayBNB(string[] calldata names, uint256[] calldata amounts, string calldata memo)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        (address[] memory recipients, uint256 total) = _validateSplit(names, amounts);
        if (msg.value != total) revert WrongPaymentAmount();
        for (uint256 i; i < recipients.length; ++i) {
            _sendBNB(recipients[i], amounts[i]);
            emit PaymentSent(
                msg.sender, _names[msg.sender], recipients[i], _names[recipients[i]], address(0), amounts[i], memo
            );
        }
        emit SplitPaymentSent(msg.sender, address(0), total, recipients.length);
    }

    /// @notice Splits one token payment across up to 20 named recipients.
    /// @param token The token to pay with (must be allowlisted, not address(0)).
    /// @param names The recipients' name labels.
    /// @param amounts The token amount per recipient.
    /// @param memo An optional memo recorded in the events.
    function splitPayToken(address token, string[] calldata names, uint256[] calldata amounts, string calldata memo)
        external
        nonReentrant
        whenNotPaused
    {
        if (token == address(0) || !_tokenAllowed[token]) revert TokenNotAllowed();
        (address[] memory recipients, uint256 total) = _validateSplit(names, amounts);
        IERC20(token).safeTransferFrom(msg.sender, address(this), total);
        for (uint256 i; i < recipients.length; ++i) {
            IERC20(token).safeTransfer(recipients[i], amounts[i]);
            emit PaymentSent(
                msg.sender, _names[msg.sender], recipients[i], _names[recipients[i]], token, amounts[i], memo
            );
        }
        emit SplitPaymentSent(msg.sender, token, total, recipients.length);
    }

    // --- recurring payments (escrow model, NOT allowance) ---

    /// @notice Creates a BNB subscription, funding the whole schedule up front.
    /// @param payeeName The payee's name label.
    /// @param amountPerPeriod The BNB amount paid per period.
    /// @param periodSeconds Seconds between payments (at least 1 day).
    /// @param maxPayments Total number of payments (1-24).
    /// @return subscriptionId The id of the created subscription.
    function createSubscriptionBNB(
        string calldata payeeName,
        uint256 amountPerPeriod,
        uint256 periodSeconds,
        uint256 maxPayments
    ) external payable nonReentrant whenNotPaused returns (uint256 subscriptionId) {
        address payee = _resolveName(payeeName);
        _validateSubscriptionParams(amountPerPeriod, periodSeconds, maxPayments);
        if (msg.value != amountPerPeriod * maxPayments) revert WrongPaymentAmount();
        subscriptionId = _createSubscription(payee, address(0), amountPerPeriod, periodSeconds, maxPayments);
    }

    /// @notice Creates a token subscription, funding the whole schedule up front.
    /// @param token The token to pay with (must be allowlisted, not address(0)).
    /// @param payeeName The payee's name label.
    /// @param amountPerPeriod The token amount paid per period.
    /// @param periodSeconds Seconds between payments (at least 1 day).
    /// @param maxPayments Total number of payments (1-24).
    /// @return subscriptionId The id of the created subscription.
    function createSubscriptionToken(
        address token,
        string calldata payeeName,
        uint256 amountPerPeriod,
        uint256 periodSeconds,
        uint256 maxPayments
    ) external nonReentrant whenNotPaused returns (uint256 subscriptionId) {
        if (token == address(0) || !_tokenAllowed[token]) revert TokenNotAllowed();
        address payee = _resolveName(payeeName);
        _validateSubscriptionParams(amountPerPeriod, periodSeconds, maxPayments);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountPerPeriod * maxPayments);
        subscriptionId = _createSubscription(payee, token, amountPerPeriod, periodSeconds, maxPayments);
    }

    /// @notice Executes one due subscription payment. Callable by anyone (keeper).
    /// @param subscriptionId The subscription id to execute.
    function executeSubscription(uint256 subscriptionId) external nonReentrant whenNotPaused {
        Subscription storage sub = _subscriptions[subscriptionId];
        if (sub.id == 0) revert SubscriptionNotFound();
        if (sub.status != SubscriptionStatus.Active) revert SubscriptionNotActive();
        if (block.timestamp < sub.nextPaymentDue) revert SubscriptionNotDue();
        uint256 amount = sub.amountPerPeriod;
        if (sub.token == address(0)) {
            if (address(this).balance < amount) revert InsufficientEscrow();
        } else if (IERC20(sub.token).balanceOf(address(this)) < amount) {
            revert InsufficientEscrow();
        }
        // Checks-effects-interactions: advance the schedule before paying.
        sub.paymentsMade += 1;
        uint256 paymentNumber = sub.paymentsMade;
        sub.nextPaymentDue += sub.periodSeconds;
        if (sub.paymentsMade == sub.maxPayments) {
            sub.status = SubscriptionStatus.Completed;
        }
        if (sub.token == address(0)) {
            _sendBNB(sub.payee, amount);
        } else {
            IERC20(sub.token).safeTransfer(sub.payee, amount);
        }
        emit SubscriptionExecuted(subscriptionId, paymentNumber, amount);
    }

    /// @notice Cancels an active subscription and refunds the unspent escrow.
    /// Only the subscriber can call this. Works while paused so funds are
    /// never locked by a pause.
    /// @param subscriptionId The subscription id to cancel.
    function cancelSubscription(uint256 subscriptionId) external nonReentrant {
        Subscription storage sub = _subscriptions[subscriptionId];
        if (sub.id == 0) revert SubscriptionNotFound();
        if (msg.sender != sub.subscriber) revert NotSubscriber();
        if (sub.status != SubscriptionStatus.Active) revert SubscriptionNotActive();
        uint256 refund = sub.amountPerPeriod * (sub.maxPayments - sub.paymentsMade);
        sub.status = SubscriptionStatus.Cancelled;
        if (refund > 0) {
            if (sub.token == address(0)) {
                _sendBNB(sub.subscriber, refund);
            } else {
                IERC20(sub.token).safeTransfer(sub.subscriber, refund);
            }
        }
        emit SubscriptionCancelled(subscriptionId, msg.sender, refund);
    }

    // --- names ---

    /// @notice Registers the caller's name for display (reverse mapping).
    /// The caller must own the name on the Agent ID contract.
    /// @param name The name label the caller owns.
    function registerName(string calldata name) external {
        address owner = _resolveName(name);
        // No dedicated error in the spec's list: a name owned by someone else
        // is reported the same way as an unregistered name.
        if (owner != msg.sender) revert NameNotRegistered();
        _names[msg.sender] = name;
        emit NameRegistered(msg.sender, name);
    }

    // --- admin (owner only) ---

    /// @notice Adds or removes a token from the payment allowlist.
    /// @param token The token address.
    /// @param allowed True to allow, false to remove.
    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        _tokenAllowed[token] = allowed;
        emit TokenAllowlistUpdated(token, allowed);
    }

    /// @notice Pauses all user-facing payment functions.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract.
    function unpause() external onlyOwner {
        _unpause();
    }

    // --- internals ---

    /// @notice Validates a name label: 1-63 chars, [a-z0-9-], no leading/trailing "-".
    /// @dev Byte ranges as hex literals (0x61-0x7a = a-z, 0x30-0x39 = 0-9,
    /// 0x2d = "-") so no typecast is involved.
    function _validateName(string calldata name) internal pure {
        bytes calldata raw = bytes(name);
        if (raw.length == 0 || raw.length > 63) revert InvalidName();
        if (raw[0] == 0x2d || raw[raw.length - 1] == 0x2d) revert InvalidName();
        for (uint256 i; i < raw.length; ++i) {
            bytes1 c = raw[i];
            bool ok = (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c == 0x2d;
            if (!ok) revert InvalidName();
        }
    }

    /// @notice Resolves a validated name through the Agent ID contract.
    /// A revert from the Agent ID contract (unclaimed name) maps to
    /// NameNotRegistered.
    function _resolveName(string calldata name) internal view returns (address) {
        _validateName(name);
        uint256 tokenId = uint256(keccak256(bytes(name)));
        try IERC721(AGENT_ID).ownerOf(tokenId) returns (address owner) {
            return owner;
        } catch {
            revert NameNotRegistered();
        }
    }

    /// @notice Validates split inputs and resolves every recipient up front so
    /// a bad name reverts before any funds move.
    /// @return recipients The resolved recipient addresses, in order.
    /// @return total The sum of all amounts.
    function _validateSplit(string[] calldata names, uint256[] calldata amounts)
        internal
        view
        returns (address[] memory recipients, uint256 total)
    {
        if (names.length != amounts.length) revert ArrayLengthMismatch();
        if (names.length == 0) revert ArrayLengthMismatch();
        if (names.length > MAX_SPLIT_RECIPIENTS) revert TooManyRecipients();
        recipients = new address[](names.length);
        for (uint256 i; i < names.length; ++i) {
            if (amounts[i] == 0) revert ZeroAmount();
            recipients[i] = _resolveName(names[i]);
            total += amounts[i];
        }
    }

    /// @notice Validates the shared subscription parameters.
    function _validateSubscriptionParams(uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments)
        internal
        pure
    {
        if (amountPerPeriod == 0) revert ZeroAmount();
        if (periodSeconds < MIN_SUBSCRIPTION_PERIOD) revert InvalidPeriod();
        if (maxPayments == 0 || maxPayments > MAX_SUBSCRIPTION_PAYMENTS) revert InvalidMaxPayments();
    }

    /// @notice Stores a subscription and emits SubscriptionCreated.
    function _createSubscription(
        address payee,
        address token,
        uint256 amountPerPeriod,
        uint256 periodSeconds,
        uint256 maxPayments
    ) internal returns (uint256 subscriptionId) {
        subscriptionId = _nextSubscriptionId++;
        _subscriptions[subscriptionId] = Subscription({
            id: subscriptionId,
            subscriber: msg.sender,
            payee: payee,
            token: token,
            amountPerPeriod: amountPerPeriod,
            periodSeconds: periodSeconds,
            maxPayments: maxPayments,
            paymentsMade: 0,
            nextPaymentDue: block.timestamp + periodSeconds,
            status: SubscriptionStatus.Active
        });
        emit SubscriptionCreated(subscriptionId, msg.sender, payee, token, amountPerPeriod, periodSeconds, maxPayments);
    }

    /// @notice Sends BNB with a low-level call and reverts if the transfer fails.
    function _sendBNB(address to, uint256 amount) internal {
        (bool success,) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
