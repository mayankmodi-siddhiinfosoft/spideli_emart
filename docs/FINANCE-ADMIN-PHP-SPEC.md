# Spideli Finance: admin back-office specification (for the PHP admin panel)

> **Superseded (15 Oct 2026)** by `SPIDELI_FINANCE_ADMIN_WEB_SPEC.md`, which are complete and checked against the security rules. Where this document differs, they win. Kept for history.

**For:** the PHP developer of the Spideli admin panel.
**Date:** 14 Oct 2026. **Firebase project:** `spideli-870b0`.
**Customer side:** the customer app (Flutter) writes the customer's requests **directly to Firestore**; there are **no Cloud Functions** for finance. The admin panel is the only "server": it reviews, approves, pays out, executes and reconciles, writing to the **same Firestore documents** the app reads live.

> Read with: `.claude/FINANCE-DIRECT-FIRESTORE.md` (the data design shared by the app and this panel), `.claude/FINANCE-APP-CONTRACT.md` (every field), `docs/FINANCE-FLOW.md` (the customer journeys).

---

## 0. How the panel talks to Firebase

- Use the **Firebase Admin SDK for PHP** (`kreait/firebase-php`) with a service account of `spideli-870b0`. The Admin SDK **bypasses the security rules**: the panel is trusted, so every check described below must be done in PHP before writing.
- Keep the service account JSON outside the web root, never in Git, never sent to a browser.
- **Writes that move money or change several documents must be atomic**: use a Firestore **transaction** (read the documents, check, write all of them) or a **batch**. Never update a balance without its ledger transaction (section 2).
- Timestamps: `FieldValue::serverTimestamp()` (or `new \DateTimeImmutable()` converted to a Firestore Timestamp).
- Amounts are **integers in minor units** of the currency (`XAF`, `XOF`, `GNF`, `RWF` have no decimals: 1 500 XAF = `1500`; `USD`, `EUR` have 2: 12.50 USD = `1250`).
- Every admin action writes an **audit entry** (section 13).
- Admin accounts: an admin must also be recognised by the rules when using a Firebase client (custom claim `admin: true` set with `$auth->setCustomUserClaims($uid, ['admin' => true])`, or `users/{uid}.role == 'admin'`).

---

## 1. Settings the panel manages (`platform_settings/*`)

One form per document. A missing or invalid document makes the app show "… is not available yet" for that module. Full examples: `.claude/FINANCE-APP-CONTRACT.md` and `.claude/seed_finance_config.py`.

| Document | Admin screen | Fields |
|---|---|---|
| `platform_settings/kyc` | Verification settings | document types and sides, levels (`basic`, `full`, `business`) with required documents (`anyOf` groups), allowed file types, max file size |
| `platform_settings/wallet` | Wallet settings | `currencies`; `deposit {enabled, min{CUR}, max{CUR}}`; `withdraw {enabled, methods: [mobile_money, wave, bank], min, max, feePercent, feeFixed{CUR}, feeMax{CUR}, delay}`; `convert {enabled, currencies, feePercent}`; `security.reauthAbove{CUR}` |
| `platform_settings/transfers` | Transfer settings | `currencies`, `sourceMethods`, `security.reauthAbove`, `channels.{internal, mobile_money, wave, bank}` each `{enabled, feePercent, feeFixed, feeMax, min, max, delay}`, mobile money `operators`, bank `banks[{code, name}]` |
| `platform_settings/bills` | Bill settings | `currencies`, `categories` (electricity, water, tv, internet, phone, gas, education, taxes, products, other), `paymentMethods`, `security.reauthAbove` |
| `platform_settings/cards` | Card settings | issuer, network, max cards, fees, funding methods and limits, limit ceilings, `capabilities {withdraw, renew, cardTransfer, onlineToggle, internationalToggle, secureDetails}`, `terms`, `termsVersion` |
| `platform_settings/savings` | Savings settings | purposes, currencies, frequencies, `groupGoals`, `maxMembers`, `earlyWithdrawal.allowed`, `paymentMethods` |
| `platform_settings/tontines` | Tontine settings | currencies, frequencies, `minMembers`, `maxMembers`, payout order methods, `paymentMethods`, `minContribution{CUR}` |
| `platform_settings/lending` | Loan settings | currencies, min / max amount, durations, repayment frequencies, purposes, `interest {method, annualPercent}`, `feePercent`, `latePenaltyPercent`, `voting {quorumPercent, approvalPercent, durationHours}`, `paymentMethods` |
| `platform_settings/investments` | Investment settings | currencies, asset classes, `paymentMethods`, `riskDisclosure`, `simulator.maxYears` |
| `platform_settings/insurance` | Insurance settings | currencies, categories, `paymentMethods`, `claims.maxFiles` |
| `platform_settings/financing` | Project financing settings | currencies, financing types, sectors, stages, document types, required documents, min / max amount, durations, file types and size |
| `platform_settings/intelligence` | Markets and coach settings | indicators, exchange rates, matching, `markets {enabled, stocks, bonds, ipos, collections, news}`, coach (off) |
| `settings/authProviders` | Sign-in providers | `linkedin`, `linkedinProviderId`, `facebook` (shown in the app only when enabled and configured in Firebase) |

`paymentMethods` values: `wallet` (Spideli Finance wallet) and the payment gateways the app already supports (the gateway settings under `settings/*`, per region, that this panel already manages for the shopping wallet: Stripe = Visa / Mastercard, PayPal, Flutterwave and Orange Money = Mobile Money, …).

---

## 2. Money: accounts, ledger and how the panel posts

### 2.1 Accounts `financial_accounts/{accountId}`

| Kind | Id | Meaning |
|---|---|---|
| `wallet` | `wallet_{uid}_{CUR}` (older wallets keep their id) | a customer's Spideli Finance wallet in one currency |
| `savings_goal` | `goal_{goalId}` | the money saved in a goal |
| `tontine_pot` | `tontine_{tontineId}` | a tontine's pot between collection and payout |
| `loan` | `loan_{loanId}` | a loan's escrow (fundings in, disbursement and repayments) |
| `platform` | `platform_{CUR}` | **Spideli's clearing account**: money received by gateways, money waiting to be paid out, fees |

Fields: `id, kind, userId (wallets), refId (pools), currency, balance, normalSide: "credit", status, lastTxId, createdAt, updatedAt`.

**Create one `platform_{CUR}` per currency before going live** (`kind: "platform", currency, balance: 0, normalSide: "credit", status: "active"`). Its balance can go negative: it is Spideli's position (customers' gateway deposits minus payouts done).

### 2.2 A posting `ledger_transactions/{txId}`

```jsonc
{ "id": "tx_1760440000000_AB12CD34", "type": "withdrawal", "status": "posted",
  "reference": "SPF-261014-7K2Q9A", "currency": "XAF",
  "lines": [ { "accountId": "platform_XAF", "direction": "debit", "amount": 10000 },
             { "accountId": "wallet_U1_XAF", "direction": "credit", "amount": 10000 } ],
  "userIds": ["U1"], "accountIds": ["platform_XAF", "wallet_U1_XAF"],
  "source": { "kind": "wallet_operations", "id": "<doc id>" },
  "funding": "wallet", "description": "Refund of a failed withdrawal",
  "createdBy": "admin:<adminId>", "createdAt": <serverTimestamp> }
```

**How to post from PHP (always in one transaction):**
1. Read every account of the lines (and the source document).
2. Check: amounts > 0 and integers; debits = credits; a wallet never below 0 after a debit; the source document is in the expected status.
3. Write the transaction, then each account: `balance` += credit / −= debit (`FieldValue::increment`), `lastTxId = txId`, `updatedAt`. Create a missing wallet `wallet_{uid}_{CUR}` with the credit.
4. Update the source document (status, reference, `txId`) and write the audit entry.

**Reversal:** never delete or edit a posted transaction. Post a new transaction of `type: "reversal"` with the lines inverted, `reversalOf: <original txId>`, and set the original `status: "reversed"`.

**Transaction types** the panel posts: `withdrawal` refunds, `reversal`, `manual_adjustment` (with a reason), `investment_redemption` settlement (platform → wallet), `insurance_claim_payout` (platform → wallet), `loan_lender_payout` (when distributing on behalf of lenders), `fee`.

---

## 3. User management

Screens: list (search by name, e-mail, phone), detail, create, activate, suspend, delete.

| Action | Firestore |
|---|---|
| Create | Firebase Auth `createUser` + `users/{uid}` profile (same fields the app writes at sign-up: `id, firstName, lastName, email, phoneNumber, countryCode, role: "customer", active: true, createdAt` …) |
| Activate / suspend the account | `users/{uid}.active` true / false **and** Firebase Auth `disabled` (a suspended user cannot sign in) |
| Delete | as the app's "Delete account": Firebase Auth delete + the website's `/api/delete-user` cleanup; keep finance records (legal retention) with the user marked deleted |
| Finance restriction (blacklist) | `users/{uid}.financeRestriction = {status: "restricted", reason, since, scopes: ["loans", "tontines"] or ["all"], by: adminId}`; lift: delete the field. The app shows it and blocks new loans / tontine joins; record the decision in the audit log (after a documented review, never automatically) |
| Finance overview of a user | wallets (`financial_accounts where userId == uid`), ledger (`ledger_transactions where userIds array-contains uid`), verification, goals, tontines, loans, holdings, policies, cards, transfers, bills |

Two-step verification is managed by the user in the app; the panel can show whether it is on (`$auth->getUser($uid)->mfaInfo`) and remove factors for a locked-out user after identity checks.

---

## 4. KYC management

**Queue:** `kyc_applications where status in ["submitted", "under_review"]` ordered by `submittedAt`.

| Step | Writes |
|---|---|
| Start review | `status: "under_review"` + `kyc_reviews {applicationId, userId, action: "start_review", by: adminId, at}` |
| Document control | view each `kyc_documents where applicationId == X` file: Storage `storagePath`, opened with a **signed URL** of ≤ 5 min (`$bucket->object($path)->signedUrl(...)`); set each document `status: "accepted"` or `"rejected"` (+ `note`) |
| Ask for more | `status: "additional_info_required"`, `reason` (what is missing, in the user's language) + review entry `request_info` |
| Approve | `status: "approved"` + **`users/{uid}.kycLevel = <level>`** and `users/{uid}.kycStatus = "approved"` + review entry `approve` |
| Reject | `status: "rejected"`, `reason` + `users/{uid}.kycStatus = "rejected"` + review entry `reject` |
| History | `kyc_reviews where applicationId == X` (the customer sees them too) |

Send `kyc_*` notifications (section 12). Automated validation (an identity provider) can be added later behind the same steps.

---

## 5. Payment management

### 5.1 Reconciliation of gateway payments
Every payment taken by a gateway in the app creates `payment_receipts/{method}_{gatewayReference}` `{method, reference, txId, amount, currency, userId, verified: false, createdAt}`. Without a server, a gateway success is **reported by the phone**: the panel must verify it.
- Screen "Gateway payments to verify": `payment_receipts where verified == false`.
- For each, check the payment on the provider (Stripe / PayPal / Flutterwave / Orange Money … dashboard or API, by `reference`, amount and currency).
- OK: `verified: true, verifiedAt, verifiedBy`.
- Not found or different amount: post a **reversal** of `txId` (section 2.2) and flag the user (audit, possibly a restriction).
- Better: receive the providers' **webhooks** in PHP and mark receipts verified automatically.

### 5.2 Requests waiting for the admin (manual validation)

| Queue | Collection and filter | Done | Failed |
|---|---|---|---|
| Wallet withdrawals | `wallet_operations where type == "withdrawal" and status == "pending"` (`destination`: `{method: "mobile_money", operator, number}`, `{method: "wave", number}` or `{method: "bank", bankName, bankCode?, holderName, accountNumber, accountMasked}`; `amount` is what the user receives, `fee`, `total` already taken from the wallet) | pay `destination` → `status: "completed"`, `payoutReference` (or `providerReference`), `completedAt` | `status: "failed"`, `reason` + reversal of `txId` (money back to the wallet) |
| External transfers | `money_transfers where status == "processing"` (channel mobile_money / wave / bank; `recipient` holds the full number / account, readable only by the sender and you) | set `adminLockedAt` when you start (the customer can no longer ask to cancel); pay the recipient → `completed`, `providerReference`, `completedAt`, `recipientVerified: true` if the provider confirmed the name | `failed` + `reason` + reversal → `reversed`; a `cancelRequested: true` transfer not yet paid → reversal + `cancelled` |
| Bill payments | `utility_payment_requests where status == "processing"` | pay the biller → `completed`, `billerReference`, and for prepaid: `token`, `tokenLabel`, `units` | `failed` + reversal → `reversed` |
| Card top-ups | `card_funding_requests where type == "fund" and status == "pending"` (`total` already posted to the platform) | load `amount` on the card at the issuer → `succeeded`; `virtual_cards.balance`; `card_transactions {type: "funding"}` | `failed` + reversal of `txId` |
| Card → wallet | `card_funding_requests where type == "withdraw" and status == "pending"` (nothing posted yet) | unload the card, post `platform → wallet` (type `card_withdrawal`) → `succeeded`, `txId` | `failed` + `reason` |
| Card → another card | `card_funding_requests where type == "transfer" and status == "pending"` (`recipientId`, `recipient {userId, name, contact}`) | move the money at the issuer to the recipient's active card in that currency (newest if several), update both balances, `card_transactions` on both → `succeeded`; push the recipient | `failed` + `reason` |
| Group savings withdrawals | `savings_withdrawals where status == "requested"` | apply the group's rules; post `goal_{id} → wallet_{requester}_{CUR}` (`savings_withdrawal`) and on the goal `savedAmount −= amount`, `lastTxId` → `completed`, `txId`, `reference` | `rejected` + `reason` |
| Savings goal cancellations (group) | `savings_goals where status == "cancellation_requested"` | return each member's share (postings `goal → wallet`) → `cancelled`, `savedAmount: 0` | restore `status: "active"` |
| Loans stuck in funding | `loan_applications where status == "funding"` past your funding deadline | refund each lender (`loan_{id} → wallet_{lender}`), `loan_fundings.status: "refunded"`, loan `cancelled` + `reason` | — |
| Loan rounding remainder | repaid loans whose `loan_{id}` balance is a few units after every lender collected | sweep it to `platform_{CUR}` (`fee`) | — |

### 5.3 Complete history and bank reconciliation
- History: `ledger_transactions` (filters: date, type, user, reference, currency), export CSV / PDF.
- Bank reconciliation: compare `platform_{CUR}` movements with bank / provider statements per day; record `reconciliations/{date_CUR} {expected, actual, difference, notes, by, at}`.

---

## 6. Fund management (investments)

| Screen | Writes |
|---|---|
| Funds | `investment_funds/{fundId}`: name, manager, description, objective, `assetClass`, `riskLevel` 1-7, currency, `minInvestment`, `minAdditional`, `fees {subscriptionPercent, managementPercent, redemptionPercent, performancePercent}`, `lockUpDays`, `settlementDays`, `redemption {allowed, partial}`, `terms`, **`termsVersion` (+1 at every change of the terms)**, documents, `eligibility`, `status` open / closed / suspended, `published`, `order` |
| Unit prices ("return updates") | each new price: `investment_valuations {fundId, date, navPerUnit}` + fund `navPerUnit`, `navDate`, `performance {ytd, oneYear, threeYears, fiveYears, sinceInception}`; then revalue every holding of the fund (below) |
| Subscriptions to execute | `investment_subscriptions where status == "paid"`: at the price of the trade date: `fee = round(amount × subscriptionPercent / 100)`, `units = (amount − fee) / navPerUnit` → `status: "completed"`, `units`, `navPerUnit`, `fee`, `netAmount`, `tradeDate`; upsert `investment_holdings/{uid}_{fundId}` (`units`, `investedAmount`, `currentValue`, `redeemableUnits`, `lockedUntil`…) and `investment_transactions {type: "subscription"}`; rejected → `rejected` + `reason` + reversal |
| Redemptions to execute | `investment_redemptions where status == "submitted"` → `processing` → `settling` (`navPerUnit`, `units`, `fee`, `netAmount`, `expectedSettlementDate`) → `settled` with a posting `platform → wallet` (or a payout to `destination`); holding units reduced, `realizedGains` booked; `rejected` + `reason` |
| Reports | upload PDFs to Storage `investment_reports/{uid}/…` + `investment_reports {userId, title, period, storagePath, createdAt}` |
| Revaluation | for each holding: `currentValue = units × navPerUnit`, `unrealizedGains = currentValue − investedAmount`, `valuedAt` |

---

## 7. Tontine management

| Screen | Content / writes |
|---|---|
| Consultation | `tontines` (filters: status, currency, created), members (`tontine_members where tontineId == X`), cycles, contributions, payouts, disputes |
| Payouts waiting for Spideli | `tontine_payouts where status == "pending_approval"` of tontines whose only admin is the beneficiary: approve = posting `tontine_{tid} → wallet_{beneficiary}`, payout `paid`, cycle `paid`, next cycle `collecting`, `tontines.currentCycle + 1`, `nextDueAt` (last cycle → tontine `completed`) |
| Suspension | `tontines.status: "suspended"` (+ reason, audit); the app blocks contributions |
| Audit | contributions per cycle and member, pot balance vs collected amounts, overdue members |
| Disputes | `tontine_disputes`: `open → under_review → resolved / rejected` with `resolution`; possible member restriction `tontine_members.status: "restricted"` and `users.financeRestriction` after a documented decision |
| Overdue | members without a `paid` contribution after `dueDate`: mark `overdue` contributions if your rules say so, send reminders |

---

## 8. Loan management (member loans)

| Step | Writes |
|---|---|
| Review queue | `loan_applications where status == "submitted"` → `under_review` |
| Credit scoring | `credit_assessments/{loanId} {loanId, borrowerId, score, band, factors[{label, impact, detail}], assessedAt}` (the borrower sees it) |
| Open the vote | `status: "voting"`, `votingEndsAt = now + voting.durationHours` (+ notify the eligible voters) — or `rejected` + `reason` |
| Penalties | for installments past `dueDate`: `loan_schedules/{loanId}.installments[i].status = "overdue"`, `penalty`, `amountDue`; loan `status: "overdue"` |
| Default | `defaulted` only after a documented review; restriction (section 3) |
| Lender distribution (if you choose to pay lenders yourself) | posting `loan_{loanId} → wallet_{lender}` pro rata, increasing `loan_fundings.collected` (the app also lets each lender collect their share) |

---

## 9. Insurance management

| Screen | Writes |
|---|---|
| Partners | `insurance_partners/{id} {name, licenceNumber, country, contact}` (staff only) |
| Catalog | `insurance_products` (category, coverages, exclusions, deductible, waiting period, term, `rating`, terms + `termsVersion`, documents, status, `published`) |
| Quotes to price | `insurance_quotes where status == "requested"` → `quoted` with `premium` (a year), `installmentAmount`, `deductible`, `coverStart`, `coverEnd`, `validUntil`, `terms`, `termsVersion`, `insurerReference` — or `rejected` + `reason`; expire `quoted` ones after `validUntil` → `expired` |
| Contract administration | `insurance_policies where status == "pending_activation"` (id = the quote id; the first premium `insurance_premiums/{quoteId}_1` is already `paid`) → `active` + `policyNumber`, documents (Storage `insurance_policies/{uid}/{policyId}/…`), `nextPremiumDue` and the later premiums (`insurance_premiums {userId, policyId, amount, currency, dueDate, status: "upcoming"}`, then `due` / `overdue`); or `rejected` + refund. Renewals: set `renewalPremium`, `renewalDate`, `status: "renewal_due"`; a policy with `renewalRequestedAt` (renewal paid) → new `coverStart` / `coverEnd`, `status: "active"`, and **clear `renewalRequestedAt`**. `cancellation_requested` → `cancelled` (+ refund) or back to `statusBefore`; `lapsed` for unpaid premiums |
| Claims | `insurance_claims where status in [submitted, under_review]` → `under_review`, `info_requested` (+ the question in `reason`), `approved` (`approvedAmount`), `paid` (`paidAmount`, `paidAt`, posting `platform → wallet`), `rejected` + `reason`; messages in `insurance_claims/{id}/events` |

---

## 10. Cards, transfers and bills (operations)

- **Cards:** `virtual_cards where status == "requested"` → create at the issuer → `active` with `last4, expiryMonth, expiryYear, cardholderName` (the verified KYC name), `network`, `balance`; or `failed` + `reason` + reversal of `feeTxId`. `termination_requested` → close at the issuer, return the balance (posting `platform → wallet`) → `terminated`. A card with `renewalRequestedAt` → create the new card, set `replacedBy` on the old one (and clear `renewalRequestedAt`). `card_limit_settings where status == "pending"` → apply → `applied`. Freeze for security: `status: "frozen"`, `frozenBy: "admin"` (the customer cannot unfreeze it). **Never store the full card number or CVV.**
- **Billers:** `utility_billers` (name, category, country, currency, account label / hint / pattern, `amountType` due / open / packages, packages, min / max, fees, `published`, `order`).
- **Transfers / bills / withdrawals** queues: section 5.2.

---

## 11. Project financing, markets and content

- **Financing reviews:** `financing_applications where status == "submitted"` → `under_review` → `additional_info_required` (`reason`) / `approved` (`approvedAmount`, `institutionName`) / `rejected` (`reason`) → `funded` (`fundedAmount`, `fundedAt`) → `closed`; each document `financing_documents.status` received / accepted / rejected (+ `note`); write `financing_reviews {ownerId, applicationId, fromStatus, toStatus, publicNote, at}` at every change (internal notes in a staff-only collection).
- **Resources:** `financial_resources` (templates, guides, FAQ, regulations; `published`).
- **Opportunities:** `investment_opportunities` (`published` after review); interests received: `opportunity_interests where opportunityId == X` (name and e-mail of interested users).
- **Indicators and rates:** `economic_indicators` (+ `economic_indicator_history`), `exchange_rate_snapshots` — only from approved sources, with `source`, `period`, `updatedAt`.
- **Markets:** `market_securities`, `market_price_history`, `ipo_listings`, `stock_collections`, `finance_news` (from a licensed data feed; `published`; `updatedAt`, `delayed`).

---

## 12. Notifications (push, SMS, e-mail)

- Texts: the `dynamic_notification` templates (one per `type`, placeholders `{amount}` …). **Create the new template `finance_chat_message`** (`{senderName}`, `{chatName}`, `{message}`), used by the app's finance chat. The app sends pushes for events it creates; **the panel sends** the notifications of the admin's decisions (KYC, payouts, executions, activations, claim decisions…), as push to `users/{uid}.fcmToken` and as a Notification Center record `users/{uid}/notifications/{id} {type, title, body, category: "account", source: "finance", read: false, createdAt, data}`.
- **SMS** (critical transactions: withdrawals, transfers, card security) and **e-mail** (receipts and alerts): sent by the panel through your SMS / e-mail provider, honouring `users/{uid}.financeNotificationPrefs {push: {...}, sms: {...}, email: {...}}` (categories: payments, groups, loans, investments, insurance, news). **Security notices are always sent.**
- Reminders (scheduled, cron in PHP): tontine contributions due (`tontine_cycles.dueDate`), loan installments due (`loan_schedules`), savings schedules, insurance premiums and renewals, card expiry.

---

## 13. Incident management, reporting, security, audit

- **Support / complaints / tickets:** the app's support chat is `chat/{uid}/thread`. Tickets: `support_tickets/{id} {userId, subject, category (payment, transfer, card, loan, tontine, insurance, kyc, other), relatedRef (a transfer / payment reference), status: open | in_progress | resolved | closed, priority, assignedTo, messages[] or subcollection, createdAt, updatedAt}` created by support from a chat or a complaint.
- **Reporting:** number of users (`users` with `kycLevel`, active), assets under management (sum of `investment_holdings.currentValue`), contribution volumes (`savings_contributions`, `tontine_contributions` per period), activity statistics (`ledger_transactions` per type and period). Use Firestore aggregation queries (`count()`, `sum()`) or a nightly export to BigQuery.
- **Security:** admin accounts with 2FA on the panel; session timeout; IP allow-list for the panel if possible; least privilege (roles: support, finance operations, compliance, super admin).
- **Data protection:** Firestore and Storage are encrypted at rest by Google; passwords are handled by Firebase Auth (never stored by the panel); enable **daily Firestore backups** (scheduled exports to a Cloud Storage bucket) and Point-in-time recovery.
- **Audit (complete logging, traceability):** every admin write also writes `admin_audit_logs/{id} {adminId, adminEmail, action, collection, docId, before (changed fields), after, reason, ip, at}`; never deletable from the panel.
