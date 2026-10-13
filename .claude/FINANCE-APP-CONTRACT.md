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
