// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {NamePay} from "../src/NamePay.sol";
import {MockAgentID} from "./mocks/MockAgentID.sol";

/// @notice Unit tests for NamePay. Mocks stand in for Agent ID (names
/// hanta->alice, budi->bob, cici->carol, dedi->dave) and for USDT/USDC.
contract NamePayTest is Test {
    // Events mirrored from NamePay for vm.expectEmit.
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

    // Checksummed Agent ID address on BSC (solc 0.8.24 rejects the
    // all-lowercase form). NamePay hardcodes USDT/USDC as constants, so unit
    // tests etch the mock's code onto this address instead of injecting it.
    address internal constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    MockAgentID internal agentId;
    ERC20Mock internal usdt;
    ERC20Mock internal usdc;
    ERC20Mock internal other;
    NamePay internal namePay;

    address internal alice;
    address internal bob;
    address internal carol;
    address internal dave;
    address internal stranger;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        dave = makeAddr("dave");
        stranger = makeAddr("stranger");

        bytes32[] memory ids = new bytes32[](4);
        address[] memory owners = new address[](4);
        ids[0] = keccak256(bytes("hanta"));
        owners[0] = alice;
        ids[1] = keccak256(bytes("budi"));
        owners[1] = bob;
        ids[2] = keccak256(bytes("cici"));
        owners[2] = carol;
        ids[3] = keccak256(bytes("dedi"));
        owners[3] = dave;
        agentId = new MockAgentID(ids, owners);
        // NamePay reads the Agent ID contract at its hardcoded BSC address,
        // so etch the mock's code there and re-populate its storage through
        // the mock's test-only setOwner helper (etching copies code, not
        // storage, so the constructor-set pairs would otherwise be lost).
        vm.etch(AGENT_ID, address(agentId).code);
        for (uint256 i; i < ids.length; ++i) {
            MockAgentID(AGENT_ID).setOwner(uint256(ids[i]), owners[i]);
        }

        usdt = new ERC20Mock();
        usdc = new ERC20Mock();
        other = new ERC20Mock();

        namePay = new NamePay(AGENT_ID);
        // The mock stablecoins stand in for the hardcoded USDT/USDC, so
        // allowlist them; the real USDT/USDC constants are already allowed.
        namePay.setTokenAllowed(address(usdt), true);
        namePay.setTokenAllowed(address(usdc), true);

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        vm.deal(dave, 100 ether);
        usdt.mint(alice, 1_000_000 ether);
        usdt.mint(bob, 1_000_000 ether);
        usdc.mint(alice, 1_000_000 ether);
        usdc.mint(bob, 1_000_000 ether);
        other.mint(alice, 1_000_000 ether);
    }

    // --- helpers ---

    function _names3() internal pure returns (string[] memory names) {
        names = new string[](3);
        names[0] = "budi";
        names[1] = "cici";
        names[2] = "dedi";
    }

    function _amounts3(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](3);
        amounts[0] = a;
        amounts[1] = b;
        amounts[2] = c;
    }

    /// @notice Creates a BNB subscription from alice to bob and returns its id.
    function _createBnbSub(uint256 amountPerPeriod, uint256 periodSeconds, uint256 maxPayments)
        internal
        returns (uint256 subscriptionId)
    {
        vm.prank(alice);
        subscriptionId = namePay.createSubscriptionBNB{value: amountPerPeriod * maxPayments}(
            "budi", amountPerPeriod, periodSeconds, maxPayments
        );
    }

    // --- resolveName ---

    function test_resolveName_valid() public view {
        assertEq(namePay.resolveName("hanta"), alice);
        assertEq(namePay.resolveName("budi"), bob);
        assertEq(namePay.resolveName("cici"), carol);
        assertEq(namePay.resolveName("dedi"), dave);
    }

    function test_resolveName_invalidChars() public {
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.resolveName("Hanta");
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.resolveName("han_ta");
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.resolveName("hanta.ai");
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.resolveName("hanta!");
    }

    function test_resolveName_empty() public {
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.resolveName("");
    }

    function test_resolveName_tooLong() public {
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.resolveName("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    }

    function test_resolveName_leadingTrailingDash() public {
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.resolveName("-hanta");
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.resolveName("hanta-");
        // A dash inside the name is valid; it just isn't claimed here.
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.resolveName("han-ta");
    }

    function test_resolveName_unclaimed() public {
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.resolveName("ghost");
    }

    // --- registerName ---

    function test_registerName_happy() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit NameRegistered(alice, "hanta");
        namePay.registerName("hanta");
        assertEq(namePay.nameOf(alice), "hanta");
    }

    function test_registerName_notOwner() public {
        vm.prank(bob);
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.registerName("hanta");
    }

    function test_registerName_unclaimed() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.registerName("ghost");
    }

    function test_registerName_invalid() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.InvalidName.selector);
        namePay.registerName("Hanta");
    }

    // --- payBNB / payToken ---

    function test_payBNB_happy() public {
        uint256 bobBefore = bob.balance;
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PaymentSent(alice, "", bob, "", address(0), 1 ether, "thanks");
        namePay.payBNB{value: 1 ether}("budi", "thanks");
        assertEq(bob.balance, bobBefore + 1 ether);
        assertEq(alice.balance, 99 ether);
        assertEq(address(namePay).balance, 0);
    }

    function test_payBNB_eventIncludesRegisteredNames() public {
        vm.prank(alice);
        namePay.registerName("hanta");
        vm.prank(bob);
        namePay.registerName("budi");
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PaymentSent(alice, "hanta", bob, "budi", address(0), 1 ether, "hi");
        namePay.payBNB{value: 1 ether}("budi", "hi");
    }

    function test_payBNB_zeroValue() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.ZeroAmount.selector);
        namePay.payBNB{value: 0}("budi", "");
    }

    function test_payBNB_unregisteredName() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.payBNB{value: 1 ether}("ghost", "");
    }

    function test_payToken_happy() public {
        vm.prank(alice);
        usdt.approve(address(namePay), 500 ether);
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit PaymentSent(alice, "", bob, "", address(usdt), 500 ether, "usdt");
        namePay.payToken(address(usdt), "budi", 500 ether, "usdt");
        assertEq(usdt.balanceOf(bob), 1_000_000 ether + 500 ether);
        assertEq(usdt.balanceOf(alice), 1_000_000 ether - 500 ether);
        assertEq(usdt.balanceOf(address(namePay)), 0);
    }

    function test_payToken_zeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.ZeroAmount.selector);
        namePay.payToken(address(usdt), "budi", 0, "");
    }

    function test_payToken_unregisteredName() public {
        vm.prank(alice);
        usdt.approve(address(namePay), 1 ether);
        vm.prank(alice);
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.payToken(address(usdt), "ghost", 1 ether, "");
    }

    function test_payToken_unallowlistedToken() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.TokenNotAllowed.selector);
        namePay.payToken(address(other), "budi", 1 ether, "");
    }

    function test_payToken_bnbAddressRejected() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.TokenNotAllowed.selector);
        namePay.payToken(address(0), "budi", 1 ether, "");
    }

    function test_payToken_noAllowance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(namePay), 0, 1 ether)
        );
        namePay.payToken(address(usdt), "budi", 1 ether, "");
    }

    // --- payment requests ---

    function test_createRequest_bnbHappy() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit RequestCreated(1, alice, bob, address(0), 1 ether, block.timestamp + 1 days);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "lunch");
        assertEq(requestId, 1);
        NamePay.PaymentRequest memory req = namePay.getRequest(requestId);
        assertEq(req.requester, alice);
        assertEq(req.payer, bob);
        assertEq(req.token, address(0));
        assertEq(req.amount, 1 ether);
        assertEq(req.expiry, block.timestamp + 1 days);
        assertEq(uint256(req.status), uint256(NamePay.RequestStatus.Pending));
        assertEq(req.memo, "lunch");
    }

    function test_createRequest_tokenHappy() public {
        vm.prank(alice);
        uint256 requestId =
            namePay.createRequest("budi", address(usdt), 100 ether, block.timestamp + 1 days, "usdt please");
        NamePay.PaymentRequest memory req = namePay.getRequest(requestId);
        assertEq(req.token, address(usdt));
        assertEq(req.amount, 100 ether);
    }

    function test_createRequest_unregisteredPayer() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.createRequest("ghost", address(0), 1 ether, block.timestamp + 1 days, "");
    }

    function test_createRequest_zeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.ZeroAmount.selector);
        namePay.createRequest("budi", address(0), 0, block.timestamp + 1 days, "");
    }

    function test_createRequest_unallowlistedToken() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.TokenNotAllowed.selector);
        namePay.createRequest("budi", address(other), 1 ether, block.timestamp + 1 days, "");
    }

    function test_createRequest_pastExpiry() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.InvalidExpiry.selector);
        namePay.createRequest("budi", address(0), 1 ether, block.timestamp, "");
    }

    function test_payRequest_bnbHappy() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        uint256 aliceBefore = alice.balance;
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit RequestPaid(requestId, bob, 1 ether);
        namePay.payRequest{value: 1 ether}(requestId);
        assertEq(alice.balance, aliceBefore + 1 ether);
        assertEq(uint256(namePay.getRequest(requestId).status), uint256(NamePay.RequestStatus.Paid));
    }

    function test_payRequest_tokenHappy() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(usdt), 100 ether, block.timestamp + 1 days, "");
        vm.prank(bob);
        usdt.approve(address(namePay), 100 ether);
        vm.prank(bob);
        namePay.payRequest(requestId);
        assertEq(usdt.balanceOf(alice), 1_000_000 ether + 100 ether);
        assertEq(usdt.balanceOf(bob), 1_000_000 ether - 100 ether);
        assertEq(uint256(namePay.getRequest(requestId).status), uint256(NamePay.RequestStatus.Paid));
    }

    function test_payRequest_nonPayer() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        vm.prank(carol);
        vm.expectRevert(NamePay.NotPayer.selector);
        namePay.payRequest{value: 1 ether}(requestId);
    }

    function test_payRequest_expired() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        vm.warp(vm.getBlockTimestamp() + 2 days);
        vm.prank(bob);
        vm.expectRevert(NamePay.RequestNotPayable.selector);
        namePay.payRequest{value: 1 ether}(requestId);
    }

    function test_payRequest_wrongBnbAmount() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        vm.prank(bob);
        vm.expectRevert(NamePay.WrongPaymentAmount.selector);
        namePay.payRequest{value: 0.5 ether}(requestId);
    }

    function test_payRequest_doublePay() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        vm.prank(bob);
        namePay.payRequest{value: 1 ether}(requestId);
        vm.prank(bob);
        vm.expectRevert(NamePay.RequestNotPayable.selector);
        namePay.payRequest{value: 1 ether}(requestId);
    }

    function test_payRequest_notFound() public {
        vm.prank(bob);
        vm.expectRevert(NamePay.RequestNotFound.selector);
        namePay.payRequest{value: 1 ether}(999);
    }

    function test_getRequest_notFound() public {
        vm.expectRevert(NamePay.RequestNotFound.selector);
        namePay.getRequest(999);
    }

    function test_cancelRequest_happy() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit RequestCancelled(requestId, alice);
        namePay.cancelRequest(requestId);
        assertEq(uint256(namePay.getRequest(requestId).status), uint256(NamePay.RequestStatus.Cancelled));
        // A cancelled request can no longer be paid.
        vm.prank(bob);
        vm.expectRevert(NamePay.RequestNotPayable.selector);
        namePay.payRequest{value: 1 ether}(requestId);
    }

    function test_cancelRequest_nonRequester() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        vm.prank(bob);
        vm.expectRevert(NamePay.NotRequester.selector);
        namePay.cancelRequest(requestId);
    }

    function test_cancelRequest_paid() public {
        vm.prank(alice);
        uint256 requestId = namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        vm.prank(bob);
        namePay.payRequest{value: 1 ether}(requestId);
        vm.prank(alice);
        vm.expectRevert(NamePay.RequestNotPayable.selector);
        namePay.cancelRequest(requestId);
    }

    // --- split payments ---

    function test_splitPayBNB_happy() public {
        uint256 bobBefore = bob.balance;
        uint256 carolBefore = carol.balance;
        uint256 daveBefore = dave.balance;
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit SplitPaymentSent(alice, address(0), 6 ether, 3);
        namePay.splitPayBNB{value: 6 ether}(_names3(), _amounts3(1 ether, 2 ether, 3 ether), "split");
        assertEq(bob.balance, bobBefore + 1 ether);
        assertEq(carol.balance, carolBefore + 2 ether);
        assertEq(dave.balance, daveBefore + 3 ether);
        assertEq(address(namePay).balance, 0);
    }

    function test_splitPayToken_happy() public {
        vm.prank(alice);
        usdt.approve(address(namePay), 600 ether);
        vm.prank(alice);
        namePay.splitPayToken(address(usdt), _names3(), _amounts3(100 ether, 200 ether, 300 ether), "split");
        assertEq(usdt.balanceOf(bob), 1_000_000 ether + 100 ether);
        assertEq(usdt.balanceOf(carol), 200 ether);
        assertEq(usdt.balanceOf(dave), 300 ether);
        assertEq(usdt.balanceOf(address(namePay)), 0);
    }

    function test_splitPay_lengthMismatch() public {
        string[] memory names = new string[](2);
        names[0] = "budi";
        names[1] = "cici";
        vm.prank(alice);
        vm.expectRevert(NamePay.ArrayLengthMismatch.selector);
        namePay.splitPayBNB{value: 2 ether}(names, _amounts3(1 ether, 1 ether, 1 ether), "");
    }

    function test_splitPay_emptyArrays() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.ArrayLengthMismatch.selector);
        namePay.splitPayBNB{value: 0}(new string[](0), new uint256[](0), "");
    }

    function test_splitPay_tooManyRecipients() public {
        string[] memory names = new string[](21);
        uint256[] memory amounts = new uint256[](21);
        for (uint256 i; i < 21; ++i) {
            names[i] = "budi";
            amounts[i] = 0.01 ether;
        }
        vm.prank(alice);
        vm.expectRevert(NamePay.TooManyRecipients.selector);
        namePay.splitPayBNB{value: 0.21 ether}(names, amounts, "");
    }

    function test_splitPay_maxRecipientsOk() public {
        string[] memory names = new string[](20);
        uint256[] memory amounts = new uint256[](20);
        for (uint256 i; i < 20; ++i) {
            names[i] = "budi";
            amounts[i] = 0.01 ether;
        }
        vm.prank(alice);
        namePay.splitPayBNB{value: 0.2 ether}(names, amounts, "");
        assertEq(bob.balance, 100 ether + 0.2 ether);
    }

    function test_splitPay_wrongTotal() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.WrongPaymentAmount.selector);
        namePay.splitPayBNB{value: 5 ether}(_names3(), _amounts3(1 ether, 2 ether, 3 ether), "");
    }

    function test_splitPay_zeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.ZeroAmount.selector);
        namePay.splitPayBNB{value: 2 ether}(_names3(), _amounts3(1 ether, 0, 1 ether), "");
    }

    function test_splitPay_unregisteredName() public {
        string[] memory names = new string[](2);
        names[0] = "budi";
        names[1] = "ghost";
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;
        uint256 bobBefore = bob.balance;
        vm.prank(alice);
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.splitPayBNB{value: 2 ether}(names, amounts, "");
        // Nothing moved: a bad name reverts before any transfer.
        assertEq(bob.balance, bobBefore);
    }

    function test_splitPayToken_unallowlisted() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.TokenNotAllowed.selector);
        namePay.splitPayToken(address(other), _names3(), _amounts3(1 ether, 1 ether, 1 ether), "");
    }

    // --- subscriptions ---

    function test_createSubscriptionBNB_happy() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, false);
        emit SubscriptionCreated(1, alice, bob, address(0), 1 ether, 30 days, 3);
        uint256 subscriptionId = namePay.createSubscriptionBNB{value: 3 ether}("budi", 1 ether, 30 days, 3);
        assertEq(subscriptionId, 1);
        assertEq(address(namePay).balance, 3 ether);
        NamePay.Subscription memory sub = namePay.getSubscription(subscriptionId);
        assertEq(sub.subscriber, alice);
        assertEq(sub.payee, bob);
        assertEq(sub.token, address(0));
        assertEq(sub.amountPerPeriod, 1 ether);
        assertEq(sub.periodSeconds, 30 days);
        assertEq(sub.maxPayments, 3);
        assertEq(sub.paymentsMade, 0);
        assertEq(sub.nextPaymentDue, block.timestamp + 30 days);
        assertEq(uint256(sub.status), uint256(NamePay.SubscriptionStatus.Active));
    }

    function test_createSubscriptionToken_happy() public {
        vm.prank(alice);
        usdt.approve(address(namePay), 300 ether);
        vm.prank(alice);
        uint256 subscriptionId = namePay.createSubscriptionToken(address(usdt), "budi", 100 ether, 7 days, 3);
        assertEq(usdt.balanceOf(address(namePay)), 300 ether);
        assertEq(usdt.balanceOf(alice), 1_000_000 ether - 300 ether);
        NamePay.Subscription memory sub = namePay.getSubscription(subscriptionId);
        assertEq(sub.token, address(usdt));
        assertEq(sub.amountPerPeriod, 100 ether);
    }

    function test_createSubscriptionBNB_wrongEscrow() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.WrongPaymentAmount.selector);
        namePay.createSubscriptionBNB{value: 2 ether}("budi", 1 ether, 30 days, 3);
    }

    function test_createSubscription_invalidPeriod() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.InvalidPeriod.selector);
        namePay.createSubscriptionBNB{value: 3 ether}("budi", 1 ether, 12 hours, 3);
        vm.prank(alice);
        vm.expectRevert(NamePay.InvalidPeriod.selector);
        namePay.createSubscriptionBNB{value: 1 ether}("budi", 1 ether, 0, 1);
    }

    function test_createSubscription_invalidMaxPayments() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.InvalidMaxPayments.selector);
        namePay.createSubscriptionBNB{value: 0}("budi", 1 ether, 30 days, 0);
        vm.prank(alice);
        vm.expectRevert(NamePay.InvalidMaxPayments.selector);
        namePay.createSubscriptionBNB{value: 25 ether}("budi", 1 ether, 30 days, 25);
    }

    function test_createSubscription_zeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.ZeroAmount.selector);
        namePay.createSubscriptionBNB{value: 0}("budi", 0, 30 days, 3);
    }

    function test_createSubscription_unallowlistedToken() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.TokenNotAllowed.selector);
        namePay.createSubscriptionToken(address(other), "budi", 1 ether, 30 days, 3);
    }

    function test_createSubscription_unregisteredPayee() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.NameNotRegistered.selector);
        namePay.createSubscriptionBNB{value: 3 ether}("ghost", 1 ether, 30 days, 3);
    }

    function test_executeSubscription_early() public {
        uint256 subscriptionId = _createBnbSub(1 ether, 30 days, 3);
        vm.prank(dave);
        vm.expectRevert(NamePay.SubscriptionNotDue.selector);
        namePay.executeSubscription(subscriptionId);
    }

    function test_executeSubscription_happy() public {
        uint256 subscriptionId = _createBnbSub(1 ether, 30 days, 3);
        uint256 bobBefore = bob.balance;
        uint256 due = namePay.getSubscription(subscriptionId).nextPaymentDue;
        vm.warp(due);
        // Anyone (a keeper) can execute.
        vm.prank(dave);
        vm.expectEmit(true, true, false, true);
        emit SubscriptionExecuted(subscriptionId, 1, 1 ether);
        namePay.executeSubscription(subscriptionId);
        assertEq(bob.balance, bobBefore + 1 ether);
        NamePay.Subscription memory sub = namePay.getSubscription(subscriptionId);
        assertEq(sub.paymentsMade, 1);
        assertEq(sub.nextPaymentDue, due + 30 days);
        assertEq(uint256(sub.status), uint256(NamePay.SubscriptionStatus.Active));
        assertEq(address(namePay).balance, 2 ether);
    }

    function test_executeSubscription_tokenHappy() public {
        vm.prank(alice);
        usdt.approve(address(namePay), 300 ether);
        vm.prank(alice);
        uint256 subscriptionId = namePay.createSubscriptionToken(address(usdt), "budi", 100 ether, 7 days, 3);
        vm.warp(vm.getBlockTimestamp() + 7 days);
        vm.prank(dave);
        namePay.executeSubscription(subscriptionId);
        assertEq(usdt.balanceOf(bob), 1_000_000 ether + 100 ether);
        assertEq(usdt.balanceOf(address(namePay)), 200 ether);
    }

    function test_executeSubscription_completes() public {
        uint256 subscriptionId = _createBnbSub(1 ether, 30 days, 2);
        vm.warp(vm.getBlockTimestamp() + 30 days);
        namePay.executeSubscription(subscriptionId);
        vm.warp(vm.getBlockTimestamp() + 30 days);
        namePay.executeSubscription(subscriptionId);
        NamePay.Subscription memory sub = namePay.getSubscription(subscriptionId);
        assertEq(sub.paymentsMade, 2);
        assertEq(uint256(sub.status), uint256(NamePay.SubscriptionStatus.Completed));
        assertEq(bob.balance, 100 ether + 2 ether);
        assertEq(address(namePay).balance, 0);
        // Completed subscriptions cannot execute again.
        vm.warp(vm.getBlockTimestamp() + 30 days);
        vm.expectRevert(NamePay.SubscriptionNotActive.selector);
        namePay.executeSubscription(subscriptionId);
    }

    function test_executeSubscription_notFound() public {
        vm.expectRevert(NamePay.SubscriptionNotFound.selector);
        namePay.executeSubscription(999);
    }

    function test_cancelSubscription_refundsRemainder() public {
        uint256 subscriptionId = _createBnbSub(1 ether, 30 days, 3);
        vm.warp(vm.getBlockTimestamp() + 30 days);
        namePay.executeSubscription(subscriptionId);
        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit SubscriptionCancelled(subscriptionId, alice, 2 ether);
        namePay.cancelSubscription(subscriptionId);
        assertEq(alice.balance, aliceBefore + 2 ether);
        assertEq(address(namePay).balance, 0);
        assertEq(uint256(namePay.getSubscription(subscriptionId).status), uint256(NamePay.SubscriptionStatus.Cancelled));
    }

    function test_cancelSubscription_tokenRefund() public {
        vm.prank(alice);
        usdt.approve(address(namePay), 300 ether);
        vm.prank(alice);
        uint256 subscriptionId = namePay.createSubscriptionToken(address(usdt), "budi", 100 ether, 7 days, 3);
        vm.prank(alice);
        namePay.cancelSubscription(subscriptionId);
        assertEq(usdt.balanceOf(alice), 1_000_000 ether);
        assertEq(usdt.balanceOf(address(namePay)), 0);
    }

    function test_cancelSubscription_nonSubscriber() public {
        uint256 subscriptionId = _createBnbSub(1 ether, 30 days, 3);
        vm.prank(bob);
        vm.expectRevert(NamePay.NotSubscriber.selector);
        namePay.cancelSubscription(subscriptionId);
    }

    function test_cancelSubscription_completed() public {
        uint256 subscriptionId = _createBnbSub(1 ether, 30 days, 1);
        vm.warp(vm.getBlockTimestamp() + 30 days);
        namePay.executeSubscription(subscriptionId);
        vm.prank(alice);
        vm.expectRevert(NamePay.SubscriptionNotActive.selector);
        namePay.cancelSubscription(subscriptionId);
    }

    function test_cancelSubscription_notFound() public {
        vm.prank(alice);
        vm.expectRevert(NamePay.SubscriptionNotFound.selector);
        namePay.cancelSubscription(999);
    }

    function test_getSubscription_notFound() public {
        vm.expectRevert(NamePay.SubscriptionNotFound.selector);
        namePay.getSubscription(999);
    }

    // --- admin / pause ---

    function test_admin_nonOwnerPause() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        namePay.pause();
    }

    function test_admin_nonOwnerSetTokenAllowed() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        namePay.setTokenAllowed(address(other), true);
    }

    function test_admin_pauseBlocksPayments() public {
        namePay.pause();
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        namePay.payBNB{value: 1 ether}("budi", "");
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        namePay.payToken(address(usdt), "budi", 1 ether, "");
        // Unpause restores payments.
        namePay.unpause();
        vm.prank(alice);
        namePay.payBNB{value: 1 ether}("budi", "");
        assertEq(bob.balance, 100 ether + 1 ether);
    }

    function test_admin_pauseBlocksRequestsAndSplits() public {
        namePay.pause();
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        namePay.createRequest("budi", address(0), 1 ether, block.timestamp + 1 days, "");
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        namePay.splitPayBNB{value: 1 ether}(_names3(), _amounts3(1 ether, 0, 0), "");
    }

    function test_admin_cancelStillWorksWhilePaused() public {
        uint256 subscriptionId = _createBnbSub(1 ether, 30 days, 3);
        namePay.pause();
        vm.prank(alice);
        namePay.cancelSubscription(subscriptionId);
        assertEq(alice.balance, 100 ether);
    }

    function test_admin_setTokenAllowed() public {
        assertTrue(namePay.isTokenAllowed(address(0)));
        assertTrue(namePay.isTokenAllowed(address(usdt)));
        assertTrue(namePay.isTokenAllowed(address(usdc)));
        assertFalse(namePay.isTokenAllowed(address(other)));
        vm.expectEmit(true, false, false, true);
        emit TokenAllowlistUpdated(address(other), true);
        namePay.setTokenAllowed(address(other), true);
        assertTrue(namePay.isTokenAllowed(address(other)));
        vm.prank(alice);
        other.approve(address(namePay), 10 ether);
        vm.prank(alice);
        namePay.payToken(address(other), "budi", 10 ether, "");
        assertEq(other.balanceOf(bob), 10 ether);
        namePay.setTokenAllowed(address(other), false);
        assertFalse(namePay.isTokenAllowed(address(other)));
        vm.prank(alice);
        vm.expectRevert(NamePay.TokenNotAllowed.selector);
        namePay.payToken(address(other), "budi", 1 ether, "");
    }

    // --- fuzz ---

    /// @notice Split sums stay exact: every recipient gets exactly their
    /// amount and the contract keeps nothing, for arbitrary bounded amounts.
    function testFuzz_splitAmounts(uint256 a, uint256 b, uint256 c) public {
        a = bound(a, 0.01 ether, 10 ether);
        b = bound(b, 0.01 ether, 10 ether);
        c = bound(c, 0.01 ether, 10 ether);
        uint256 bobBefore = bob.balance;
        uint256 carolBefore = carol.balance;
        uint256 daveBefore = dave.balance;
        vm.prank(alice);
        namePay.splitPayBNB{value: a + b + c}(_names3(), _amounts3(a, b, c), "fuzz");
        assertEq(bob.balance, bobBefore + a);
        assertEq(carol.balance, carolBefore + b);
        assertEq(dave.balance, daveBefore + c);
        assertEq(address(namePay).balance, 0);
    }

    /// @notice A subscription over its full schedule pays exactly maxPayments
    /// periods, advances the due date each time, and completes with the
    /// escrow fully drained to the payee.
    function testFuzz_subscriptionSchedule(uint256 periodSeconds, uint256 maxPayments) public {
        periodSeconds = bound(periodSeconds, 1 days, 365 days);
        maxPayments = bound(maxPayments, 1, 24);
        uint256 amountPerPeriod = 0.1 ether;
        uint256 subscriptionId = _createBnbSub(amountPerPeriod, periodSeconds, maxPayments);
        uint256 bobBefore = bob.balance;
        for (uint256 i; i < maxPayments; ++i) {
            NamePay.Subscription memory before = namePay.getSubscription(subscriptionId);
            assertEq(uint256(before.status), uint256(NamePay.SubscriptionStatus.Active));
            assertEq(before.paymentsMade, i);
            vm.warp(before.nextPaymentDue);
            namePay.executeSubscription(subscriptionId);
            NamePay.Subscription memory afterExecution = namePay.getSubscription(subscriptionId);
            assertEq(afterExecution.paymentsMade, i + 1);
            assertEq(afterExecution.nextPaymentDue, before.nextPaymentDue + periodSeconds);
        }
        NamePay.Subscription memory sub = namePay.getSubscription(subscriptionId);
        assertEq(uint256(sub.status), uint256(NamePay.SubscriptionStatus.Completed));
        assertEq(bob.balance, bobBefore + amountPerPeriod * maxPayments);
        assertEq(address(namePay).balance, 0);
    }
}
