// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
