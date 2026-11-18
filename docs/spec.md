# NamePay — Spec

## Project

- **Name:** NamePay (repo: `Bonggola69/namepay`, public, MIT)
- **One-liner:** Pay anyone by their Agent ID name (`.ai`) on BNB Chain instead of a hex address.
- **Event:** Agent ID Hackathon (Binance Wallet + BNB Chain). Submission period 2026-11-18 08:00 UTC to 2026-12-09 08:00 UTC (15:00 WIB). No registration needed.
- **Chain:** BNB Smart Chain (chain id 56). Contracts deployed on BSC mainnet, source verified and open-sourced on BscScan.
- **Status:** in build. Mainnet deploy is a human gate (Ezra only, preview + fresh confirmation). Nothing in this repo broadcasts, signs, or spends.

## Why this fits the hackathon

Judging weights: Agent ID application depth 30%, practicality and feasibility 25%, product completion 25%, innovation 20%. Innovation Award needs a live product with at least 30 Agent ID addresses interacting during the submission period.

Agent ID is the core of the product, not a garnish: every payment resolves the recipient's name to an address through the Agent ID contract, every sender/receiver is displayed by name, and only Agent ID holders can register a name or be paid by name. This is payments + identity, two of the three use cases the rules name (access control, payments, identity).

## Verified primitive (do not re-derive)

Agent ID contract on BSC: `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`, ERC-721 "SPACE ID Agent ID" (symbol `AI`), non-transferable.

- `tokenId = uint256(keccak256(label))`, where `label` is the name part without `.ai` (e.g. `hanta` for `hanta.ai`).
- `ownerOf(tokenId)` returns the holder address. Verified on-chain 2026-11-18: `ownerOf(labelhash("hanta")) = 0xB23D93c20a420d52d3F88333F7Be9a25927C929b`, `balanceOf` of that wallet = 1.
- If a name was never claimed, `ownerOf` reverts (`ERC721NonexistentToken`).

## Contracts

One contract, `NamePay`, in `src/NamePay.sol`. Single contract on purpose: one address to verify, one audit surface, no cross-contract wiring to get wrong.

- Compiler: `solc 0.8.24`, `pragma solidity ^0.8.24;`
- OpenZeppelin Contracts 5.0.2: `ReentrancyGuard`, `Pausable`, `Ownable2Step`, `SafeERC20`.
- Ownership model: `Ownable2Step` (two-step transfer protects against a fat-finger ownership transfer). Owner powers are minimal and disclosed below.
- No upgradeability, no proxy. Constructor-only init (all dependencies known at deploy time).
- No fees. The contract takes no cut of any payment. Owner cannot withdraw user funds: the contract never holds user funds except subscription escrow, which only the subscriber can cancel-refund and only the scheduled payee can receive.
- `ReentrancyGuard` (`nonReentrant`) on every fund-moving function. `SafeERC20` for all token moves. Checks-Effects-Interactions ordering everywhere. Custom errors, no `require` strings. NatSpec on every public/external function. Events on every state change.

### Constants (immutable, set in constructor)

| Name | Value |
|---|---|
| `AGENT_ID` | `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` |
| `USDT` | `0x55d398326f99059fF775485246999027B3197955` |
| `USDC` | `0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d` |
| `MAX_SPLIT_RECIPIENTS` | `20` |
| `MAX_SUBSCRIPTION_PAYMENTS` | `24` |
| `MIN_SUBSCRIPTION_PERIOD` | `1 days` |

Token allowlist: BNB (native, `address(0)`), USDT, USDC only. Owner can add/remove allowlisted tokens later (event emitted); the initial list is exactly these three.

### Name rules

- Input names are the label only, e.g. `hanta`, not `hanta.ai`. The frontend strips a trailing `.ai` if the user types it.
- `resolveName(string name)` (view) returns the owner address. Validation: length 1–63, characters `[a-z0-9-]` only, must not start or end with `-`. Invalid input reverts `InvalidName`. Unclaimed name reverts `NameNotRegistered` (mapped from the Agent ID contract's revert).
- `registerName(string name)`: caller proves they own the name (`ownerOf(labelhash) == msg.sender`), then `nameOf[msg.sender] = name` is stored. Emits `NameRegistered`. Anyone can overwrite only their own entry. This is the reverse mapping (address → name) used to display sender names in history. Forward resolution always reads live from the Agent ID contract, never from a stale cache.

### Functions (exact signatures — executors must not rename or reorder)

```solidity
// --- views ---
function resolveName(string calldata name) external view returns (address);
function nameOf(address account) external view returns (string memory);
function isTokenAllowed(address token) external view returns (bool);
function getRequest(uint256 requestId) external view returns (PaymentRequest memory);
function getSubscription(uint256 subscriptionId) external view returns (Subscription memory);

// --- payments ---
function payBNB(string calldata name, string calldata memo) external payable nonReentrant whenNotPaused;
function payToken(address token, string calldata name, uint256 amount, string calldata memo) external nonReentrant whenNotPaused;

// --- payment requests ---
function createRequest(string calldata payerName, address token, uint256 amount, uint256 expiry, string calldata memo) external whenNotPaused returns (uint256 requestId);
function payRequest(uint256 requestId) external payable nonReentrant whenNotPaused;
function cancelRequest(uint256 requestId) external;

// --- split payments ---
function splitPayBNB(string[] calldata names, uint256[] calldata amounts, string calldata memo) external payable nonReentrant whenNotPaused;
function splitPayToken(address token, string[] calldata names, uint256[] calldata amounts, string calldata memo) external nonReentrant whenNotPaused;

// --- recurring payments (escrow model, NOT allowance) ---
function createSubscriptionBNB(string calldata payeeName, uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments) external payable nonReentrant whenNotPaused returns (uint256 subscriptionId);
function createSubscriptionToken(address token, string calldata payeeName, uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments) external nonReentrant whenNotPaused returns (uint256 subscriptionId);
function executeSubscription(uint256 subscriptionId) external nonReentrant whenNotPaused;
function cancelSubscription(uint256 subscriptionId) external nonReentrant;

// --- names ---
function registerName(string calldata name) external;

// --- admin (owner only, all emit events) ---
function setTokenAllowed(address token, bool allowed) external onlyOwner;
function pause() external onlyOwner;
function unpause() external onlyOwner;
```

### Semantics

- `payBNB`: `msg.value > 0` required, recipient = `resolveName(name)`. Reverts on unregistered name. Emits `PaymentSent(msg.sender, senderName, recipient, recipientName, address(0), msg.value, memo)`. `senderName`/`recipientName` are looked up from `nameOf` and fall back to `""` when unregistered (the frontend resolves them for display instead).
- `payToken`: token must be allowlisted, `amount > 0`, `transferFrom(msg.sender, recipient, amount)`. Same event with the token address.
- `createRequest`: requester is `msg.sender`; `payerName` resolves to the payer address at creation (reverts if unregistered). `token` is `address(0)` (BNB) or an allowlisted token. `amount > 0`. `expiry` must be in the future. Returns the request id. States: `Pending`, `Paid`, `Cancelled`, `Expired` (expired is derived: `Pending` and `block.timestamp > expiry`). Emits `RequestCreated`.
- `payRequest`: only the recorded payer can pay; request must be `Pending` and unexpired. BNB requests: `msg.value == amount`. Token requests: `transferFrom(payer, requester, amount)`. Marks `Paid`, emits `RequestPaid`.
- `cancelRequest`: only the requester can cancel, only while `Pending`. Emits `RequestCancelled`.
- `splitPayBNB`: `names.length == amounts.length`, `1 <= length <= MAX_SPLIT_RECIPIENTS`, `msg.value == sum(amounts)`, every amount `> 0`, every name resolves. Pays each recipient in order. Emits `SplitPaymentSent` once (with arrays) plus one `PaymentSent` per recipient.
- `splitPayToken`: same, with a single `transferFrom` for the total, then internal transfers to each recipient.
- Subscriptions (escrow model — this is deliberate): the subscriber funds the whole schedule up front (`amountPerPeriod * maxPayments`), either as BNB (`msg.value`) or as a token deposit (`transferFrom`). No allowance is ever requested for recurring payments: there is nothing to approve, nothing to revoke, and no unbounded approval anywhere in the product. `periodSeconds >= MIN_SUBSCRIPTION_PERIOD`, `1 <= maxPayments <= MAX_SUBSCRIPTION_PAYMENTS`. `executeSubscription` can be called by anyone (keeper) when `block.timestamp >= nextPaymentDue`; it sends one period's amount to the payee and advances `paymentsMade` / `nextPaymentDue`. When `paymentsMade == maxPayments` the subscription is `Completed`. `cancelSubscription` (subscriber only, while `Active`) refunds the unspent escrow to the subscriber and marks `Cancelled`. Emits `SubscriptionCreated`, `SubscriptionExecuted`, `SubscriptionCancelled`.
- `pause`/`unpause`: owner only. Pausing blocks all user-facing payment functions; admin functions stay available. Disclosed owner power (see below).

### Data structures

```solidity
struct PaymentRequest {
    uint256 id;
    address requester;
    address payer;
    address token;      // address(0) = BNB
    uint256 amount;
    uint256 expiry;
    RequestStatus status;
    string memo;
}

struct Subscription {
    uint256 id;
    address subscriber;
    address payee;
    address token;      // address(0) = BNB
    uint256 amountPerPeriod;
    uint256 periodSeconds;
    uint256 maxPayments;
    uint256 paymentsMade;
    uint256 nextPaymentDue;
    SubscriptionStatus status;
}

enum RequestStatus { Pending, Paid, Cancelled }
enum SubscriptionStatus { Active, Completed, Cancelled }
```

### Events

```solidity
event PaymentSent(address indexed sender, string senderName, address indexed recipient, string recipientName, address indexed token, uint256 amount, string memo);
event SplitPaymentSent(address indexed sender, address indexed token, uint256 totalAmount, uint256 recipientCount);
event RequestCreated(uint256 indexed requestId, address indexed requester, address indexed payer, address token, uint256 amount, uint256 expiry);
event RequestPaid(uint256 indexed requestId, address indexed payer, uint256 amount);
event RequestCancelled(uint256 indexed requestId, address indexed requester);
event SubscriptionCreated(uint256 indexed subscriptionId, address indexed subscriber, address indexed payee, address token, uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments);
event SubscriptionExecuted(uint256 indexed subscriptionId, uint256 indexed paymentNumber, uint256 amount);
event SubscriptionCancelled(uint256 indexed subscriptionId, address indexed subscriber, uint256 refunded);
event NameRegistered(address indexed account, string name);
event TokenAllowlistUpdated(address indexed token, bool allowed);
```

### Custom errors

`InvalidName`, `NameNotRegistered`, `TokenNotAllowed`, `ZeroAmount`, `ArrayLengthMismatch`, `TooManyRecipients`, `RequestNotFound`, `NotPayer`, `NotRequester`, `RequestNotPayable`, `WrongPaymentAmount`, `SubscriptionNotFound`, `NotSubscriber`, `SubscriptionNotActive`, `SubscriptionNotDue`, `InvalidPeriod`, `InvalidMaxPayments`, `InsufficientEscrow`.

### Security notes (for the README and the submission)

- Owner powers, disclosed: add/remove allowlisted tokens; pause/unpause. Owner cannot move user funds, cannot change a request or subscription, cannot mint, cannot change fees (there are none), cannot freeze a specific user. `Ownable2Step` for ownership transfer.
- Red-line compliance: no QR-code login (frontend uses the injected wallet provider only); no prompts that bypass user confirmation (every transaction is a normal wallet confirmation); no unauthorized transfers (every transfer is either the user's own explicit payment or a scheduled release from escrow the subscriber funded); no unlimited approvals (recurring payments use escrow, never allowances; token payments approve the exact amount per payment); no "Binance"/"BNB" in the project/token/domain name (the project is "NamePay"); no collection of secrets; no promised returns; not a trading product; not a wallet-lookup tool — the product is payments between willing parties, names are only resolved to complete a payment the user initiated.
- Known limitations: name resolution depends on the Agent ID contract; if a name's owner changes (transfer is disabled — the NFT is non-transferable — so ownership is stable), resolution follows the current owner. Frontends must not cache resolved addresses across sessions for payments.

## Frontend

Static site in `app/` (vanilla JS + ethers v6 via CDN). No build step, no backend, no server storage.

- Pages: home/pay (send by name), request (create + pay requests), split, tip page (`tip.html?name=hanta`), history (reads contract events from the deployment block via `eth_getLogs`, resolves names for display).
- Connects through `window.ethereum` (Binance Wallet / MetaMask injected provider). Chain check: must be BSC (56); otherwise prompt the user to switch. No QR login, no WalletConnect, no backend session.
- Token payments: frontend calls `approve` for the exact amount, then `payToken`. Never `MaxUint256`.
- History: event-driven; the frontend queries `PaymentSent`/`RequestPaid`/`SubscriptionExecuted` logs and renders sender/recipient names (via `nameOf` + local label cache from events).
- Hosting: GitHub Pages from the same repo (`/app` via Pages). The live URL becomes the submission website URL.

## Tests (Foundry)

`test/NamePay.t.sol` + `test/mocks/MockAgentID.sol` (a minimal ERC-721 whose `ownerOf` returns a preset address for a preset labelhash; the mock exists so unit tests run offline).

Required coverage (from the testing skill: happy path, permissions, boundaries, failures, state changes, edge cases):

- `resolveName`: valid name resolves; invalid chars/length revert `InvalidName`; unclaimed name reverts `NameNotRegistered`.
- `payBNB`/`payToken`: happy path moves funds and emits events; zero value/amount reverts; unregistered name reverts; unallowlisted token reverts; balances and state checked, not just events.
- Requests: create/pay/cancel happy paths; non-payer cannot pay; requester-only cancel; expired request cannot be paid; wrong BNB amount reverts; double-pay reverts.
- Split: happy path with 3 recipients; length mismatch reverts; >20 recipients reverts; wrong total reverts; zero amount reverts.
- Subscriptions: create BNB + token (escrow funded exactly); early `executeSubscription` reverts `SubscriptionNotDue`; execution pays one period and advances the schedule; completion at `maxPayments`; cancel refunds the remainder; non-subscriber cannot cancel; invalid period/maxPayments revert.
- Admin: non-owner cannot pause or set allowlist; pause blocks payments; unpause restores.
- Fuzz: `testFuzz_splitAmounts` (bounded split sums) and `testFuzz_subscriptionSchedule` (period/maxPayments domain).
- Fork test (`test/fork/NamePayFork.t.sol`, pinned BSC block, run separately): resolves `hanta` against the real Agent ID contract and asserts the owner is `0xB23D93c20a420d52d3F88333F7Be9a25927C929b`. Gate: `forge test --match-contract NamePayForkTest` with a BSC RPC. If the RPC is unreachable the test must fail loudly, never silently pass. Use `https://bsc.publicnode.com` for the fork RPC: `bsc-dataseed1.binance.org` does not serve historical state (archive calls fail with `missing trie node`).

## Deployment plan (human gate — Ezra only)

1. `forge build`, `forge test` — zero failures required.
2. Dry-run: `forge script script/Deploy.s.sol --rpc-url <BSC RPC> -vvvv` (no `--broadcast`).
3. Ezra reviews the dry-run + the deployment preview (contract, constructor args, estimated gas, cost in BNB) and gives fresh confirmation.
4. Only then: broadcast with Ezra's wallet flow. Record the address + tx hash in `deployments/`.
5. Verify on BscScan (`forge verify-contract`, needs a BscScan API key — open gate, Ezra creates it or provides it).
6. Enable GitHub Pages for `app/`; record the live URL.
7. Demo video (≤3 min) and submission are Ezra's gates, after the product is live.

## Stretch (only if time remains before 2026-12-09)

- Batch payroll: pay a list of names with individual memos in one tx (a thin wrapper over split with per-recipient memos).
- Bill reminders: off-chain only (frontend local reminders from on-chain request expiries) — no contract change.

## Out of scope

- No token of our own. No fees. No trading, no swaps, no price oracles. No backend, no database, no user accounts. No QR login. No lookup-by-name directory: names are resolved only to complete a payment the user initiated.
