# NamePay — Deployment Runbook

Deployment is a **human gate, Ezra only**. Nothing in this repo broadcasts,
signs, or spends on its own. This runbook is the only deployment procedure;
follow it in order and stop at any step that fails.

## Pre-flight checklist

All of these must pass before a dry-run:

- [ ] `forge build` — compiles with zero errors or warnings.
- [ ] `forge test` — zero failures (unit tests + fuzz tests).
- [ ] `forge test --match-contract NamePayForkTest` — the fork test resolves
      `hanta` against the real Agent ID contract and asserts the owner is
      `0xB23D93c20a420d52d3F88333F7Be9a25927C929b`. If the RPC is unreachable
      the test must fail loudly, never silently pass.
- [ ] `forge fmt --check` — formatting clean.
- [ ] Constructor args checked against `src/NamePay.sol`: the deploy script
      passes exactly one argument, the Agent ID contract address
      `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`. If the contract's
      constructor ever gains further arguments, update `script/Deploy.s.sol`
      to match it exactly and re-run the dry-run.
- [ ] Deployer wallet funded: `cast balance <DEPLOYER> --rpc-url
      https://bsc-dataseed1.binance.org` shows enough BNB for the deployment
      cost below (plus a margin).
- [ ] No secrets anywhere in the repo: no private key, keystore, or `.env`
      file. `git status` shows only intended files.

## Dry-run (simulation only — sends nothing)

```shell
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed1.binance.org -vvvv
```

This command contains no broadcast flag on purpose: without it, Foundry
simulates the deployment against the BSC RPC and reports the gas used, but
sends no transaction. Never add a broadcast flag to this command, to the
script, or to any comment/template in this repo — broadcasting is a separate
step that only happens after the mainnet gate below.

### How to read the dry-run output

- **"NamePay deployed at:"** — the address the contract *would* deploy to
  from the simulated sender. In a dry-run this is a simulated address; the
  real address is only known after the broadcast transaction is mined, and
  it depends on the deployer's address and nonce at that time. Do not record
  a dry-run address as the deployed address.
- **"Agent ID contract:"** — must read
  `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`.
- **"Owner (deployer):"** — must be the deployer address Ezra expects.
- **"USDT allowed:" / "USDC allowed:"** — both must read `true`.
- **"Chain ID:"** — must read `56` (BNB Smart Chain).
- **Gas used** — Foundry prints the gas for the deployment transaction
  (look for the `gas` figure in the script run summary). Record it together
  with the gas price used (see "Deployment cost estimate" below).

If any line is wrong, stop. Fix the cause, re-run `forge build` and
`forge test`, and re-run the dry-run.

## Mainnet gate (Ezra reviews and confirms fresh)

1. Ezra reviews the dry-run output and the deployment preview: the contract
   source, the constructor argument (Agent ID address above), the estimated
   gas, and the cost in BNB.
2. Ezra gives **fresh confirmation** for this specific broadcast. A dry-run
   passing is not approval to broadcast, and an earlier confirmation does
   not carry over to a later attempt — if anything changed (code, args,
   gas price), re-preview and re-confirm.
3. Only then: broadcast through Ezra's confirmed wallet flow. No private
   key is ever typed into a command, pasted into a file, or stored in this
   repo — the `.env` `PRIVATE_KEY` option in the deploy skill is NOT used
   here.

## Deployment cost estimate

Measured values (2026-11-18, BSC public RPC reachable):

- Live BSC gas price at check time: **50,000,000 wei = 0.05 gwei**
  (`cast gas-price --rpc-url https://bsc-dataseed1.binance.org`).
- Deployment gas: **measured 2026-11-18 (dry-run, no broadcast).**
  `forge script script/Deploy.s.sol --rpc-url https://bsc.publicnode.com`
  simulated cleanly on chain 56 with the real contract: gas-limit estimate
  **3,713,214**; the test-EVM deployment cost from `forge test --gas-report`
  is **2,856,319 gas** (12,720 bytes, under the 24,576-byte EIP-170 limit).
  At the checked gas price of 0.05 gwei that is **0.000143–0.000186 BNB**
  (about $0.12 at ~$850/BNB). At 1 gwei it would be 0.00286 BNB. Gas price
  varies — re-check at deploy time. The deploy script was first validated
  end-to-end on 2026-11-18 against a minimal spec-shaped stub contract in
  `/tmp` (stub gas 383,701, now superseded by the real figures above).

Cost formula (once gas is measured):

```
cost_BNB = deployment_gas × gas_price_wei / 1e18
```

At the checked gas price of 0.05 gwei, every 1,000,000 gas costs 0.00005 BNB
(about $0.03–$0.05 at typical BNB prices — re-check the BNB price at deploy
time). A typical single-contract deployment of this size lands in the
1,000,000–2,000,000 gas range, i.e. roughly 0.00005–0.0001 BNB at 0.05 gwei —
but do not quote that range as measured; the real number comes from the
dry-run.

Fallback if the public RPC is unreachable at deploy time: estimate from
`forge build` bytecode size —

```
deployment_gas ≈ 21000 + 200 × <bytecode bytes> + execution gas
```

and multiply by the live gas price. A formula-only number is an estimate,
never a measured cost; say so when reporting it.

## After broadcast

1. Wait for the transaction receipt. Record the deployed contract address
   and the transaction hash in `deployments/latest.env` (plain text, no
   secrets) and update the Deployment section of `README.md`.
2. Sanity-check the live contract with read-only calls (no transaction):
   ```shell
   cast call <NAMEPAY_ADDRESS> "owner()" --rpc-url https://bsc-dataseed1.binance.org
   cast call <NAMEPAY_ADDRESS> "resolveName(string)" "hanta" --rpc-url https://bsc-dataseed1.binance.org
   ```
   `owner()` must be the deployer; `resolveName("hanta")` must return
   `0xB23D93c20a420d52d3F88333F7Be9a25927C929b`.
3. Verify on BscScan (open gate — needs a BscScan API key, which Ezra
   creates or provides):
   ```shell
   forge verify-contract <NAMEPAY_ADDRESS> src/NamePay.sol:NamePay \
     --chain-id 56 \
     --etherscan-api-key <BSCSCAN_API_KEY> \
     --constructor-args $(cast abi-encode "constructor(address)" 0x60b9262456de011f7d15a54cdd8c48baaa8b022f)
   ```
   Confirm on BscScan that the source shows as verified and the constructor
   argument matches the Agent ID address.
4. Enable GitHub Pages for `app/` (repo Settings → Pages → deploy from
   branch, `/app` folder). Record the live URL in `README.md` and in
   `deployments/latest.env` — the live URL becomes the submission website URL.
5. Demo video (≤3 min) and hackathon submission are Ezra's gates, after the
   product is live.

## Where the deployed address is recorded

- `deployments/latest.env` — address, tx hash, chain id, deploy date, live
  frontend URL (plain text, no secrets).
- `README.md` — Deployment section, status flipped from "NOT deployed yet"
  to deployed with the address and BscScan link.
