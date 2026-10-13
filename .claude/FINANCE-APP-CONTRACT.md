# Spideli Finance: what the customer app expects from the server (KYC + dashboard)

**For:** the backend team (Cloud Functions, Firestore / Storage rules, admin panel).
**Date:** 13 Oct 2026.
**Scope:** the **app-level** part of the "Spideli Digital Finance Platform Using Firebase" brief, sections 3 (KYC) and 10 (dashboard), built in the **customer app** (`customer/`). The app is done; everything below marked **SERVER** is the backend's and does not exist in this repository.

**Rule of the whole contract:** the app **never** decides a status, a balance or a total. It reads what the server stored, and asks the server, through callable functions, to change anything. Every collection below is **read-only for the app** except the KYC file upload in Storage (section 3).

App code: `customer/lib/screen_ui/finance/` (screens), `customer/lib/service/finance_service.dart` (every read and call), `customer/lib/utils/finance_rules.dart` (pure rules, tested in `customer/test/finance_rules_test.dart`), `customer/lib/utils/finance_statement_pdf.dart` (statement PDF). Entry point: Profile > Account & Subscriptions > **Spideli Finance**.

---

## 1. Callable functions the app calls (SERVER)

- Firebase callable functions (`cloud_functions`), **region `us-central1`** (`FinanceService._functions`).
- The app sends an **App Check** token: it is activated in `customer/lib/main.dart` (Play Integrity / App Attest in release builds, the debug provider in debug builds). The server should enforce App Check on these functions.
- **Errors:** the app reads `HttpsError.details.reason` and maps it to a translated message (`FinanceErrors.messageKey`, list below). Any other reason shows a generic error. Please keep these reason strings stable.

| Function | Request | Response | Reasons the app maps |
|---|---|---|---|
| `kycCreateApplication` | `{ level: string, accountType: "individual" \| "business" }` | `{ applicationId: string }` | `kyc_not_configured`, `kyc_application_open`, `kyc_level_approved` |
| `kycUpdateApplication` | `{ applicationId, personal?: { fullName, dateOfBirth (yyyy-MM-dd), nationality, idNumber, address, city, country }, business?: { companyName, registrationNumber, taxNumber, registeredAddress, country } }` (only non-empty fields are sent) | anything | `kyc_not_editable` |
| `kycRegisterDocument` | `{ applicationId, type, side, storagePath }` after the upload in section 3 | anything | `kyc_file_type`, `kyc_file_size`, `kyc_file_missing`, `kyc_not_editable` |
| `kycSubmit` | `{ applicationId }`. The app first calls `kycUpdateApplication` with the form, then this. | anything | `kyc_documents_missing`, `kyc_personal_details_missing`, `kyc_business_details_missing`, `kyc_invalid_transition` |
| `kycReopen` | `{ applicationId }` (on a `rejected` application: start again as a new revision) | anything | `kyc_invalid_transition` |

Also mapped: `insufficient_funds`, `sign_in_required` / `unauthenticated`. The server is expected to:
- check every request against the caller's verified identity (never the payload);
- enforce the workflow in section 2;
- check the uploaded file itself (path, existence, content type, size);
- write the review history and the user's mirrored state;
- send the notifications in section 6.

The reviewer side (start review, approve / reject / request information, view documents) is the **admin panel's** and is not called by the app.

---

## 2. KYC data the app reads (SERVER writes all of it)

**Statuses** (`kyc_applications.status`), as the app shows them (`KycStatus`):

| Status | App label | The owner may edit and upload |
|---|---|---|
| `draft` | Not submitted | yes |
| `submitted` | Submitted | no |
| `under_review` | Under review | no |
| `additional_info_required` | More information needed (the `reason` is shown) | yes, then re-submits |
| `approved` | Verified | no |
| `rejected` | Not approved (the `reason` is shown, with "Start again" = `kycReopen`) | no |

Workflow the app assumes: draft → submitted → under_review → (additional_info_required → submitted …) → approved / rejected; rejected → draft (new `revision`). **One open application per user and level** (open = not approved / rejected).

### 2.1 `platform_settings/kyc` (config, read by signed-in users; never a secret)

```jsonc
{
  "documentTypes": { "national_id": { "sides": ["front", "back"] }, "passport": { "sides": ["front"] },
                     "selfie": { "sides": ["front"] }, "proof_of_address": { "sides": ["front"] },
                     "business_registration": { "sides": ["front"] } },
  "levels": {
    "basic":    { "accountTypes": ["individual"], "requiredDocuments": [ { "anyOf": ["national_id", "passport"] }, { "anyOf": ["selfie"] } ] },
    "business": { "accountTypes": ["business"],   "requiredDocuments": [ { "anyOf": ["national_id", "passport"] }, { "anyOf": ["business_registration"] } ] }
  },
  "allowedContentTypes": ["image/jpeg", "image/png", "application/pdf"],
  "maxFileBytes": 10485760
}
```

- A requirement group is met when ONE of its types has every side uploaded (or accepted).
- A missing or malformed document makes the app show "Identity verification is not available yet" (`KycSettings.parse`).
- Known identifiers get translated labels (`KycLabels`): document types `national_id`, `passport`, `selfie`, `proof_of_address`, `business_registration`; levels `basic`, `full`, `business`; sides `front`, `back`. Any other identifier is shown humanized ("utility_bill" → "Utility bill").

### 2.2 `kyc_applications/{id}`

`id`, `userId`, `level`, `accountType`, `status`, `revision` (int), `personal{}`, `business{}`, `reason` (string or null), `createdAt`, `submittedAt`. The app queries `where userId == <uid>` and sorts by `createdAt` itself.

### 2.3 `kyc_documents/{id}`

`applicationId`, `userId`, `type`, `side`, `status`: `uploaded` / `accepted` / `rejected` / **`superseded`** (an earlier upload of the same type and side; the app ignores it). The app queries `where applicationId == X and userId == <uid>`.

### 2.4 `kyc_reviews/{id}` (history)

`applicationId`, `userId`, `action` (`submit`, `start_review`, `request_info`, `approve`, `reject`, `reopen`), `reason`, `at`. The app queries `where applicationId == X and userId == <uid>` and sorts by `at`.

### 2.5 `users/{uid}` (mirrored state)

`kycStatus` (the latest application status) and `kycLevel` (set when a level is approved; drives "Verified" on the dashboard). **These two fields must be server-only in the rules:** the app never writes them, and no client (admin included) may.

---

## 3. KYC file upload (the app's only write)

- **Path:** `kyc/{uid}/{applicationId}/{type}-{side}-{epochMillis}.jpg`, `contentType: image/jpeg`. The app compresses to quality 85, at most 2400 px wide, and refuses files above `maxFileBytes` before uploading. A new upload always uses a new name: nothing is overwritten.
- **Storage rules expected:** the owner may **create** (not overwrite) under `kyc/{own uid}/…` with an image / PDF type and a size cap, and read its own files. **Nobody else** reads them directly; reviewers should get short-lived signed links from a server function.
- After the upload the app calls `kycRegisterDocument` with that `storagePath`. The server must check the path belongs to the caller and the application, that the object exists, and its type and size.

---

## 4. Dashboard data the app reads (SERVER)

### 4.1 `financial_accounts/{id}` (balances)

`id`, `userId` (owner), `kind` (`wallet` shows "Wallet", anything else "Account"), `currency` (ISO), `balance` (**integer minor units**), `normalSide` (`credit` for customer money), `status` (`active` is shown). Query: `where userId == <uid>`.

### 4.2 `ledger_transactions/{id}` (activity, history, statements)

`type` (`deposit`, `withdrawal`, `transfer`, `manual_adjustment`, `reversal`, …), `status` (`posted` / `reversed`), `reference` (shown to the user), `currency`, `lines: [{accountId, direction: debit|credit, amount}]`, `userIds` (the users whose accounts are involved), `reversalOf`, `description`, `createdAt`.

The app shows each transaction **from the user's side**: the sum over the lines on the user's own accounts, in each account's normal side (positive = money in). Queries:

```
ledger_transactions where userIds array-contains <uid> orderBy createdAt desc   (pages of 20; statements: pages of 200, at most 2000)
  + where type == <type>                                    (filter)
  + where createdAt >= <from> and createdAt < <to + 1 day>  (date range)
```

### 4.3 `finance_summaries/{uid}` (overview: NEW, please maintain it)

The dashboard's totals. The brief forbids client-side totals, so **the server maintains this document** (e.g. from the ledger and each module's records, in the same transactions or with a trigger). Amounts are integer minor units in `currency`. **Omit a section** for a module the user has not used: the app then shows "Not started yet".

```jsonc
{
  "currency": "XAF",                       // required (no summary is shown without it)
  "updatedAt": "<timestamp>",
  "investments": { "investedCapital": 100000, "currentValuation": 112000, "realizedGains": 2000, "unrealizedGains": 10000 },
  "savings":     { "activeGoals": 2, "savedAmount": 30000, "targetAmount": 120000 },   // saved = funds actually deposited
  "tontines":    { "active": 1, "nextContributionAmount": 5000, "nextContributionDate": "<timestamp>", "nextPayoutDate": "<timestamp>" },
  "loans":       { "borrowedOutstanding": 0, "lentOutstanding": 15000, "nextRepaymentAmount": 2500, "nextRepaymentDate": "<timestamp>", "overdueCount": 0 },
  "insurance":   { "activePolicies": 1, "nextRenewalDate": "<timestamp>", "openClaims": 0 },
  "payments":    { "last30Days": { "deposits": 50000, "withdrawals": 20000, "transfers": 0, "cardPayments": 0, "billPayments": 0 } },
  "monthly":     [ { "month": "2026-09", "moneyIn": 12000, "moneyOut": 15000 }, { "month": "2026-10", "moneyIn": 9000, "moneyOut": 4000 } ]   // up to 12 months, "yyyy-MM"
}
```

### 4.4 Statements (app only)

"Download statement" builds a PDF in the app from the user's `ledger_transactions` in the chosen date range: totals in and out per currency, then one row per transaction. It is shared through the system share sheet. Nothing is written to the server.

---

## 5. Firestore rules and indexes the app needs (SERVER)

**Read access the app needs** (and nothing more):

| Collection | Who may read |
|---|---|
| `platform_settings/kyc` | any signed-in user |
| `kyc_applications`, `kyc_documents`, `kyc_reviews` | `resource.data.userId == request.auth.uid` (plus the reviewers' permission) |
| `financial_accounts`, `ledger_entries` | `resource.data.userId == request.auth.uid` (plus staff) |
| `ledger_transactions` | `request.auth.uid in resource.data.userIds` (plus staff) |
| `finance_summaries/{uid}` | `uid == request.auth.uid` (plus staff) |
| `users/{uid}` | as today; but `kycStatus` / `kycLevel` must be **unwritable by any client** |

**No client writes** to any of these, nor to `users/{uid}/notifications` records carrying `source: "finance"` (so nobody can forge a "verified" or "payment received" notice).

**Composite indexes:**
- `ledger_transactions (userIds CONTAINS, createdAt DESC)`
- `ledger_transactions (userIds CONTAINS, type ASC, createdAt DESC)`

The KYC queries are equality-only and need none.

---

## 6. Notifications (SERVER)

Send through the existing `dynamic_notification` templates (no text in code) and record them in the existing Notification Center, `users/{uid}/notifications`, with `category: "account"` and `source: "finance"`:

| Template `type` | When | Placeholders |
|---|---|---|
| `kyc_submitted` | the user submitted | — |
| `kyc_additional_info_required` | a reviewer asked for more | `{reason}` |
| `kyc_approved` | a level was approved | `{level}` |
| `kyc_rejected` | the application was rejected | `{reason}` |

Push data: `{ type: <template>, applicationId, status }`. The app's KYC screen updates live from Firestore, so a missing push never leaves it stale.

---

## 7. What is NOT in the app (all SERVER / admin)

- the callable functions of section 1;
- the KYC review tools (queue, document viewer with signed links, decisions, history);
- `finance_summaries` maintenance;
- the ledger itself (accounts, postings, reversals, reconciliation);
- the rules and indexes of section 5;
- the notifications of section 6;
- App Check enforcement and app registration (Play Integrity / App Attest; debug tokens for test devices).

Until these exist, the Spideli Finance screen shows "Identity verification is not available yet" (no `platform_settings/kyc`), empty balances, "Your overview appears here…" and no transactions. It never shows invented data.

---

## 8. Savings goals (brief section 6)

App code: `customer/lib/screen_ui/finance/savings_screens.dart`, `customer/lib/service/finance_group_service.dart`, rules in `customer/lib/utils/finance_group_rules.dart` (tested in `customer/test/finance_group_rules_test.dart`). Entry: Spideli Finance > Services > **Savings goals** (and the overview's savings card).

### 8.1 `platform_settings/savings` (admin config; signed-in read; never a secret)

```jsonc
{
  "purposes": ["real_estate", "education", "travel", "healthcare", "business", "other"],
  "currencies": ["XAF"],
  "frequencies": ["weekly", "biweekly", "monthly"],      // scheduled contributions offered
  "groupGoals": true,                                    // allow inviting others to a goal
  "maxMembers": 10,
  "earlyWithdrawal": { "allowed": true },                // withdraw before the target is reached
  "paymentMethods": ["wallet", "mobile_money", "wave"]   // offered in the payment step
}
```

The document is required: the app shows "Savings goals are not available yet" when it is missing, or when it has no purpose, currency or payment method. Known purposes are translated; any other is shown humanized.

### 8.2 Collections (SERVER writes all of them; clients never)

**`savings_goals/{goalId}`**
- `id`, `ownerId`, `memberIds[]` (owner + accepted members), `invitedIds[]` (pending invitations);
- `name`, `purpose`, `description`, `currency`;
- `targetAmount`, and **`savedAmount` = funds actually deposited** (the goal's ledger account balance, never the target);
- `deadline` (timestamp or absent), `schedule: { frequency, amount }` (absent = none);
- `status`: `active` / `completed` / `cancelled`;
- `accountId` (ledger account), `createdAt`.

**`savings_contributions/{id}`**: `goalId`, `userId`, `amount`, `currency`, `status`, `reference`, `paymentId`, `createdAt`.
- `status` is one of `pending`, `processing`, `succeeded`, `failed`, `refunded`.
- Only `succeeded` counts in projections. The app shows the latest 50.

**`savings_withdrawals/{id}`**: `goalId`, `userId`, `amount`, `currency`, `status`, `reason`, `createdAt`.
- `status` is one of `requested`, `processing`, `completed`, `rejected`.

App queries (each needs the composite index shown):

```
savings_goals where memberIds array-contains <uid> orderBy createdAt desc   -> (memberIds CONTAINS, createdAt DESC)
savings_goals where invitedIds array-contains <uid>                         -> single field
savings_contributions where goalId == X orderBy createdAt desc limit 50     -> (goalId ASC, createdAt DESC)
savings_withdrawals   where goalId == X orderBy createdAt desc limit 20     -> (goalId ASC, createdAt DESC)
```

Rules:
- a goal is readable by `uid in memberIds || uid in invitedIds`;
- contributions and withdrawals are readable by the members of their `goalId`'s goal. The app's queries always constrain `goalId`, so the rule can check `get(/savings_goals/$(resource.data.goalId)).data.memberIds`.

### 8.3 Callables

| Function | Request | Reply / notes |
|---|---|---|
| `savingsCreateGoal` | `{ name, purpose, description?, targetAmount, currency, deadline? "yyyy-MM-dd", schedule?: { frequency, amount }, inviteEmails?: [] }` | `{ goalId }`. Validate against `platform_settings/savings`; invite only existing accounts (email); the creator is `ownerId` and in `memberIds`. |
| `savingsUpdateGoal` | `{ goalId, name?, description?, deadline?, schedule?: {…} \| null }` | owner only |
| `savingsInviteMember` | `{ goalId, email }` | owner only; respects `maxMembers` |
| `savingsRespondInvite` | `{ goalId, accept: bool }` | moves the caller from `invitedIds` to `memberIds` (accept) or drops it |
| `savingsContribute` | `{ goalId, amount, payment, idempotencyKey }` | see 8.4 |
| `savingsRequestWithdrawal` | `{ goalId, amount, destination, idempotencyKey, reason? }` | `{ status, instructions?, reference? }`. Never more than `savedAmount`; early withdrawal only when `earlyWithdrawal.allowed` or the target is reached; group rules (e.g. who may withdraw) are server-side. |
| `savingsCancelGoal` | `{ goalId }` | owner only; returns the funds per the withdrawal rules |

### 8.4 Payments (contributions, withdrawals, tontines)

**`payment` / `destination`** is one of:
- `{ method: "wallet" }`
- `{ method: "mobile_money", operator: "MTN Mobile Money" | "Orange Money" | …, number }`
- `{ method: "wave", number }`

The numbers come from the user's saved payment methods (`users.savedPaymentMethods`).

**Reply:** `{ status: "pending" | "processing" | "succeeded", instructions?: string, reference?: string }`.
- The app shows `instructions` verbatim, for example "Approve the 5 000 XAF payment on your phone (dial *126#)". **Write it in the user's language.**
- Then it waits: the contribution's final status arrives in `savings_contributions` / `tontine_contributions`, live.

**Never trust the app:**
- A contribution is `succeeded` / `paid` only after the provider's **verified webhook or status check**.
- `idempotencyKey` is unique per confirmed request (the app generates a fresh one per confirmation dialog): the same key must never create a second payment.
- Amounts are integer minor units. The server re-checks KYC (`users.kycLevel` set), limits, fees and balances.

---

## 9. Tontines (brief section 5)

App code: `customer/lib/screen_ui/finance/tontine_screens.dart`, `finance_group_service.dart`, `finance_group_rules.dart`. Entry: Spideli Finance > Services > **Tontines**.

### 9.1 `platform_settings/tontines` (admin config)

```jsonc
{
  "currencies": ["XAF"],
  "frequencies": ["weekly", "biweekly", "monthly"],
  "minMembers": 3,
  "maxMembers": 30,
  "payoutOrderMethods": ["fixed", "random"],   // fixed = set by the tontine's admin; random = drawn at start
  "paymentMethods": ["wallet", "mobile_money", "wave"],
  "minContribution": { "XAF": 1000 }           // minor units
}
```

Required: the app shows "Tontines are not available yet" when it is missing or invalid (no currency, frequency or payment method, `minMembers` < 2, or `maxMembers` < `minMembers`).

### 9.2 Collections (SERVER writes all of them)

**`tontines/{id}`**
- `id`, `name`, `description`, `rules`, `currency`, `contributionAmount`;
- `frequency`, `membersLimit`, `payoutOrderMethod`, `startDate`;
- `status`: `forming` / `active` / `completed` / `suspended`;
- `adminIds[]`, `memberIds[]` (ACTIVE members only), `currentCycle` (number), `nextDueAt`, `potAccountId`, `createdBy`, `createdAt`.

**`tontine_members/{tontineId}_{userId}`**
- `tontineId`, `tontineName` (shown on the invitation), `userId`, `displayName`, `email`;
- `role`: `admin` / `member`;
- `status`: `invited` / `active` / `declined` / `removed` / `restricted`;
- `payoutPosition` (1..n), `invitedBy`, `invitedByName`, `joinedAt`.

**`tontine_cycles/{id}`**
- `id`, `tontineId`, `number`, `dueDate`, `beneficiaryUserId`;
- `status`: `upcoming` / `collecting` / `payout_pending` / `paid` / `closed`;
- `expectedAmount`, `collectedAmount`.

**`tontine_contributions/{id}`**
- `tontineId`, `cycleId`, `cycleNumber`, `userId`, `amount`, `currency`;
- `status`: `pending` / `processing` / `paid` / `failed` / `overdue`;
- `reference`, `paymentId`, `paidAt`, `createdAt`.

**`tontine_payouts/{id}`**
- `id`, `tontineId`, `cycleId`, `cycleNumber`, `beneficiaryUserId`, `amount`;
- `status`: `pending_approval` / `approved` / `paid` / `failed`;
- `reference`, `createdAt`, `paidAt`.

**`tontine_disputes/{id}`**
- `tontineId`, `raisedBy`, `againstUserId?`, `subject`, `description`;
- `status`: `open` / `under_review` / `resolved` / `rejected`;
- `resolution`, `createdAt`.

**What the app shows:**
- Each cycle's status for EVERY member (group transparency). A member with no contribution record is shown pending, then overdue after `dueDate`; a `paid` record wins over an older `failed` one.
- The pot = `contributionAmount × memberIds.length`.
- The schedule: one cycle per member from `startDate`. Monthly keeps the day, clamped to the month's end.

App queries and indexes:

```
tontines where memberIds array-contains <uid> orderBy createdAt desc         -> (memberIds CONTAINS, createdAt DESC)
tontine_members where userId == <uid> and status == "invited"                -> equality only
tontine_members where tontineId == X                                         -> single field
tontine_cycles where tontineId == X orderBy number                           -> (tontineId ASC, number ASC)
tontine_contributions where tontineId == X and cycleId == Y                  -> equality only
tontine_payouts where tontineId == X orderBy createdAt desc                  -> (tontineId ASC, createdAt DESC)
tontine_disputes where tontineId == X orderBy createdAt desc                 -> (tontineId ASC, createdAt DESC)
```

Rules:
- a tontine and all its sub-records are readable by its ACTIVE members (`uid in tontines/{tontineId}.memberIds`). The app's queries always constrain `tontineId`;
- an invited user reads only their own `tontine_members` document;
- no client writes.

### 9.3 Callables

| Function | Request | Who / server checks |
|---|---|---|
| `tontineCreate` | `{ name, description?, rules?, contributionAmount, currency, frequency, membersLimit, payoutOrderMethod, startDate "yyyy-MM-dd" }` -> `{ tontineId }` | KYC-verified; validates against `platform_settings/tontines`; the creator is admin and the first member |
| `tontineInvite` | `{ tontineId, email }` | an admin; while `forming` / `active`; never beyond `membersLimit` (active + invited) |
| `tontineRespondInvite` | `{ tontineId, accept }` | the invitee |
| `tontineSetPayoutOrder` | `{ tontineId, order: [userIds] }` | an admin; `forming` only; exactly the active members |
| `tontineStart` | `{ tontineId }` | an admin; `forming`; at least `minMembers`; a full order (or a draw for `random`); creates the cycles; fixes members, amount and order |
| `tontineContribute` | `{ tontineId, cycleId, payment, idempotencyKey }` | an active member, once per cycle; the amount is the tontine's; reply and payment rules as in 8.4 |
| `tontineApprovePayout` | `{ payoutId }` | an admin, never the beneficiary approving their own payout alone (require a second admin when the beneficiary is the only admin, or the platform's review) |
| `tontineRaiseDispute` | `{ tontineId, subject, description, againstUserId? }` | an active member |

**Defaults and restriction (brief):** never restrict or blacklist a member automatically from an unverified payment failure. Record overdue obligations, review them through `tontine_disputes` with evidence and history, and apply `restricted` only after a documented decision.

---

## 10. Scheduled jobs and notifications for sections 8-9 (SERVER)

**Jobs:**
- contribution reminders (savings schedules, tontine cycles) before `nextDueAt` / `dueDate`;
- mark unpaid tontine contributions `overdue` after `dueDate`;
- open the next cycle and create its payout (`pending_approval`) when a cycle is fully collected;
- reconcile pending payments with the providers;
- keep `finance_summaries/{uid}` (`savings`, `tontines` sections) and each goal's `savedAmount` up to date.

**`dynamic_notification` templates** (record with `source: "finance"`, category `account`):

| Template `type` | To | Placeholders |
|---|---|---|
| `savings_invite` | invitee | `{goalName}`, `{inviterName}` |
| `savings_contribution_received` | contributor | `{amount}`, `{goalName}` |
| `savings_contribution_failed` | contributor | `{amount}`, `{goalName}` |
| `savings_contribution_due` | members | `{amount}`, `{goalName}`, `{dueDate}` |
| `savings_goal_completed` | members | `{goalName}` |
| `savings_withdrawal_completed` | requester | `{amount}`, `{goalName}` |
| `savings_withdrawal_rejected` | requester | `{amount}`, `{goalName}`, `{reason}` |
| `tontine_invite` | invitee | `{tontineName}`, `{inviterName}` |
| `tontine_started` | members | `{tontineName}`, `{firstDueDate}` |
| `tontine_contribution_due` | members | `{tontineName}`, `{amount}`, `{dueDate}` |
| `tontine_contribution_received` | contributor | `{tontineName}`, `{amount}` |
| `tontine_contribution_overdue` | the late member | `{tontineName}`, `{amount}` |
| `tontine_payout_pending_approval` | admins | `{tontineName}`, `{beneficiaryName}`, `{amount}` |
| `tontine_payout_paid` | beneficiary (and members) | `{tontineName}`, `{amount}` |
| `tontine_dispute_raised` | admins | `{tontineName}`, `{subject}` |

`.claude/seed_finance_config.py` creates the two config documents and these templates (create-only, dry run by default).

---

## 11. Member-to-member lending (brief section 7)

App code: `customer/lib/screen_ui/finance/lending_screens.dart`, `customer/lib/service/finance_lending_service.dart`, rules in `customer/lib/utils/finance_lending_rules.dart` (tested in `customer/test/finance_lending_rules_test.dart`). Entry: Spideli Finance > Services > **Loans** (Borrow / Group requests / Lent), and the overview's loans card.

**Model:** a member borrows from the members of a **group** they belong to (a tontine, `groupId`). The group's active members (except the borrower) vote and may fund. Subject to the applicable lending law: enable it per country only with legal sign-off.

### 11.1 `platform_settings/lending` (admin config)

```jsonc
{
  "currencies": ["XAF"],
  "minAmount": { "XAF": 10000 },          // minor units
  "maxAmount": { "XAF": 1000000 },
  "durationsMonths": [3, 6, 12],
  "repaymentFrequencies": ["weekly", "monthly"],
  "purposes": ["business", "education", "healthcare", "real_estate", "other"],
  "interest": { "method": "declining", "annualPercent": 12 },   // "flat" | "declining"
  "feePercent": 2,
  "latePenaltyPercent": 5,
  "voting": { "quorumPercent": 50, "approvalPercent": 60, "durationHours": 48 },
  "paymentMethods": ["wallet", "mobile_money", "wave"]
}
```

Required: "Loans are not available yet" when it is missing or invalid (no currency, duration, frequency or payment method; an unknown interest method; quorum or approval outside 1-100; or `durationHours` < 1).

- The app shows an **estimated** schedule from these terms before applying (flat, or declining-balance annuity). Amounts are whole minor units, rounding goes to the last installment, and the first due date is one period after today.
- It is labelled an estimate: the **binding** schedule is the agreement's.

### 11.2 Loan states (`loan_applications.status`)

`submitted` → `under_review` (eligibility, KYC, credit assessment) → `voting` → `funding` → `agreement_pending` → `disbursing` → `active` (or `overdue`) → `repaid`.

The loan can also end as `rejected` (with `reason`), `cancelled`, or `defaulted`.

### 11.3 Collections (SERVER writes all of them)

**`loan_applications/{id}`**
- `id`, `borrowerId`, `groupId`, `groupName`, `status`, `currency`, `amount`;
- `fundedAmount`, `outstandingAmount`, `durationMonths`, `repaymentFrequency`, `purpose`, `description`, `reason`;
- `eligibleVoterIds[]` (the group's active members minus the borrower, fixed when voting opens), `lenderIds[]` (members who funded);
- `votes: { yes, no }` (counts only), `votingEndsAt`, `documents: [{ name, storagePath }]`, `createdAt`.

**`loan_votes/{loanId}_{voterId}`**: `{ loanId, voterId, approve: bool, comment, at }`. One per voter (the id makes duplicates impossible). The app reads only the caller's own vote.

**`credit_assessments/{loanId}`**: `{ loanId, borrowerId, score, band, factors: [{ label, impact: "positive" | "negative", detail }], assessedAt }`.
- **Explain the material factors** in plain language.
- Readable by the borrower and authorised reviewers only, never by the voters.

**`loan_fundings/{id}`**: `{ loanId, lenderId, amount, currency, status: pending | succeeded | failed | refunded, reference, createdAt }`.

**`loan_agreements/{loanId}`**:
- `{ loanId, version, principal, currency, interestMethod, annualInterestPercent, fee, totalRepayable, latePenaltyPercent, terms, installments: [...], createdAt, acceptedAt }`;
- a NEW `version` whenever the terms change.

**`loan_schedules/{loanId}`**: `{ installments: [{ number, dueDate, amount, principal, interest, penalty, amountDue, status }] }`.
- Installment `status` is one of `upcoming`, `due`, `paid`, `partially_paid`, `overdue`.

**`loan_disbursements/{id}`**: `{ loanId, amount, fee, status, reference, paidAt }`.

**`loan_repayments/{id}`**: `{ loanId, borrowerId, amount, currency, status: pending | processing | succeeded | failed, reference, createdAt }`.

App queries (with indexes):

```
loan_applications where borrowerId == <uid>                 orderBy createdAt desc limit 50 -> (borrowerId ASC, createdAt DESC)
loan_applications where eligibleVoterIds array-contains <uid> orderBy createdAt desc limit 50 -> (eligibleVoterIds CONTAINS, createdAt DESC)
loan_applications where lenderIds array-contains <uid>       orderBy createdAt desc limit 50 -> (lenderIds CONTAINS, createdAt DESC)
loan_repayments where loanId == X orderBy createdAt desc                                      -> (loanId ASC, createdAt DESC)
loan_fundings where loanId == X and lenderId == <uid>                                         -> equality only
loan_votes/{loanId}_{uid}, loan_agreements/{loanId}, loan_schedules/{loanId}, credit_assessments/{loanId}: single documents
```

Rules:
- A loan is readable by its borrower, its eligible voters and its lenders.
- Agreement, schedule and repayments: the borrower and the lenders.
- Credit assessment: the borrower (and reviewers) only.
- A vote: its voter.
- A funding: its lender (and the borrower, if you choose).
- **No client writes.**
- Storage `loan_documents/{uid}/{loanId}/{file}`: the borrower creates (images, size cap, no overwrite). Reviewers and voters read through signed links.

### 11.4 Callables

| Function | Request | Server checks |
|---|---|---|
| `loanApply` | `{ amount, currency, purpose, durationMonths, repaymentFrequency, groupId, description? }` -> `{ loanId }` | KYC-verified; an ACTIVE member of `groupId`; limits from config; no other open request beyond your policy |
| `loanRegisterDocument` | `{ loanId, storagePath, name }` | the borrower; the path is theirs; type and size |
| `loanCancel` | `{ loanId }` | the borrower; only `submitted` / `under_review` / `voting` |
| `loanVote` | `{ loanId, approve, comment? }` | an eligible voter, never the borrower; `voting` and before `votingEndsAt`; **once** (`loan_votes/{loanId}_{uid}` must not exist) |
| `loanFund` | `{ loanId, amount, payment, idempotencyKey }` | an eligible member, not the borrower; `funding`; never beyond the remaining amount (a transaction on `fundedAmount`); payment as section 8.4 |
| `loanAcceptAgreement` | `{ loanId, agreementVersion }` | the borrower; `agreement_pending`; refuse an outdated `version`; record the acceptance (time, version, device) as the electronic agreement |
| `loanRepay` | `{ loanId, amount, payment, idempotencyKey }` | the borrower; `active` / `overdue`; never beyond `outstandingAmount`; allocate to the oldest installment (penalty, interest, then principal) |

**After voting:**
- quorum = `ceil(eligible × quorumPercent / 100)` votes cast;
- approval = `yes / cast ≥ approvalPercent`;
- not reached by `votingEndsAt` → `rejected` with a reason.

The app shows the live tally from `votes` and these rules.

**Anti-duplication:**
- one vote per voter (document id);
- one disbursement per loan (idempotent on `loanId`);
- every funding and repayment is idempotent on its `idempotencyKey`, and confirmed only by the provider (section 8.4).

**Defaults:** an `overdue` installment applies `latePenaltyPercent` per your disclosed terms. `defaulted` is set only after a documented review, never automatically from one failed payment. Disputes and restrictions follow the tontine rules (section 9.3).

### 11.5 Jobs and notifications (SERVER)

**Jobs:**
- close voting at `votingEndsAt`;
- installment reminders before `dueDate`;
- mark installments `overdue` and apply penalties;
- distribute received repayments to the lenders, pro rata to their funding;
- reconcile payments;
- keep `finance_summaries/{uid}.loans` up to date.

**Templates** (`dynamic_notification`, `source: "finance"`):

| Template `type` | To | Placeholders |
|---|---|---|
| `loan_submitted` | borrower | `{amount}` |
| `loan_vote_requested` | eligible voters | `{borrowerName}`, `{amount}`, `{groupName}`, `{votingEndsAt}` |
| `loan_approved` | borrower | `{amount}` |
| `loan_rejected` | borrower | `{amount}`, `{reason}` |
| `loan_funding_open` | eligible voters | `{borrowerName}`, `{amount}`, `{groupName}` |
| `loan_funded` | borrower | `{amount}` |
| `loan_agreement_ready` | borrower | `{amount}` |
| `loan_disbursed` | borrower and lenders | `{amount}` |
| `loan_repayment_due` | borrower | `{amount}`, `{dueDate}` |
| `loan_repayment_received` | borrower | `{amount}` |
| `loan_repayment_overdue` | borrower | `{amount}` |
| `loan_lender_repayment` | each lender | `{amount}`, `{borrowerName}` |
| `loan_repaid` | borrower and lenders | `{amount}` |

---

## 12. Investments (brief section 4)

App code: `customer/lib/screen_ui/finance/investment_screens.dart`, `customer/lib/service/finance_investment_service.dart`, rules in `customer/lib/utils/finance_investment_rules.dart` (tested in `customer/test/finance_investment_rules_test.dart`). Entry: Spideli Finance > Services > **Investments** (Portfolio / Funds / Orders), and the overview's investments card.

**Model:** fund managers / the admin publish funds. A KYC-verified user subscribes an amount: they pay, then units are bought at the unit price (NAV) of the processing date. They redeem part or all of the redeemable position, and the money is settled to a wallet or Mobile Money number. **Fund valuations, unit counts, gains, fees charged and settlements are server-only.** Offering collective investments is regulated: publish a fund only with the manager's licence and legal sign-off for the country.

### 12.1 `platform_settings/investments` (admin config)

```jsonc
{
  "currencies": ["XAF"],
  "assetClasses": ["money_market", "bonds", "equities", "real_estate", "agriculture", "infrastructure", "mixed"],   // the catalog filter order
  "paymentMethods": ["wallet", "mobile_money", "wave"],     // to pay subscriptions and receive redemptions
  "riskDisclosure": "Investing carries risks…",             // REQUIRED: shown and accepted before every subscription
  "simulator": { "maxYears": 30 }                            // optional, 1-50 (default 30)
}
```

Required: "Investments are not available yet" when it is missing or has no valid currency, no payment method, or no `riskDisclosure`.

### 12.2 Collections (SERVER writes all of them)

**`investment_funds/{fundId}`** (catalog; the app lists `published == true`):
- `name`, `manager`, `description`, `objective`, `assetClass`, `riskLevel` (1-7), `currency`, `order` (display order, optional);
- `minInvestment`, `minAdditional` (optional; the minimum once the user holds units), in minor units;
- `fees: { subscriptionPercent, managementPercent (a year), redemptionPercent, performancePercent }`;
- `navPerUnit` (unit price in minor units, decimals allowed), `navDate`;
- `lockUpDays`, `settlementDays` (business days), `redemption: { allowed, partial }`;
- `terms` (text), `termsVersion` (≥ 1; **a new version whenever the terms change**), `documents: [{ name, storagePath | url (https) }]`, `eligibility` (plain-language text);
- `performance: { ytd, oneYear, threeYears, fiveYears, sinceInception }` (percent, from the official valuations);
- `status`: `open` | `closed` (no new subscriptions) | `suspended` (no orders), `published: bool`.

The app offers "Invest" only for an `open` fund with a `navPerUnit` and a `termsVersion`.

**`investment_valuations/{id}`**: `{ fundId, date, navPerUnit }`, one per published price (the price history chart, last 90).

**`investment_holdings/{uid}_{fundId}`** (one position per user and fund):
- `{ userId, fundId, fundName, assetClass, currency, units, redeemableUnits, redeemableValue, investedAmount, currentValue, realizedGains, unrealizedGains, lockedUntil, valuedAt }`;
- `redeemableUnits` / `redeemableValue` exclude the units still in their lock-up; `lockedUntil` is when the next locked units free up;
- revalue at each new `navPerUnit`.

**`investment_subscriptions/{id}`**:
- `{ userId, fundId, fundName, currency, amount, fee, netAmount, units, navPerUnit, termsVersion, signatureName, acceptedAt, paymentId, reference, status, reason, tradeDate, createdAt }`;
- `status`: `pending_payment` → `paid` → `processing` → `completed` (units allocated), or `payment_failed` / `rejected` (with `reason`) / `cancelled`.

**`investment_redemptions/{id}`**:
- `{ userId, fundId, fundName, currency, full, amount (null for a full redemption until processed), fee, netAmount, units, navPerUnit, destination, reference, status, reason, tradeDate, expectedSettlementDate, settledAt, createdAt }`;
- `status`: `submitted` → `processing` → `settling` → `settled`, or `rejected` / `cancelled`.

**`investment_transactions/{id}`**: `{ userId, fundId, type: subscription | redemption | fee | distribution | adjustment, amount, units, navPerUnit, currency, reference, createdAt }`. Also post each money movement to the ledger (section 4.2).

**`investment_reports/{id}`**: `{ userId, title, period, storagePath, createdAt }`, a PDF in Storage at `investment_reports/{uid}/{file}.pdf` (monthly / annual statements, tax certificates).

**`finance_summaries/{uid}.investments`** (section 4.3), plus **`allocation: { <assetClass>: currentValue }`** (minor units): the app shows the shares of each class and computes only the display percentages.

App queries (with indexes):

```
investment_funds where published == true limit 100                                           -> equality only
investment_valuations where fundId == X orderBy date desc limit 90                           -> (fundId ASC, date DESC)
investment_holdings where userId == <uid>                                                     -> equality only
investment_subscriptions where userId == <uid> orderBy createdAt desc limit 50                -> (userId ASC, createdAt DESC)
investment_redemptions where userId == <uid> orderBy createdAt desc limit 50                  -> (userId ASC, createdAt DESC)
investment_transactions where userId == <uid> and fundId == X orderBy createdAt desc limit 50 -> (userId ASC, fundId ASC, createdAt DESC)
investment_reports where userId == <uid> orderBy createdAt desc limit 24                      -> (userId ASC, createdAt DESC)
investment_funds/{id}, investment_holdings/{uid}_{fundId}, investment_subscriptions/{id}, investment_redemptions/{id}: single documents
```

Rules:
- `platform_settings/investments`, published `investment_funds` and `investment_valuations`: any signed-in user.
- Holdings, subscriptions, redemptions, transactions, reports: `resource.data.userId == request.auth.uid` (plus staff).
- **No client writes** to any of them.
- Storage: `investment_funds/{fundId}/**` read by signed-in users; `investment_reports/{uid}/**` read by its owner only; no client writes.

### 12.3 Callables

| Function | Request | Server checks |
|---|---|---|
| `investmentSubscribe` | `{ fundId, amount, currency, termsVersion, riskAcknowledged: true, signatureName, payment, idempotencyKey }` -> `{ subscriptionId, status, instructions?, reference? }` (as section 8.4) | KYC-verified and eligible for the fund; fund `open`; `currency` is the fund's; `amount ≥ minInvestment` (`minAdditional` for a holder); `termsVersion` is the **current** one (else `terms_outdated`); `riskAcknowledged`; record the acceptance (time, terms version, signature name, device) as the electronic agreement; payment as section 8.4 |
| `investmentRedeem` | `{ fundId, full, amount? (when not full), destination, idempotencyKey }` -> `{ redemptionId, status }` | the holder; fund not `suspended` and `redemption.allowed`; partial only if `redemption.partial`; `amount ≤ redeemableValue` (lock-up respected); `destination` as section 8.4 |
| `investmentCancelRedemption` | `{ redemptionId }` | the holder; only `submitted` |

Reasons the app maps to a translated message (`FinanceErrors`): `fund_closed`, `terms_outdated`, `below_minimum`, `not_eligible`, `locked_up`, `redemption_not_allowed`, `insufficient_units`.

**Processing:**
- a subscription becomes `paid` only on the provider's verified confirmation (section 8.4), then is executed at the next `navPerUnit`: `units = netAmount / navPerUnit`, `fee = amount × subscriptionPercent`;
- a redemption is executed at the next `navPerUnit`, the fee is deducted, and it is settled to `destination` within `settlementDays`, idempotent on the redemption id;
- realized gains are booked on redemption (cost basis: your documented method, e.g. average cost); unrealized gains on each revaluation.

The fee and unit figures in the app are labelled **estimates at the last price**; the return simulator is labelled an **illustration** (constant yearly return, before fees and taxes, not guaranteed).

### 12.4 Jobs and notifications (SERVER)

**Jobs:**
- publish each new `navPerUnit` to the fund and `investment_valuations`, then revalue the holdings and `finance_summaries/{uid}.investments`;
- execute pending subscriptions and redemptions at the new price;
- settle redemptions and reconcile payments;
- generate the periodic statements into `investment_reports`.

**Templates** (`dynamic_notification`, `source: "finance"`):

| Template `type` | To | Placeholders |
|---|---|---|
| `investment_subscription_received` | investor | `{amount}`, `{fundName}` |
| `investment_payment_confirmed` | investor | `{amount}`, `{fundName}` |
| `investment_payment_failed` | investor | `{amount}`, `{fundName}` |
| `investment_units_allocated` | investor | `{units}`, `{fundName}`, `{navPerUnit}` |
| `investment_subscription_rejected` | investor | `{amount}`, `{fundName}`, `{reason}` |
| `investment_redemption_received` | investor | `{fundName}` |
| `investment_redemption_processed` | investor | `{amount}`, `{fundName}`, `{settlementDate}` |
| `investment_redemption_settled` | investor | `{amount}`, `{fundName}` |
| `investment_redemption_rejected` | investor | `{fundName}`, `{reason}` |
| `investment_report_available` | investor | `{period}` |
| `investment_terms_updated` | holders of the fund | `{fundName}` |
