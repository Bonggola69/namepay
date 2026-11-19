// NamePay frontend — vanilla JS + ethers v6 via CDN.
// Read-only preview until the contract is deployed. No transaction is ever
// broadcast while NAMEPAY_ADDRESS is the zero address.

// TBD-post-build: fill after mainnet deploy
const NAMEPAY_ADDRESS = "0x7987124EB007d383021986FcFD5024EC4D2e303E";
// TBD-post-build: fill with the block number the contract was deployed in.
const DEPLOYMENT_BLOCK = 134414026;

const BSC_CHAIN_ID = 56;
const BSC_CHAIN_HEX = "0x38";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const MAX_SPLIT_RECIPIENTS = 20;
const MAX_SUBSCRIPTION_PAYMENTS = 24;

// Hand-written from docs/spec.md — exact function signatures, no extras.
const NAMEPAY_ABI = [
  // --- views ---
  "function resolveName(string name) view returns (address)",
  "function nameOf(address account) view returns (string)",
  "function isTokenAllowed(address token) view returns (bool)",
  "function getRequest(uint256 requestId) view returns (tuple(uint256 id, address requester, address payer, address token, uint256 amount, uint256 expiry, uint8 status, string memo))",
  "function getSubscription(uint256 subscriptionId) view returns (tuple(uint256 id, address subscriber, address payee, address token, uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments, uint256 paymentsMade, uint256 nextPaymentDue, uint8 status))",
  // --- payments ---
  "function payBNB(string name, string memo) payable",
  "function payToken(address token, string name, uint256 amount, string memo)",
  // --- payment requests ---
  "function createRequest(string payerName, address token, uint256 amount, uint256 expiry, string memo) returns (uint256 requestId)",
  "function payRequest(uint256 requestId) payable",
  "function cancelRequest(uint256 requestId)",
  // --- split payments ---
  "function splitPayBNB(string[] names, uint256[] amounts, string memo) payable",
  "function splitPayToken(address token, string[] names, uint256[] amounts, string memo)",
  // --- recurring payments (escrow model) ---
  "function createSubscriptionBNB(string payeeName, uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments) payable returns (uint256 subscriptionId)",
  "function createSubscriptionToken(address token, string payeeName, uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments) returns (uint256 subscriptionId)",
  "function executeSubscription(uint256 subscriptionId)",
  "function cancelSubscription(uint256 subscriptionId)",
  // --- names ---
  "function registerName(string name)",
  // --- admin ---
  "function setTokenAllowed(address token, bool allowed)",
  "function pause()",
  "function unpause()",
  // --- events ---
  "event PaymentSent(address indexed sender, string senderName, address indexed recipient, string recipientName, address indexed token, uint256 amount, string memo)",
  "event SplitPaymentSent(address indexed sender, address indexed token, uint256 totalAmount, uint256 recipientCount)",
  "event RequestCreated(uint256 indexed requestId, address indexed requester, address indexed payer, address token, uint256 amount, uint256 expiry)",
  "event RequestPaid(uint256 indexed requestId, address indexed payer, uint256 amount)",
  "event RequestCancelled(uint256 indexed requestId, address indexed requester)",
  "event SubscriptionCreated(uint256 indexed subscriptionId, address indexed subscriber, address indexed payee, address token, uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments)",
  "event SubscriptionExecuted(uint256 indexed subscriptionId, uint256 indexed paymentNumber, uint256 amount)",
  "event SubscriptionCancelled(uint256 indexed subscriptionId, address indexed subscriber, uint256 refunded)",
  "event NameRegistered(address indexed account, string name)",
  "event TokenAllowlistUpdated(address indexed token, bool allowed)",
];

const ERC20_ABI = [
  "function approve(address spender, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
  "function balanceOf(address account) view returns (uint256)",
  "function symbol() view returns (string)",
];

const TOKENS = {
  BNB: { address: ZERO_ADDRESS, decimals: 18, label: "BNB" },
  USDT: { address: "0x55d398326f99059fF775485246999027B3197955", decimals: 18, label: "USDT" },
  USDC: { address: "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d", decimals: 18, label: "USDC" },
};

const isDeployed = NAMEPAY_ADDRESS.toLowerCase() !== ZERO_ADDRESS;

let provider = null;
let signer = null;
let contract = null;      // read/write contract (needs signer)
let readContract = null;  // read-only contract (provider only)
let account = null;

const $ = (id) => document.getElementById(id);

// ---------- helpers ----------

function setStatus(el, msg, kind) {
  el.textContent = msg;
  el.className = "status" + (kind ? " " + kind : "");
}

function stripAi(raw) {
  let name = (raw || "").trim().toLowerCase();
  if (name.endsWith(".ai")) name = name.slice(0, -3);
  return name;
}

// Client-side name validation, same rules as the contract:
// length 1-63, [a-z0-9-] only, must not start or end with "-".
function isValidName(name) {
  return typeof name === "string"
    && name.length >= 1 && name.length <= 63
    && /^[a-z0-9-]+$/.test(name)
    && !name.startsWith("-") && !name.endsWith("-");
}

function shortAddr(addr) {
  return addr ? addr.slice(0, 6) + "…" + addr.slice(-4) : "";
}

function fmtAmount(value, decimals) {
  try { return ethers.formatUnits(value, decimals); } catch (e) { return String(value); }
}

function parseAmount(str, decimals) {
  return ethers.parseUnits(str.trim(), decimals);
}

function tokenLabel(addr) {
  if (!addr || addr.toLowerCase() === ZERO_ADDRESS) return "BNB";
  for (const [key, t] of Object.entries(TOKENS)) {
    if (t.address.toLowerCase() === addr.toLowerCase()) return key;
  }
  return shortAddr(addr);
}

function tokenDecimals(addr) {
  if (!addr || addr.toLowerCase() === ZERO_ADDRESS) return 18;
  for (const t of Object.values(TOKENS)) {
    if (t.address.toLowerCase() === addr.toLowerCase()) return t.decimals;
  }
  return 18;
}

function guardDeployed(statusEl) {
  if (!isDeployed) {
    setStatus(statusEl, "Contract not deployed yet — connect to preview the interface. Sending is disabled until the contract is deployed.", "error");
    return false;
  }
  if (!signer) {
    setStatus(statusEl, "Connect your wallet first.", "error");
    return false;
  }
  return true;
}

async function ensureBsc() {
  if (!window.ethereum) return false;
  const chainId = await window.ethereum.request({ method: "eth_chainId" });
  if (parseInt(chainId, 16) === BSC_CHAIN_ID) return true;
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: BSC_CHAIN_HEX }],
    });
    return true;
  } catch (err) {
    return false;
  }
}

// Resolve a name to an address and show it. Returns the address or null.
async function resolveAndShow(inputEl, outEl) {
  const name = stripAi(inputEl.value);
  outEl.textContent = "";
  if (!name) return null;
  if (!isValidName(name)) {
    outEl.textContent = "Invalid name: use 1–63 characters, letters, numbers and hyphens only, and do not start or end with a hyphen.";
    return null;
  }
  if (!isDeployed) {
    outEl.innerHTML = "Preview mode: <b>" + escapeHtml(name) + ".ai</b> — address lookup needs the deployed contract.";
    return null;
  }
  if (!readContract) {
    outEl.textContent = "Connect your wallet to resolve the name.";
    return null;
  }
  try {
    const addr = await readContract.resolveName(name);
    outEl.innerHTML = "Resolves to: <b>" + escapeHtml(addr) + "</b>";
    return addr;
  } catch (err) {
    outEl.textContent = "This name could not be resolved. It may not be registered yet.";
    return null;
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

async function getNameLabel(addr) {
  if (!readContract || !addr || addr.toLowerCase() === ZERO_ADDRESS) return "";
  try {
    const n = await readContract.nameOf(addr);
    return n || "";
  } catch (e) {
    return "";
  }
}

// ---------- wallet ----------

async function connectWallet() {
  if (!window.ethereum) {
    $("accountInfo").textContent = "No injected wallet found. Open this page in a browser with a wallet extension installed (for example MetaMask).";
    return;
  }
  try {
    const ok = await ensureBsc();
    if (!ok) {
      $("accountInfo").textContent = "Please switch your wallet to BNB Smart Chain (chain id 56) and try again.";
      return;
    }
    provider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await provider.send("eth_requestAccounts", []);
    account = accounts[0];
    signer = await provider.getSigner();
    contract = new ethers.Contract(NAMEPAY_ADDRESS, NAMEPAY_ABI, signer);
    readContract = new ethers.Contract(NAMEPAY_ADDRESS, NAMEPAY_ABI, provider);
    $("connectBtn").textContent = "Connected: " + shortAddr(account);
    let label = "";
    if (isDeployed) {
      try { label = await readContract.nameOf(account); } catch (e) { /* no name registered */ }
    }
    $("accountInfo").textContent = "Connected as " + account + (label ? " (" + label + ".ai)" : "") + " on BNB Smart Chain.";
    refreshHistory();
  } catch (err) {
    $("accountInfo").textContent = "Wallet connection failed: " + (err && err.message ? err.message : err);
  }
}

// ---------- send ----------

async function sendPayment() {
  const statusEl = $("sendStatus");
  if (!guardDeployed(statusEl)) return;
  const name = stripAi($("sendName").value);
  if (!isValidName(name)) {
    setStatus(statusEl, "Invalid name: use 1–63 characters, letters, numbers and hyphens only.", "error");
    return;
  }
  const tokenKey = $("sendToken").value;
  const token = TOKENS[tokenKey];
  const amountStr = $("sendAmount").value;
  if (!amountStr || Number(amountStr) <= 0) {
    setStatus(statusEl, "Enter an amount greater than zero.", "error");
    return;
  }
  const memo = $("sendMemo").value || "";
  let amount;
  try { amount = parseAmount(amountStr, token.decimals); } catch (e) {
    setStatus(statusEl, "Amount is not valid for this token.", "error");
    return;
  }
  // Show the resolved address before confirming, so the user sees who they pay.
  const resolved = await resolveAndShow($("sendName"), $("sendResolved"));
  if (!resolved) {
    setStatus(statusEl, "Could not resolve that name. Check the name and try again.", "error");
    return;
  }
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    let tx;
    if (tokenKey === "BNB") {
      tx = await contract.payBNB(name, memo, { value: amount });
    } else {
      // Step 1: approve the EXACT amount (never an unlimited approval).
      setStatus(statusEl, "Step 1 of 2: approve " + amountStr + " " + tokenKey + " for this payment. Confirm in your wallet.", "info");
      const erc20 = new ethers.Contract(token.address, ERC20_ABI, signer);
      const approveTx = await erc20.approve(NAMEPAY_ADDRESS, amount);
      await approveTx.wait();
      // Step 2: the payment itself.
      setStatus(statusEl, "Step 2 of 2: confirm the payment in your wallet.", "info");
      tx = await contract.payToken(token.address, name, amount, memo);
    }
    setStatus(statusEl, "Payment sent. Waiting for confirmation…", "info");
    const receipt = await tx.wait();
    setStatus(statusEl, "Payment confirmed. Transaction: " + receipt.hash, "ok");
    refreshHistory();
  } catch (err) {
    setStatus(statusEl, "Payment failed: " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

// ---------- requests ----------

async function createRequest() {
  const statusEl = $("reqStatus");
  if (!guardDeployed(statusEl)) return;
  const payerName = stripAi($("reqPayerName").value);
  if (!isValidName(payerName)) {
    setStatus(statusEl, "Invalid payer name.", "error");
    return;
  }
  const tokenKey = $("reqToken").value;
  const token = TOKENS[tokenKey];
  const amountStr = $("reqAmount").value;
  if (!amountStr || Number(amountStr) <= 0) {
    setStatus(statusEl, "Enter an amount greater than zero.", "error");
    return;
  }
  const expiryVal = $("reqExpiry").value;
  if (!expiryVal) {
    setStatus(statusEl, "Pick an expiry date and time.", "error");
    return;
  }
  const expiry = Math.floor(new Date(expiryVal).getTime() / 1000);
  if (expiry <= Math.floor(Date.now() / 1000)) {
    setStatus(statusEl, "Expiry must be in the future.", "error");
    return;
  }
  const memo = $("reqMemo").value || "";
  let amount;
  try { amount = parseAmount(amountStr, token.decimals); } catch (e) {
    setStatus(statusEl, "Amount is not valid for this token.", "error");
    return;
  }
  const resolved = await resolveAndShow($("reqPayerName"), $("reqPayerResolved"));
  if (!resolved) {
    setStatus(statusEl, "Could not resolve the payer name.", "error");
    return;
  }
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    const tx = await contract.createRequest(payerName, token.address, amount, expiry, memo);
    const receipt = await tx.wait();
    const created = receipt.logs
      .map((l) => { try { return contract.interface.parseLog(l); } catch (e) { return null; } })
      .find((p) => p && p.name === "RequestCreated");
    const id = created ? created.args.requestId.toString() : "(see transaction)";
    setStatus(statusEl, "Request created. Request ID: " + id + ". Share that ID with the payer.", "ok");
  } catch (err) {
    setStatus(statusEl, "Could not create the request: " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

async function loadRequest() {
  const statusEl = $("payReqStatus");
  const idStr = $("payReqId").value;
  if (idStr === "" || idStr === null) {
    setStatus(statusEl, "Enter a request ID.", "error");
    return;
  }
  if (!isDeployed) {
    $("reqDetails").textContent = "Preview mode: request details need the deployed contract.";
    return;
  }
  if (!readContract) {
    setStatus(statusEl, "Connect your wallet first.", "error");
    return;
  }
  try {
    const r = await readContract.getRequest(idStr);
    const statusNames = ["Pending", "Paid", "Cancelled"];
    const expired = Number(r.status) === 0 && Number(r.expiry) * 1000 < Date.now();
    const payerName = await getNameLabel(r.payer);
    const requesterName = await getNameLabel(r.requester);
    $("reqDetails").innerHTML =
      "Request #" + r.id.toString() + " — " + fmtAmount(r.amount, tokenDecimals(r.token)) + " " + tokenLabel(r.token) +
      "<br>From: " + escapeHtml(requesterName ? requesterName + ".ai" : shortAddr(r.requester)) +
      " (" + escapeHtml(r.requester) + ")" +
      "<br>To be paid by: " + escapeHtml(payerName ? payerName + ".ai" : shortAddr(r.payer)) +
      " (" + escapeHtml(r.payer) + ")" +
      "<br>Status: " + (expired ? "Expired" : statusNames[Number(r.status)] || r.status) +
      " — expires " + new Date(Number(r.expiry) * 1000).toLocaleString() +
      (r.memo ? "<br>Memo: " + escapeHtml(r.memo) : "");
    window._loadedRequest = r;
    setStatus(statusEl, "", "info");
  } catch (err) {
    $("reqDetails").textContent = "";
    setStatus(statusEl, "Could not load that request. It may not exist.", "error");
  }
}

async function payLoadedRequest() {
  const statusEl = $("payReqStatus");
  if (!guardDeployed(statusEl)) return;
  const r = window._loadedRequest;
  if (!r) {
    setStatus(statusEl, "Load a request first (Show request).", "error");
    return;
  }
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    let tx;
    const isBnb = r.token.toLowerCase() === ZERO_ADDRESS;
    if (isBnb) {
      tx = await contract.payRequest(r.id, { value: r.amount });
    } else {
      // Approve the EXACT request amount first, then pay.
      setStatus(statusEl, "Step 1 of 2: approve the exact request amount. Confirm in your wallet.", "info");
      const erc20 = new ethers.Contract(r.token, ERC20_ABI, signer);
      const approveTx = await erc20.approve(NAMEPAY_ADDRESS, r.amount);
      await approveTx.wait();
      setStatus(statusEl, "Step 2 of 2: confirm the payment in your wallet.", "info");
      tx = await contract.payRequest(r.id);
    }
    const receipt = await tx.wait();
    setStatus(statusEl, "Request paid. Transaction: " + receipt.hash, "ok");
    window._loadedRequest = null;
    refreshHistory();
  } catch (err) {
    setStatus(statusEl, "Payment failed: " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

async function cancelLoadedRequest() {
  const statusEl = $("payReqStatus");
  if (!guardDeployed(statusEl)) return;
  const r = window._loadedRequest;
  if (!r) {
    setStatus(statusEl, "Load a request first (Show request).", "error");
    return;
  }
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    const tx = await contract.cancelRequest(r.id);
    const receipt = await tx.wait();
    setStatus(statusEl, "Request cancelled. Transaction: " + receipt.hash, "ok");
    window._loadedRequest = null;
  } catch (err) {
    setStatus(statusEl, "Cancel failed: " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

// ---------- split ----------

function splitRowHtml(index) {
  return '<div class="split-row" data-row="' + index + '">' +
    '<input type="text" class="split-name" placeholder="Name (e.g. hanta)" autocomplete="off" spellcheck="false">' +
    '<input type="number" class="split-amount" min="0" step="any" placeholder="Amount">' +
    '<button type="button" class="secondary split-remove">Remove</button>' +
    '</div>';
}

function initSplitRows() {
  const box = $("splitRows");
  box.innerHTML = splitRowHtml(0) + splitRowHtml(1);
  box.addEventListener("click", (e) => {
    if (e.target.classList.contains("split-remove")) {
      const rows = box.querySelectorAll(".split-row");
      if (rows.length > 1) e.target.closest(".split-row").remove();
      updateSplitTotal();
    }
  });
  box.addEventListener("input", updateSplitTotal);
}

function addSplitRow() {
  const box = $("splitRows");
  const count = box.querySelectorAll(".split-row").length;
  if (count >= MAX_SPLIT_RECIPIENTS) {
    setStatus($("splitStatus"), "A split payment supports at most " + MAX_SPLIT_RECIPIENTS + " recipients.", "error");
    return;
  }
  box.insertAdjacentHTML("beforeend", splitRowHtml(count));
}

function readSplitRows() {
  const rows = [];
  document.querySelectorAll("#splitRows .split-row").forEach((row) => {
    const name = stripAi(row.querySelector(".split-name").value);
    const amountStr = row.querySelector(".split-amount").value;
    rows.push({ name, amountStr });
  });
  return rows;
}

function updateSplitTotal() {
  const tokenKey = $("splitToken").value;
  const token = TOKENS[tokenKey];
  let total = 0n;
  let ok = true;
  for (const r of readSplitRows()) {
    if (!r.amountStr || Number(r.amountStr) <= 0) { ok = false; continue; }
    try { total += parseAmount(r.amountStr, token.decimals); } catch (e) { ok = false; }
  }
  $("splitTotal").textContent = ok
    ? "Total to send: " + fmtAmount(total, token.decimals) + " " + tokenKey
    : "Total: enter a positive amount for every row.";
}

async function sendSplit() {
  const statusEl = $("splitStatus");
  if (!guardDeployed(statusEl)) return;
  const tokenKey = $("splitToken").value;
  const token = TOKENS[tokenKey];
  const rows = readSplitRows().filter((r) => r.name !== "" || r.amountStr !== "");
  if (rows.length < 1) {
    setStatus(statusEl, "Add at least one recipient.", "error");
    return;
  }
  if (rows.length > MAX_SPLIT_RECIPIENTS) {
    setStatus(statusEl, "A split payment supports at most " + MAX_SPLIT_RECIPIENTS + " recipients.", "error");
    return;
  }
  const names = [];
  const amounts = [];
  for (const r of rows) {
    if (!isValidName(r.name)) {
      setStatus(statusEl, "Invalid name: \"" + r.name + "\". Use 1–63 characters, letters, numbers and hyphens only.", "error");
      return;
    }
    if (!r.amountStr || Number(r.amountStr) <= 0) {
      setStatus(statusEl, "Enter a positive amount for every recipient.", "error");
      return;
    }
    try {
      names.push(r.name);
      amounts.push(parseAmount(r.amountStr, token.decimals));
    } catch (e) {
      setStatus(statusEl, "An amount is not valid for this token.", "error");
      return;
    }
  }
  const memo = $("splitMemo").value || "";
  const total = amounts.reduce((a, b) => a + b, 0n);
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    let tx;
    if (tokenKey === "BNB") {
      tx = await contract.splitPayBNB(names, amounts, memo, { value: total });
    } else {
      // Approve the EXACT total first, then send the split.
      setStatus(statusEl, "Step 1 of 2: approve the exact total (" + fmtAmount(total, token.decimals) + " " + tokenKey + "). Confirm in your wallet.", "info");
      const erc20 = new ethers.Contract(token.address, ERC20_ABI, signer);
      const approveTx = await erc20.approve(NAMEPAY_ADDRESS, total);
      await approveTx.wait();
      setStatus(statusEl, "Step 2 of 2: confirm the split payment in your wallet.", "info");
      tx = await contract.splitPayToken(token.address, names, amounts, memo);
    }
    const receipt = await tx.wait();
    setStatus(statusEl, "Split payment confirmed. Transaction: " + receipt.hash, "ok");
    refreshHistory();
  } catch (err) {
    setStatus(statusEl, "Split payment failed: " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

// ---------- recurring ----------

function updateSubTotal() {
  const tokenKey = $("subToken").value;
  const token = TOKENS[tokenKey];
  const amountStr = $("subAmount").value;
  const max = Number($("subMaxPayments").value);
  if (!amountStr || Number(amountStr) <= 0 || !max || max < 1 || max > MAX_SUBSCRIPTION_PAYMENTS) {
    $("subTotal").textContent = "Total escrow: enter a positive amount per period and 1–" + MAX_SUBSCRIPTION_PAYMENTS + " payments.";
    return;
  }
  try {
    const per = parseAmount(amountStr, token.decimals);
    const total = per * BigInt(max);
    $("subTotal").textContent = "Total escrow (paid up front): " + fmtAmount(total, token.decimals) + " " + tokenKey +
      " — " + fmtAmount(per, token.decimals) + " " + tokenKey + " × " + max + " payments.";
  } catch (e) {
    $("subTotal").textContent = "Amount is not valid for this token.";
  }
}

async function createSubscription() {
  const statusEl = $("subStatus");
  if (!guardDeployed(statusEl)) return;
  const payeeName = stripAi($("subPayeeName").value);
  if (!isValidName(payeeName)) {
    setStatus(statusEl, "Invalid payee name.", "error");
    return;
  }
  const tokenKey = $("subToken").value;
  const token = TOKENS[tokenKey];
  const amountStr = $("subAmount").value;
  if (!amountStr || Number(amountStr) <= 0) {
    setStatus(statusEl, "Enter an amount per period greater than zero.", "error");
    return;
  }
  const periodSeconds = Number($("subPeriod").value);
  const maxPayments = Number($("subMaxPayments").value);
  if (maxPayments < 1 || maxPayments > MAX_SUBSCRIPTION_PAYMENTS) {
    setStatus(statusEl, "Number of payments must be between 1 and " + MAX_SUBSCRIPTION_PAYMENTS + ".", "error");
    return;
  }
  let per;
  try { per = parseAmount(amountStr, token.decimals); } catch (e) {
    setStatus(statusEl, "Amount is not valid for this token.", "error");
    return;
  }
  const total = per * BigInt(maxPayments);
  const resolved = await resolveAndShow($("subPayeeName"), $("subPayeeResolved"));
  if (!resolved) {
    setStatus(statusEl, "Could not resolve the payee name.", "error");
    return;
  }
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    let tx;
    if (tokenKey === "BNB") {
      tx = await contract.createSubscriptionBNB(payeeName, per, periodSeconds, maxPayments, { value: total });
    } else {
      // Token subscriptions are funded by a direct transfer, not an allowance:
      // approve the EXACT escrow total, then create the subscription.
      setStatus(statusEl, "Step 1 of 2: approve the exact escrow total (" + fmtAmount(total, token.decimals) + " " + tokenKey + "). Confirm in your wallet.", "info");
      const erc20 = new ethers.Contract(token.address, ERC20_ABI, signer);
      const approveTx = await erc20.approve(NAMEPAY_ADDRESS, total);
      await approveTx.wait();
      setStatus(statusEl, "Step 2 of 2: confirm the subscription in your wallet.", "info");
      tx = await contract.createSubscriptionToken(token.address, payeeName, per, periodSeconds, maxPayments);
    }
    const receipt = await tx.wait();
    const created = receipt.logs
      .map((l) => { try { return contract.interface.parseLog(l); } catch (e) { return null; } })
      .find((p) => p && p.name === "SubscriptionCreated");
    const id = created ? created.args.subscriptionId.toString() : "(see transaction)";
    setStatus(statusEl, "Subscription created. Subscription ID: " + id + ".", "ok");
  } catch (err) {
    setStatus(statusEl, "Could not create the subscription: " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

async function loadSubscription() {
  const statusEl = $("subActionStatus");
  const idStr = $("subLookupId").value;
  if (idStr === "" || idStr === null) {
    setStatus(statusEl, "Enter a subscription ID.", "error");
    return;
  }
  if (!isDeployed) {
    $("subDetails").textContent = "Preview mode: subscription details need the deployed contract.";
    return;
  }
  if (!readContract) {
    setStatus(statusEl, "Connect your wallet first.", "error");
    return;
  }
  try {
    const s = await readContract.getSubscription(idStr);
    const statusNames = ["Active", "Completed", "Cancelled"];
    const payeeName = await getNameLabel(s.payee);
    const subName = await getNameLabel(s.subscriber);
    const due = new Date(Number(s.nextPaymentDue) * 1000);
    $("subDetails").innerHTML =
      "Subscription #" + s.id.toString() + " — " + fmtAmount(s.amountPerPeriod, tokenDecimals(s.token)) + " " + tokenLabel(s.token) +
      " every " + Math.round(Number(s.periodSeconds) / 86400) + " day(s)" +
      "<br>Subscriber: " + escapeHtml(subName ? subName + ".ai" : shortAddr(s.subscriber)) +
      "<br>Payee: " + escapeHtml(payeeName ? payeeName + ".ai" : shortAddr(s.payee)) +
      "<br>Payments made: " + s.paymentsMade.toString() + " of " + s.maxPayments.toString() +
      "<br>Next payment due: " + due.toLocaleString() + (due.getTime() <= Date.now() ? " (due now)" : "") +
      "<br>Status: " + (statusNames[Number(s.status)] || s.status);
    window._loadedSubscription = s;
    setStatus(statusEl, "", "info");
  } catch (err) {
    $("subDetails").textContent = "";
    setStatus(statusEl, "Could not load that subscription. It may not exist.", "error");
  }
}

async function executeLoadedSubscription() {
  const statusEl = $("subActionStatus");
  if (!guardDeployed(statusEl)) return;
  const s = window._loadedSubscription;
  if (!s) {
    setStatus(statusEl, "Load a subscription first (Show subscription).", "error");
    return;
  }
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    const tx = await contract.executeSubscription(s.id);
    const receipt = await tx.wait();
    setStatus(statusEl, "Payment executed. Transaction: " + receipt.hash, "ok");
    refreshHistory();
  } catch (err) {
    setStatus(statusEl, "Execution failed: " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

async function cancelLoadedSubscription() {
  const statusEl = $("subActionStatus");
  if (!guardDeployed(statusEl)) return;
  const s = window._loadedSubscription;
  if (!s) {
    setStatus(statusEl, "Load a subscription first (Show subscription).", "error");
    return;
  }
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    const tx = await contract.cancelSubscription(s.id);
    const receipt = await tx.wait();
    setStatus(statusEl, "Subscription cancelled. The unspent escrow is refunded to the subscriber. Transaction: " + receipt.hash, "ok");
    window._loadedSubscription = null;
  } catch (err) {
    setStatus(statusEl, "Cancel failed: " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

// ---------- tip link ----------

function makeTipLink() {
  const name = stripAi($("tipName").value);
  if (!isValidName(name)) {
    $("tipLinkOut").textContent = "Invalid name: use 1–63 characters, letters, numbers and hyphens only.";
    return;
  }
  const url = location.origin + location.pathname.replace(/index\.html$/, "") + "tip.html?name=" + encodeURIComponent(name);
  $("tipLinkOut").innerHTML = "Your tip link: <a href=\"" + escapeHtml(url) + "\">" + escapeHtml(url) + "</a>";
}

// ---------- register name ----------

async function registerMyName() {
  const statusEl = $("nameStatus");
  if (!guardDeployed(statusEl)) return;
  const name = stripAi($("myName").value);
  if (!isValidName(name)) {
    setStatus(statusEl, "Invalid name.", "error");
    return;
  }
  setStatus(statusEl, "Waiting for wallet confirmation…", "info");
  try {
    const tx = await contract.registerName(name);
    const receipt = await tx.wait();
    setStatus(statusEl, "Name registered: " + name + ".ai. Transaction: " + receipt.hash, "ok");
  } catch (err) {
    setStatus(statusEl, "Registration failed (you must own this name): " + (err && err.reason ? err.reason : err && err.message ? err.message : err), "error");
  }
}

// ---------- history ----------

async function refreshHistory() {
  const box = $("historyList");
  if (!isDeployed) {
    box.textContent = "History needs the deployed contract. Connect to preview the interface.";
    return;
  }
  if (!provider) {
    box.textContent = "Connect your wallet to load history.";
    return;
  }
  box.textContent = "Loading history…";
  try {
    const fromBlock = DEPLOYMENT_BLOCK > 0 ? DEPLOYMENT_BLOCK : (await provider.getBlockNumber()) - 5000;
    const iface = new ethers.Interface(NAMEPAY_ABI);
    const paymentTopic = iface.getEvent("PaymentSent").topicHash;
    const logs = await provider.getLogs({
      address: NAMEPAY_ADDRESS,
      topics: [paymentTopic],
      fromBlock,
      toBlock: "latest",
    });
    if (logs.length === 0) {
      box.textContent = "No payments found yet.";
      return;
    }
    const items = [];
    for (const log of logs.slice(-20).reverse()) {
      const parsed = iface.parseLog(log);
      const senderName = parsed.args.senderName || await getNameLabel(parsed.args.sender);
      const recipientName = parsed.args.recipientName || await getNameLabel(parsed.args.recipient);
      const label = (n, a) => n ? n + ".ai" : shortAddr(a);
      items.push("<li>" + escapeHtml(label(senderName, parsed.args.sender)) + " → " +
        escapeHtml(label(recipientName, parsed.args.recipient)) + " — " +
        escapeHtml(fmtAmount(parsed.args.amount, tokenDecimals(parsed.args.token))) + " " +
        escapeHtml(tokenLabel(parsed.args.token)) +
        (parsed.args.memo ? " — “" + escapeHtml(parsed.args.memo) + "”" : "") + "</li>");
    }
    box.innerHTML = "<ul class=\"clean\">" + items.join("") + "</ul>";
  } catch (err) {
    box.textContent = "Could not load history: " + (err && err.message ? err.message : err);
  }
}

// ---------- init ----------

function init() {
  const banner = $("deployBanner");
  if (!isDeployed) {
    banner.textContent = "Contract not deployed yet — connect to preview the interface. All forms accept input, but Send buttons are disabled until the contract is deployed.";
    banner.classList.remove("ok");
  } else {
    banner.textContent = "Contract live at " + NAMEPAY_ADDRESS + " on BNB Smart Chain.";
    banner.classList.add("ok");
  }

  // Disable send buttons in preview mode (forms stay usable for input).
  const sendButtons = ["sendBtn", "createReqBtn", "payReqBtn", "cancelReqBtn", "splitBtn", "createSubBtn", "execSubBtn", "cancelSubBtn", "registerNameBtn"];
  if (!isDeployed) {
    for (const id of sendButtons) $(id).disabled = true;
    for (const id of sendButtons) $(id).title = "Disabled: contract not deployed yet.";
  }

  $("connectBtn").addEventListener("click", connectWallet);
  $("sendBtn").addEventListener("click", sendPayment);
  $("sendToken").addEventListener("change", () => {
    $("sendApproveNote").hidden = $("sendToken").value === "BNB";
  });
  $("sendName").addEventListener("change", () => resolveAndShow($("sendName"), $("sendResolved")));
  $("createReqBtn").addEventListener("click", createRequest);
  $("reqPayerName").addEventListener("change", () => resolveAndShow($("reqPayerName"), $("reqPayerResolved")));
  $("loadReqBtn").addEventListener("click", loadRequest);
  $("payReqBtn").addEventListener("click", payLoadedRequest);
  $("cancelReqBtn").addEventListener("click", cancelLoadedRequest);
  initSplitRows();
  $("addSplitRowBtn").addEventListener("click", addSplitRow);
  $("splitToken").addEventListener("change", updateSplitTotal);
  $("splitBtn").addEventListener("click", sendSplit);
  $("subPayeeName").addEventListener("change", () => resolveAndShow($("subPayeeName"), $("subPayeeResolved")));
  $("subAmount").addEventListener("input", updateSubTotal);
  $("subMaxPayments").addEventListener("input", updateSubTotal);
  $("subToken").addEventListener("change", updateSubTotal);
  $("createSubBtn").addEventListener("click", createSubscription);
  $("loadSubBtn").addEventListener("click", loadSubscription);
  $("execSubBtn").addEventListener("click", executeLoadedSubscription);
  $("cancelSubBtn").addEventListener("click", cancelLoadedSubscription);
  $("makeTipLinkBtn").addEventListener("click", makeTipLink);
  $("refreshHistoryBtn").addEventListener("click", refreshHistory);
  $("registerNameBtn").addEventListener("click", registerMyName);
  updateSubTotal();
  updateSplitTotal();
}

document.addEventListener("DOMContentLoaded", init);
