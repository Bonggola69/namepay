# NamePay

**Pay anyone by their Agent ID name (`.ai`) on BNB Chain instead of a hex address.**

NamePay is a single smart contract plus a static frontend, built for the Agent ID Hackathon (Binance Wallet + BNB Chain). Send BNB, USDT, or USDC to `hanta` instead of `0xB23D…929b`. Request a payment from someone by name. Split a payment across up to 20 names. Set up a recurring payment funded up front from escrow — never from an allowance.

- **Chain:** BNB Smart Chain (chain id 56)
- **Status:** in build. **NOT deployed yet** — mainnet deployment is a human gate (see [Deployment](#deployment)).
- **License:** MIT

## How Agent ID resolution works

Agent ID is the core of the product, not a garnish: every payment resolves the recipient's name to an address through the Agent ID contract, every sender and receiver is displayed by name, and only Agent ID holders can register a name or be paid by name.

The verified primitive (checked on-chain 2026-11-18, do not re-derive):

- Agent ID contract on BSC: `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` — ERC-721 "SPACE ID Agent ID" (symbol `AI`), non-transferable.
- `tokenId = uint256(keccak256(label))`, where `label` is the name part without `.ai` (e.g. `hanta` for `hanta.ai`).
- `ownerOf(tokenId)` returns the holder address. Verified: `ownerOf(labelhash("hanta")) = 0xB23D93c20a420d52d3F88333F7Be9a25927C929b`.
- If a name was never claimed, `ownerOf` reverts (`ERC721NonexistentToken`), which NamePay maps to `NameNotRegistered`.

NamePay never caches a resolved address for payments: forward resolution always reads live from the Agent ID contract. The contract stores only a reverse mapping (`address → name`, set by `registerName` after the caller proves they own the name) so sender names can be shown in history.

## Features

- **Pay by name** — `payBNB(name, memo)` / `payToken(token, name, amount, memo)` in BNB, USDT, or USDC.
- **Payment requests** — create a request naming the payer; only that payer can pay it, only while it is pending and unexpired; the requester can cancel it.
- **Split payments** — pay up to 20 names in one transaction, BNB or token, with one total that must match the sum exactly.
- **Recurring payments (escrow, not allowance)** — the subscriber funds the whole schedule up front (`amountPerPeriod × maxPayments`, max 24 payments, minimum period 1 day). Anyone can trigger a due payment; the subscriber can cancel and get the unspent escrow refunded. No allowance is ever requested: nothing to approve, nothing to revoke, no unbounded approval anywhere in the product.
- **Name registration** — `registerName(name)` proves ownership on-chain and stores the reverse mapping used for display.
- **No fees.** The contract takes no cut of any payment.

## Contract

One contract, `src/NamePay.sol`, on purpose: one address to verify, one audit surface, no cross-contract wiring to get wrong. No upgradeability, no proxy. Constructor-only init.

- Compiler: `solc 0.8.24`, `pragma solidity ^0.8.24;`
- OpenZeppelin Contracts 5.0.2: `ReentrancyGuard`, `Pausable`, `Ownable2Step`, `SafeERC20`.
- `ReentrancyGuard` (`nonReentrant`) on every fund-moving function. `SafeERC20` for all token moves. Checks-Effects-Interactions ordering everywhere. Custom errors, no `require` strings. NatSpec on every public/external function. Events on every state change.
- Token allowlist at deploy: BNB (native, `address(0)`), USDT (`0x55d398326f99059fF775485246999027B3197955`), USDC (`0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d`).

### Owner powers (disclosed)

The owner can only:

- add/remove allowlisted tokens (`setTokenAllowed`, emits `TokenAllowlistUpdated`);
- pause/unpause the contract (`pause`/`unpause` — pausing blocks all user-facing payment functions; admin functions stay available).

The owner **cannot** move user funds, change a request or subscription, mint anything, change fees (there are none), or freeze a specific user. Ownership transfer is two-step (`Ownable2Step`), which protects against a fat-finger transfer. The contract never holds user funds except subscription escrow, which only the subscriber can cancel-refund and only the scheduled payee can receive.

## Repo layout

```
src/NamePay.sol            # the contract
test/NamePay.t.sol         # unit tests (Foundry)
test/mocks/MockAgentID.sol # minimal ERC-721 mock so unit tests run offline
test/fork/NamePayFork.t.sol# fork test against the real Agent ID contract
script/Deploy.s.sol        # deployment script (dry-run only — see below)
app/                       # static frontend (vanilla JS + ethers v6 via CDN)
docs/spec.md               # full specification
docs/deployment.md         # deployment runbook
deployments/               # deployed address + tx hash, recorded after deploy
```

## Build and test

```shell
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2
forge build
forge test
forge fmt
```

(Dependencies are not vendored in this repo: `lib/` is git-ignored and fetched with the two `forge install` commands above.)

The fork test runs separately against a BSC RPC and pins a block:

```shell
forge test --match-contract NamePayForkTest
```

It resolves `hanta` against the real Agent ID contract and asserts the owner is `0xB23D93c20a420d52d3F88333F7Be9a25927C929b`. If the RPC is unreachable the test must fail loudly, never silently pass.

## How the frontend works

Static site in `app/` — vanilla JS + ethers v6 via CDN. No build step, no backend, no server storage.

- Pages: home/pay (send by name), request (create + pay requests), split, tip page (`tip.html?name=hanta`), history (reads contract events from the deployment block via `eth_getLogs`, resolves names for display).
- Connects through `window.ethereum` (Binance Wallet / MetaMask injected provider). Chain check: must be BSC (56); otherwise the user is prompted to switch. No QR login, no WalletConnect, no backend session.
- Token payments: the frontend calls `approve` for the exact amount, then `payToken`. Never `MaxUint256`.
- Hosting: GitHub Pages from this repo (`/app`). The live URL becomes the submission website URL.

## Deployment

**Status: NOT deployed yet.** Deployment is a human gate — see the full runbook in [docs/deployment.md](docs/deployment.md).

Measured dry-run (2026-11-18, no broadcast): deployment gas 2,856,319 (test-EVM) / 3,713,214 gas-limit estimate (fork), about 0.000143–0.000186 BNB at 0.05 gwei.

1. `forge build`, `forge test` — zero failures required.
2. Dry-run: `forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed1.binance.org -vvvv` (simulation only, sends nothing).
3. Ezra reviews the dry-run and the deployment preview (contract, constructor args, estimated gas, cost in BNB) and gives fresh confirmation.
4. Only then: broadcast through Ezra's confirmed wallet flow. Record the address + tx hash in `deployments/`.
5. Verify on BscScan (`forge verify-contract` — needs a BscScan API key, an open gate).
6. Enable GitHub Pages for `app/`; record the live URL.

Nothing in this repo broadcasts, signs, or spends. There is no private key, keystore, or `.env` file anywhere in it, and there must never be one.

## Red-line compliance

- No QR-code login (frontend uses the injected wallet provider only).
- No prompts that bypass user confirmation — every transaction is a normal wallet confirmation.
- No unauthorized transfers — every transfer is either the user's own explicit payment or a scheduled release from escrow the subscriber funded.
- No unlimited approvals — recurring payments use escrow, never allowances; token payments approve the exact amount per payment.
- No "Binance"/"BNB" in the project, token, or domain name — the project is "NamePay". ("BNB Chain" as the deployment chain and "BNB" as the currency are fine in text.)
- No collection of secrets. No promised returns. Not a trading product. Not a wallet-lookup tool — the product is payments between willing parties; names are resolved only to complete a payment the user initiated.

## Status: done vs pending

**Done**

- Specification (`docs/spec.md`) — contract, semantics, events, errors, frontend, tests, deployment plan.
- Deployment script (`script/Deploy.s.sol`), Foundry config, deployment runbook (`docs/deployment.md`).
- BSC gas price checked live (0.05 gwei at time of writing — see `docs/deployment.md` for the deployment cost estimate).

**In progress (parallel work)**

- `src/NamePay.sol` — the contract itself.
- `test/NamePay.t.sol` + mock + fork test.
- `app/` — the frontend.

**Pending (human gates, Ezra only)**

- Mainnet deployment (preview + fresh confirmation required).
- BscScan verification (needs a BscScan API key — open gate).
- GitHub Pages enablement for `app/`.
- Demo video (≤3 min) and hackathon submission.

## Known limitations

- Name resolution depends on the Agent ID contract. The NFT is non-transferable, so ownership is stable, and resolution always follows the current owner.
- Frontends must not cache resolved addresses across sessions for payments.
