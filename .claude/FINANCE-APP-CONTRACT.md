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

---

## 13. Online insurance (brief section 8)

App code: `customer/lib/screen_ui/finance/insurance_screens.dart`, `customer/lib/service/finance_insurance_service.dart`, rules in `customer/lib/utils/finance_insurance_rules.dart` (tested in `customer/test/finance_insurance_rules_test.dart`). Entry: Spideli Finance > Services > **Insurance** (My policies / Quotes / Claims / Insurance offers), and the overview's insurance card.

**Model:** Spideli distributes products of **authorised insurers** (`insurance_partners`). The server talks to each insurer's API (or its back office) and writes only **verified** responses. **A policy is never `active`, and a claim never `approved` / `paid`, until the insurer or its verified integration confirms it.** Distribution needs the right intermediary licence in each country.

### 13.1 `platform_settings/insurance` (admin config)

```jsonc
{
  "currencies": ["XAF"],
  "categories": ["health", "life", "auto", "home", "travel", "business", "agriculture", "device", "funeral"],   // the catalog filter order
  "paymentMethods": ["wallet", "mobile_money", "wave"],
  "claims": { "maxFiles": 5 }                        // photos per claim / response, 1-20 (default 5)
}
```

Required: "Insurance is not available yet" when it is missing or has no valid currency, category or payment method.

### 13.2 Collections (SERVER writes all of them)

**`insurance_partners/{partnerId}`**: `{ name, licenceNumber, country, contact, api: <server-only settings, never readable by clients> }`. The app does not read it: products carry `partnerName`.

**`insurance_products/{productId}`** (catalog; the app lists `published == true`):
- `partnerId`, `partnerName`, `category`, `name`, `summary`, `description`, `currency`, `order` (optional);
- `coverages: [{ name, description, limit }]`, `exclusions: [string]`, `deductible`, `waitingPeriodDays`, `termMonths`;
- `rating` (optional; without it the app offers a quote but no simulation):

```jsonc
"rating": {
  "basePremium": 60000,                                   // a year, minor units
  "frequencies": { "annual": 0, "monthly": 5 },           // allowed: annual, semiannual, quarterly, monthly; value = loading %
  "factors": [                                            // the quote questions, also sent to the insurer as `answers`
    { "key": "age", "label": "Age", "type": "number", "unit": "years", "min": 18, "max": 75,
      "bands": [ { "upTo": 30, "multiplier": 1 }, { "upTo": 50, "multiplier": 1.3 }, { "upTo": 75, "multiplier": 1.8 } ] },
    { "key": "level", "label": "Cover level", "type": "select",
      "options": [ { "value": "basic", "label": "Basic", "multiplier": 1 }, { "value": "plus", "label": "Plus", "multiplier": 1.5 } ] }
  ]
}
```

- `terms`, `termsVersion` (≥ 1), `documents: [{ name, storagePath | url (https) }]` (policy wording, product information sheet), `status: open | closed`, `published`.
- **Simulation** (labelled an estimate): `basePremium × Π multipliers`, then `× (1 + loading%) / payments a year`, rounded to minor units. Factor labels are shown as written: write them in the users' language.

**`insurance_quotes/{quoteId}`**:
- `{ userId, productId, productName, partnerName, category, answers, frequency, coverStart, coverEnd, currency, premium (a year), installmentAmount, deductible, coverages, documents, terms, termsVersion, validUntil, insurerReference, status, reason, policyId, createdAt }`;
- `status`: `requested` → `quoted` (the insurer priced it) → `accepted` (policy created), or `declined` (by the user), `expired` (after `validUntil`), `rejected` (the insurer will not cover; `reason`).

**`insurance_policies/{policyId}`**:
- `{ userId, quoteId, productId, productName, partnerName, category, policyNumber, status, currency, premium, frequency, installmentAmount, deductible, coverages, coverStart, coverEnd, nextPremiumDue, autoRenew, renewalPremium, renewalDate, documents: [{ name, storagePath }], reason, createdAt }`;
- `status`: `pending_activation` (paid, waiting for the insurer) → `active` → `renewal_due` → `active` (renewed) or `expired`. Also `lapsed` (premium unpaid), `cancellation_requested` → `cancelled`, and `rejected` (the insurer refused after payment: **refund** the premium).
- Policy documents (certificate, schedule) go to Storage under `insurance_policies/{uid}/{policyId}/`.

**`insurance_premiums/{premiumId}`**: `{ userId, policyId, amount, currency, dueDate, status: upcoming | due | overdue | processing | paid | failed, paidAt, reference }`.

**`insurance_claims/{claimId}`**:
- `{ userId, policyId, policyNumber, productName, currency, incidentDate, description, amountClaimed, approvedAmount, paidAmount, paidAt, insurerReference, documents: [{ name, storagePath }], status, reason, createdAt }`;
- `status`: `submitted` → `under_review` → (`info_requested` → `under_review` …) → `approved` → `paid`, or `rejected` (`reason`), `withdrawn`;
- for `info_requested`, put the insurer's question in `reason`; keep the full exchange in `insurance_claims/{claimId}/events` (server).

App queries (with indexes):

```
insurance_products where published == true limit 100                                        -> equality only
insurance_quotes   where userId == <uid> orderBy createdAt desc limit 50                     -> (userId ASC, createdAt DESC)
insurance_policies where userId == <uid> orderBy createdAt desc limit 50                     -> (userId ASC, createdAt DESC)
insurance_claims   where userId == <uid> orderBy createdAt desc limit 50                     -> (userId ASC, createdAt DESC)
insurance_claims   where userId == <uid> and policyId == X orderBy createdAt desc            -> (userId ASC, policyId ASC, createdAt DESC)
insurance_premiums where userId == <uid> and policyId == X orderBy dueDate                   -> (userId ASC, policyId ASC, dueDate ASC)
insurance_products/{id}, insurance_quotes/{id}, insurance_policies/{id}, insurance_claims/{id}: single documents
```

Rules:
- `platform_settings/insurance` and published products: any signed-in user. `insurance_partners`: staff only.
- Quotes, policies, premiums, claims: `resource.data.userId == request.auth.uid` (plus staff and the insurer's authorised users).
- **No client writes.**
- Storage: `insurance_claims/{uid}/{claimId}/{file}` created by the owner (images, size cap, no overwrite), read by the owner, staff and the insurer; `insurance_policies/{uid}/**` read by the owner; product documents read by signed-in users.

### 13.3 Callables

| Function | Request | Server checks |
|---|---|---|
| `insuranceRequestQuote` | `{ productId, answers, frequency, coverStart (yyyy-MM-dd) }` -> `{ quoteId }` | KYC-verified; product `open`; every factor answered within range; `frequency` allowed; `coverStart` today .. +180 days; then ask the insurer and store its answer |
| `insuranceDeclineQuote` | `{ quoteId }` | the owner; `quoted` |
| `insuranceAcceptQuote` | `{ quoteId, termsVersion, signatureName, payment, idempotencyKey }` -> payment reply (section 8.4) | the owner; `quoted` and before `validUntil` (else `quote_expired`); current `termsVersion` (else `terms_outdated`); record the acceptance (time, terms version, signature name, device) as the electronic signature; collect the first premium; create the policy `pending_activation`; **activate only on the insurer's confirmation** |
| `insurancePayPremium` | `{ policyId, premiumId, payment, idempotencyKey }` | the owner; premium `due` / `overdue` / `failed` |
| `insuranceRenewPolicy` | `{ policyId, payment, idempotencyKey }` | the owner; `renewal_due` with a `renewalPremium` confirmed by the insurer |
| `insuranceSetAutoRenew` | `{ policyId, autoRenew }` | the owner; `active` / `renewal_due` |
| `insuranceRequestCancellation` | `{ policyId, reason? }` | the owner; `active` / `renewal_due`; forward to the insurer; `cancelled` (and any refund) only on its confirmation |
| `insuranceCreateClaim` | `{ policyId, incidentDate (yyyy-MM-dd), description, amountClaimed }` -> `{ claimId }` | the owner; policy `active` / `renewal_due` (else `policy_not_active`); incident within the cover period and after the waiting period |
| `insuranceRegisterClaimDocument` | `{ claimId, storagePath, name }` | the owner; the path is theirs; type and size |
| `insuranceSubmitClaim` | `{ claimId }` | the owner; then forward the claim and its files to the insurer |
| `insuranceRespondClaim` | `{ claimId, message? }` (after registering new files) | the owner; `info_requested` (else `claim_not_editable`); back to `under_review` |
| `insuranceWithdrawClaim` | `{ claimId }` | the owner; `submitted` / `under_review` / `info_requested` |

Reasons the app maps (`FinanceErrors`): `quote_expired`, `terms_outdated`, `product_closed`, `policy_not_active`, `claim_not_editable`, `insurer_unavailable`, `not_eligible`.

Claim payouts go to the wallet or a saved Mobile Money number chosen with the insurer's process (the app does not ask for a destination yet), and are posted to the ledger.

### 13.4 Jobs and notifications (SERVER)

**Jobs:**
- expire quotes after `validUntil`;
- premium reminders, then `overdue` and `lapsed` per the policy terms;
- renewal: obtain `renewalPremium` from the insurer before `coverEnd`, set `renewal_due`; with `autoRenew`, collect it from the wallet if allowed, otherwise remind;
- poll or receive the insurer's status updates (activation, claim decisions, payments), verified;
- keep `finance_summaries/{uid}.insurance` up to date (`activePolicies`, `nextRenewalDate`, `openClaims`).

**Templates** (`dynamic_notification`, `source: "finance"`):

| Template `type` | To | Placeholders |
|---|---|---|
| `insurance_quote_ready` | user | `{productName}`, `{amount}`, `{validUntil}` |
| `insurance_quote_rejected` | user | `{productName}`, `{reason}` |
| `insurance_policy_active` | user | `{productName}`, `{policyNumber}`, `{coverStart}` |
| `insurance_policy_rejected` | user | `{productName}`, `{reason}` |
| `insurance_premium_due` | user | `{productName}`, `{amount}`, `{dueDate}` |
| `insurance_premium_overdue` | user | `{productName}`, `{amount}` |
| `insurance_policy_lapsed` | user | `{productName}` |
| `insurance_renewal_due` | user | `{productName}`, `{amount}`, `{renewalDate}` |
| `insurance_policy_renewed` | user | `{productName}`, `{coverEnd}` |
| `insurance_policy_cancelled` | user | `{productName}` |
| `insurance_claim_received` | user | `{productName}`, `{amount}` |
| `insurance_claim_info_requested` | user | `{productName}`, `{reason}` |
| `insurance_claim_approved` | user | `{productName}`, `{amount}` |
| `insurance_claim_rejected` | user | `{productName}`, `{reason}` |
| `insurance_claim_paid` | user | `{productName}`, `{amount}` |

---

## 14. Virtual cards (brief section 12)

App code: `customer/lib/screen_ui/finance/card_screens.dart`, `customer/lib/service/finance_card_service.dart`, `customer/lib/screen_ui/finance/finance_security.dart` (re-authentication, screenshot blocking), rules in `customer/lib/utils/finance_card_rules.dart` (tested in `customer/test/finance_card_rules_test.dart`). Entry: Spideli Finance > Services > **Virtual cards**.

**Model:** cards are issued by an **approved issuer** (BIN sponsor / card programme manager) through the server. The issuer is the source of truth for card status, balance, limits and transactions; the server mirrors only **non-sensitive display metadata** to Firestore.

**Card data (PCI DSS):**
- **Never** store the full card number (PAN) or the CVV in Firestore, Storage, logs, analytics or crash reports.
- `virtual_cards` holds only `last4`, expiry, holder name, status, balance and labels.
- The issuer's references (card token, account id) live in a server-only collection (e.g. `virtual_cards_private/{cardId}`), unreadable by clients.

### 14.1 `platform_settings/cards` (admin config)

```jsonc
{
  "currencies": ["XAF"],
  "issuerName": "<issuer>",
  "network": "visa",
  "maxCardsPerUser": 3,                          // cards that are requested / active / frozen
  "issuanceFee": { "XAF": 1000 },                // minor units; omit or 0 = free
  "monthlyFee":  { "XAF": 500 },
  "renewalFee":  { "XAF": 0 },
  "fundingMethods": ["wallet", "mobile_money", "wave"],
  "minFunding": { "XAF": 1000 }, "maxFunding": { "XAF": 500000 },
  "fundingFeePercent": 1.5,                      // added on top of the amount the card receives
  "limits": {                                    // the ceilings of the user's own limits
    "maxPerTransaction": { "XAF": 300000 }, "maxDaily": { "XAF": 500000 }, "maxMonthly": { "XAF": 2000000 }
  },
  "capabilities": {                              // what THIS issuer supports; anything missing = not offered
    "withdraw": false,                           // card balance back to the wallet / Mobile Money
    "renew": true,
    "onlineToggle": false, "internationalToggle": false,
    "secureDetails": "hosted"                    // "hosted" | "direct" | "none" (section 14.3)
  },
  "terms": "<the issuer's cardholder agreement>", // REQUIRED
  "termsVersion": 1                               // REQUIRED, >= 1
}
```

Required: "Virtual cards are not available yet" when it is missing, or has no valid currency, no funding method, no `terms` or no `termsVersion`. **Only fill `terms` / `termsVersion` once an issuer is contracted**: until then the module stays hidden behind that message.

### 14.2 Collections (SERVER writes all of them)

**`virtual_cards/{cardId}`**:
- `{ userId, label, network, last4, expiryMonth, expiryYear, cardholderName, currency, balance, status, frozenBy, replacedBy, reason, createdAt }`;
- `status`: `requested` → `active` ⇄ `frozen` → `terminated`; also `expired`, or `failed` (creation refused; `reason`, and refund the fee);
- `frozenBy`: `user` (the user may unfreeze), or `issuer` / `admin` (fraud, compliance: only staff unfreeze);
- `balance` is the issuer's available balance, refreshed on every event (webhook) and on each app action;
- `cardholderName` comes from the user's **verified KYC name**, never from the app.

**`card_transactions/{id}`**: `{ userId, cardId, type: purchase | refund | funding | withdrawal | fee | reversal | authorization, status: pending | completed | declined | reversed, amount, currency, originalAmount, originalCurrency, merchantName, merchantCountry, declineReason, createdAt }`, from the issuer's **verified** webhooks.

**`card_funding_requests/{id}`**: `{ userId, cardId, type: fund | withdraw, amount, fee, currency, status: pending | processing | succeeded | failed, reference, createdAt }`.

**`card_limit_settings/{cardId}`**: `{ userId, cardId, perTransaction, daily, monthly (null = the issuer's maximum), allowOnline, allowInternational, status: pending | applied, updatedAt }`.

App queries (with indexes):

```
virtual_cards         where userId == <uid> orderBy createdAt desc limit 20                    -> (userId ASC, createdAt DESC)
card_transactions     where userId == <uid> and cardId == X orderBy createdAt desc limit 50   -> (userId ASC, cardId ASC, createdAt DESC)
card_funding_requests where userId == <uid> and cardId == X orderBy createdAt desc limit 10   -> (userId ASC, cardId ASC, createdAt DESC)
virtual_cards/{id}, card_limit_settings/{cardId}: single documents
```

Rules: owner read only (`resource.data.userId == request.auth.uid`), plus staff; **no client writes**; `virtual_cards_private` readable by no client.

### 14.3 Showing the card details

The app shows the full number, expiry and CVV only after **re-authentication**, and only through the mode set in `capabilities.secureDetails`:
- **`hosted`** (recommended): `cardSecureDetailsLink` returns `{ url, expiresAt }`, a single-use, short-lived (≤ 5 min) **https** link to the issuer's PCI-compliant page. The app opens it in an in-app browser tab; neither the app nor the server ever sees the data.
- **`direct`**: `cardRevealDetails` returns `{ number, expiryMonth, expiryYear, cvv, cardholderName }` from the issuer's secure retrieval API, relayed in memory only. This puts the relay in PCI scope: use it only if your environment is certified for it. The app:
  - shows them for 60 seconds, blocking screenshots and screen recording (Android `FLAG_SECURE`);
  - hides them when the app goes to the background;
  - lets the user copy the number only (cleared from the clipboard after a minute), never the CVV;
  - never stores or logs them.
- **`none`**: no "Show details" button.

Record every reveal (time, device, IP) and send the `card_details_viewed` security notice.

### 14.4 Callables

**Re-authentication:** for the functions marked **R**, refuse with reason `reauth_required` unless `request.auth.token.auth_time` is within the last **5 minutes**. Before calling them, the app re-authenticates the user (password, SMS code, Google or Apple, the way they signed in), or skips that step when the sign-in is under 4 minutes old.

| Function | Request | Server checks |
|---|---|---|
| `cardCreate` | `{ label?, currency, termsVersion, payment? (when there is an issuance fee), idempotencyKey }` -> payment reply (section 8.4) or `{ cardId }` | KYC-verified (the issuer's KYC level); under `maxCardsPerUser` (else `card_limit_reached`); current `termsVersion`; record the acceptance; collect the fee; create the card at the issuer (`requested` → `active` / `failed`) |
| `cardFund` | `{ cardId, amount, payment, idempotencyKey }` | owner; `active`; `minFunding`..`maxFunding` (else `amount_out_of_range`); the payment is `amount + fee` (section 8.4); load the card **only after the payment is confirmed** |
| `cardWithdraw` **R** | `{ cardId, amount, destination, idempotencyKey }` | `capabilities.withdraw` (else `not_supported`); owner; `amount ≤ balance` at the issuer |
| `cardFreeze` | `{ cardId }` | owner; `active` → `frozen` with `frozenBy: "user"` (no re-auth: freezing must be instant) |
| `cardUnfreeze` **R** | `{ cardId }` | owner; `frozen` with `frozenBy == "user"` |
| `cardSetLimits` **R** | `{ cardId, perTransaction, daily, monthly (null = maximum), allowOnline?, allowInternational? }` | owner; within the config ceilings; per transaction ≤ daily ≤ monthly; toggles only if supported |
| `cardSecureDetailsLink` **R** | `{ cardId }` -> `{ url, expiresAt }` | owner; `active`; mode `hosted` |
| `cardRevealDetails` **R** | `{ cardId }` -> `{ number, expiryMonth, expiryYear, cvv, cardholderName }` | owner; `active`; mode `direct`; rate-limited |
| `cardRenew` | `{ cardId, payment?, idempotencyKey }` | `capabilities.renew`; owner; `expired` or expiring within 30 days, not already replaced; the new card gets `replacedBy` on the old one |
| `cardTerminate` **R** | `{ cardId }` | owner; `active`, `expired`, or frozen by the user; close it at the issuer and return any balance to the wallet (ledger) |

Reasons the app maps (`FinanceErrors`): `reauth_required`, `card_limit_reached`, `card_not_active`, `issuer_unavailable`, `amount_out_of_range`, `not_supported`, `terms_outdated`, `insufficient_funds`.

**Never trust the app:**
- balances and statuses only from the issuer;
- funding is idempotent on `idempotencyKey`;
- monthly fees are charged by the server per the disclosed terms;
- verify the issuer's webhook signatures;
- App Check on every card function.

### 14.5 Jobs and notifications (SERVER)

**Jobs:**
- process the issuer's webhooks (authorisations, settlements, declines, refunds, status) into `card_transactions` and `virtual_cards.balance`;
- charge monthly fees;
- mark cards `expired`;
- remind users 30 days before expiry;
- reconcile with the issuer daily.

**Templates** (`dynamic_notification`, `source: "finance"`; the **security** ones should always be sent, whatever the user's preferences):

| Template `type` | To | Placeholders |
|---|---|---|
| `card_created` | user | `{last4}` |
| `card_creation_failed` | user | `{reason}` |
| `card_funded` | user | `{amount}`, `{last4}` |
| `card_funding_failed` | user | `{amount}`, `{last4}` |
| `card_transaction` | user | `{amount}`, `{merchantName}`, `{last4}` |
| `card_transaction_declined` | user | `{amount}`, `{merchantName}`, `{reason}` |
| `card_refund` | user | `{amount}`, `{merchantName}`, `{last4}` |
| `card_frozen` (security) | user | `{last4}` |
| `card_unfrozen` (security) | user | `{last4}` |
| `card_details_viewed` (security) | user | `{last4}`, `{time}` |
| `card_limits_updated` (security) | user | `{last4}` |
| `card_withdrawal_completed` | user | `{amount}`, `{last4}` |
| `card_expiring` | user | `{last4}`, `{expiry}` |
| `card_renewed` | user | `{last4}` |
| `card_terminated` (security) | user | `{last4}`, `{amount}` (balance returned) |

---

## 15. Transfers and bill payments (brief sections 11 and 13)

App code: `customer/lib/screen_ui/finance/transfer_screens.dart`, `customer/lib/screen_ui/finance/bill_screens.dart`, `customer/lib/service/finance_transfer_service.dart`, receipts in `customer/lib/utils/finance_receipt_pdf.dart`, rules in `customer/lib/utils/finance_transfer_rules.dart` (tested in `customer/test/finance_transfer_rules_test.dart`). Entry: Spideli Finance > Services > **Send money** and **Pay bills**.

**One flow for both: create, confirm, then the state machine.**
1. **Create:** the app sends the recipient (or bill account) and the amount. The server validates them and computes the **binding fee**, then stores the request as `awaiting_confirmation` with `expiresAt` (about 15 min). No money moves at this step.
2. **Confirm:** the app shows the server's figures (verified recipient name, amount, fee, total) for the user to confirm. Above `security.reauthAbove` the user re-authenticates first (section 14.4: the server checks `auth_time`). The user then picks how to pay, and the app calls the confirm function with an `idempotencyKey`.
3. **State machine:** `awaiting_confirmation` → `pending` (waiting for the payment, section 8.4) → `processing` (sent to the provider or biller) → `completed`. It can also end as `failed` (with `reason`), `cancelled` (by the user before `processing`), `expired` (not confirmed in time), or `reversed` (refunded after a provider failure).

**Not atomic:** a Firestore transaction **cannot** make a provider operation atomic. Use:
- the explicit states above;
- the providers' **verified** callbacks;
- daily reconciliation;
- **compensating actions**: when the payout fails after the user paid, refund automatically and set `reversed`.

### 15.1 `platform_settings/transfers` (admin config)

```jsonc
{
  "currencies": ["XAF"],
  "sourceMethods": ["wallet", "mobile_money", "wave"],     // what pays a transfer
  "security": { "reauthAbove": { "XAF": 50000 } },        // re-authentication from this amount (missing currency = always)
  "channels": {                                           // a channel is offered only with enabled: true
    "internal":     { "enabled": true, "feePercent": 0, "min": { "XAF": 100 }, "max": { "XAF": 1000000 }, "delay": "Instant" },
    "mobile_money": { "enabled": true, "operators": ["Orange Money", "MTN Mobile Money"], "feePercent": 1, "feeFixed": { "XAF": 0 }, "feeMax": { "XAF": 5000 },
                      "min": { "XAF": 500 }, "max": { "XAF": 500000 }, "delay": "A few minutes" },
    "wave":         { "enabled": false },
    "bank":         { "enabled": false, "banks": [ { "code": "10005", "name": "Afriland First Bank" } ], "feePercent": 0.5, "feeFixed": { "XAF": 500 }, "delay": "1-2 business days" }
  }
}
```

**Fee:** `round(amount × feePercent / 100) + feeFixed`, capped at `feeMax`. The app shows it only as an **estimate**; the binding fee is the server's (step 1). A `mobile_money` channel without operators, or a `bank` channel without banks, is not offered. Required: "Transfers are not available yet" when there is no valid currency, no source method, or no usable channel.

### 15.2 `money_transfers/{transferId}`

```jsonc
{
  "senderId": "<uid>", "senderName": "...", "recipientId": "<uid, internal only>",
  "participantIds": ["<senderId>", "<recipientId if internal>"],    // the app lists where participantIds contains the user
  "channel": "internal | mobile_money | wave | bank",
  "recipient": { "email" | "phone" | "operator" + "number" | "bankCode" + "bankName" + "accountMasked" + "holderName" },
  "recipientName": "...", "recipientVerified": true,               // the name the server / provider verified
  "currency": "XAF", "amount": 10000, "fee": 150, "total": 10150, "receiveAmount": 10000,
  "note": "...", "status": "...", "reason": "...", "reference": "SPT-...", "providerReference": "...",
  "expiresAt": "<ts>", "createdAt": "<ts>", "completedAt": "<ts>"
}
```

- **Never store a full bank account number in this readable document**: keep `accountMasked` (e.g. `•••• 6789`) and hold the full number server-side.
- An internal recipient sees the transfer (via `participantIds`), its `senderName`, `receiveAmount` and the note. It never sees the sender's fee or payment method.

**`transfer_beneficiaries/{id}`**: `{ userId, channel, displayName, detail (masked), recipient (as sent by the app, for re-use), lastUsedAt }`. Saved by the server when `saveBeneficiary` is true.

### 15.3 Transfer callables

| Function | Request | Server checks |
|---|---|---|
| `transferCreate` | `{ channel, amount, currency, recipient, note?, saveBeneficiary }` -> `{ transferId }` | KYC-verified; channel enabled; min / max / daily limits (`daily_limit_exceeded`); **recipient validation**: an existing active Spideli user for `internal` (`recipient_not_found`), never the sender (`self_transfer`), and a name lookup at the operator / bank where available (`recipient_invalid`); compute the fee; `awaiting_confirmation` |
| `transferConfirm` | `{ transferId, payment, idempotencyKey }` -> payment reply (section 8.4) | the sender; `awaiting_confirmation` and before `expiresAt` (`request_expired`); `auth_time` when ≥ `reauthAbove`; balance check for `wallet`; then `pending` → `processing` |
| `transferCancel` | `{ transferId }` | the sender; `awaiting_confirmation` / `pending` only |
| `transferDeleteBeneficiary` | `{ beneficiaryId }` | the owner |

**Internal transfers:** debit the sender and credit the recipient **in one Firestore transaction on the ledger** (both accounts, section 4.2), so they are atomic. External channels follow the state machine above.

### 15.4 Bills: `platform_settings/bills` and `utility_billers`

```jsonc
// platform_settings/bills
{ "currencies": ["XAF"], "categories": ["electricity", "water", "tv", "internet", "phone"],
  "paymentMethods": ["wallet", "mobile_money", "wave"], "security": { "reauthAbove": { "XAF": 100000 } } }
```

**`utility_billers/{billerId}`** (the app lists `published == true` per `category`):
- `{ name, category, country, currency, order, accountLabel ("Contract number"), accountHint, accountPattern (a regex; the app anchors it), amountType, lookup, partialPayment, packages, min, max, feePercent, feeFixed, feeMax }`;
- `amountType`:
  - `due`: the amount owed comes from a **lookup**; paid in full unless `partialPayment`;
  - `open`: any amount within `min`..`max`, e.g. prepaid electricity;
  - `packages`: one of `packages: [{ code, name, amount }]`, e.g. TV bouquets.
- `lookup: true` makes the app check the account before showing the amount.

**`utility_payment_requests/{requestId}`**:
- `{ userId, billerId, billerName, category, account, customerName, packageCode, packageName, currency, amount, fee, total, status, reason, reference, billerReference, token, tokenLabel, units, expiresAt, createdAt, completedAt }`;
- the same states as transfers;
- `token` is the prepaid code the biller returns (e.g. a 20-digit electricity token): the app shows it large with a copy button, and on the receipt.

**`utility_payment_transactions/{id}`** (server-only, not read by the app): every attempt with the biller or aggregator, raw responses, retries.

**`utility_saved_accounts/{id}`**: `{ userId, billerId, billerName, category, account, nickname, lastUsedAt }`, saved when `saveAccount` is true.

| Function | Request | Server checks |
|---|---|---|
| `billLookup` | `{ billerId, account }` -> `{ lookupId, customerName, amountDue, dueDate }` | KYC-verified; account format; ask the biller (`account_not_found`, `biller_unavailable`) |
| `billCreatePayment` | `{ billerId, account, amount, packageCode?, lookupId?, saveAccount }` -> `{ requestId }` | the amount rule of the biller (due / open / packages); a fresh `lookupId` for `due`; compute the fee; `awaiting_confirmation` |
| `billConfirmPayment` | `{ requestId, payment, idempotencyKey }` -> payment reply | owner; before `expiresAt`; `auth_time` when ≥ `reauthAbove`; pay the biller **only after the user's payment is confirmed**; on a biller failure, **refund** (`reversed`) |
| `billCancelPayment` | `{ requestId }` | owner; `awaiting_confirmation` / `pending` |
| `billDeleteSavedAccount` | `{ savedAccountId }` | owner |

App queries (with indexes):

```
money_transfers          where participantIds array-contains <uid> orderBy createdAt desc limit 50 -> (participantIds CONTAINS, createdAt DESC)
transfer_beneficiaries   where userId == <uid> orderBy lastUsedAt desc limit 20                    -> (userId ASC, lastUsedAt DESC)
utility_billers          where published == true and category == X limit 100                        -> equality only
utility_saved_accounts   where userId == <uid> orderBy lastUsedAt desc limit 20                    -> (userId ASC, lastUsedAt DESC)
utility_payment_requests where userId == <uid> orderBy createdAt desc limit 50                     -> (userId ASC, createdAt DESC)
money_transfers/{id}, utility_payment_requests/{id}, utility_billers/{id}: single documents
```

Rules:
- `money_transfers`: readable when `request.auth.uid in resource.data.participantIds`;
- beneficiaries, saved accounts, bill payments: owner only;
- published billers and both configs: signed-in users;
- `utility_payment_transactions`: staff only;
- **no client writes**.

Reasons the app maps (`FinanceErrors`): `recipient_not_found`, `recipient_invalid`, `self_transfer`, `daily_limit_exceeded`, `request_expired`, `biller_unavailable`, `account_not_found`, `provider_unavailable`, `reauth_required`, `insufficient_funds`, `amount_out_of_range`.

**Receipts:** the app builds the PDF receipt from the **server's** document (reference, dates, parties, amounts, fee, token). Also email it, or keep a server-rendered copy, if receipts must be legally binding.

### 15.5 Jobs and notifications (SERVER)

**Jobs:**
- expire unconfirmed requests;
- poll or receive provider and biller callbacks (verify signatures);
- reconcile daily;
- refund failures (`reversed`);
- post every movement to the ledger;
- update `finance_summaries/{uid}.payments.last30Days` (`transfers`, `billPayments`).

**Templates** (`dynamic_notification`, `source: "finance"`):

| Template `type` | To | Placeholders |
|---|---|---|
| `transfer_sent` | sender | `{amount}`, `{recipientName}` |
| `transfer_received` | internal recipient | `{amount}`, `{senderName}` |
| `transfer_failed` | sender | `{amount}`, `{recipientName}`, `{reason}` |
| `transfer_reversed` | sender | `{amount}`, `{recipientName}` |
| `bill_paid` | user | `{amount}`, `{billerName}`, `{account}` |
| `bill_token` | user | `{billerName}`, `{token}` |
| `bill_failed` | user | `{amount}`, `{billerName}`, `{reason}` |
| `bill_reversed` | user | `{amount}`, `{billerName}` |
