// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NamePay} from "../../src/NamePay.sol";

/// @notice Fork test against the REAL Agent ID contract on BSC.
/// Pinned block 134342000 (2026-11-18). The fork RPC is bsc.publicnode.com:
/// the spec-named bsc-dataseed1.binance.org does NOT serve historical state
/// (eth_call at ~400 blocks behind head fails with "missing trie node"),
/// so a pinned block cannot be tested against it at all; publicnode serves
/// archive state and the pinned block was verified there with cast.
/// If the RPC is unreachable this test FAILS (createFork reverts) — it never
/// silently passes or skips. Run separately:
/// forge test --match-contract NamePayForkTest
contract NamePayForkTest is Test {
    // Checksummed forms (solc 0.8.24 rejects non-checksummed address literals).
    // NOTE: the canonical EIP-55 checksum of the Agent ID address is
    // 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F (cast to-checksum) — the
    // casing in the correction message (…54cdd8c48baaa8b022f) is not a valid
    // checksum and solc rejects it; the form below is the one that compiles.
    address internal constant REAL_AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    address internal constant EXPECTED_HANTA_OWNER = 0xB23D93c20a420d52d3F88333F7Be9a25927C929b;

    uint256 internal constant FORK_BLOCK = 134342000;

    function testFork_resolveHanta() public {
        uint256 forkId = vm.createFork("bsc", FORK_BLOCK);
        vm.selectFork(forkId);
        assertEq(block.chainid, 56, "fork is not BSC");
        assertEq(block.number, FORK_BLOCK, "fork is not at the pinned block");

        NamePay namePay = new NamePay(REAL_AGENT_ID);
        assertEq(namePay.resolveName("hanta"), EXPECTED_HANTA_OWNER);
    }

    function testFork_resolveUnclaimedReverts() public {
        uint256 forkId = vm.createFork("bsc", FORK_BLOCK);
        vm.selectFork(forkId);
        NamePay namePay = new NamePay(REAL_AGENT_ID);
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.resolveName("definitely-not-claimed-name-xyz");
    }
}
