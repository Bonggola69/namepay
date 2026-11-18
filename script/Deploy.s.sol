// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {NamePay} from "../src/NamePay.sol";

/// @title NamePay deployment script
/// @notice Deploys NamePay on BNB Smart Chain (chain id 56).
/// @dev DRY-RUN ONLY. Running this script simulates the deployment against
///      the configured RPC and sends no transaction on its own. Broadcasting
///      is a separate, human-gated step: Ezra reviews the dry-run output and
///      the deployment preview and gives fresh confirmation before anything
///      is sent. No private key, keystore, or .env file is used or read
///      anywhere in this repo.
contract DeployScript is Script {
    /// @dev Agent ID contract on BSC (ERC-721 "SPACE ID Agent ID", symbol AI).
    ///      tokenId = uint256(keccak256(label)); ownerOf(tokenId) is the holder.
    address internal constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    /// @dev USDT / USDC on BSC, the two allowlisted stablecoins at deploy time.
    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    function run() external {
        vm.startBroadcast();

        // The constructor takes exactly one argument: the Agent ID contract
        // address. If src/NamePay.sol ever gains further constructor
        // arguments, update this call to match it exactly.
        NamePay namePay = new NamePay(AGENT_ID);

        vm.stopBroadcast();

        console.log("NamePay deployed at:", address(namePay));
        console.log("Agent ID contract:", AGENT_ID);
        console.log("Owner (deployer):", namePay.owner());
        console.log("USDT allowed:", namePay.isTokenAllowed(USDT));
        console.log("USDC allowed:", namePay.isTokenAllowed(USDC));
        console.log("Chain ID:", block.chainid);
    }
}
