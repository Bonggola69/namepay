# NamePay — Agent ID Hackathon submission draft

Prepared 2026-11-19. The submission itself is Ezra's gate (he submits it);
this file holds the exact texts so nothing has to be re-derived at submit time.

## Project name

NamePay

## Website

https://bonggola69.github.io/namepay/

## Contract address (BNB Chain mainnet, chain 56)

- NamePay: `0x7987124EB007d383021986FcFD5024EC4D2e303E`
- Deploy tx: `0x041ef0079914f4238c192c9c3f231b2d312142d8deb98074709118b24d4b3973` (block 134414026)
- BscScan: https://bscscan.com/address/0x7987124EB007d383021986FcFD5024EC4D2e303E
- Source: https://github.com/Bonggola69/namepay (public, MIT)

## Agent ID usage description

NamePay is built around Agent ID (name.ai). Every payment resolves the
recipient's name to an address through the Agent ID contract
(`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, SPACE ID Agent ID, ERC-721):
a name like `hanta` is hashed to its tokenId and `ownerOf` returns the
holder's wallet, so users pay `hanta.ai` instead of a 42-character address.
Only Agent ID holders can register a name or be paid by name, and the
frontend shows names both ways (sender and receiver resolved from the
contract's stored reverse mapping). Agent ID is used for identity in
payments, payment requests, split payments (up to 20 names in one
transaction), public tip pages per name, and escrow recurring payments
(the subscriber funds the whole schedule up front, so no allowance is
ever requested). No fees are charged by the contract.

## Notes for the submitter

- Source verification: VERIFIED on BscScan and on Sourcify (confirmed
  2026-11-19 ~08:42 WIB via Etherscan API V2 getsourcecode: ContractName
  NamePay, compiler v0.8.34, optimizer off, 200 runs; Sourcify
  exact_match creation + runtime from 08:18 WIB). Remix's verify toggle
  at deploy did it.
- The announcement contains NO submission form link — it only says to
  submit project name, website, contract addresses, Agent ID usage
  description and other required materials during the Submission Period.
  A web search on 2026-11-19 found no public submission form either
  (only the Community Promotion survey for X-post links). The project
  submission channel is most likely inside the Binance Wallet app or a
  follow-up announcement — check the app's hackathon banner before
  the deadline.
- Innovation Award eligibility needs at least 30 Agent ID addresses
  interacting during the submission period — distribution is the real gap.
  Baseline checked 2026-11-19 ~08:44 WIB (block 134417505): 0
  interactions so far, only the deploy event on-chain.
- Submission deadline: 9 Dec 2026 08:00 UTC (15:00 WIB).
