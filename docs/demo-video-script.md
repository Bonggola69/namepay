# NamePay — demo video script (≤3 min)

Record last, on the live site https://bonggola69.github.io/namepay/ with a
real wallet. English voiceover (or English subtitles). Screen recording +
voiceover is enough; no face cam needed. Target ~2:30.

## 0:00–0:15 — Hook

On screen: the NamePay home page.
Say: "Pay anyone by their .ai name. No wallet addresses, no copy-paste.
This is NamePay, built for the Agent ID Hackathon."

## 0:15–0:50 — Pay by name (BNB)

On screen: connect wallet (Binance Wallet / MetaMask, BSC Mainnet), type
`hanta` in the recipient field, amount 0.001 BNB, click Send, confirm in
the wallet.
Say: "I type hanta, not a 42-character address. NamePay resolves the name
on-chain through the Agent ID contract and sends the payment. One
confirmation, done."

## 0:50–1:20 — Payment request

On screen: Requests tab, create a request to `hanta` for 0.001 BNB with a
note "demo". Show it listed as pending, then pay it from the same page.
Say: "Requests work the other way round. I ask hanta for payment, the
request waits as pending, and paying it is one click."

## 1:20–1:50 — Split payment

On screen: Split tab, add two names, split 0.002 BNB between them, one
transaction.
Say: "Split pays up to twenty names in a single transaction. One
confirmation for the whole bill."
Note for the recording: use real Agent ID names. If only `hanta` is
available, split between `hanta` twice for the UI walkthrough and say so
on camera; do not present it as two different people.

## 1:50–2:15 — Tip page + recurring (escrow)

On screen: open `tip.html?name=hanta`, send a small tip. Then show the
recurring section.
Say: "Every name gets a public tip page. And recurring payments run on
escrow: the full schedule is funded up front, so the app never asks for
an allowance."

## 2:15–2:30 — Close

On screen: the contract address on BscScan, then the GitHub repo.
Say: "NamePay is live on BNB Chain, open source, no fees. Contract and
links are in the description."

## Recording checklist

- [ ] Wallet funded with a little BNB for the demos (deployer account
      0x024f89c5F94A831270484cDEb45c74FEf4eB2417).
- [ ] Site loaded on BSC Mainnet (chain 56), not a testnet.
- [ ] Amounts are small test amounts only (0.001–0.002 BNB per demo).
- [ ] Keep the whole video under 3 minutes.
- [ ] Upload to YouTube (unlisted is fine) — the link goes in the
      hackathon submission.
