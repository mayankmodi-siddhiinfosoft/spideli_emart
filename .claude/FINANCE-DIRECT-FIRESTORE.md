# Spideli Finance on Firestore without Cloud Functions

**Status:** design for the customer app and the PHP admin panel, 14 Oct 2026. Replaces the callable functions of `.claude/FINANCE-APP-CONTRACT.md` (none was ever deployed: every finance callable answers 404). The collections and fields of that contract stay: the customer app writes them **directly**, guarded by Firestore Security Rules, and the **PHP admin panel** (Firebase Admin SDK, bypasses the rules) does every step that needs a person or a partner (reviews, payouts, executions, activations).

## 1. Roles

| Role | How it writes | Identified by |
|---|---|---|
| **Customer** | the customer app, direct Firestore writes in batches / transactions, checked by the rules | `request.auth.uid` |
| **Admin** | the PHP admin panel with the Firebase Admin SDK (service account; rules do not apply), or an admin account in a client (rules: `isAdmin()` = custom claim `admin: true` or `users/{uid}.role == 'admin'`) | — |
| Server | **none** | — |

Out of scope: insurers, fund managers, banks, rating agencies, microfinance institutions (their steps are done by the Spideli admin).

## 2. Money: accounts and the ledger

### 2.1 Accounts `financial_accounts/{accountId}`

| Kind | Id | Owner fields | Who may debit it (client) |
|---|---|---|---|
| `wallet` | `wallet_{uid}_{CUR}` (an older wallet of that user and currency keeps its id) | `userId` | its owner |
| `savings_goal` | `goal_{goalId}` | `refId` = goalId | the goal's owner, only for a **solo** goal (withdrawal to own wallet) |
| `tontine_pot` | `tontine_{tontineId}` | `refId` | a tontine admin approving a payout to that cycle's beneficiary |
| `loan` | `loan_{loanId}` | `refId` | the borrower (disbursement after accepting the agreement); a lender collecting their share of repayments |
| `platform` | `platform_{CUR}` | — | a client only for a **gateway-funded** posting (money received by a payment gateway); otherwise admin |

Fields: `id, kind, userId (wallets), refId (pools), currency, balance (int minor units, never < 0 except platform), normalSide: "credit", status: "active", lastTxId, createdAt, updatedAt`.

A client may change an account only by `balance` (+`lastTxId`, `updatedAt`), and only together with the ledger transaction named by `lastTxId` created **in the same batch**. A wallet is created (by its owner) in the batch of its first credit.

### 2.2 Ledger `ledger_transactions/{txId}` (client id `tx_<epochMillis>_<random>`)

```jsonc
{
  "type": "deposit | withdrawal | transfer | transfer_out | bill_payment | card_funding | card_fee | savings_contribution | savings_withdrawal | tontine_contribution | tontine_payout | loan_funding | loan_disbursement | loan_repayment | loan_lender_payout | investment_subscription | insurance_premium | conversion | fee | reversal | manual_adjustment",
  "status": "posted",                  // "reversed" only by the admin
  "reference": "SPF-261014-7K2Q9A",     // shown to users
  "currency": "XAF",
  "lines": [                            // 2 or 3 lines, integer minor units
    { "accountId": "<debited>",  "direction": "debit",  "amount": 10150 },
    { "accountId": "<credited>", "direction": "credit", "amount": 10000 },
    { "accountId": "platform_XAF", "direction": "credit", "amount": 150 }   // optional fee line
  ],
  "userIds": ["<wallet owners involved>"],
  "accountIds": ["<every accountId of the lines>"],
  "source": { "kind": "money_transfers | savings_contributions | …", "id": "<doc id>" },
  "funding": "wallet | gateway",
  "gateway": { "method": "stripe | paypal | flutterwave | orange_money | …", "reference": "<gateway transaction id>" },   // funding gateway only
  "description": "…",
  "createdBy": "<uid>",
  "createdAt": "<request.time>"
}
```

**Rules for a client posting:** `lines[0]` is the only debit; `lines[0].amount == lines[1].amount (+ lines[2].amount)`; every amount > 0; every account of the lines is updated in the same batch with `lastTxId == txId` and a balance change equal to its line (debit: −amount, credit: +amount); a wallet never goes below 0; the debited account is one the caller may debit (table 2.1); `createdBy == uid`; `createdAt == request.time`. Each account appears once per batch (two postings that touch the same account go in two batches, or use a pool directly).

### 2.3 Paying (`FinanceMoney.pay`)

The payment sheet offers:
- **Spideli Finance wallet**: the posting debits the user's wallet.
- **A payment gateway** already configured for the app (per region, `settings/*` gateway documents managed by the admin: Stripe for Visa / Mastercard, PayPal, Flutterwave and Orange Money for Mobile Money, PayStack, Xendit, MercadoPago, MidTrans, PayFast, RazorPay): the app runs the gateway checkout for the amount; on success, the posting debits `platform_{CUR}` with `funding: "gateway"` and the gateway's reference. `payment_receipts/{gatewayMethod}_{gatewayReference}` is created in the same batch (create-only: a gateway payment can fund one posting only).

> **Trust note.** Without a server, a gateway success is reported by the device. Every gateway-funded posting carries the gateway reference and is listed for the admin's **reconciliation** (PHP: compare with the provider's dashboard / API, reverse a fraudulent one). Before real money, add a server-side check (the PHP panel can receive the providers' webhooks and mark `payment_receipts.verified`).

Paying out of Spideli (withdrawal to Mobile Money / Wave / bank, external transfer, bill, card load, insurance premium, fund subscription): the posting moves the money from the user's wallet (or a gateway payment) to `platform_{CUR}` immediately, and the request waits for the **admin** to complete it (pay out, pay the biller, load the card, execute the order, activate the policy). If the admin cannot, it posts a `reversal` back to the wallet and marks the request `failed` / `reversed`.

### 2.4 Re-authentication
Above `security.reauthAbove` (transfers, bills, wallet withdrawals) and for card details / limits / termination, the app re-authenticates first (`FinanceReauth`); the rules check `request.auth.token.auth_time > request.time - duration.value(5, 'm')` on those writes.

## 3. Module by module (customer writes / admin steps)

Status lists are those of the contract. "C:" = the customer app writes it; "A:" = the admin panel.

### 3.1 Identity (KYC)
- C: create `kyc_applications/{id}` (`userId`, `level`, `accountType`, `status: "draft"`, `revision: 1`, `createdAt`); update `personal` / `business` while `draft` / `additional_info_required`; upload to Storage `kyc/{uid}/{applicationId}/…`, create `kyc_documents/{id}` (`status: "uploaded"`), set an older one of the same type and side to `superseded`; submit: `status → "submitted"`, `submittedAt`, plus `kyc_reviews` `{action: "submit"}`; after `rejected`: reopen = `status → "draft"`, `revision + 1`, `reason: null`, plus `kyc_reviews {action: "reopen"}`.
- A: `submitted → under_review → additional_info_required | approved | rejected` with `reason`; `kyc_documents.status` accepted / rejected; `kyc_reviews` entries; on approval `users/{uid}.kycLevel` (and `kycStatus`). Clients never write `kycLevel` / `kycStatus`; the app shows the status from the latest application.

### 3.2 Wallet
- C deposit: gateway checkout → batch: `wallet_operations/{id}` `{type: "deposit", status: "completed", amount, currency, gateway{method, reference}, txId}` + `payment_receipts` + posting `platform → wallet` (`deposit`).
- C withdraw (to saved Mobile Money / Wave / bank): `wallet_operations {type: "withdrawal", status: "pending", amount, fee, destination}` + posting `wallet → platform` (`withdrawal`, fee line). A: pays out → `completed` (+ `reference`), or `failed` + `reversal`.
- C convert (multi-currency): rate = the latest `exchange_rate_snapshots` (admin-published), `platform_settings/wallet.convert.feePercent`; batch 1 posting `wallet_A → platform_A` (`conversion`), batch 2 posting `platform_B → wallet_B` — **done as one batch** (four different accounts) with `wallet_operations {type: "conversion", rate, receiveAmount}`.
- Settings `platform_settings/wallet` (admin): `currencies`, `deposit {enabled, min{CUR}, max{CUR}}`, `withdraw {enabled, methods: ["mobile_money","wave","bank"], min, max, feePercent, feeFixed{CUR}, feeMax{CUR}, delay}`, `convert {enabled, currencies, feePercent}`, `security.reauthAbove{CUR}`.

### 3.3 Transfers
- C internal (to a Spideli user found by email / phone in `users`): batch `money_transfers {status: "completed", channel: "internal", senderId, recipientId, participantIds, recipientName, recipientVerified: true, amount, fee, total, receiveAmount, note, reference, txId, createdAt, completedAt}` + posting `sender wallet → recipient wallet (+ fee line)` (`transfer`). Recipient's wallet in that currency is created in the same batch if missing. Push `transfer_received`.
- C external (Mobile Money / Wave / bank): `money_transfers {status: "processing", …}` + posting `wallet or gateway → platform` (`transfer_out`). A: pays out → `completed` / `failed` + `reversal` (`reversed`).
- C cancel: only an external transfer still `processing` and not yet taken by the admin (`adminLockedAt` absent): `cancelled` + the admin reverses; the app asks the admin (field `cancelRequested: true`).
- Beneficiaries `transfer_beneficiaries`: C creates / deletes its own.

### 3.4 Bills
- C: `utility_payment_requests {status: "processing", billerId, account, amount, fee, total, …}` + posting `wallet or gateway → platform` (`bill_payment`); saved accounts `utility_saved_accounts` (C creates / deletes its own). The biller lookup needs a partner API: without it, the customer enters the amount from the bill (`due` billers then behave like `open`, up to `max`).
- A: pays the biller → `completed` with `billerReference`, `token`, `tokenLabel`, `units`; or `failed` + `reversal`.

### 3.5 Virtual cards
- C request: `virtual_cards {status: "requested", userId, label, currency, termsVersion, acceptedAt}` (+ creation fee posting `card_fee` when there is one). A (with the issuer): `active` with `last4, expiryMonth, expiryYear, cardholderName, network, balance` — or `failed` + refund.
- C top up: `card_funding_requests {type: "fund", status: "pending", amount, fee}` + posting `→ platform` (`card_funding`). A: loads the card → `succeeded`, `virtual_cards.balance`.
- C withdraw / card-to-card: `card_funding_requests {type: "withdraw" | "transfer", …, recipient?}` → A.
- C freeze: `active → frozen`, `frozenBy: "user"`; unfreeze (re-auth): `frozen (frozenBy user) → active`. A may freeze with `frozenBy: "admin"`.
- C limits (re-auth): `card_limit_settings/{cardId} {…, status: "pending"}` → A applies (`applied`).
- C delete (re-auth): `status → "termination_requested"` → A closes it and returns the balance (`terminated`).
- Card details need the issuer's secure page: `capabilities.secureDetails` stays `none` until then.

### 3.6 Savings goals
- C create: `savings_goals {ownerId, memberIds:[uid], invitedIds:[uids found by email], status: "active", savedAmount: 0, …}` + account `goal_{goalId}` (kind `savings_goal`, `refId`, `memberIds`). Invite (owner): `invitedIds` arrayUnion. Respond (invitee): remove self from `invitedIds`, add to `memberIds` on accept. Edit (owner): name, description, deadline, schedule.
- C contribute (member): `savings_contributions {goalId, userId, amount, status: "succeeded", reference, txId}` + posting `wallet or gateway → goal_…` (`savings_contribution`) + `savedAmount` += amount.
- C withdraw: **solo goal** (owner, `earlyWithdrawal.allowed` or target reached): `savings_withdrawals {status: "completed"}` + posting `goal_… → own wallet` + `savedAmount` −= amount. **Group goal:** `savings_withdrawals {status: "requested"}` → A decides (group rules) and posts it.
- C cancel (owner): solo goal: posting of the whole balance to the owner's wallet + `status: "cancelled"`; group goal: `status: "cancellation_requested"` → A returns the funds.

### 3.7 Tontines
- C create: `tontines {status: "forming", adminIds:[uid], memberIds:[uid], createdBy, …}` + `tontine_members/{tid}_{uid} {role: "admin", status: "active", payoutPosition: 1}` + account `tontine_{tid}`.
- C invite (an admin): `tontine_members/{tid}_{inviteeUid} {status: "invited", tontineName, invitedBy, invitedByName,` **the terms**: `contributionAmount, currency, frequency, membersLimit, startDate, rules}`. Active + invited ≤ `membersLimit`.
- C respond (invitee): own member doc `invited → active | declined`; on accept `tontines.memberIds` arrayUnion self (rules: own active member doc after, not restricted, not full).
- C payout order (admin, forming, `fixed`): `payoutPosition` of each member doc. C start (admin, ≥ `minMembers`, full order; `random`: positions drawn on the device and saved): `status: "active"`, `currentCycle: 1`, `nextDueAt`, and `tontine_cycles/{tid}_{n}` for every member (`number`, `dueDate`, `beneficiaryUserId`, `expectedAmount`, `collectedAmount: 0`, `status`: first `collecting`, others `upcoming`).
- C contribute (active member, cycle `collecting`): `tontine_contributions/{cycleId}_{uid}` (create-only: one per cycle and member) `{status: "paid", amount: contributionAmount, txId}` + posting `→ tontine_{tid}` + cycle `collectedAmount` += amount; when it reaches `expectedAmount`: cycle `payout_pending` + `tontine_payouts/{cycleId} {status: "pending_approval", beneficiaryUserId, amount}`.
- C approve payout (a tontine admin; the beneficiary alone cannot approve their own unless they are not the only admin… if they are the only admin, the payout waits for the platform admin): posting `tontine_{tid} → beneficiary wallet` (`tontine_payout`), payout `paid`, cycle `paid`, next cycle `collecting`, `currentCycle` + 1 (last cycle: tontine `completed`). Push `tontine_payout_paid`.
- C dispute: `tontine_disputes {status: "open", raisedBy, …}`. A: review, resolve, restrict a member (`tontine_members.status: "restricted"`, `users/{uid}.financeRestriction`).
- Overdue: shown by the app from the due date; the admin may mark `overdue` and apply its rules. A: suspend a tontine (`suspended`), audit.

### 3.8 Member loans
- C apply: `loan_applications {status: "submitted", borrowerId, groupId, groupName, eligibleVoterIds: the group's memberIds − borrower, votes: {yes: 0, no: 0}, fundedAmount: 0, outstandingAmount: 0, lenderIds: [], …}`; documents to Storage `loan_documents/{uid}/{loanId}/…` + `documents` arrayUnion. Not when `users/{uid}.financeRestriction` is set.
- A review: `under_review`, `credit_assessments/{loanId}`, then `voting` with `votingEndsAt` (or `rejected` + `reason`).
- C vote (eligible voter, `voting`, before `votingEndsAt`): `loan_votes/{loanId}_{uid}` (create-only) + `votes.yes` or `votes.no` + 1.
- C close the vote (any participant, after `votingEndsAt` or when everyone voted): `funding` when quorum (`cast × 100 ≥ eligible × quorumPercent`) and approval (`yes × 100 ≥ cast × approvalPercent`), else `rejected` (`reason: "vote"`).
- C fund (eligible member, not the borrower, `funding`): `loan_fundings/{loanId}_{uid}_{n}` `{amount, status: "succeeded", txId}` + posting `→ loan_{loanId}` + `fundedAmount` += amount (≤ `amount`) + `lenderIds` arrayUnion. The last funder's batch also sets `agreement_pending` and creates `loan_agreements/{loanId}` from `platform_settings/lending` (version 1, the schedule of `LoanCalculator`).
- C accept (borrower): `acceptedAt`, `agreementVersion`, then in the same batch disbursement: posting `loan_{loanId} → borrower wallet` (`loan_disbursement`, the whole funded amount), `status: "active"`, `outstandingAmount = totalRepayable`, `loan_schedules/{loanId}`.
- C repay (borrower): `loan_repayments {status: "succeeded", amount, txId}` + posting `→ loan_{loanId}` + `outstandingAmount` −= amount (≥ 0; 0 → `repaid`), installments marked `paid` / `partially_paid` in `loan_schedules`.
- C collect (lender): posting `loan_{loanId} → own wallet` (`loan_lender_payout`) of at most `floor(repaid × lent / amount) − collected`, with `loan_fundings` `collected` += amount.
- C cancel (borrower): `submitted | under_review | voting → cancelled`.
- A: penalties (`overdue`, `penalty` on installments), `defaulted` after a documented review, restrictions (blacklist).

### 3.9 Investments
- C subscribe: `investment_subscriptions {status: "paid", amount, fee (estimate), termsVersion, signatureName, riskAcknowledged, acceptedAt, txId}` + posting `→ platform` (`investment_subscription`). A: executes at the next NAV → `processing → completed` (`units`, `navPerUnit`, `tradeDate`), updates `investment_holdings/{uid}_{fundId}` and `investment_transactions`; or `rejected` + `reversal`.
- C redeem: `investment_redemptions {status: "submitted", full, amount, destination}`; cancel while `submitted`. A: `processing → settling → settled` with a posting `platform → wallet` (or a payout to `destination`).
- A: funds (`investment_funds`), prices (`investment_valuations`, fund `navPerUnit`), reports (`investment_reports`).

### 3.10 Insurance
- C quote request: `insurance_quotes {status: "requested", productId, answers, frequency, coverStart, …}`. A prices it (`quoted`: `premium`, `installmentAmount`, `validUntil`, `terms`, `termsVersion`) or `rejected`.
- C decline: `quoted → declined`. C accept (before `validUntil`): posting of the first instalment `→ platform` (`insurance_premium`) + quote `accepted` + `insurance_policies {status: "pending_activation", quoteId, …}` + `insurance_premiums {status: "paid"}`. A activates (`active`, `policyNumber`, documents).
- C pay a premium: `due | overdue | failed → paid` + posting. C renew (`renewal_due`, `renewalPremium` set by A): posting + `renewalRequestedAt` → A renews. C auto-renew: `autoRenew`. C cancel: `active | renewal_due → cancellation_requested` → A.
- C claim: `insurance_claims {status: "submitted", policyId, incidentDate, description, amountClaimed, documents}` (photos in Storage `insurance_claims/{uid}/{claimId}/…`); respond when `info_requested` (→ `under_review`, message in `insurance_claims/{id}/events`); withdraw. A: decisions and payment (`approved`, `paid` with a posting to the wallet).

### 3.11 Project financing, intelligence, chat, coach
- Financing: C writes `financing_projects`, `financing_applications` (`draft`, edit while `draft` / `additional_info_required`, `submitted` with `declarationAccepted`, `withdrawn`), `financing_documents` (Storage first). A reviews (statuses, `reason`, document notes, `financing_reviews`).
- Intelligence: C writes its own `investor_profiles/{uid}` and `opportunity_interests/{oppId}_{uid}` `{interested, message, name, email (only when interested), createdAt}`. A publishes indicators, rates, opportunities and news.
- **Chat:** `finance_chats/{chatId}` — direct `dm_{uidA}_{uidB}` (sorted) or tontine group `tontine_{tid}` — `{type, memberIds (direct), tontineId (group), lastMessage {text, senderId, at}, updatedAt}` and `finance_chats/{chatId}/messages/{id} {senderId, senderName, text, createdAt}`. Members read and write (group: the tontine's active members). Push via `dynamic_notification` type `finance_chat_message`.
- AI coach: needs a server holding the AI provider key — stays **off** (`coach.enabled: false`).

### 3.12 Users, restrictions, notifications
- `users/{uid}.financeRestriction {status: "restricted", reason, since, scopes: ["loans","tontines","all"]}` — A only (the blacklist). The app shows it and blocks the matching actions; the rules refuse them.
- `users/{uid}.financeNotificationPrefs {push, sms, email: {payments, groups, loans, investments, insurance, news}}` — C writes its own; A's senders honour it (security notices always sent).
- Pushes from the app: `SendNotification.sendFcmMessage(type, token, …)` with the `dynamic_notification` templates of the contract (`transfer_received`, `tontine_invite`, `loan_vote_requested`, …). SMS and e-mail are sent by the admin side.

## 4. Dashboard totals

No server maintains `finance_summaries`: the app computes the dashboard from the user's own records (accounts, goals, tontines and cycles, loans and schedules, holdings, policies and claims, and the last 12 months of `ledger_transactions`). The admin's reports read the same collections.
