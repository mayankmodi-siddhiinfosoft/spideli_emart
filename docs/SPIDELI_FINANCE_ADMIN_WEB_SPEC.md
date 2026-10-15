# Spideli Finance — Admin Panel Specification

`SPIDELI_FINANCE_ADMIN_WEB_SPEC.md` · version 1.0 · 15 October 2026

**For:** the developer of the Spideli Finance **admin panel** (PHP).
**Companion document:** `SPIDELI_FINANCE_CUSTOMER_WEB_SPEC.md` (the customer website, built by another developer at the same time).
**Supersedes:** `docs/FINANCE-ADMIN-PHP-SPEC.md` and the admin side of `docs/FINANCE-FLOW.md`.

## How to use this document

- **One Firebase architecture, no separate backend.** The admin panel, the customer website and the Flutter customer app all read and write the **same** Firestore collections, documents and fields, described once in sections 1–4. The panel uses the Firebase **Admin SDK** (`kreait/firebase-php`) on that same project and database. There is no finance API between the panel and the customers: the panel processes the customers' request documents where they are, and the customers see each decision live.
- **The Admin SDK bypasses the security rules.** Every validation, permission and invariant listed here must be coded in the panel, server side, and every multi-document change must run in one Firestore transaction (5.1, 5.2). The customer rules (Appendix R) tell you exactly what the customers may write and which admin-owned fields they depend on (R.14.4).
- **Customers write their requests; the admin decides.** Statuses that mean approved, paid out, executed, activated or verified are written only by the panel (1.2). For each queue, section 6 gives the query, the preconditions to re-check in the transaction, the exact writes, the notification template and the audit entry.
- **Do not change the data model.** No new collection, field, status or id format without agreement with the customer-website developer and an update of the rules and of both documents. Admin-only additions are listed in 3.14 (for example `admin_audit_logs`, `support_tickets`, `reconciliations`, `virtual_cards_private`).

| Sections | Content | Shared with the customer specification |
|---|---|---|
| 1–4 | Platform foundation, settings, data model, money movement | yes, identical |
| 5 | Panel architecture: stack, posting helper, roles, notifications | no |
| 6 | Every admin feature: dashboard, settings, users, KYC, payments, cards, savings, tontines, loans, funds, insurance, financing, content, templates, tickets, reports, security, audit | no |
| 7–8 | Scheduled jobs, acceptance and go-live checklist | no |
| Appendix R | Security rules reference | yes, identical |

## Contents

- [1. Platform foundation (shared by both specifications)](#1-platform-foundation-shared-by-both-specifications)
  - [1.1 Firebase project and services](#11-firebase-project-and-services)
  - [1.2 Who writes what](#12-who-writes-what)
  - [1.3 Conventions](#13-conventions)
  - [1.4 Roles of a customer inside Finance](#14-roles-of-a-customer-inside-finance)
  - [1.5 Entry point and service list](#15-entry-point-and-service-list)
  - [1.6 Push notifications (one contract for every client)](#16-push-notifications-one-contract-for-every-client)
- [2. Settings (configuration documents)](#2-settings-configuration-documents)
  - [2.1 `platform_settings/kyc`](#21-platform_settingskyc)
  - [2.2 `platform_settings/wallet`](#22-platform_settingswallet)
  - [2.3 `platform_settings/transfers`](#23-platform_settingstransfers)
  - [2.4 `platform_settings/bills`](#24-platform_settingsbills)
  - [2.5 `platform_settings/cards`](#25-platform_settingscards)
  - [2.6 `platform_settings/savings`](#26-platform_settingssavings)
  - [2.7 `platform_settings/tontines`](#27-platform_settingstontines)
  - [2.8 `platform_settings/lending`](#28-platform_settingslending)
  - [2.9 `platform_settings/investments`](#29-platform_settingsinvestments)
  - [2.10 `platform_settings/insurance`](#210-platform_settingsinsurance)
  - [2.11 `platform_settings/financing`](#211-platform_settingsfinancing)
  - [2.12 `platform_settings/intelligence`](#212-platform_settingsintelligence)
  - [2.13 Other settings read by Finance](#213-other-settings-read-by-finance)
- [3. Unified data model (Firestore collections)](#3-unified-data-model-firestore-collections)
  - [3.1 Users](#31-users)
  - [3.2 Money](#32-money)
  - [3.3 Identity verification (KYC)](#33-identity-verification-kyc)
  - [3.4 Transfers and bills](#34-transfers-and-bills)
  - [3.5 Virtual cards](#35-virtual-cards)
  - [3.6 Collective savings](#36-collective-savings)
  - [3.7 Tontines](#37-tontines)
  - [3.8 Member loans](#38-member-loans)
  - [3.9 Investments](#39-investments)
  - [3.10 Insurance](#310-insurance)
  - [3.11 Project financing](#311-project-financing)
  - [3.12 Markets, intelligence and opportunities](#312-markets-intelligence-and-opportunities)
  - [3.13 Finance chat](#313-finance-chat)
  - [3.14 Admin-only collections](#314-admin-only-collections)
  - [3.15 AI coach (disabled)](#315-ai-coach-disabled)
  - [3.16 Storage paths](#316-storage-paths)
- [4. Money movement, payments and integrity (shared)](#4-money-movement-payments-and-integrity-shared)
  - [4.1 Double-entry postings](#41-double-entry-postings)
  - [4.2 Posting types](#42-posting-types)
  - [4.3 Who may debit which account](#43-who-may-debit-which-account)
  - [4.4 Account creation](#44-account-creation)
  - [4.5 Paying: the wallet or a payment gateway](#45-paying-the-wallet-or-a-payment-gateway)
  - [4.6 Never paying twice](#46-never-paying-twice)
  - [4.7 Re-authentication](#47-re-authentication)
  - [4.8 Restrictions (blacklist)](#48-restrictions-blacklist)
  - [4.9 Error reasons](#49-error-reasons)
- [5. Admin panel: architecture](#5-admin-panel-architecture)
  - [5.1 Stack and Firebase access](#51-stack-and-firebase-access)
  - [5.2 Posting helper (PHP pseudo-code)](#52-posting-helper-php-pseudo-code)
  - [5.3 Admin identity and roles (RBAC)](#53-admin-identity-and-roles-rbac)
  - [5.4 Sending notifications](#54-sending-notifications)
- [6. Admin features](#6-admin-features)
  - [6.1 Dashboard (home of the panel)](#61-dashboard-home-of-the-panel)
  - [6.2 Settings management](#62-settings-management)
  - [6.3 User management](#63-user-management)
  - [6.4 KYC management](#64-kyc-management)
  - [6.5 Payment management](#65-payment-management)
  - [6.6 Card management (with the issuer)](#66-card-management-with-the-issuer)
  - [6.7 Collective savings management](#67-collective-savings-management)
  - [6.8 Tontine management](#68-tontine-management)
  - [6.9 Loan management](#69-loan-management)
  - [6.10 Fund management (investments)](#610-fund-management-investments)
  - [6.11 Insurance management](#611-insurance-management)
  - [6.12 Financing review (project owners)](#612-financing-review-project-owners)
  - [6.13 Content: opportunities, markets, indicators, billers](#613-content-opportunities-markets-indicators-billers)
  - [6.14 Notifications and templates](#614-notifications-and-templates)
  - [6.15 Incident management (complaints, support, tickets)](#615-incident-management-complaints-support-tickets)
  - [6.16 Reporting](#616-reporting)
  - [6.17 Security and data protection](#617-security-and-data-protection)
  - [6.18 Audit (complete logging, traceability)](#618-audit-complete-logging-traceability)
- [7. Scheduled jobs (cron)](#7-scheduled-jobs-cron)
- [8. Acceptance criteria and go-live checklist](#8-acceptance-criteria-and-go-live-checklist)
- [Appendix R. Security rules reference (shared)](#appendix-r-security-rules-reference-shared)
  - [R.0 Global conventions (apply everywhere)](#r0-global-conventions-apply-everywhere)
  - [R.1 Helpers (L44-105, L1182-1239)](#r1-helpers-l44-105-l1182-1239)
  - [R.2 `users/{uid}` finance fields (L480-530; identityKeys L292-294; identitySame L387-395)](#r2-usersuid-finance-fields-l480-530-identitykeys-l292-294-identitysame-l387-395)
  - [R.3 Ledger core](#r3-ledger-core)
  - [R.4 Wallet operations: `wallet_operations/{opId}` (L1544-1631)](#r4-wallet-operations-wallet_operationsopid-l1544-1631)
  - [R.5 Transfers and bills](#r5-transfers-and-bills)
  - [R.6 Virtual cards (L1737-1856)](#r6-virtual-cards-l1737-1856)
  - [R.7 Savings (L1858-1988)](#r7-savings-l1858-1988)
  - [R.8 Tontines (L1990-2214)](#r8-tontines-l1990-2214)
  - [R.9 Member loans (L2216-2465)](#r9-member-loans-l2216-2465)
  - [R.10 Investments (L2467-2519)](#r10-investments-l2467-2519)
  - [R.11 Insurance (L2521-2670)](#r11-insurance-l2521-2670)
  - [R.12 Project financing (L2672-2754)](#r12-project-financing-l2672-2754)
  - [R.13 Intelligence, coach, chat, KYC, admin-written records](#r13-intelligence-coach-chat-kyc-admin-written-records)
  - [R.14 Cross-cutting lists](#r14-cross-cutting-lists)

---

## 1. Platform foundation (shared by both specifications)

> Sections 1–4 and Appendix R are **identical** in `SPIDELI_FINANCE_CUSTOMER_WEB_SPEC.md` and `SPIDELI_FINANCE_ADMIN_WEB_SPEC.md`. They define the one Firebase architecture of Spideli Finance. The Flutter customer app (`customer/`) already implements the customer side on it; the customer website and the admin panel must use it unchanged.

### 1.1 Firebase project and services

| Item | Value |
|---|---|
| Firebase project | `spideli-870b0` |
| Database | Cloud Firestore, `(default)` database |
| Authentication | Firebase Authentication: email + password, phone (SMS OTP), Google, Apple, LinkedIn (OpenID Connect provider `oidc.linkedin`, when enabled). Two-step verification = Firebase multi-factor (SMS second factor; requires Identity Platform). |
| File storage | Cloud Storage for Firebase, default bucket |
| App Check | enabled on the mobile apps; the website registers a reCAPTCHA Enterprise provider |
| Push | Firebase Cloud Messaging; texts come from `dynamic_notification` templates |
| Server code | **none for finance** (no Cloud Functions). Customers write directly to Firestore under the security rules; the admin panel (Firebase Admin SDK) does every step that needs a person or a partner. |

### 1.2 Who writes what

| Actor | Client | How it writes | Identified in the rules by |
|---|---|---|---|
| **Customer** | mobile app, **customer website** | Firebase client SDK; every write is checked by the Firestore security rules (finance block of `firestore.rules.draft`) | `request.auth.uid` |
| **Admin** | **admin panel** (PHP, Firebase Admin SDK with a service account) | bypasses the security rules; must validate everything itself and write atomically | — (Admin SDK) |
| Admin in a client SDK (optional) | admin tools built on a client SDK | checked by the rules | custom claim `admin: true` **or** `users/{uid}.role == "admin"` (`isAdmin()`) |

**Golden rule:** the customer clients write only the customer's own requests and the customer's own money movements, in the exact shapes of this document. Statuses that mean "approved", "paid out", "executed", "activated", "verified" are written **only** by the admin.

### 1.3 Conventions

- **Amounts** are **integers in minor units** of their currency, everywhere (documents, ledger, settings). Currency exponents: `XAF`, `XOF`, `GNF`, `RWF` = 0 decimals (1 500 XAF = `1500`); `USD`, `EUR`, `GBP`, `NGN`, `GHS`, `KES` and every other finance currency = 2 decimals (12.50 USD = `1250`). The conversion rule (4.1, Appendix R) uses exactly this table, so do not offer another zero-decimal currency (such as `JPY`) in finance settings. A gateway may expect a different unit when charging (Stripe's zero-decimal list); convert at the gateway call only. Display: thousands separated by a space, the currency code after (`245 000 XAF`, `12.50 USD`).
- **Currencies:** ISO 4217 codes, upper case, 3 letters. **Countries:** ISO 3166-1 alpha-2 (`CM`, `GA`, `GN`, `CI`, `SN`, `RW`).
- **Timestamps:** Firestore `Timestamp`. Every `createdAt` / `updatedAt` / `…At` written by a customer is `serverTimestamp()` (the rules require `== request.time`). Dates entered by users (deadline, start date, date of birth, incident date) are `Timestamp` at local midnight unless stated as a `"yyyy-MM-dd"` string.
- **Ids:** where this document gives a pattern (`wallet_{uid}_{CUR}`, `{tontineId}_{uid}`), it is mandatory. Elsewhere the client generates the id: a **request key** `"{epochMillis}-{12 random base36 chars}"` (one per user intent, kept until the write succeeds — see 4.6), or a Firestore auto-id when stated.
- **Statuses** are lower-case snake_case strings from the lists in section 3. Unknown statuses are displayed humanized ("payout_pending" → "Payout pending").
- **Text:** UI languages English and Arabic (right-to-left); every label goes through the translation files; amounts, references and phone numbers are always shown left-to-right.
- **References** shown to users: `SPF-yyMMdd-XXXXXX` (6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`).
- **Booleans** never stored as strings; absent optional fields are omitted (not `null`) unless this document says `null`.

### 1.4 Roles of a customer inside Finance

A customer can at the same time be: wallet holder, sender / recipient of transfers, bill payer, card holder, savings goal owner or member, tontine admin or member, borrower, voter, lender, investor, policyholder, project owner, opportunity investor, chat participant. Group roles come from the documents (`savings_goals.ownerId`, `tontines.adminIds`, `loan_applications.eligibleVoterIds`, …), never from a global role.

### 1.5 Entry point and service list

Finance appears in the customer's service list either as the admin's own section (`sections/{id}` with `serviceTypeFlag: "finance-service"`, its name, image, colour and order) or, without one, as a built-in **Spideli Finance** entry (id `spideli-finance`, navy `#0B2A4A`, wallet icon). Opening it never changes the selected store section (taxes, theme).

### 1.6 Push notifications (one contract for every client)

**Texts.** Every push and Notification Center record uses a `dynamic_notification` template: `{ type, subject (title), message (body with {placeholders}), … }`, looked up by `type`. A client never hard-codes the wording.

**Credentials.** No browser, phone or website ever holds FCM or Admin SDK credentials. The apps' current `settings/notification_setting.serviceJson` (the URL of a service-account key that the apps download) is a **known security issue** and must be retired. The replacement is a push **relay**, switched on by `settings/notification_setting.serverPushUrl` (an `https://` URL, written by an admin only):

| `serverPushUrl` | Clients |
|---|---|
| a valid `https://` URL with a host | POST every push to the relay; never touch `serviceJson`; no fallback when the relay fails |
| absent or empty | the mobile apps keep their legacy path; **the customer website sends no pushes** (the admin panel notifies for its own decisions) |

**Relay contract** (host it in the admin panel with the Admin SDK `Messaging`, or as a Cloud Function: the contract is the same):

- **Request:** `POST {serverPushUrl}`, headers `Authorization: Bearer <Firebase ID token of the signed-in user>`, `Content-Type: application/json`, body ≤ 16 KB:
  `{ token: <recipient FCM token>, title, body, data: { type, …ids }, kind: <template type>, android: { channelId, sound }, apns: { sound } }`.
  For a customer recipient: `android.channelId = "high_importance_channel"`, sounds `"default"`.
- **Checks:**
  - verify the ID token (refuse anonymous and disabled accounts; the caller must have a `users/{uid}` document);
  - exactly one of `token` / `topic`; `topic` only for callers with `users/{uid}.role == "admin"`; token 32–4096 characters of `[A-Za-z0-9_\-:.]`;
  - at least one of `title`, `body`, non-empty `data`;
  - clip `title` to 200 and `body` to 1000 characters (report it in `truncated`);
  - convert `data` values to strings (objects and arrays JSON-encoded, `null` drops the key); drop the reserved keys `from`, `notification`, `message_type`, `collapse_key`, `google*`, `gcm*`; data over 4096 bytes → 413;
  - limit each account to 60 sends per rolling minute and 3 000 per UTC day (`push_rate_limits/{uid}`, server only).
- **FCM message:** `{ token, notification: { title, body }, data, android: { priority: "high", notification: { channel_id, sound } }, apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound, "content-available": 1 } } } }`.
- **Responses** (JSON, `Cache-Control: no-store`): `200 { ok: true, messageId }`; errors `{ ok: false, error, message }`, with status 400 `invalid_argument` / `invalid_token`, 401 `unauthenticated` / `invalid_id_token` / `id_token_expired` (the client refreshes the token and retries **once**), 403 `user_not_found` / `user_disabled` / `topic_forbidden`, 404 `unregistered` (dead token: the relay sets `fcmToken: ""` on the profiles holding it; the client does not retry), 413 `payload_too_large`, 429 `rate_limited` (with `Retry-After`), 5xx `internal` / `unavailable` (one retry at most).
- **Logging:** the uid, `kind`, a short hash of the token, lengths and key names only. Never a token, a title, a body or a data value.

**Notification Center** (in-app list): `users/{uid}/notifications/{id} = { type, title, body, category: "account", source: "finance", read: false, createdAt, data }`, written by the admin panel.

## 2. Settings (configuration documents)

Written **only by the admin**; read by every signed-in customer (never put a secret in them). A **missing or invalid** settings document makes the matching module show "… is not available yet" — the customer clients never invent defaults for missing required fields. Money values are per-currency maps of minor units: `{ "XAF": 1000, "EUR": 150 }`.

### 2.1 `platform_settings/kyc`

| Field | Type | Required | Meaning |
|---|---|---|---|
| `documentTypes` | map: type → `{ sides: ["front", "back"] }` | yes | the documents that can be uploaded and their sides. Known types: `national_id`, `passport`, `selfie`, `proof_of_address`, `business_registration` (others shown humanized) |
| `levels` | map: level → `{ accountTypes: ["individual" \| "business"], requiredDocuments: [ { anyOf: [type, …] }, … ] }` | yes | verification levels (`basic`, `full`, `business`, …). A requirement group is met when **one** of its types has every side uploaded or accepted |
| `allowedContentTypes` | string[] | **yes**, non-empty, must include `image/jpeg` (every KYC upload is a JPEG) | `image/jpeg`, `image/png`, `image/webp`, `application/pdf` |
| `maxFileBytes` | int | yes (> 0) | e.g. `10485760` |

### 2.2 `platform_settings/wallet`

| Field | Type | Meaning |
|---|---|---|
| `currencies` | string[] (required, ≥ 1) | wallet currencies |
| `deposit.enabled` | bool | "Add money" offered |
| `deposit.methods` | string[] of `mobile_money`, `wave`, `card`, `paypal` | how money can be added (default all four) |
| `deposit.min` / `deposit.max` | per-currency int | limits of one deposit |
| `withdraw.enabled` | bool | "Withdraw" offered |
| `withdraw.methods` | string[] of `mobile_money`, `wave`, `bank` | where money can be withdrawn |
| `withdraw.min` / `withdraw.max` | per-currency int | limits |
| `withdraw.feePercent` | number 0-100 | fee = round(amount × % / 100) + `feeFixed[CUR]`, capped at `feeMax[CUR]` |
| `withdraw.feeFixed` / `withdraw.feeMax` | per-currency int | — |
| `withdraw.delay` | string | shown to users ("Within 24 hours") |
| `convert.enabled` | bool | currency conversion offered (needs ≥ 2 currencies) |
| `convert.currencies` | string[] | convertible currencies |
| `convert.feePercent` | number 0-100 | conversion fee |
| `convert.maxRateAgeHours` | int (default 48) | an exchange rate older than this is refused |
| `security.reauthAbove` | per-currency int | re-authentication from this amount; **a currency without a value = always** |

### 2.3 `platform_settings/transfers`

| Field | Type | Meaning |
|---|---|---|
| `currencies` | string[] (required) | — |
| `sourceMethods` | string[] (required): `wallet`, `mobile_money`, `wave`, `card`, `paypal` | what may pay a transfer |
| `security.reauthAbove` | per-currency int | re-authentication from this amount (missing currency = always) |
| `channels.internal` / `.mobile_money` / `.wave` / `.bank` | map | a channel is offered only with `enabled: true` |
| `channels.*.feePercent`, `feeFixed`, `feeMax`, `min`, `max`, `delay` | number / per-currency int / string | fee = round(amount × % / 100) + fixed, capped at max |
| `channels.mobile_money.operators` | string[] | e.g. `"MTN Mobile Money"`, `"Orange Money"` (channel hidden without operators) |
| `channels.bank.banks` | `[{ code, name }]` | channel hidden without banks |

### 2.4 `platform_settings/bills`

`currencies` (string[], required), `categories` (string[], required: `electricity`, `water`, `tv`, `internet`, `phone`, `gas`, `education`, `taxes`, `products`, `other`), `paymentMethods` (string[], required), `security.reauthAbove` (per-currency int, compared with the **total**; **a currency without a value = always**, as for wallet and transfers). The document must exist, even with only this field.

### 2.5 `platform_settings/cards`

| Field | Type | Meaning |
|---|---|---|
| `currencies`, `fundingMethods` | string[] (required) | — |
| `issuerName`, `network` (`visa` default) | string | shown on the card |
| `maxCardsPerUser` | int 1-10 | cards in `requested` / `active` / `frozen` |
| `issuanceFee`, `monthlyFee`, `renewalFee` | per-currency int | monthly fee is display only (charged by the admin) |
| `minFunding`, `maxFunding` | per-currency int | top-up limits |
| `fundingFeePercent` | number 0-100 | added on top of the top-up |
| `limits.maxPerTransaction`, `limits.maxDaily`, `limits.maxMonthly` | per-currency int | ceilings of the user's own limits |
| `capabilities.withdraw`, `.renew`, `.cardTransfer`, `.onlineToggle`, `.internationalToggle` | bool | what the issuer supports |
| `capabilities.secureDetails` | `"hosted"` \| `"direct"` \| `"none"` | how the card number / CVV can be shown (`none` until an issuer page exists) |
| `terms`, `termsVersion` | string, int ≥ 1 (**required**) | cardholder agreement; the module stays hidden without them |

### 2.6 `platform_settings/savings`

`purposes` (string[], required: `real_estate`, `education`, `travel`, `healthcare`, `business`, `other`), `currencies` (required), `frequencies` (`weekly`, `biweekly`, `monthly`), `groupGoals` (bool), `maxMembers` (int ≥ 2), `earlyWithdrawal.allowed` (bool), `paymentMethods` (required).

### 2.7 `platform_settings/tontines`

`currencies`, `frequencies`, `paymentMethods` (all required), `minMembers` (int ≥ 2), `maxMembers` (int ≥ `minMembers`), `payoutOrderMethods` (**required**, at least `["fixed"]`; values `fixed`, `random`. The rules have no default: without it every tontine creation is refused), `minContribution` (per-currency int, default 1).

### 2.8 `platform_settings/lending`

| Field | Type | Meaning |
|---|---|---|
| `currencies`, `durationsMonths` (int[]), `repaymentFrequencies` (`weekly`, `biweekly`, `monthly`), `paymentMethods` | required | — |
| `minAmount`, `maxAmount` | per-currency int | request limits |
| `purposes` | string[] | default `["other"]` |
| `interest.method` (**required**) | `"flat"` \| `"declining"` | flat: interest on the principal; declining: annuity on the remaining balance |
| `interest.annualPercent` | number | e.g. `12` |
| `feePercent` | number 0-100 | taken from the disbursement |
| `latePenaltyPercent` | number 0-100 | applied by the admin on overdue instalments |
| `voting.quorumPercent`, `voting.approvalPercent` (**required**) | int 1-100 | quorum: `cast × 100 ≥ eligible × quorum`; approval: `yes × 100 ≥ cast × approval`. The rules default both to 101, so without them **every vote fails** |
| `voting.durationHours` (**required**) | int ≥ 1 | the admin sets `votingEndsAt = opening + durationHours` |
| `agreementTerms` | string | the agreement text the borrower accepts |

### 2.9 `platform_settings/investments`

`currencies`, `paymentMethods` (required), `assetClasses` (filter order: `money_market`, `bonds`, `equities`, `real_estate`, `agriculture`, `infrastructure`, `mixed`), `riskDisclosure` (string, **required**: shown and accepted before every subscription), `simulator.maxYears` (int 1-50, default 30).

### 2.10 `platform_settings/insurance`

`currencies`, `categories` (`health`, `life`, `auto`, `home`, `travel`, `business`, `agriculture`, `device`, `funeral`), `paymentMethods` (all required), `claims.maxFiles` (int 1-20, default 5).

### 2.11 `platform_settings/financing`

`currencies` (required), `financingTypes` (required: `loan`, `equity`, `grant`, `guarantee`, `mixed`), `sectors` (**required**), `stages`, `documentTypes` (required), `requiredDocuments` (each a type string, or `{ type, financingTypes: [...] }` to require it only for those types), `minAmount`, `maxAmount` (per-currency int), `durationsMonths` (asked for `loan` and `mixed`), `allowedContentTypes` (**required**, e.g. `application/pdf`, `image/jpeg`, `image/png`), `maxFileBytes` (**required**, > 0, ≤ 50 MB). The rules default the last three to empty / 0, so without them every project and every upload is refused.

### 2.12 `platform_settings/intelligence`

| Part | Fields | Offered when |
|---|---|---|
| `indicators` | `enabled`, `countries` (ISO-2, display order) | enabled and ≥ 1 country |
| `exchangeRates` | `enabled`, `base` (ISO-3), `quotes` (ISO-3[]) | enabled, a base and ≥ 1 quote |
| `matching` | `enabled`, `currencies`, `sectors`, `types` (`equity`, `loan`, `revenue_share`, `fund`), `countries`, `weights {sector, country, type, ticket, horizon}`, `minScore` (0-100), `eligibility` (text) | enabled |
| `markets` | `enabled`, `stocks`, `bonds`, `ipos`, `collections`, `news` (bools) | enabled; each part when `true` |
| `coach` | `enabled` (**false** until an AI server exists), `consentVersion`, `consentText`, `topics`, `maxMessageLength` | enabled, version ≥ 1, text |

### 2.13 Other settings read by Finance

- `settings/authProviders`: `{ linkedin: bool, linkedinProviderId: "oidc.linkedin", facebook: bool }` (sign-in buttons; readable signed out).
- **Payment gateways** (existing documents, also used by the shopping wallet), each with its keys and `regionIds` (the customer regions where it is offered): `settings/stripeSettings`, `settings/paypalSettings`, `settings/flutterWave`, `settings/payStack`, `settings/orange_money_settings`, `settings/MercadoPago`, `settings/xendit_settings`, `settings/midtrans_settings`, `settings/payFastSettings`, `settings/razorpaySettings`. **Secret keys must never be in these documents for the website**: a web checkout needs only publishable keys; secrets stay in the admin panel's server configuration.
- `sections/{id}` with `serviceTypeFlag: "finance-service"` (optional, see 1.5).
- `dynamic_notification/{id}`: `{ type, title, message, … }` templates (placeholders `{amount}` …).

## 3. Unified data model (Firestore collections)

Legend for **Set by**: **C** = customer client (website or app) under the rules; **A** = admin panel; **C+A** = created by the customer, completed by the admin. `ts` = `Timestamp`. Every customer-created document carries `id` (= its document id) unless stated, and `createdAt` (+ `updatedAt` where updated) as `serverTimestamp()`.

### 3.1 Users

**`users/{uid}`** (existing collection; finance uses these fields)

| Field | Type | Set by | Notes |
|---|---|---|---|
| `id`, `firstName`, `lastName`, `email`, `phoneNumber`, `countryCode`, `profilePictureURL`, `fcmToken`, `role`, `active` | — | C (sign-up / profile) | `role` is never `admin` from a client |
| `kycLevel` | string | **A only** | set on KYC approval (e.g. `basic`); **non-empty = identity verified** (unlocks money features) |
| `kycStatus` | string | **A only** | mirror of the latest application status (clients show the latest application instead) |
| `financeRestriction` | `{ status: "restricted", reason, since: ts, scopes: string[], by }` | **A only** | the blacklist; scopes `loans`, `tontines`, `savings`, `transfers`, `payments`, `wallet`, `all` (empty / missing scopes = all) |
| `financeNotificationPrefs` | `{ push: {…}, sms: {…}, email: {…} }`, each `{ payments, groups, loans, investments, insurance, news }` booleans | C (own) | defaults when absent: push all on; SMS payments only; e-mail payments only. Security notices always sent |
| `savedPaymentMethods` | array of `{ id, type: "mobile_money" \| "wave" \| "bank", operator?, number, label?, isDefault, regionId?, bankName?, bankCode?, holderName? }` | C (own) | Mobile Money operators: `Orange Money`, `MTN Mobile Money`, `Moov Money`, `Airtel Money`, `Other`; `bank`: `number` = account number / IBAN, never the default checkout method |

**`users/{uid}/notifications/{id}`**: Notification Center records `{ type, title, body, category: "account", source: "finance", read: false, createdAt, data }` — finance records are written **only by the admin** (a client may never write `source: "finance"`).

### 3.2 Money

**`financial_accounts/{accountId}`**

| Field | Type | Notes |
|---|---|---|
| `id` | string | = document id |
| `kind` | `wallet` \| `savings_goal` \| `tontine_pot` \| `loan` \| `platform` | |
| `userId` | uid | wallets only |
| `refId` | string | pools: the goal / tontine / loan id |
| `memberIds` | uid[] | savings goal pool (read access) |
| `currency` | ISO-3 | |
| `balance` | int (minor) | never < 0 except `platform` |
| `normalSide` | `"credit"` | |
| `status` | `"active"` | |
| `lastTxId` | string | the posting that last changed `balance` |
| `createdAt`, `updatedAt` | ts | |

Account ids: wallet `wallet_{uid}_{CUR}` (an older active wallet of the user in that currency keeps its own id); savings goal `goal_{goalId}`; tontine pot `tontine_{tontineId}`; loan escrow `loan_{loanId}`; Spideli clearing `platform_{CUR}` (**created by the admin before go-live, one per currency**).

**`ledger_transactions/{txId}`** — immutable postings (section 4).

| Field | Type | Notes |
|---|---|---|
| `id` | `tx_{epochMillis}_{8 chars}` | |
| `type` | string | see 4.2 |
| `status` | `posted` \| `reversed` | `reversed` only by the admin |
| `reference` | `SPF-…` | |
| `currency` | ISO-3 | |
| `lines` | `[{ accountId, direction: "debit" \| "credit", amount }]` | 2 or 3 lines |
| `userIds` | uid[] | wallet owners involved (+ the caller) |
| `accountIds` | string[] | the lines' accounts, in order |
| `source` | `{ kind, id }` | the request document (collection name, id) |
| `funding` | `wallet` \| `gateway` | |
| `gateway` | `{ method, reference }` | gateway funding only |
| `description` | string | |
| `reversalOf` | txId | reversals (admin) |
| `reversedBy`, `reversedAt` | txId[], ts | on the original, set by the admin's `reverse()` |
| `createdBy` | uid or `admin:{adminId}` | |
| `createdAt` | ts | `== request.time` |

**`wallet_operations/{id}`** — deposits, withdrawals, conversions (C+A)

| Field | Type | Notes |
|---|---|---|
| `id`, `userId`, `type` | — | `type`: `deposit` \| `withdrawal` \| `conversion` |
| `status` | `completed` (deposit, conversion), `pending` → `completed` \| `failed` \| `reversed` (withdrawal) | |
| `currency`, `amount`, `fee`, `total`, `accountId` | | `amount` = what the user receives (withdrawal) / adds; `total` = what left or entered the wallet |
| `gateway` | `{ method, reference }` | deposit |
| `purpose` | `{ kind, id }` | deposit made as the first step of another payment |
| `destination` | `{ method: "mobile_money", operator, number }` \| `{ method: "wave", number }` \| `{ method: "bank", bankName, bankCode?, holderName, accountNumber, accountMasked }` | withdrawal |
| `toCurrency`, `toAccountId`, `rate`, `rateSource`, `rateObservedAt`, `rateSnapshotId`, `receiveAmount`, `txIds[2]` | | conversion |
| `txId`, `reference`, `createdAt`, `completedAt` | | |
| `payoutReference` / `providerReference`, `reason`, `processedBy` | | set by the admin |

Deposit id = `{gatewayMethod}_{gatewayReference}` (one deposit per gateway payment).

**`payment_receipts/{method}_{reference}`** — one per gateway payment (create-only): `{ method, reference, txId, amount (what the gateway charged), currency, userId, verified: false, createdAt }`; `verified`, `verifiedAt`, `verifiedBy` set by the admin after reconciliation; `disputed: true` and `note` when the provider did not confirm the payment.

### 3.3 Identity verification (KYC)

**`kyc_applications/{autoId}`** (C+A): `id, userId, level, accountType ("individual" | "business"), status, revision (int), personal { fullName, dateOfBirth ("yyyy-MM-dd"), nationality, idNumber, address, city, country }, business { companyName, registrationNumber, taxNumber, registeredAddress, country }, reason, createdAt, updatedAt, submittedAt`.

| Status | Label | Set by | Customer may edit |
|---|---|---|---|
| `draft` | Not submitted | C (create, reopen) | yes |
| `submitted` | Submitted | C | no |
| `under_review` | Under review | A | no |
| `additional_info_required` | More information needed (+ `reason`) | A | yes, then resubmit |
| `approved` | Verified | A (+ `users.kycLevel`) | no |
| `rejected` | Not approved (+ `reason`) | A | no ("Start again" = reopen) |

One open application (not approved / rejected) per user.

**`kyc_documents/{applicationId}_{type}_{side}_{epochMillis}`** (C+A): `id, applicationId, userId, type, side, status ("uploaded" | "accepted" | "rejected" | "superseded"), storagePath, contentType, size, revision, createdAt, supersededBy, updatedAt, note (admin)`. File: Storage `kyc/{uid}/{applicationId}/{type}-{side}-{epochMillis}.jpg`.

**`kyc_reviews/{autoId}`**: `id, applicationId, userId, action ("submit" | "reopen" by C; "start_review" | "request_info" | "approve" | "reject" by A), reason, by (admin), at`.

### 3.4 Transfers and bills

**`money_transfers/{requestKey}`** (C, external completed by A)

| Field | Notes |
|---|---|
| `id, senderId, senderName` | |
| `recipientId` | internal only |
| `participantIds` | `[senderId, recipientId]` (internal) / `[senderId]` (external) |
| `channel` | `internal` \| `mobile_money` \| `wave` \| `bank` |
| `recipient` | internal `{ email }` or `{ phone }`; Mobile Money `{ operator, number, name? }`; Wave `{ number, name? }`; bank `{ bankCode, bankName, holderName, accountNumber, accountMasked }` |
| `recipientName`, `recipientVerified` | internal: the Spideli user's name, `true`; external: `false` until the admin confirms |
| `currency, amount, fee, total, receiveAmount, note` | `total = amount + fee` |
| `funding` | `{ method, reference? }` |
| `status` | internal: `completed` at once; external: `processing` → `completed` \| `failed` \| `reversed` \| `cancelled` |
| `reference, txId, createdAt, completedAt` | |
| `cancelRequested, cancelRequestedAt` | C (external, before the admin starts) |
| `adminLockedAt, providerReference, reason` | A |

**`transfer_beneficiaries/ben_{uid}_{channel}_{key}`** (C): `userId, channel, displayName, detail (masked), recipient, createdAt, lastUsedAt` — the owner may delete.

**`utility_billers/{billerId}`** (A): `name, category, country, currency, order, published, accountLabel, accountHint, accountPattern (regex), amountType ("due" | "open" | "packages"), lookup (bool), partialPayment (bool), packages [{ code, name, amount }], min, max, feePercent, feeFixed, feeMax`.

**`utility_payment_requests/{requestKey}`** (C+A): `id, userId, billerId, billerName, category, account, packageCode?, packageName?, currency, amount, fee, total, status ("processing" → "completed" | "failed" | "reversed"), reference, txId, funding, createdAt`; set by A: `billerReference, token, tokenLabel, units, customerName, completedAt, reason`.

**`utility_saved_accounts/acc_{uid}_{billerId}_{account}`** (C): `userId, billerId, billerName, category, account, nickname, createdAt, lastUsedAt` — the owner may delete. `utility_payment_transactions` (A only).

### 3.5 Virtual cards

**`virtual_cards/{requestKey}`** (C+A): `id, userId, label, currency, network, status, balance, termsVersion, acceptedAt, issuanceFee, reference, feeTxId?, payment?, last4, expiryMonth, expiryYear, cardholderName, frozenBy ("user" | "issuer" | "admin"), frozenAt, unfrozenAt, statusBefore, terminationRequestedAt, renewalRequestedAt, renewalFee, renewalTxId, renewalReference, renewalPayment, replacedBy, reason, createdAt, updatedAt`. **Never** the full card number or CVV.

| Status | Set by |
|---|---|
| `requested` (Being created) | C |
| `active` | A (issued; `last4`, expiry, holder, `balance`; or unfreeze of an admin / issuer freeze); C (unfreeze from a user freeze) |
| `frozen` | C (`frozenBy: "user"`) or A (`"admin"` / `"issuer"`; only the admin unfreezes those) |
| `termination_requested` (Being deleted) | C |
| `terminated` (Deleted), `expired`, `failed` (Not created) | A |

**`card_funding_requests/{requestKey}`** (C+A): `id, userId, cardId, type ("fund" | "withdraw" | "transfer"), amount, fee, total, currency, status ("pending" → "succeeded" | "failed" (no money taken: withdraw / transfer) | "reversed" (top-up refunded)), txId?, reference, payment?, destination? ({ method: "wallet" }), recipientId?, recipient? ({ userId, name, contact }), createdAt, updatedAt`; A sets `reason`, `processedBy`, `completedAt`.

**`card_limit_settings/{cardId}`** (C+A): `userId, cardId, perTransaction, daily, monthly (null = issuer maximum), allowOnline?, allowInternational?, status ("pending" → "applied" | "rejected"), updatedAt, appliedAt (A), reason (A, refusal)`. **No other key** may ever be added (the rules check the whole document).

**`card_transactions/{id}`** (A): `userId, cardId, type (purchase | refund | funding | withdrawal | fee | reversal | authorization), status (pending | completed | declined | reversed), amount, currency, originalAmount, originalCurrency, merchantName, merchantCountry, declineReason, createdAt`.

### 3.6 Collective savings

**`savings_goals/{requestKey}`** (C+A): `id, ownerId, memberIds (uid[]), invitedIds (uid[]), name, purpose, description, currency, targetAmount, savedAmount, deadline?, schedule? { frequency, amount }, status ("active" | "completed" (A, only once the pool is paid out) | "cancellation_requested" | "cancelled"), accountId ("goal_{id}"), lastTxId, cancelledAt, cancellationRequestedBy, cancellationRequestedAt, createdAt, updatedAt`. "Solo goal" = `memberIds.length == 1`.

**`savings_contributions/{requestKey}`** (C): `id, goalId, userId, amount, currency, status ("succeeded"), reference, txId, funding, gateway?, createdAt`.

**`savings_withdrawals/{requestKey}`** (C+A): `id, goalId, userId, amount, currency, destination { method: "wallet", accountId }, reason? (the member's own), status ("completed" solo | "requested" → "completed" | "rejected" group), reference, txId, completedAt, createdAt`; A sets `rejectionReason`, `processedBy`.

### 3.7 Tontines

**`tontines/{requestKey}`** (C+A): `id, name, description, rules, currency, contributionAmount, frequency, membersLimit, payoutOrderMethod ("fixed" | "random"), startDate, status ("forming" → "active" → "completed"; "suspended" by A), adminIds, memberIds (active members), currentCycle (int; 0 while forming), nextDueAt, potAccountId ("tontine_{id}"), createdBy, startedAt, completedAt, createdAt, updatedAt`.

**`tontine_members/{tontineId}_{uid}`** (C+A): `id, tontineId, tontineName, userId, displayName, email, role ("admin" | "member"), status ("invited" | "active" | "declined" | "removed" | "restricted"), payoutPosition (1..n), invitedBy, invitedByName, joinedAt, respondedAt, invitedAt, createdAt` + **the terms on invitations**: `contributionAmount, currency, frequency, membersLimit, startDate, rules, payoutOrderMethod`.

**`tontine_cycles/{tontineId}_{n}`** (C+A): `id, tontineId, number, dueDate, beneficiaryUserId, expectedAmount (= contributionAmount × members), collectedAmount, currency, status ("upcoming" → "collecting" → "payout_pending" → "paid"), lastTxId, paidAt, createdAt, updatedAt`.

**`tontine_contributions/{cycleId}_{uid}`** (C; one per cycle and member): `id, tontineId, cycleId, cycleNumber, userId, amount, currency, status ("paid"), reference, txId, funding, gateway?, paidAt, createdAt`. The document exists only once paid: "not paid" and "overdue" are derived from its absence and the cycle's `dueDate`, never written (the id is create-only, so a document written by anyone else would block the member's payment).

**`tontine_payouts/{cycleId}`** (C+A): `id, tontineId, cycleId, cycleNumber, beneficiaryUserId, amount, currency, status ("pending_approval" → "paid"), txId, reference, approvedBy, approvedAt, paidAt, createdAt`.

**`tontine_disputes/{requestKey}`** (C+A): `id, tontineId, raisedBy, againstUserId?, subject, description, status ("open" → "under_review" → "resolved" | "rejected"), resolution, resolvedBy, resolvedAt, createdAt`.

### 3.8 Member loans

**`loan_applications/{requestKey}`** (C+A)

| Field | Notes |
|---|---|
| `id, borrowerId, groupId (a tontine id), groupName` | |
| `status` | lifecycle below |
| `currency, amount, purpose, description, durationMonths, repaymentFrequency` | |
| `eligibleVoterIds` | the group's active `memberIds` minus the borrower (non-empty) |
| `votes { yes, no }` | counters (+1 per vote) |
| `votingEndsAt, votingClosedAt` | A opens the vote; C closes it |
| `fundedAmount, lenderIds, fundedAt` | |
| `acceptedAt, agreementVersion, disbursedAt` | |
| `outstandingAmount, repaidAmount, repaidAt` | |
| `documents [{ name, storagePath }]` | Storage `loan_documents/{uid}/{loanId}/document-{n}-{ms}.jpg` |
| `reason, cancelledAt, createdAt, updatedAt` | |

Lifecycle: `submitted` (C) → `under_review` (A) → `voting` (A, + `votingEndsAt`) → `funding` or `rejected` (C closes the vote) → `agreement_pending` (C, last funder) → `active` (C, borrower accepts; disbursed at once) ⇄ `overdue` (A, both ways: back to `active` once no instalment is overdue) → `repaid` (C, outstanding reaches 0). Also `cancelled` (C while submitted / under_review / voting; A when a stuck `funding` / `agreement_pending` loan is refunded), `rejected` (A before funding, or the vote), `defaulted` (A, after a documented review).

**`loan_votes/{loanId}_{uid}`** (C, create-only): `loanId, voterId, approve (bool), comment, at`.
**`loan_fundings/{loanId}_{uid}_{n}`** (C): `id, loanId, lenderId, borrowerId, amount, currency, status ("succeeded"; "refunded" by A), funding, reference, txId, requestKey, collected (int), createdAt, updatedAt`.
**`loan_agreements/{loanId}`** (C, last funder): `loanId, borrowerId, version, principal, currency, interestMethod, annualInterestPercent, fee, totalRepayable, latePenaltyPercent, durationMonths, repaymentFrequency, terms, installments [{ number, amount, principal, interest }], createdAt, acceptedAt`.
**`loan_disbursements/{loanId}`** (C, borrower): `id, loanId, borrowerId, amount, fee, currency, status ("succeeded"), reference, txId, paidAt`.
**`loan_schedules/{loanId}`** (C, borrower; A penalties): `loanId, borrowerId, currency, installments [{ number, dueDate, amount, principal, interest, penalty, amountDue, paidAmount, status ("upcoming" → "due" (A, on the due date) → "overdue" (A); "partially_paid" | "paid" (C, repayments)) }], createdAt, updatedAt`.
**`loan_repayments/{loanId}_{requestKey}`** (C): `id, loanId, borrowerId, amount, currency, status ("succeeded"), funding, reference, txId, requestKey, createdAt`.
**`credit_assessments/{loanId}`** (A; read by the borrower only): `loanId, borrowerId, score, band, factors [{ label, impact ("positive" | "negative"), detail }], assessedAt`.

### 3.9 Investments

**`investment_funds/{fundId}`** (A): `name, manager, description, objective, assetClass, riskLevel (1-7), currency, order, minInvestment, minAdditional, fees { subscriptionPercent, managementPercent, redemptionPercent, performancePercent }, navPerUnit (number, minor units, decimals allowed), navDate, lockUpDays, settlementDays, redemption { allowed, partial }, terms, termsVersion, documents [{ name, storagePath | url }], eligibility, performance { ytd, oneYear, threeYears, fiveYears, sinceInception } (%), status ("open" | "closed" | "suspended"), published`.
**`investment_valuations/{id}`** (A): `fundId, date, navPerUnit`.
**`investment_holdings/{uid}_{fundId}`** (A): `userId, fundId, fundName, assetClass, currency, units, redeemableUnits, redeemableValue, investedAmount, currentValue, realizedGains, unrealizedGains, lockedUntil, valuedAt`.
**`investment_subscriptions/{requestKey}`** (C+A): `id, userId, fundId, fundName, assetClass, currency, amount, fee (estimate), termsVersion, signatureName, riskAcknowledged: true, acceptedAt, status ("paid" → "processing" → "completed"; "rejected" (refunded)), txId, reference, payment, createdAt, updatedAt`; A sets `units, navPerUnit, netAmount, fee (actual), tradeDate, reason`.
**`investment_redemptions/{requestKey}`** (C+A): `id, userId, fundId, fundName, currency, full (bool), amount (null when full), destination, status ("submitted" → "processing" → "settling" → "settled"; "rejected"; "cancelled" by C while submitted), reference, cancelledAt, createdAt, updatedAt`; A sets `fee, netAmount, units, navPerUnit, tradeDate, expectedSettlementDate, settledAt, txId, reason`.
**`investment_transactions/{id}`** (A): `userId, fundId, type (subscription | redemption | fee | distribution | adjustment), amount, units, navPerUnit, currency, reference, createdAt`.
**`investment_reports/{id}`** (A): `userId, title, period, storagePath, createdAt` (PDF in Storage `investment_reports/{uid}/…`).

### 3.10 Insurance

**`insurance_partners/{id}`** (A only; never readable by customers): `name, licenceNumber, country, contact`.
**`insurance_products/{productId}`** (A): `partnerId, partnerName, category, name, summary, description, currency, order, coverages [{ name, description, limit }], exclusions [string], deductible, waitingPeriodDays, termMonths, rating { basePremium, frequencies { annual, semiannual, quarterly, monthly: loading% }, factors [{ key, label, type ("number" | "select"), unit, min, max, bands [{ upTo, multiplier }], options [{ value, label, multiplier }] }] }, terms, termsVersion, documents, status ("open" | "closed"), published`.
**`insurance_quotes/{requestKey}`** (C+A): `id, userId, productId, productName, partnerName, category, currency, answers {factorKey: value}, frequency, coverStart (ts), termMonths, status ("requested" → "quoted" → "accepted"; "declined" (C), "expired", "rejected" (A)), declinedAt, createdAt, updatedAt`; A sets `premium (a year), installmentAmount, deductible, coverEnd, validUntil, terms, termsVersion, coverages, documents, insurerReference, reason`; C on acceptance `acceptedAt, signatureName, policyId`.
**`insurance_policies/{quoteId}`** (C creates on acceptance; A administers): the quote's fields + `signatureName, acceptedAt, autoRenew, status ("pending_activation" → "active" → "renewal_due" → "active"; "lapsed", "cancellation_requested" → "cancelled", "expired", "rejected"), statusBefore, policyNumber, nextPremiumDue (A keeps it current), renewalPremium, renewalDate, renewalRequestedAt, renewalPaidAmount, renewalTxId, renewalReference, renewalPayment, cancellationReason, cancellationRequestedAt, documents, reason`.
**`insurance_premiums/{quoteId}_1`** (first, C) and `{policyId}_{n}` later ones (A creates them `upcoming`): `id, userId, policyId, amount, currency, dueDate, status ("upcoming" → "due" → "overdue" (A); "paid" (C, or A for an auto-renewal charge)), paidAt, txId, reference, payment, createdAt, updatedAt`.
**`insurance_claims/{requestKey}`** (C+A): `id, userId, policyId, policyNumber, productName, currency, incidentDate (ts), description, amountClaimed, documents [{ name, storagePath }], status ("submitted" → "under_review" → "info_requested" → "under_review" → "approved" → "paid"; "rejected"; "withdrawn" by C), respondedAt, withdrawnAt, createdAt`; A sets `approvedAmount, paidAmount, paidAt, insurerReference, reason`. Photos: Storage `insurance_claims/{uid}/{claimId}/{ms}-{i}.jpg`.
**`insurance_claims/{id}/events/{key}`** (C+A): `type ("customer_response" | admin types), userId, authorId, message, documents, createdAt`.

### 3.11 Project financing

**`financing_projects/{id}`** (C): `id, ownerId, name, sector, stage?, country, city, description, employees?, foundedYear?, website?, createdAt, updatedAt`.
**`financing_applications/{id}`** (C+A): `id, ownerId, projectId, projectName, financingType, amount, currency, durationMonths?, useOfFunds, status ("draft" → "submitted" → "under_review" → "additional_info_required" → "submitted" … → "approved" → "funded" → "closed"; "rejected"; "withdrawn" by C), declarationAccepted, declarationAcceptedAt, submittedAt, ownerMessage, withdrawnAt, reviewerIds, createdAt, updatedAt`; A sets `reason, approvedAmount, fundedAmount, institutionName, fundedAt`.
**`financing_documents/{id}`** (C+A): `id, ownerId, applicationId, type, name, storagePath, contentType, size, status ("received" → "accepted" | "rejected"), note, uploadedAt`. Storage `financing_documents/{uid}/{applicationId}/{ms}-{name}`. The owner may delete a `received` document while the application is editable.
**`financing_reviews/{id}`** (A): `ownerId, applicationId, fromStatus, toStatus, publicNote, at`. Internal reviewer notes go to the staff-only `financing_internal_notes/{id}` = `{ applicationId, authorId, text, at }`, never here.
**`financial_resources/{id}`** (A): `published, type ("template" | "guide" | "faq" | "regulation"), title, summary, body, storagePath | url, country, language, order, updatedAt`.

### 3.12 Markets, intelligence and opportunities

Admin-published, read-only for customers (lists must filter `published == true`):
- `economic_indicators/{id}`: `published, country, code, name, value, previousValue, unit, currency, period, periodEnd, source, sourceUrl, updatedAt, order` (hidden without `value`, `name`, `source`, `period`, `updatedAt`); `economic_indicator_history/{id}`: `indicatorId, period, periodEnd, value`.
- `exchange_rate_snapshots/{id}`: `from, to, pair ("{from}_{to}"), rate (1 from = rate to), source, kind ("official" | "indicative"), observedAt`.
- `investment_opportunities/{id}`: `published, status ("open" | "closed"), title, summary, sector, country, type, currency, minTicket, targetAmount, raisedAmount, horizonMonths, riskLevel, targetReturnPercent, ownerName, projectId, closingDate, documents`. The owner's uid is **not** published: the admin keeps it in the staff-only `opportunity_owners/{opportunityId}` = `{ ownerId }`.
- `market_securities/{id}`: `published, type ("stock" | "etf" | "bond" | "index"), symbol, name, exchange, country, currency, price, change, changePercent, open, high, low, volume, sector, couponPercent, maturityDate, yieldPercent, source, updatedAt, delayed` (prices in major units).
- `market_price_history/{id}`: `securityId, date, close`.
- `ipo_listings/{id}`: `published, company, symbol, exchange, country, sector, currency, priceLow, priceHigh, offerPrice, openDate, closeDate, listingDate, status ("upcoming" | "open" | "closed" | "listed" | "withdrawn"), prospectusUrl (https), source, updatedAt`.
- `stock_collections/{id}`: `published, title, summary, theme, securityIds, riskLevel, order`.
- `finance_news/{id}`: `published, title, summary, source, url (https), category, country, publishedAt`.

Customer-owned:
- `investor_profiles/{uid}` (C): `currency, sectors, countries, types, minTicket, maxTicket, maxRisk (1-7), maxHorizonMonths (0 = no limit), updatedAt`.
- `opportunity_interests/{opportunityId}_{uid}` (C): `opportunityId, userId, interested (bool), message (≤ 500), name, email (only when interested), createdAt, updatedAt` (both re-sent as `serverTimestamp()` on every write).
- `investor_watchlists/{uid}` (C): `securityIds (≤ 50), updatedAt`.

### 3.13 Finance chat

**`finance_chats/{chatId}`** — `dm_{uidA}_{uidB}` (uids sorted) or `tontine_{tontineId}`: `id, type ("direct" | "tontine"), memberIds (direct, sorted), tontineId (group), lastMessage { text, senderId, at }, updatedAt, lastReadAt { uid: ts }`.
**`finance_chats/{chatId}/messages/{autoId}`**: `id, senderId, senderName, text (1-1000 characters), createdAt` — never edited or deleted.

### 3.14 Admin-only collections

`admin_audit_logs`, `support_tickets` (+ `messages`), `reconciliations`, `utility_payment_transactions`, `virtual_cards_private`, `insurance_partners`, `financing_internal_notes`, `opportunity_owners`, `push_rate_limits` — defined in the admin specification. No customer rule exists for them, so customers can never read them.

### 3.15 AI coach (disabled)

`coach_consents/{uid}`, `financial_coach_sessions/{id}` (+ `messages`) exist in the contract but the coach needs a server holding the AI provider key; `platform_settings/intelligence.coach.enabled` stays `false`. Neither client may call an AI provider directly.

### 3.16 Storage paths

| Path | Written by | Read by |
|---|---|---|
| `kyc/{uid}/{applicationId}/{type}-{side}-{epochMillis}.jpg` | the customer (create only) | the customer; the admin (signed URLs ≤ 5 min) |
| `loan_documents/{uid}/{loanId}/document-{n}-{ms}.jpg` | the borrower | the admin; voters through signed URLs |
| `insurance_claims/{uid}/{claimId}/{ms}-{i}.jpg` | the policyholder | the customer, the admin |
| `financing_documents/{uid}/{applicationId}/{ms}-{name}` | the project owner | the owner, the admin |
| `investment_reports/{uid}/…`, `insurance_policies/{uid}/{policyId}/…` | the admin | the owner |
| `investment_funds/{fundId}/…`, `financial_resources/…` | the admin | signed-in users |

## 4. Money movement, payments and integrity (shared)

### 4.1 Double-entry postings

Every change of a balance is a **posting**: one `ledger_transactions` document plus the balance change of **every** account it names, written in **one** batch (or transaction).

```
posting(type, currency, from, to, amount, fee = 0):
  txId = "tx_" + epochMillis + "_" + 8 random chars
  lines = [ { accountId: from, direction: "debit",  amount: amount + fee },
            { accountId: to,   direction: "credit", amount: amount } ]
  if fee > 0 and from != platform_{CUR} and to != platform_{CUR}:
      lines.append({ accountId: "platform_{CUR}", direction: "credit", amount: fee })
  write ledger_transactions/{txId} = { id, type, status: "posted", reference, currency, lines,
        userIds, accountIds: [line.accountId…], source: { kind, id }, funding, gateway?,
        description, createdBy: uid, createdAt: serverTimestamp() }
  for each line: financial_accounts/{line.accountId}
        update { balance: increment(±line.amount), lastTxId: txId, updatedAt: serverTimestamp() }
        (or create it with balance = the credit when the batch opens it: see 4.4)
```

Rules enforced on every customer posting (the admin must respect the same invariants):
1. 2 or 3 lines; `lines[0]` is the **only debit**; `lines[0].amount == lines[1].amount (+ lines[2].amount)`; every amount a positive integer.
2. The optional 3rd line is the fee, credited to `platform_{CUR}`.
3. Every account of the lines is written in the **same batch** with `lastTxId == txId`, and its `balance` changes by exactly its line (−debit, +credit). Each account appears **once** per batch.
4. A wallet never goes below 0.
5. The debited account is one the caller may debit (4.3).
6. `createdBy == uid`, `createdAt == request.time` (an old posting can never be replayed), `type` in the customer list (4.2), `source` names the request document written in the same batch.

**Never** edit or delete a posting. A correction is a **reversal** (admin): a new posting with the lines inverted, `type: "reversal"`, `reversalOf: <txId>`, and the original set to `status: "reversed"`.

### 4.2 Posting types

| Type | From → to | Written by |
|---|---|---|
| `deposit` | `platform_{CUR}` → wallet (gateway-funded) | C |
| `withdrawal` | wallet → platform | C (refund: A reversal) |
| `transfer` | sender wallet → recipient wallet (+ fee to platform) | C |
| `transfer_out` | wallet → platform | C |
| `bill_payment` | wallet → platform | C |
| `card_funding`, `card_fee` | wallet → platform | C |
| `card_withdrawal` | platform → wallet | A |
| `savings_contribution` | wallet / platform → `goal_{id}` | C |
| `savings_withdrawal` | `goal_{id}` → wallet | C (solo goal), A (group goal) |
| `tontine_contribution` | wallet / platform → `tontine_{id}` | C |
| `tontine_payout` | `tontine_{id}` → beneficiary wallet | C (another tontine admin), A |
| `loan_funding` | wallet / platform → `loan_{id}` | C |
| `loan_disbursement` | `loan_{id}` → borrower wallet (+ fee to platform) | C (borrower) |
| `loan_repayment` | wallet / platform → `loan_{id}` | C |
| `loan_lender_payout` | `loan_{id}` → lender wallet | C (lender), A |
| `investment_subscription` | wallet → platform | C |
| `investment_redemption`, `insurance_claim_payout` | platform → wallet | A |
| `insurance_premium` | wallet → platform | C; A only for an auto-renewal the customer switched on (`autoRenew`) |
| `conversion` | wallet_A → platform_A **and** platform_B → wallet_B (one batch, four accounts) | C |
| `fee`, `reversal`, `manual_adjustment` | any | **A only** |

### 4.3 Who may debit which account

| Account | A customer may debit it when |
|---|---|
| own wallet | always, for a request of a matching type, never below 0 |
| `goal_{id}` | the owner of a **solo** goal, to their own wallet (withdrawal, cancellation) |
| `tontine_{id}` | a tontine admin who is **not** the beneficiary, paying the current cycle's payout of exactly the collected amount |
| `loan_{id}` | the borrower once (disbursement of the whole funded amount, after accepting the agreement); a lender, at most `floor(repaidAmount × lent / loan.amount) − collected` |
| `platform_{CUR}` | only (a) for a **gateway-funded** posting of type `deposit` (to the payer's wallet) or one of the pool types `savings_contribution`, `tontine_contribution`, `loan_funding`, `loan_repayment`, with a new `payment_receipts` document naming it in the batch; or (b) for the second leg of a `conversion` (receive amount capped by the named rate snapshot). The clients use the deposit-first flow of 4.5 for every gateway payment. |

### 4.4 Account creation

- A wallet `wallet_{uid}_{CUR}` is created by the posting that first credits it (`balance` = the credit, `lastTxId` = that posting), including by **another** user's batch (an internal transfer to someone without a wallet in that currency, a tontine payout).
- Pool accounts are created **empty** (`balance: 0`, no `lastTxId`) in the same batch as their goal / tontine; the loan account by the first funding.
- `platform_{CUR}` accounts are created by the admin.

### 4.5 Paying: the wallet or a payment gateway

1. The user sees the figures first (amount, fee, total, terms, risks), then chooses how to pay among the methods the module's settings allow:
   - **Spideli Finance wallet** (balance shown; refused when too low → `insufficient_funds`);
   - **a gateway**, enabled for the user's region (`settings/*.regionIds`) and able to charge the currency:

| Method family | Gateways (key) | Currencies |
|---|---|---|
| `mobile_money` | Orange Money (`orange_money`), Flutterwave (`flutterwave`), PayStack (`paystack`) | Orange: XAF; Flutterwave: XAF, XOF, NGN, GHS, KES, TZS, RWF, ZAR, ZMW, MWK, EGP, USD, EUR, GBP; PayStack: NGN, GHS, ZAR, KES, USD |
| `wave` | Flutterwave | as above |
| `card` (Visa / Mastercard) | Stripe (`stripe`), Flutterwave, PayStack, MercadoPago, Xendit, Midtrans, PayFast, Razorpay | Stripe: XAF, XOF, GNF, RWF, USD, EUR, GBP, CAD, AUD, CHF, NGN, GHS, KES, ZAR, MAD, EGP, AED, SAR, INR |
| `paypal` | PayPal (`paypal`) | USD, EUR, GBP, CAD, AUD, CHF |

2. **Wallet payment:** one batch: the request document + its posting from the user's wallet.
3. **Gateway payment:** the gateway checkout runs first for `amount + fee`. On success, **batch 1 (deposit):** `wallet_operations/{method}_{reference}` (`type: "deposit"`, `status: "completed"`, `purpose: { kind, id }` of the request) + `payment_receipts/{method}_{reference}` + posting `deposit` platform → wallet (creates the wallet if needed). Then **batch 2:** the request paid from the wallet as in 2. If batch 2 fails, the money is safe in the wallet; "Try again" retries only batch 2 (the deposit id makes batch 1 idempotent — never charge the gateway again).
4. Result shown: "Payment received" (completed), "Payment received — Spideli Finance completes your request" (processing), "Request sent" (payouts).

> **Trust note.** Without a server, a gateway success is reported by the browser / phone. Every gateway payment leaves a `payment_receipts` record the **admin must reconcile** with the provider (dashboard / API / webhook), reversing what the provider did not receive. Gateway **secret** keys never go to the browser.

### 4.6 Never paying twice

- **One request id per intent.** The client computes an intent string `action:target:amount:method:number` and keeps one request key per intent in memory until the write succeeds; a double click or a retry after a timeout writes the **same** document id. Request documents are **create-only** in the rules.
- Before writing, the client re-reads the request document; if it exists and belongs to the user, the operation is already done.
- Deterministic ids where only one record may exist: one contribution per tontine cycle and member (`{cycleId}_{uid}`), one vote per loan and member (`{loanId}_{uid}`), one payout per cycle (`{cycleId}`), one deposit / receipt per gateway payment (`{method}_{reference}`).
- Buttons are disabled while a write runs.

### 4.7 Re-authentication

Required (the rules check `request.auth.token.auth_time` within the last **5 minutes**; clients ask again after 4):
- wallet withdrawals (`platform_settings/wallet`, compared with `amount`), transfers (`platform_settings/transfers`, `amount`) and bill payments (`platform_settings/bills`, **`total`**): re-authentication is skipped only when `security.reauthAbove[CUR]` is a number > 0 **and** the compared value is below it. A currency without a threshold = always;
- always: card unfreeze, card limits (create and change), card → wallet, card → card, card deletion request, showing card details.

Never required: deposits, conversions, card top-ups, card freeze and every other write.

Re-authentication uses the sign-in method of the account: password, SMS code, Google, Apple or LinkedIn; with two-step verification on, the SMS second factor too.

### 4.8 Restrictions (blacklist)

`users/{uid}.financeRestriction` (admin only) blocks new actions in its scopes (empty / `all` = every scope):

| Scope | Blocks |
|---|---|
| `loans` | loan application, vote, funding, accepting an agreement |
| `tontines` | creating a tontine, joining one |
| `savings` | creating a goal, joining one |
| `transfers` | sending money |
| `payments` | bill payments |
| `wallet` | add money, withdraw, convert |

Never blocked: declining invitations, receiving money, contributions (savings and tontine), loan repayments, savings withdrawals, the gateway deposit that pays another request (`purpose` set), cards, investments, insurance, financing, KYC and chat.

### 4.9 Error reasons

A refusal shows a message keyed by its reason (EN / AR). Firestore `permission-denied` → `permission_denied` ("This action is not allowed, or is no longer possible. Refresh and try again.").

`insufficient_funds`, `permission_denied`, `finance_restricted`, `state_changed`, `invalid_state`, `recipient_not_found`, `recipient_ambiguous`, `self_transfer`, `invite_self`, `already_member`, `group_full`, `invitation_closed`, `withdrawal_not_allowed`, `payout_self_approval`, `loan_no_voters`, `agreement_outdated`, `nothing_to_collect`, `terms_outdated`, `fund_closed`, `below_minimum`, `not_eligible`, `locked_up`, `redemption_not_allowed`, `quote_expired`, `policy_not_active`, `claim_not_editable`, `amount_out_of_range`, `card_limit_reached`, `card_not_active`, `not_supported`, `reauth_required`, `rate_unavailable`, `not_cancellable`, `payment_not_completed`, `gateway_unavailable`, `network`, `service_unavailable`, `watchlist_full`, `message_invalid`, `kyc_documents_missing`, `kyc_not_editable`, `financing_documents_missing`, `financing_not_editable`.

## 5. Admin panel: architecture

### 5.1 Stack and Firebase access

- PHP with **`kreait/firebase-php`** (Firebase Admin SDK): `Firestore` (via `google/cloud-firestore`), `Auth`, `Storage`, `Messaging`.
- A **service account** of `spideli-870b0` with the least roles needed (Firestore user, Storage object admin, Firebase Auth admin, FCM sender). Keep the JSON outside the web root, never in Git, never sent to a browser, and never stored in Firestore or Storage. The apps' current `settings/notification_setting.serviceJson` exposes such a key and must be retired (1.6).
- The Admin SDK **bypasses the security rules**. Every check this document lists must be coded in PHP, server side, before writing.
- **Atomicity:** anything that touches more than one document runs in a Firestore **transaction** (read, check, write all). That covers postings, status + counters, and a request together with its posting. The panel's own updates on the same document must not race the customers' writes.
- **Timestamps:** `FieldValue::serverTimestamp()` for every `…At` the panel writes.
- **Amounts:** integer minor units (section 1.3). Forms accept major units and convert them.

### 5.2 Posting helper (PHP pseudo-code)

Firestore transactions require **every read before the first write**. The helper therefore has two phases: `plan()` reads and checks the accounts, `write()` writes the posting. An action that makes several postings (a reversal of a 3-line posting, a group-goal cancellation, a card closure with a refund) plans **all** of them first, then writes them all.

```php
// Phase 1 - reads and checks only. $balances carries the running balance of each account
// across several plans of the same transaction, so two postings on one account are checked together.
function plan(Transaction $t, array &$balances, string $type, string $cur, string $from, string $to,
              int $amount, int $fee, array $userIds, array $source, string $description,
              ?string $reversalOf = null): array {
    assert($amount > 0 && $fee >= 0 && $from !== $to);
    $platform = "platform_$cur";
    $lines = [[ 'accountId' => $from, 'direction' => 'debit',  'amount' => $amount + $fee ],
              [ 'accountId' => $to,   'direction' => 'credit', 'amount' => $amount ]];
    if ($fee > 0 && $from !== $platform && $to !== $platform)
        $lines[] = [ 'accountId' => $platform, 'direction' => 'credit', 'amount' => $fee ];
    foreach ($lines as $l) {
        $id = $l['accountId'];
        if (!array_key_exists($id, $balances)) {
            $snap = $t->snapshot(doc("financial_accounts/$id"));
            $balances[$id] = $snap->exists() ? $snap->data() : null;   // null = missing
        }
        $acc = $balances[$id];
        if ($acc === null && ($l['direction'] === 'debit' || !str_starts_with($id, 'wallet_')))
            throw new AccountMissing($id);             // only a wallet may be created, and only by a credit
        if ($acc !== null && $acc['status'] !== 'active') throw new AccountFrozen($id);
        if ($acc !== null && $acc['currency'] !== $cur) throw new CurrencyMismatch($id);
        $delta = $l['direction'] === 'debit' ? -$l['amount'] : $l['amount'];
        $after = ($acc['balance'] ?? 0) + $delta;
        if ($after < 0 && ($acc['kind'] ?? 'wallet') !== 'platform') throw new InsufficientFunds($id);
        $balances[$id] = ($acc ?? ['kind' => 'wallet', 'currency' => $cur, 'new' => true]) + [];
        $balances[$id]['balance'] = $after;
    }
    return compact('type', 'cur', 'lines', 'userIds', 'source', 'description', 'reversalOf');
}

// Phase 2 - writes only. Returns the new txId.
function write(Transaction $t, array $p, string $adminId): string {
    $txId = 'tx_' . (int)(microtime(true) * 1000) . '_' . random8();      // ^tx_[0-9]{10,16}_[A-Za-z0-9_]{4,40}$
    $t->set(doc("ledger_transactions/$txId"), [
        'id' => $txId, 'type' => $p['type'], 'status' => 'posted', 'reference' => newReference(),   // SPF-yyMMdd-XXXXXX
        'currency' => $p['cur'], 'lines' => $p['lines'],
        'userIds' => array_values(array_unique($p['userIds'])),          // owners of the wallets in the lines
        'accountIds' => array_column($p['lines'], 'accountId'), 'source' => $p['source'],
        'funding' => 'wallet', 'description' => $p['description'],
        'createdBy' => "admin:$adminId", 'createdAt' => FieldValue::serverTimestamp(),
    ] + ($p['reversalOf'] ? ['reversalOf' => $p['reversalOf']] : []));
    foreach ($p['lines'] as $l) {
        $delta = $l['direction'] === 'debit' ? -$l['amount'] : $l['amount'];
        $ref = doc("financial_accounts/{$l['accountId']}");
        if (isNewWallet($l['accountId'])) {          // missing in plan(): create it with this credit
            [$uid, $cur] = parseWalletId($l['accountId']);       // wallet_{uid}_{CUR}
            $t->set($ref, [ 'id' => $l['accountId'], 'kind' => 'wallet', 'userId' => $uid, 'currency' => $cur,
                'balance' => $delta, 'normalSide' => 'credit', 'status' => 'active', 'lastTxId' => $txId,
                'createdAt' => FieldValue::serverTimestamp(), 'updatedAt' => FieldValue::serverTimestamp() ]);
            markWalletCreated($l['accountId']);      // a second posting in the same transaction updates it
        } else {
            $t->update($ref, [
                ['path' => 'balance',   'value' => FieldValue::increment($delta)],
                ['path' => 'lastTxId',  'value' => $txId],
                ['path' => 'updatedAt', 'value' => FieldValue::serverTimestamp()],
            ]);
        }
    }
    return $txId;
}

// Convenience for one posting: post($t, ...) = write($t, plan($t, $b = [], ...), $adminId).

function reverse(Transaction $t, string $txId, string $adminId, string $reason): array {
    $orig = $t->snapshot(doc("ledger_transactions/$txId"))->data();
    if ($orig['status'] === 'reversed') throw new AlreadyReversed();
    [$debit, $credit] = [$orig['lines'][0], $orig['lines'][1]];
    $b = [];
    // 1. plan everything (reads): the main amount back, credited -> debited account
    $plans = [ plan($t, $b, 'reversal', $orig['currency'], $credit['accountId'], $debit['accountId'],
                    $credit['amount'], 0, $orig['userIds'], $orig['source'], $reason, $txId) ];
    // a 3-line original also gives the fee back: platform -> debited account
    if (isset($orig['lines'][2]))
        $plans[] = plan($t, $b, 'reversal', $orig['currency'], $orig['lines'][2]['accountId'], $debit['accountId'],
                        $orig['lines'][2]['amount'], 0, $orig['userIds'], $orig['source'], $reason, $txId);
    // 2. write everything
    $ids = array_map(fn($p) => write($t, $p, $adminId), $plans);
    $t->update(doc("ledger_transactions/$txId"), [
        ['path' => 'status', 'value' => 'reversed'],
        ['path' => 'reversedBy', 'value' => $ids],
        ['path' => 'reversedAt', 'value' => FieldValue::serverTimestamp()],
    ]);
    return $ids;   // the "one write per account per batch" limit applies only to customer clients;
                   // an account's lastTxId ends on the last posting written
}
```

If the credited account no longer holds the money (a wallet already spent it), `plan()` throws `InsufficientFunds`: the reversal is impossible as such. Handle it as in 6.5.1 (restrict, ticket, recover).

Rules of the ledger (section 4.1) apply to the panel too:
- never edit or delete a posting;
- every balance change has its posting;
- platform accounts may go negative (Spideli's position); wallets may not.

### 5.3 Admin identity and roles (RBAC)

Admin accounts live in the panel's own user table (with 2FA), mapped to a Firebase uid only when needed. Roles:

| Permission | Super admin | Finance operations | Compliance | Support | Content |
|---|---|---|---|---|---|
| Settings (`platform_settings/*`, gateways) | ✔ | — | — | — | — |
| Users: view | ✔ | ✔ | ✔ | ✔ | — |
| Users: create / suspend / delete | ✔ | — | ✔ | — | — |
| Restriction (blacklist) | ✔ | — | ✔ | — | — |
| KYC review and decisions | ✔ | — | ✔ | — | — |
| Payment queues (payouts, transfers, bills, cards), reconciliation | ✔ | ✔ | — | — | — |
| Reversals, manual adjustments | ✔ | ✔ (with a second approver above a threshold) | — | — | — |
| Fund management, order execution | ✔ | ✔ | — | — | — |
| Insurance management, claims | ✔ | ✔ | ✔ | — | — |
| Loans (review, scoring, penalties, default) | ✔ | ✔ | ✔ | — | — |
| Tontines (consultation, suspension, disputes) | ✔ | ✔ | ✔ | view | — |
| Financing reviews | ✔ | ✔ | ✔ | — | — |
| Catalogs, markets, news, resources, opportunities | ✔ | — | — | — | ✔ |
| Tickets, notifications | ✔ | ✔ | ✔ | ✔ | — |
| Reports | ✔ | ✔ | ✔ | view | — |
| Audit log (read) | ✔ | — | ✔ | — | — |

Every action writes an audit entry (6.18). Sensitive money actions above a configurable amount need a **second admin** (four-eyes).

### 5.4 Sending notifications

For every customer-facing decision the panel:
1. reads the `dynamic_notification` template of the event `type` and fills its placeholders;
2. checks `users/{uid}.financeNotificationPrefs` for the category (security notices always go);
3. sends:
   - **push** (FCM via the Admin SDK) to `users/{uid}.fcmToken`, data `{ type, …ids }`;
   - **Notification Center** record `users/{uid}/notifications/{id} = { type, title, body, category: "account", source: "finance", read: false, createdAt, data }`;
   - **SMS** for critical transactions;
   - **e-mail** for receipts and alerts, through the panel's SMS / e-mail providers.

Template types per module are listed in each section below.

## 6. Admin features

Every action below: **who** (role), **preconditions** (re-read in the transaction), **writes**, **notification** (template `type`), **audit**. "Post X → Y" = the helper of 5.2.

### 6.1 Dashboard (home of the panel)

KPI tiles (Firestore aggregation queries `count()` / `sum()`, or a nightly export):
- verified users (`users` where `kycLevel != ""`);
- KYC queue size;
- payout queue sizes (withdrawals, external transfers, bills, card requests);
- receipts to reconcile (`payment_receipts` where `verified == false`);
- assets under management (Σ `investment_holdings.currentValue`);
- money held per currency (Σ wallet balances; platform balance);
- this month's contribution volumes (savings, tontines);
- loans active / overdue;
- open claims, open tickets.

Each tile links to its queue.

### 6.2 Settings management

One form per settings document (section 2), each with field-level validation. The forms:
- refuse a missing currency, method or required text;
- keep `maxMembers ≥ minMembers` and quorum / approval within 1-100;
- validate amounts as integers in minor units;
- **increment `termsVersion`** whenever terms text changes (cards, funds, insurance products).

Saving overwrites the document, writes an audit entry and shows the module's availability ("Offered" / "Not available: missing X").

Also managed here:
- the gateway documents `settings/*` (publishable keys and `regionIds`; secrets stay in the panel's server configuration);
- `settings/authProviders`;
- the finance section `sections/{id}` with `serviceTypeFlag: "finance-service"`;
- the `platform_{CUR}` accounts. "Create platform account" writes `financial_accounts/platform_{CUR}` `{ id, kind: "platform", currency, balance: 0, normalSide: "credit", status: "active", lastTxId: "", createdAt, updatedAt }`.

**Go-live minimum:** every `platform_settings` document of the offered modules; `platform_settings/wallet`; one `platform_{CUR}` per currency; the `finance_chat_message` template.

### 6.3 User management

| Screen / action | Details |
|---|---|
| List | search by name, e-mail, phone, uid; filters: verified, restricted, suspended, created date |
| Detail | profile, verification (applications, documents, reviews), wallets and balances, ledger (`ledger_transactions` where `userIds` contains uid), goals, tontines, loans, holdings, policies, claims, cards, transfers, bills, tickets, audit trail, two-step status (`Auth::getUser(uid)->mfaInfo`) |
| Create | Firebase Auth `createUser` + `users/{uid}` (same fields as the app's sign-up, `role: "customer"`, `active: true`) |
| Activate / suspend | `users/{uid}.active` true / false **and** Auth `disabled` false / true; audit with reason |
| Delete | Auth delete + the website's `/api/delete-user` clean-up; finance records kept for legal retention, the user marked deleted |
| Restrict (blacklist) | Compliance, after a documented review (never automatically from one failed payment). Writes `users/{uid}.financeRestriction = { status: "restricted", reason, since: serverTimestamp(), scopes: [...], by: adminId }`. Lift = delete the field. Optional: `tontine_members/{tid}_{uid}.status = "restricted"`. Audit. |
| Reset two-step | after identity checks, remove the user's second factors (Auth) |

### 6.4 KYC management

**Queue:** `kyc_applications` where `status in ["submitted", "under_review"]`, `orderBy submittedAt`. Show the level, account type, revision and waiting time.

**Review screen:**
- the application data (personal / business);
- each `kyc_documents` file (where `applicationId == X`, not `superseded`), opened with a **signed URL valid ≤ 5 minutes** and never downloaded to the panel's disk;
- the history (`kyc_reviews`).

| Action | Preconditions | Writes | Notification |
|---|---|---|---|
| Start review | `submitted` | application `{ status: "under_review", updatedAt }` + `kyc_reviews/{auto}` `{ id, applicationId, userId, action: "start_review", by, at }` | — |
| Accept / reject a document | the document is `uploaded` | `kyc_documents/{id}` `{ status: "accepted" \| "rejected", note, updatedAt }` | — |
| Ask for more information | `submitted` / `under_review` | application `{ status: "additional_info_required", reason, updatedAt }` + review `request_info` | `kyc_additional_info_required` {reason} |
| Approve | `under_review`; every requirement group met by accepted documents | application `{ status: "approved", updatedAt }` + `users/{uid}` `{ kycLevel: <level>, kycStatus: "approved" }` + review `approve` | `kyc_approved` {level} |
| Reject | `submitted` / `under_review` | application `{ status: "rejected", reason, updatedAt }` + `users/{uid}.kycStatus = "rejected"` + review `reject` | `kyc_rejected` {reason} |

Validation history = the `kyc_reviews` of the application (also visible to the customer). The customer's "Start again" creates a new revision; the panel shows the revisions.

### 6.5 Payment management

#### 6.5.1 Reconciliation of gateway payments

Every gateway payment made by a customer creates `payment_receipts/{method}_{reference}` (`verified: false`) and a deposit posting.

- **Queue:** `payment_receipts` where `verified == false`, `orderBy createdAt`.
- **Check** each receipt with the provider by `reference`: amount, currency, status. Use the provider's API or dashboard, or better, the provider's **webhook received by the panel**.
- **Matches:** `{ verified: true, verifiedAt, verifiedBy }`.
- **Not paid or different:**
  1. reverse the receipt's `txId` (the deposit). If the wallet no longer holds the money, the reversal is impossible, because a wallet never goes below 0. In that case restrict the user (scope `all`), record the amount owed in a ticket and recover it;
  2. mark the receipt `{ verified: false, disputed: true, note }`;
  3. audit.

#### 6.5.2 Queues (manual validation)

Outcome rule for every queue below: the money left the wallet when the customer made the request, so a payout that cannot be made always ends **`reversed`** (reverse the request's `txId`, then `{ status: "reversed", reason, completedAt, processedBy }`). `failed` is used only for requests that took no money (card → wallet, card → card).

| Queue | Query | Complete | Fail / refund |
|---|---|---|---|
| Wallet withdrawals | `wallet_operations` where `type == "withdrawal"` and `status == "pending"` (`destination`, `amount` to pay, `total` already taken) | pay `destination`. `{ status: "completed", payoutReference, completedAt, processedBy }`. Notify `wallet_withdrawal_completed`. | reverse `txId` (money back) → `{ status: "reversed", reason }`. Notify `wallet_withdrawal_failed`. |
| External transfers | `money_transfers` where `status == "processing"` | set `adminLockedAt` when starting (the customer can no longer ask to cancel). Pay the recipient → `{ status: "completed", providerReference, completedAt, recipientVerified: true }` (when the provider confirmed the name). Notify `transfer_sent`. | reverse → `{ status: "reversed", reason }`. Notify `transfer_reversed`. A `cancelRequested: true` transfer not yet paid → reverse → `{ status: "cancelled", reason: "cancelled_by_sender" }`. |
| Bill payments | `utility_payment_requests` where `status == "processing"` | pay the biller → `{ status: "completed", billerReference, customerName?, token?, tokenLabel?, units?, completedAt }`. Notify `bill_paid` (+ `bill_token`). | reverse → `{ status: "reversed", reason }`. Notify `bill_reversed`. |
| Card top-ups | `card_funding_requests` where `type == "fund"` and `status == "pending"` | load `amount` at the issuer → `{ status: "succeeded" }` + `virtual_cards/{cardId}.balance += amount` + `card_transactions` `{ type: "funding", status: "completed", … }`. Notify `card_funded`. | reverse `txId` → `{ status: "reversed", reason }`. Notify `card_funding_failed`. |
| Card → wallet | `type == "withdraw"` | unload at the issuer + post `card_withdrawal` `platform_{CUR}` → `wallet_{uid}_{CUR}` (created if missing), source `{ card_funding_requests, id }` + card `balance −= amount` → `succeeded`. Notify `card_withdrawal_completed`. | `{ status: "failed", reason }` (no money moved) |
| Card → card | `type == "transfer"` | move at the issuer to the recipient's active card in that currency (the newest) + both balances + `card_transactions` on both → `succeeded`. Notify the recipient (`card_transaction`). | `{ status: "failed", reason }` (no money moved; e.g. the recipient has no active card in that currency) |

#### 6.5.3 History, adjustments, bank reconciliation

- **Complete history:** `ledger_transactions` with filters (date, type, user, reference, currency, status) and export (CSV / PDF).
- **Manual adjustment** (four-eyes above the threshold): post `manual_adjustment` between a wallet and `platform_{CUR}` with a mandatory reason; audit.
- **Reversal:** select a posting → `reverse()` (5.2); audit.
- **Bank reconciliation:** per day and currency, compare the movements of `platform_{CUR}` with the bank / provider statements. Record `reconciliations/{yyyy-MM-dd}_{CUR}` = `{ date, currency, expected, actual, difference, notes, by, at }`. Investigate differences.

### 6.6 Card management (with the issuer)

| Action | Writes | Notification |
|---|---|---|
| Issue a requested card (`virtual_cards` where `status == "requested"`) | create at the issuer. Card `{ status: "active", last4, expiryMonth, expiryYear, cardholderName (the verified KYC name), network, balance: 0, updatedAt }`. Issuer tokens go to `virtual_cards_private/{cardId}` (admin only). | `card_created` |
| Refuse | `{ status: "failed", reason }` + reverse `feeTxId` | `card_creation_failed` |
| Apply limits (`card_limit_settings` where `status == "pending"`) | apply at the issuer → `{ status: "applied", appliedAt }`; refused by the issuer → `{ status: "rejected", reason }`. Write **only** these keys: the customer rule checks the whole document, so any other key (a lock, a note) blocks every later change by the customer. | `card_limits_updated` / `card_limits_rejected` (security) |
| Renew (`renewalRequestedAt` set, no `replacedBy`) | create the new card at the issuer and `virtual_cards/{newId}` with the full 3.5 shape: `{ id, userId, label, currency, network, status: "active", balance: <old balance>, termsVersion, acceptedAt (the old card's), reference, last4, expiryMonth, expiryYear, cardholderName, createdAt, updatedAt }`; move the balance at the issuer; old card `{ status: "terminated", balance: 0, replacedBy: <newId>, updatedAt }`. **Keep** the old card's `renewalRequestedAt` (clearing it would let the customer pay a second renewal). | `card_renewed` |
| Close (`status == "termination_requested"`) | close at the issuer + post `card_withdrawal` `platform_{CUR}` → `wallet_{uid}_{CUR}` of the remaining balance (none when 0), source `{ virtual_cards, cardId }` + `{ status: "terminated", balance: 0, updatedAt }` | `card_terminated` (security) |
| Security freeze | `{ status: "frozen", frozenBy: "admin" \| "issuer", frozenAt }` (the customer cannot unfreeze) | `card_frozen` (security) |
| Unfreeze (admin / issuer freeze) | after the review: `{ status: "active", frozenBy: null, unfrozenAt, updatedAt }` | `card_unfrozen` (security) |
| Expire | `{ status: "expired" }` at expiry | `card_expiring` 30 days before |
| Card activity | `card_transactions` from the issuer's verified webhooks (purchases, refunds, declines) + `virtual_cards.balance` | `card_transaction`, `card_transaction_declined`, `card_refund` |
| Monthly fee | post `card_fee` wallet → platform per the terms | — |

**Never** store or log the full card number or the CVV.

### 6.7 Collective savings management

| Action | Preconditions | Writes | Notification |
|---|---|---|---|
| Group withdrawal (`savings_withdrawals` where `status == "requested"`) | goal `active`; the goal's group rules (e.g. up to what the member contributed); amount ≤ `savedAmount` | post `savings_withdrawal` `goal_{id}` → `wallet_{requester}_{CUR}` (created if missing), source `{ savings_withdrawals, id }` + goal `{ savedAmount: increment(-amount), lastTxId, updatedAt }` + withdrawal `{ status: "completed", txId, completedAt, processedBy }` (keep the customer's `reference`) | `savings_withdrawal_completed` |
| Refuse it | — | withdrawal `{ status: "rejected", rejectionReason, processedBy }` (never overwrite the member's own `reason`) | `savings_withdrawal_rejected` |
| Group cancellation (`savings_goals` where `status == "cancellation_requested"`) | — | one transaction: plan, then post one `savings_withdrawal` per member `goal_{id}` → `wallet_{member}_{CUR}`, source `{ savings_goals, goalId }`, of the member's share (Σ their `succeeded` contributions − Σ their `completed` withdrawals, scaled down pro rata if the balance is lower; any rounding remainder to the owner), then goal `{ status: "cancelled", savedAmount: 0, lastTxId, cancelledAt, updatedAt }`. The pool must end at 0. | — |
| Keep the goal | — | `{ status: "active", updatedAt }` | — |
| Target reached | `savedAmount ≥ targetAmount` | **notification only**; the goal stays `active` so members can still withdraw or cancel. Set `completed` only after paying the whole pool out (as the group cancellation, with final status `completed`): every customer exit requires an `active` goal. | `savings_goal_completed` |
| Consultation | goals, members, contributions, withdrawals, `goal_{id}` balance vs `savedAmount` (must match) | — | — |

Reminders (cron): `savings_contribution_due` for goals with a `schedule`.

### 6.8 Tontine management

| Screen / action | Writes | Notification |
|---|---|---|
| Consultation | `tontines` (filters: status, currency), members, cycles, contributions per cycle and member, payouts, disputes, chat (read-only) | — |
| Audit | for each cycle, `collectedAmount` = Σ its `paid` contributions; the pot balance = Σ collected − Σ paid-out payouts; flag differences | — |
| Approve a payout when the beneficiary is the only admin (`tontine_payouts` where `status == "pending_approval"`) | transaction: post `tontine_payout` `tontine_{tid}` → `wallet_{beneficiary}_{CUR}` (amount = the cycle's `collectedAmount`) + payout `{ status: "paid", txId, reference, approvedBy: "admin:{id}", approvedAt, paidAt }` + cycle `{ status: "paid", paidAt }` + next cycle `{ status: "collecting" }` + tontine `{ currentCycle + 1, nextDueAt }` (last: `{ status: "completed", completedAt }`) | `tontine_payout_paid` |
| Suspend / resume | `tontines/{id}.status = "suspended"` / back to `active`; reason in the audit | — |
| Overdue | after a cycle's `dueDate`, for each active member without a `tontine_contributions/{cycleId}_{uid}` document: **notify only**. Never create or edit that document: its id is create-only, so a document written by the panel would stop the member from ever paying and the cycle from completing. | `tontine_contribution_overdue` |
| Disputes (`tontine_disputes`) | `open` → `under_review` → `resolved` / `rejected` with `resolution`, `resolvedBy`, `resolvedAt`; possible member restriction (`tontine_members.status = "restricted"`, `users.financeRestriction`) after a documented decision | — |
| Clean-up | invitations still `invited` after the start → `{ status: "removed" }` | — |

Reminders (cron): `tontine_contribution_due` before each cycle's `dueDate`.

### 6.9 Loan management

| Step | Preconditions | Writes | Notification |
|---|---|---|---|
| Review queue | `loan_applications` where `status == "submitted"` | `{ status: "under_review", updatedAt }` | `loan_submitted` |
| Credit scoring | — | `credit_assessments/{loanId}` = `{ loanId, borrowerId, score, band, factors: [{ label, impact, detail }], assessedAt }` (plain-language factors; the borrower sees them, voters never do) | — |
| Open the vote | `under_review`; eligible voters still members | `{ status: "voting", votingEndsAt: now + voting.durationHours, updatedAt }` | `loan_vote_requested` to each eligible voter |
| Reject | `submitted`, `under_review` or `voting` only (no money yet). For `funding` / `agreement_pending` use "Refund a stuck funding". | `{ status: "rejected", reason, updatedAt }` | `loan_rejected` |
| Close a vote nobody closed | `voting`, after `votingEndsAt` | as the customer close (section 6.9 of the customer spec): `funding` or `rejected` | `loan_funding_open` / `loan_rejected` |
| Instalments due (cron, daily) | an `upcoming` instalment reaches its `dueDate` | `installments[i].status = "due"` (rewrite the whole array, same length) | `loan_repayment_due` |
| Penalties (cron, daily) | instalments past `dueDate` (+ grace) not fully paid | `loan_schedules/{id}.installments[i]` `{ status: "overdue", penalty, amountDue }` + loan `{ status: "overdue", outstandingAmount: increment(penalty), updatedAt }` | `loan_repayment_overdue` |
| Back to active (cron, daily, and after each repayment) | loan `overdue`, `outstandingAmount > 0`, no instalment `overdue` any more | loan `{ status: "active", updatedAt }` | — |
| Default | after a documented review | `{ status: "defaulted", reason }` + restriction | — |
| Refund a stuck funding | `funding` past your deadline, or `agreement_pending` the borrower never accepted | one transaction: `reverse()` each `loan_fundings.txId` (`loan_{id}` → the lender's wallet), funding `{ status: "refunded", updatedAt }`; loan `{ status: "cancelled", reason, cancelledAt, updatedAt }`. The pool must end at 0. | `loan_rejected` (borrower), a refund notice to each lender |
| Pay lenders (optional) | — | post `loan_lender_payout` `loan_{id}` → lender wallet of their share, funding `collected += amount` (lenders can also collect themselves) | `loan_lender_repayment` |
| Rounding sweep | `repaid`, every lender collected, a few units left | post `fee` `loan_{id}` → platform | — |

Reminders (cron): `loan_repayment_due` before each instalment's `dueDate`.

### 6.10 Fund management (investments)

| Screen / action | Writes | Notification |
|---|---|---|
| Funds (create / edit) | `investment_funds/{id}` (all fields of 3.9). `termsVersion + 1` whenever the terms change. `status` open / closed / suspended. `published`. | `investment_terms_updated` to holders |
| Unit prices ("return updates") | each new price: `investment_valuations/{auto}` `{ fundId, date, navPerUnit }` + fund `{ navPerUnit, navDate, performance }`; then revalue every holding of the fund: `currentValue = round(units × navPerUnit)`, `redeemableValue = round(redeemableUnits × navPerUnit)`, `unrealizedGains = currentValue − investedAmount`, `valuedAt`; when `lockedUntil` passes, `redeemableUnits = units` | — |
| Execute subscriptions (`investment_subscriptions` where `status == "paid"`) | at the trade-date price: `fee = round(amount × subscriptionPercent / 100)`, `units = (amount − fee) / navPerUnit` → `{ status: "processing" }` then `{ status: "completed", units, navPerUnit, netAmount, fee, tradeDate }` + upsert `investment_holdings/{uid}_{fundId}` with the **full** 3.9 shape: `{ userId, fundId, fundName, assetClass, currency, units, redeemableUnits (0 while locked up), redeemableValue, investedAmount, currentValue, realizedGains, unrealizedGains, lockedUntil, valuedAt }` (the customer lists holdings by `userId`, and the redemption rule reads `userId`, `units` and `redeemableValue`) + `investment_transactions` `{ userId, fundId, type: "subscription", amount, units, navPerUnit, currency, reference, createdAt }` | `investment_payment_confirmed`, `investment_units_allocated` |
| Refuse a subscription | reverse `txId` (money back) + `{ status: "rejected", reason }` | `investment_subscription_rejected` |
| Execute redemptions (`investment_redemptions` where `status == "submitted"`) | `processing` → `settling` (`navPerUnit`, `units`, `fee = round(gross × redemptionPercent / 100)`, `netAmount`, `tradeDate`, `expectedSettlementDate`) → `settled` (`settledAt`, `txId`): post `investment_redemption` `platform_{CUR}` → `wallet_{uid}_{CUR}` of `netAmount`, source `{ investment_redemptions, id }` (or pay out to `destination`) + holding `units`, `redeemableUnits`, `redeemableValue`, `investedAmount` reduced pro rata, `realizedGains` booked, `currentValue` + `investment_transactions` `{ type: "redemption", … }` | `investment_redemption_processed`, `investment_redemption_settled` |
| Refuse a redemption | `{ status: "rejected", reason }` | `investment_redemption_rejected` |
| Reports | upload a PDF to `investment_reports/{uid}/…` + `investment_reports/{auto}` `{ userId, title, period, storagePath, createdAt }` | `investment_report_available` |

### 6.11 Insurance management

| Screen / action | Writes | Notification |
|---|---|---|
| Partners | `insurance_partners/{id}` `{ name, licenceNumber, country, contact }` (admin only) | — |
| Catalog | `insurance_products/{id}` (3.10 fields; `termsVersion + 1` on term changes; `published`) | — |
| Price a quote (`insurance_quotes` where `status == "requested"`) | `{ status: "quoted", premium, installmentAmount, deductible, coverEnd, validUntil, terms, termsVersion, coverages, documents, insurerReference }` | `insurance_quote_ready` |
| Refuse | `{ status: "rejected", reason }` | `insurance_quote_rejected` |
| Expire (cron) | `quoted` past `validUntil` → `expired` | — |
| Activate (`insurance_policies` where `status == "pending_activation"`) | `{ status: "active", policyNumber, documents, nextPremiumDue }` + the next premiums `insurance_premiums/{policyId}_{n}` (n = 2, 3, …) `{ id, userId, policyId, amount, currency, dueDate, status: "upcoming", createdAt, updatedAt }` | `insurance_policy_active` |
| Refuse after payment | `{ status: "rejected", reason }` + refund (reverse the first premium's `txId`) | `insurance_policy_rejected` |
| Premiums (cron) | `upcoming` → `due` near `dueDate` → `overdue` after; policy `lapsed` per the terms. Keep the policy's `nextPremiumDue` = the earliest unpaid premium's `dueDate` (also after each payment). | `insurance_premium_due`, `insurance_premium_overdue`, `insurance_policy_lapsed` |
| Renewal | before `coverEnd`: `{ status: "renewal_due", renewalPremium, renewalDate }`; when the customer paid (`renewalRequestedAt` set, `renewalTxId` posted): new `coverStart` / `coverEnd`, `{ status: "active" }`, **clear `renewalRequestedAt`**, `renewalTxId`, `renewalPaidAmount` | `insurance_renewal_due`, `insurance_policy_renewed` |
| Auto-renewal (cron, at `renewalDate`) | `renewal_due`, `autoRenew == true`, no `renewalRequestedAt`: if `wallet_{uid}_{CUR}` holds `renewalPremium`, post `insurance_premium` wallet → `platform_{CUR}` of it, source `{ insurance_policies, policyId }`, then renew as above; otherwise notify and leave it `renewal_due` | `insurance_policy_renewed` / `insurance_renewal_due` |
| Expiry (cron) | `renewal_due` past `coverEnd` and not renewed → `{ status: "expired" }` | — |
| Cancellation (`cancellation_requested`) | `{ status: "cancelled" }` (+ refund) or back to `statusBefore` | `insurance_policy_cancelled` |
| Claims queue (`insurance_claims` where `status in ["submitted", "under_review", "approved"]`; `approved` claims still await payment) | `under_review`; `info_requested` + question in `reason` (+ an `events` entry); `approved` + `approvedAmount`; `paid` + `paidAmount`, `paidAt` + post `insurance_claim_payout` platform → wallet; `rejected` + `reason` | `insurance_claim_received`, `_info_requested`, `_approved`, `_paid`, `_rejected` |

### 6.12 Financing review (project owners)

| Action | Writes | Notification |
|---|---|---|
| Queue (`financing_applications` where `status == "submitted"`) | `{ status: "under_review" }` + `financing_reviews/{auto}` `{ ownerId, applicationId, fromStatus, toStatus, publicNote, at }` (the customer reads these). Internal notes: `financing_internal_notes/{auto}` `{ applicationId, authorId, text, at }` (staff only) | `financing_under_review` |
| Document control | `financing_documents/{id}` `{ status: "accepted" \| "rejected", note }` | `financing_document_rejected` |
| Request information | `{ status: "additional_info_required", reason }` + review | `financing_info_required` |
| Approve | `{ status: "approved", approvedAmount, institutionName }` + review | `financing_approved` |
| Reject | `{ status: "rejected", reason }` + review | `financing_rejected` |
| Record funding | `{ status: "funded", fundedAmount, fundedAt }` + review | `financing_funded` |
| Close | `{ status: "closed" }` + review | `financing_closed` |
| Resources | `financial_resources/{id}` (templates, guides, FAQ, regulations; upload files to Storage `financial_resources/…`; `published`) | — |

### 6.13 Content: opportunities, markets, indicators, billers

| Collection | Admin form | Rules for publishing |
|---|---|---|
| `investment_opportunities` | 3.12 fields | only after review; crowdfunding rules per country; the owner's uid goes to the staff-only `opportunity_owners/{opportunityId}`, never to the published document |
| `opportunity_interests` | read-only list per opportunity (name, e-mail, message of interested investors) | share with the project owner only for `interested == true` |
| `economic_indicators` (+ history) | value, previous value, unit, period, source, `sourceUrl`, `updatedAt` | approved sources only (central banks, statistics institutes, IMF / World Bank); never estimated |
| `exchange_rate_snapshots` | from, to, pair, rate, source, kind, `observedAt` | licensed feed; refresh often enough for `maxRateAgeHours` (conversions are refused with older rates) |
| `market_securities`, `market_price_history`, `ipo_listings`, `stock_collections`, `finance_news` | 3.12 fields | licensed market-data feed; `delayed` flag; https links only |
| `utility_billers` | 3.4 fields; `accountPattern` tested on samples | only billers the operations team can pay |

### 6.14 Notifications and templates

- **Templates:** CRUD on `dynamic_notification` (`type`, `subject` = title, `message` with `{placeholders}`, per language). Create every type below. Types marked **(C)** are events the customers cause (a transfer received, a tontine started…): the customer clients send them through the push relay (1.6). Until the relay is live, the mobile app sends them on its legacy path and the website does not send them; everything else is sent by the panel (5.4).

| Module | Types |
|---|---|
| KYC | `kyc_submitted`, `kyc_additional_info_required`, `kyc_approved`, `kyc_rejected` |
| Wallet | deposit, withdrawal completed / failed (create `wallet_deposit_received`, `wallet_withdrawal_completed`, `wallet_withdrawal_failed`) |
| Transfers / bills | `transfer_sent`, `transfer_received` (C), `transfer_failed`, `transfer_reversed`, `bill_paid`, `bill_token`, `bill_failed`, `bill_reversed` |
| Cards | `card_created`, `card_creation_failed`, `card_funded`, `card_funding_failed`, `card_transaction`, `card_transaction_declined`, `card_refund`, `card_withdrawal_completed`, `card_expiring`, `card_renewed`; security (always sent): `card_frozen`, `card_unfrozen`, `card_details_viewed`, `card_limits_updated`, `card_limits_rejected`, `card_terminated` |
| Savings | `savings_invite` (C), `savings_contribution_received`, `savings_contribution_failed`, `savings_contribution_due`, `savings_goal_completed`, `savings_withdrawal_completed`, `savings_withdrawal_rejected` |
| Tontines | `tontine_invite` (C), `tontine_started` (C), `tontine_contribution_due`, `tontine_contribution_received`, `tontine_contribution_overdue`, `tontine_payout_pending_approval` (C), `tontine_payout_paid` (C), `tontine_dispute_raised` (C) |
| Loans | `loan_submitted`, `loan_vote_requested`, `loan_approved`, `loan_rejected` (C), `loan_funding_open` (C), `loan_funded` (C), `loan_agreement_ready` (C), `loan_disbursed` (C), `loan_repayment_due`, `loan_repayment_received` (C), `loan_repayment_overdue`, `loan_lender_repayment` (C), `loan_repaid` (C) |
| Investments | `investment_subscription_received`, `investment_payment_confirmed`, `investment_payment_failed`, `investment_units_allocated`, `investment_subscription_rejected`, `investment_redemption_received`, `investment_redemption_processed`, `investment_redemption_settled`, `investment_redemption_rejected`, `investment_report_available`, `investment_terms_updated` |
| Insurance | `insurance_quote_ready`, `insurance_quote_rejected`, `insurance_policy_active`, `insurance_policy_rejected`, `insurance_premium_due`, `insurance_premium_overdue`, `insurance_policy_lapsed`, `insurance_renewal_due`, `insurance_policy_renewed`, `insurance_policy_cancelled`, `insurance_claim_received`, `insurance_claim_info_requested`, `insurance_claim_approved`, `insurance_claim_rejected`, `insurance_claim_paid` |
| Financing | `financing_submitted`, `financing_under_review`, `financing_info_required`, `financing_document_rejected`, `financing_approved`, `financing_rejected`, `financing_funded`, `financing_closed` |
| Intelligence / chat | `intelligence_new_match`, `intelligence_interest_received`, `finance_chat_message` (C; placeholders `{senderName}`, `{chatName}`, `{message}`) |

- **Channels:** push + Notification Center for every decision; **SMS** for critical transactions (withdrawals, transfers, card security, overdue); **e-mail** for receipts and alerts. Honour `financeNotificationPrefs` except for security notices.
- **Push relay:** host the relay of 1.6 (a panel endpoint using the Admin SDK `Messaging`, or a Cloud Function) and set `settings/notification_setting.serverPushUrl`, so customer clients stop holding FCM credentials; then remove `serviceJson` and delete that service-account key.

### 6.15 Incident management (complaints, support, tickets)

- **Support chat:** the existing `chat/{uid}/thread` conversations (help and support).
- **Tickets:** `support_tickets/{id}` = `{ userId, subject, category ("payment" | "transfer" | "card" | "loan" | "tontine" | "savings" | "insurance" | "kyc" | "other"), relatedRef (a reference or a document path), status ("open" | "in_progress" | "resolved" | "closed"), priority ("low" | "normal" | "high" | "urgent"), assignedTo, messages (subcollection `messages`: { authorId, authorType: "admin" | "customer", text, createdAt }), createdAt, updatedAt, resolvedAt }`.
  - Created by support from a chat, a complaint or a failed operation.
  - Linked from the user's detail page.
  - SLA timers by priority.

### 6.16 Reporting

| Report | Source |
|---|---|
| Number of users (total, verified, restricted, by country, new per period) | `users` (`count()` with filters) |
| Assets under management (per fund, per currency) | Σ `investment_holdings.currentValue` |
| Money held (per currency) | Σ wallet balances; the platform position |
| Contribution volumes (savings, tontines; per period) | Σ `savings_contributions.amount` / `tontine_contributions.amount` where status succeeded / paid |
| Activity statistics (per type, per period) | `ledger_transactions` counts and sums by `type` |
| Loans (requested, funded, active, overdue, defaulted; amounts) | `loan_applications` |
| Insurance (policies, premiums collected, claims, loss ratio) | `insurance_*` |
| Payout queues and processing times | request documents' `createdAt` → `completedAt` |

Use Firestore aggregation queries for live tiles; for history and heavy reports, schedule a nightly **export to BigQuery** (Firebase extension "Stream Firestore to BigQuery" or managed exports). Export CSV / PDF.

### 6.17 Security and data protection

- **Panel sign-in:** individual admin accounts; **2FA mandatory** (TOTP); session timeout (e.g. 30 min idle); IP allow-list if possible; lockout after failed attempts.
- **Session management:** list and revoke active admin sessions.
- **Customers:** revoke a customer's sessions with `Auth::revokeRefreshTokens(uid)` (e.g. after fraud).
- **Least privilege:** the roles of 5.3.
- **Data protection:**
  - Firestore and Storage are encrypted at rest by Google; TLS everywhere;
  - customer passwords are handled by Firebase Auth (the panel never stores them); admin passwords hashed with bcrypt / argon2;
  - **daily scheduled Firestore exports** to a Cloud Storage bucket, plus Point-in-time recovery; restore tested;
  - KYC files read only through signed URLs; card numbers never stored.

### 6.18 Audit (complete logging, traceability)

Every write made by the panel also writes:

```
admin_audit_logs/{autoId} = { adminId, adminEmail, role, action, collection, docId, before (changed fields), after, reason, ip, userAgent, at }
```

Rules for the log:
- **append-only:** nobody, not even an admin through the panel, can edit or delete it;
- searchable by admin, user, document and date;
- kept for the legal retention period.

## 7. Scheduled jobs (cron)

| Job | Frequency | Does |
|---|---|---|
| Reconcile gateway receipts | every 15 min (or webhook) | 6.5.1 |
| Exchange rates and market data | per the feed (≤ hourly for rates) | 6.13 |
| Unit prices and revaluation | per fund's valuation calendar | 6.10 |
| Execute subscriptions / redemptions | per the funds' cut-off | 6.10 |
| Tontine reminders and overdue notices | daily | 6.8 |
| Loan instalments due, penalties, back to active | daily | 6.9 |
| Savings schedule reminders | daily | 6.7 |
| Insurance: quote expiry, premiums and `nextPremiumDue`, renewals, auto-renewals, lapses, expiry | daily | 6.11 |
| Card expiry reminders, monthly fees | daily / monthly | 6.6 |
| Close votes past `votingEndsAt` | hourly | 6.9 |
| Refund stuck loan fundings | daily | 6.9 |
| Daily bank reconciliation | daily | 6.5.3 |
| Firestore backup export | daily | 6.17 |

## 8. Acceptance criteria and go-live checklist

**Each queue** shows the oldest first, locks an item while an admin works on it, completes it in one transaction, sends its notification and writes its audit entry. The lock lives in the panel's own database. The only lock written to Firestore is `money_transfers.adminLockedAt` (the customer's cancel rule reads it); never add a lock or note field to another customer document (`card_limit_settings` is checked as a whole document, so an extra key would block the customer).

**Before go-live:**
1. Merge the finance rules (`firestore.rules.draft`) with the live rules (draft 184 KB, limit 256 KB). Run `finance/rules-test` on the merged file, then deploy. Deploy the indexes of `.claude/firestore.indexes.json`.
2. Create every `platform_settings` document, `platform_settings/wallet`, the `platform_{CUR}` accounts and the notification templates (including `finance_chat_message`).
3. Configure the gateways per region (publishable keys in `settings/*`; secrets in the panel) and their webhooks to the panel.
4. Deploy the push relay (1.6), set `serverPushUrl`, then retire `serviceJson` and revoke that key. Upload an APNs key for each iOS app in the Firebase console, or no iPhone receives any push.
5. Enable Identity Platform with SMS multi-factor (two-step verification) and, if wanted, the LinkedIn OpenID Connect provider.
6. Contract the partners whose features stay hidden until then (card issuer, biller APIs, market-data feed, broker, AI server).
7. Turn on the daily backups and Point-in-time recovery; test a restore.
8. Run the joint test plan of the customer specification (section 8) with the panel processing every request.

## Appendix R. Security rules reference (shared)

> This appendix is **identical** in both specifications. It condenses the finance block of `firestore.rules.draft` (lines 1133–2987; admin wildcard 2989–2995) into the exact checks every customer write must pass. It was cross-checked against the rules test suite `finance/rules-test/` (79/79 passing), whose `lib/fixtures.js` `plan()` is a port of the app's `FinanceLedger.plan`. "L1234" = a line of `firestore.rules.draft`.
>
> - **Customer website developer:** every write shape of section 6 of `SPIDELI_FINANCE_CUSTOMER_WEB_SPEC.md` must pass these checks. When a write is refused (`permission-denied`), compare the batch with the matching entry here.
> - **Admin panel developer:** the Admin SDK bypasses the rules, so the panel must keep the invariants itself, and must maintain the admin-owned state the customer rules read (R.14.4).
>
> Notation: "== now" = written with `serverTimestamp()` in this request (`== request.time`); "stamp" = absent or `serverTimestamp()` on the whole resulting document (so re-send it on every write); "stampCh" = only when the field changes, its new value is `serverTimestamp()`; "pre-state" = `get()` (before the batch); "after-state" = `getAfter()` (after the whole batch).

### R.0 Global conventions (apply everywhere)

**Value types and validators**

| Item | Rule (line) |
|---|---|
| Amounts | `int` (Firestore integerValue) in minor units. `fPos` = 1..10^12, `fNonNeg` = 0..10^12 (L1192-1193). A double amount is refused. Percent fields may be doubles. |
| ids | `fIdOk` = `^[A-Za-z0-9_-]{1,200}$` (L1189). Currency `fCurOk` = `^[A-Z]{3}$` (L1190). |
| strings | `fStr(v,min,max)` = a string with length in [min,max]. `fOptStr(m,k,max)` = absent, null, or a string of length ≤ max (L1194-1195). `fDate` = null, timestamp or string (L1200). |
| "now" | `== request.time`. The field must be written with `serverTimestamp()` in this request. |
| "stamp" | `fStamp` (L1198): the field is absent or `serverTimestamp()`. It is evaluated on the **whole resulting document**, so an older stored value fails it. If the field exists, re-send it as `serverTimestamp()` on every write. |
| "stampCh" | `fStampCh` (L1550): only if the key changes in this update, its new value must be `serverTimestamp()`. |
| per-currency setting | `fPerCur` (L1203): `{XAF: 1000}` or a plain number. `fMinOk` / `fMaxOk` (L1204-1205) enforce only when a number resolves for that currency. |
| fee formula | `fFee(cfg,cur,amount)` (L1210-1214): `raw = math.round(amount*feePercent/100) + feeFixed[cur]`. If `feeMax[cur] > 0 && raw > feeMax`, the fee is `feeMax`. The client's `fee` must be **≥** this (overpaying is accepted). |

**How batches and rule reads behave**
- Every operation is **one WriteBatch / commit**.
- `get()` returns the state before the batch; `getAfter()` returns the state after the whole batch.
- Limits: 10 distinct docs read per write, 20 per batch, 1000 expressions per write (README).
- **Update writes:** use `update()` with only the intended fields. The rules check `diff().affectedKeys()`. A `set()` without merge drops absent fields, and those count as changed.
- **Settings docs must exist:** `fSetting(id)` = `get(platform_settings/{id}).data` (L1187). A missing settings doc makes the write fail.

**Admin**
- `isAdmin()` (L79-81) = signed in AND (`token.admin == true` OR `users/{uid}.role == 'admin'`). The role check costs one read.
- The wildcard `match /{document=**} { allow read, write: if isAdmin(); }` (L2993-2995) lets an admin client read and write **every** finance path, including subcollections, with **no validation**.
- **No finance collection is closed to an admin client.**
- Rules do not apply at all to the Admin SDK. The header (L1140-1142) says the PHP panel uses the Admin SDK.
- Collections with no client rule are admin-only: `insurance_partners`, `virtual_cards_private`, `utility_payment_transactions` (L2982-2983, L1856, L2670).

**Customer DELETE** is refused on every finance collection except:
- `transfer_beneficiaries` (owner)
- `utility_saved_accounts` (owner)
- `financing_documents` (owner, under conditions)

---

### R.1 Helpers (L44-105, L1182-1239)

- `signedIn()` = `request.auth != null` (L44).
- `uid()` = `request.auth.uid` (L45).
- `hasProfile()` = `exists(users/{uid})` (L67).
- `myProfile()` = `get(users/{uid}).data` (L68).
- `myRole()` = `users/{uid}.role` (L69).
- `fFresh()` (L1218): `token.auth_time * 1000 > request.time.toMillis() - 300000`. The ID token's sign-in time must be **less than 5 minutes ago**.
- `fReauthOk(cfg,cur,amount)` (L1222-1225) passes when either:
  - `fFresh()`, OR
  - `cfg.security.reauthAbove` is a map, `reauthAbove[cur]` is a number > 0, and `amount < reauthAbove[cur]`.
  - So a currency with no threshold (or a threshold ≤ 0) **always** needs re-auth.
- `fRestricted(scope)` (L1235-1239) is true when `users/{uid}.financeRestriction` is a map AND `string(status).trim().lower() == 'restricted'` AND one of:
  - `scopes` is not a list, OR
  - `scopes` is empty, OR
  - `scopes` contains `'all'` or `scope`.

---

### R.2 `users/{uid}` finance fields (L480-530; identityKeys L292-294; identitySame L387-395)

**Read:** any signed-in user can read any profile (L513). Finance relies on this for recipient lookup by email or phone, member names and push tokens, and the caller's own `financeRestriction`.

**Field rules**
- **`financeRestriction`, `kycLevel`, `kycStatus`** (`financeServerKeys`, L486):
  - Never set or changed by a non-admin, either on create or on update.
  - Not on yourself (including deleting your own restriction), and not on anyone else.
  - Only the admin, or the Admin SDK, writes them.
- **`financeNotificationPrefs`** (L488-504):
  - Only the account itself may set or change it.
  - Allowed values: `null`, or a map with keys ⊆ `{push, sms, email}`.
  - Each channel is a map with keys ⊆ `{payments, groups, loans, investments, insurance, news}`, each a `bool`.
  - Staff-create and other-user updates may not touch it.
- **`savedPaymentMethods`** is in `identityKeys`:
  - **Self:** free to change. It is not a privileged key; only `selfUpdateOk()` applies.
  - **Other users:** must leave it unchanged (`identitySame`), except a fleet owner on its driver or a store manager on its staff. Their paths don't check identity keys (L445-451).

**Write branches**
- **Create (L515-518):**
  - Self: `signupFieldsOk() && newWalletZero() && financeUserKeysOk(keys, true)`.
  - Or `isAdmin()`.
  - Or staff-create with `financeUserKeysOk(keys, false)`.
- **Update (L523-526):**
  - Self: `selfUpdateOk() && financeUserKeysOk(changedKeys, true)`.
  - Or admin.
  - Or another user: `otherUpdateOk() && financeUserKeysOk(changedKeys, false)`.

---

### R.3 Ledger core

#### R.3.1 `ledger_transactions/{txId}` (L1241-1440)

**ID:** `^tx_[0-9]{10,16}_[A-Za-z0-9_]{4,40}$` (L1243). The app uses `tx_{millis}_{8 chars}`.

**Read (L1437):** `uid in resource.data.userIds`. A list query must use `where('userIds','array-contains',uid)`.

**Update and delete:** never by a client (L1439). Reversals are admin-only.

**Allowed customer types (`fClientTxTypes`, L1251-1256):**
`deposit, withdrawal, transfer, transfer_out, bill_payment, card_funding, card_fee, savings_contribution, savings_withdrawal, tontine_contribution, tontine_payout, loan_funding, loan_disbursement, loan_repayment, loan_lender_payout, investment_subscription, insurance_premium, conversion`.
Admin-only types: `reversal`, `manual_adjustment`, `fee`.

**Create algorithm** (`fTxCreateOk` → `fTxShapeOk` L1305-1318 → `fTxPostedOk` L1330-1335):

1. **Keys:**
   - Allowed: `id, type, status, reference, currency, lines, userIds, accountIds, source, funding, gateway, description, createdBy, createdAt`.
   - Required: all of those except `gateway` and `description`.
2. **Field values:**
   - `id == txId`, `status == 'posted'`, `type ∈ fClientTxTypes`.
   - `reference`: string, 1..40 chars.
   - `currency`: `^[A-Z]{3}$`.
   - `createdBy == uid`; `createdAt == request.time`.
   - `description`: optional string, ≤500 chars.
3. **`source`:** a map with keys only `{kind, id}`. `kind` matches `^[a-z_]{1,40}$`; `id` passes `fIdOk`.
4. **`funding`:**
   - `'wallet'`: the `gateway` key must be absent.
   - `'gateway'`: `gateway` must be exactly `{method, reference}`, with `method` matching `^[a-z0-9_]{2,40}$` and `reference` a 1..200 char string (`fGatewayOk`, L1298-1301).
5. **`userIds`:** a list of 1..3 entries.
6. **`lines`** (`fLinesOk`, L1279-1294). Each line is exactly `{accountId (fIdOk), direction, amount (fPos int)}`.
   - `lines[0]` is the **only debit** (`direction:'debit'`). `lines[1]` is a credit, and `lines[0].accountId != lines[1].accountId`.
   - With 2 lines: `lines[0].amount == lines[1].amount`.
   - With 3 lines: `lines[2]` is a credit to **`'platform_' + currency`** (the fee line), distinct from lines 0 and 1, and `lines[0].amount == lines[1].amount + lines[2].amount`.
   - So a fee line can only exist when neither line 0 nor line 1 is the platform account.
7. **`accountIds`:** exactly `[lines[0].accountId, lines[1].accountId(, lines[2].accountId)]`, in the same order (L1296, L1317).
8. **Every line's account is written in this batch.** `getAfter(financial_accounts/{id}).lastTxId == txId` for line 0, line 1, and line 2 if present (L1331-1332).
9. **userIds rule** (`fTxUsersOk`, L1337-1342). Owners = the `userId` of `a0` / `a1` (after-state of line 0 and line 1 accounts) when their `kind == 'wallet'`.
   - `userIds.toSet() ⊇ owners`.
   - `userIds.toSet() ⊆ owners ∪ {uid}`.
10. **Debit authorization** (`fTxDebitOk`, L1345-1352) depends on `a0.kind`:

| a0.kind (debited) | Who | Allowed (rule) |
|---|---|---|
| `wallet` (L1363-1367) | its owner: `a0.userId == uid` | `funding=='wallet'`; `type != 'deposit'`; `fCreditKind[type] == a1.kind`; `fRecordOk`. |
| `platform` (L1372-1381) | any caller, two cases | **(A) gateway:** `funding=='gateway'`; `type ∈ [deposit, savings_contribution, tontine_contribution, loan_funding, loan_repayment]`; `fCreditKind[type]==a1.kind`; `fRecordOk`; `getAfter(payment_receipts/{method}_{reference with every '/'→'_'}).txId == txId`. **(B) conversion leg 2:** `funding=='wallet'`, `type=='conversion'`, `a1` is the caller's own wallet, `source.kind=='wallet_operations'`, and that op (after-state) has `userId==uid`, `txId ∈ op.txIds`, and `op.txId != txId`. |
| `savings_goal` (L1387-1395) | the solo goal owner | `type=='savings_withdrawal'`, wallet funding, 2 lines, `a1` = the caller's wallet. Goal (pre-state): `ownerId==uid`, `memberIds` set == `{uid}`, `status=='active'`. `getAfter(goal).lastTxId==txId`. Then either `source={savings_withdrawals,id}` with that record's `txId==txId`, or `source={savings_goals, refId}` with the goal's after-status `'cancelled'`. |
| `tontine_pot` (L1399-1409) | a tontine admin who is **not** the beneficiary | `type=='tontine_payout'`, wallet funding, 2 lines, `a1` is a wallet, `source.kind=='tontine_payouts'`. Tontine (pre-state): `uid ∈ adminIds`, `status=='active'`. Payout p (pre-state): `p.tontineId==refId`, `p.status=='pending_approval'`, `p.cycleNumber==tontine.currentCycle`, `p.beneficiaryUserId==a1.userId`, `p.beneficiaryUserId != uid`. `lines[0].amount==p.amount`. Payout after-state: `status 'paid'`, `txId==txId`. |
| `loan` (L1413-1424) | the borrower, or a lender | Wallet funding, `a1` = the caller's wallet. **Disbursement:** `type 'loan_disbursement'`, `source={loan_disbursements, loanId}`, `loan.borrowerId==uid`, loan pre-status `'agreement_pending'`, `lines[0].amount == loan.fundedAmount`, loan after-status `'active'`, `getAfter(loan_disbursements/{loanId}).txId==txId`, and **`!fRestricted('loans')`**. 2 lines, or 3 with a fee line. **Lender payout:** `type 'loan_lender_payout'`, 2 lines, `source.kind 'loan_fundings'`, `uid ∈ loan.lenderIds`, loan status ∈ `[active, overdue, repaid, defaulted]`, and `fLenderShareOk`. |

**`fCreditKind`** (L1260-1265) maps each type to the kind of account its `lines[1]` credits:

| Credited kind | Types |
|---|---|
| wallet | `deposit`, `transfer` |
| platform | `withdrawal`, `conversion`, `transfer_out`, `bill_payment`, `card_funding`, `card_fee`, `investment_subscription`, `insurance_premium` |
| savings_goal | `savings_contribution` |
| tontine_pot | `tontine_contribution` |
| loan | `loan_funding`, `loan_repayment` |

**`fRecordOk`** (L1355-1360) reads `r = getAfter(source.kind / source.id)` and passes when any of these holds:
- `source.kind == fRecordOf[type]` AND (`r.txId == txId`, OR for a conversion, `txId ∈ r.txIds`).
- `type=='card_fee'` AND `source.kind=='virtual_cards'` AND (`r.feeTxId==txId` OR `r.renewalTxId==txId`).
- `type=='insurance_premium'` AND `source.kind=='insurance_policies'` AND `r.renewalTxId==txId`.

**`fRecordOf`** (L1266-1272) maps each type to its request collection:

| Type | Request collection |
|---|---|
| `deposit`, `withdrawal`, `conversion` | `wallet_operations` |
| `transfer`, `transfer_out` | `money_transfers` |
| `bill_payment` | `utility_payment_requests` |
| `card_funding` | `card_funding_requests` |
| `card_fee` | `virtual_cards` |
| `savings_contribution` | `savings_contributions` |
| `tontine_contribution` | `tontine_contributions` |
| `loan_funding` | `loan_fundings` |
| `loan_repayment` | `loan_repayments` |
| `investment_subscription` | `investment_subscriptions` |
| `insurance_premium` | `insurance_premiums` |

**`fLenderShareOk`** (L1428-1434). With `f0 = get(loan_fundings/source.id)` and `f1 = getAfter(...)`:
- `f0.lenderId==uid`, `f0.loanId==loanId`, `f0.status` (default `'succeeded'`) == `'succeeded'`.
- `f1.collected - f0.collected == lines[0].amount`.
- `f1.collected <= loan.repaidAmount * f0.amount / loan.amount`. This is integer division, so it truncates.

**Gateway rule:** a gateway payment can directly fund only `deposit` (to the payer's wallet) and the four pool types (`savings_contribution`, `tontine_contribution`, `loan_funding`, `loan_repayment`). Everything else paid by a gateway works in two steps:
1. A gateway deposit into the payer's wallet, with `purpose`.
2. A separate wallet-funded posting.

#### R.3.2 `financial_accounts/{accountId}` (L1442-1520)

**ID formats:**
- Wallet: `wallet_{userId}_{CUR}`.
- Pools: `goal_{goalId}`, `tontine_{tontineId}`, `loan_{loanId}` (`fPoolPrefix`, L1447).
- Platform: `platform_{CUR}`, created by the admin only.

**Read**
- **get (L1516):** allowed if the doc is missing (it reads as not-found), or if `fAccountReadOk` (L1449-1454) passes:
  - `a.userId==uid`, OR `uid ∈ a.memberIds`, OR
  - a savings_goal account and `uid ∈ savings_goals/{refId}.memberIds`, OR
  - a tontine_pot account and `uid ∈ tontines/{refId}.memberIds`, OR
  - a loan account and the caller is the borrower, a lender, or an eligible voter (`fLoanParty`).
  - Someone else's existing wallet is **denied**. The client must treat permission-denied as "exists".
- **list (L1517):** `userId == uid`, or `memberIds array-contains uid`. Tontine and loan accounts are get-only.

**Create** (`fAccountCreateOk`, L1459-1471)
- Allowed keys: `id, kind, userId, refId, currency, memberIds, balance, normalSide, status, lastTxId, createdAt, updatedAt`.
- Required keys: `id, kind, currency, balance, normalSide, status`.
- Values: `id == docId`, `currency` valid, `normalSide=='credit'`, `status=='active'`, `balance is int`, `createdAt` and `updatedAt` stamp.
- **Wallet:**
  - `kind=='wallet'`, no `refId` or `memberIds`, `userId` passes `fIdOk`, and `id == 'wallet_'+userId+'_'+currency`.
  - Must pass `fFirstCreditOk` (L1473-1476): `lastTxId` is a posting created in this request (`fTxNow`), with the same currency, `lines[1].accountId == id`, and `balance == lines[1].amount`.
  - **This is how a sender creates a missing recipient wallet.** Doc shape: `{id, kind:'wallet', userId:<recipient>, currency, balance:<credited amount>, normalSide:'credit', status:'active', lastTxId:txId, createdAt:serverTs, updatedAt:serverTs}`. It can only be the posting's `lines[1]`.
- **Pool:**
  - `kind ∈ [savings_goal, tontine_pot, loan]`, no `userId`, `refId` passes `fIdOk`, and `id == prefix+refId`.
  - `memberIds` is allowed only on a savings_goal, and must equal `getAfter(savings_goals/refId).memberIds`.
  - Then either first credit (`fFirstCreditOk`) or `fPoolOpenOk` (L1478-1483):
    - `balance==0` and `lastTxId` absent, null, or `''`.
    - Creator check (after-state): goal `ownerId==uid` / `uid ∈ tontine.adminIds` / `loan.borrowerId==uid`.

**Update** (`fAccountUpdateOk`, L1489-1502). Two branches:
- **A. Posting branch.** Changed keys ⊆ `{balance, lastTxId, updatedAt}`, and both `balance` and `lastTxId` must change. Then:
  - `fTxNow(n.lastTxId)`.
  - Old `status=='active'` (a frozen account cannot move).
  - Posting currency == account currency.
  - `n.balance is int`, and `n.balance >= 0` unless `kind=='platform'` (the platform account may go negative).
  - `updatedAt` == now if it changed.
  - `n.balance - o.balance == fLineDelta`: minus the amount if this account is `lines[0]`, plus the amount if it is `lines[1]` or `lines[2]`, otherwise impossible.
  - Client form: `update({balance: increment(±amount), lastTxId: txId, updatedAt: serverTimestamp()})`.
- **B. Member sync branch.** Changed keys ⊆ `{memberIds, updatedAt}`, `kind=='savings_goal'`, and `n.memberIds == get(savings_goals/refId).memberIds`.
  - This uses **get(), the pre-batch state**, so the sync must happen in a later write, after the goal's membership has changed.
  - `updatedAt` is not checked here, and no caller check is made.

**Delete:** none.

#### R.3.3 `payment_receipts/{method}_{reference}` (L1522-1542)

**ID:** `method + '_' + reference.replace('/', '_')`. In rules, `replace` is a global regex replace, so every `/` becomes `_`.

**Read:**
- get: the doc is missing, or `userId==uid`.
- list: `userId == uid`.

**Create** (L1527-1536):
- Keys ⊆ `{method, reference, txId, amount, currency, userId, verified, createdAt}`, all effectively required. **No `id` key.**
- `userId==uid`, `verified==false`, `createdAt == now`.
- `{method, reference}` passes `fGatewayOk`, and the doc id equals the formula above.
- `amount` passes `fPos`; `currency` valid.
- `fTxNow(txId)`: the posting is created in the same batch, with `funding=='gateway'`, `gateway == {method, reference}`, the same currency, and `amount >= posting.lines[0].amount`. The tests use `amount + fee`.

**Update / delete:** never. A receipt is create-only, so each gateway payment can fund only one posting.

---

### R.4 Wallet operations: `wallet_operations/{opId}` (L1544-1631)

**ID:** free-form. A deposit that pays a request uses the receipt id by app convention; this is not enforced.

**Read:**
- get: the doc is missing, or `userId==uid`.
- list: `userId==uid`.

**Update / delete:** never.

**Common create checks** (`fOpCreateOk`, L1552-1559):
- `id` (optional) == opId; `userId==uid`; `currency` valid; `amount` passes `fPos`.
- `createdAt` == now; `reference` optional, ≤40 chars.
- `type ∈ {deposit, withdrawal, conversion}`.

**deposit** (L1561-1577)
- **Keys** ⊆ `id, userId, type, status, currency, amount, fee, total, accountId, gateway, txId, reference, purpose, createdAt, completedAt`.
- **Field values:**
  - `status=='completed'`; `completedAt` stamp.
  - `fee` absent or 0; `total` absent or == `amount`.
  - `gateway` passes `fGatewayOk`.
- **Posting** (`fTxNow(txId)`):
  - `type 'deposit'`, `funding 'gateway'`, `gateway == d.gateway`.
  - `source == {kind:'wallet_operations', id:opId}`; same currency.
  - `lines[1].amount == amount`; `userIds == [uid]`.
  - `accountId` absent or == `lines[1].accountId`.
  - Shape: 2 lines, `platform_{CUR}` → `wallet_{uid}_{CUR}`.
- **Limits and restriction:**
  - If `purpose` is present: it is a map with keys ⊆ `{kind, id}`, and there is **no** limit or restriction check.
  - Otherwise: `platform_settings/wallet.deposit.enabled == true`, deposit min/max, and **`!fRestricted('wallet')`**.
- **No re-auth.**

**withdrawal** (L1581-1593)
- **Keys** ⊆ `id, userId, type, status, currency, amount, fee, total, accountId, destination, txId, reference, createdAt`.
- **Field values:**
  - `status=='pending'`; `fee` passes `fNonNeg` (required); `total` absent or == `amount+fee`.
  - `destination`: a map with ≤12 entries, and `destination.method ∈ wallet.withdraw.methods`.
- **Settings and fee:**
  - `withdraw.enabled == true`; min/max on `amount`.
  - `fee >= fFee(wallet.withdraw, cur, amount)`.
- **Re-auth and restriction:**
  - **`fReauthOk(platform_settings/wallet, cur, amount)`**.
  - **`!fRestricted('wallet')`**.
- **Posting:** `type 'withdrawal'`, `source == {wallet_operations, opId}`, same currency, 2 lines, `lines[0].amount == amount+fee`. Wallet → `platform_{CUR}`; the platform keeps the fee.

**conversion** (L1595-1625)
- **Keys** ⊆ `id, userId, type, status, currency, amount, fee, total, accountId, toCurrency, toAccountId, rate, rateSource, rateObservedAt, rateSnapshotId, receiveAmount, txId, txIds, reference, createdAt, completedAt`.
- **Field values:**
  - `status=='completed'`.
  - `toCurrency` valid and != `currency`.
  - `receiveAmount` passes `fPos`; `fee` passes `fNonNeg` and `fee < amount`.
- **Settings:** `wallet.convert.enabled == true`, and both currencies ∈ `convert.currencies`.
- **Rate snapshot:** `rateSnapshotId` (passes `fIdOk`, **required**). With `s = get(exchange_rate_snapshots/rateSnapshotId)`:
  - `s.rate` is a number > 0.
  - The pair is `(s.from==currency && s.to==toCurrency)` or the inverse.
  - `s.observedAt > request.time - maxRateAgeHours` hours. `maxRateAgeHours` is `convert.maxRateAgeHours` when it is an int > 0, else 48.
- **Fee:** `fee >= math.round(amount * convert.feePercent / 100)`. There is no fixed or max component.
- **Receive cap:**
  `float(receiveAmount) <= float(amount - fee) * R * 10^(exp(toCurrency) - exp(currency)) + 0.000001`
  - `R = s.rate` if `s.from == currency`, else `1.0/s.rate`.
  - `exp(cur)` = 0 for `XAF, XOF, GNF, RWF`, else 2 (`fExp`, L1596).
  - Worked example from the tests: 100000 XAF, fee 1000, rate 655.957 EUR→XAF gives a cap of `99000/655.957*100 = 15092.4`, so 15092 cents is accepted.
- **Legs:**
  - `txIds` is a list of exactly 2, and `txIds[0] == txId`.
  - **`!fRestricted('wallet')`**.
  - No re-auth. `completedAt` and `total` are not checked; the tests send `total = amount`.
  - `fConversionLegsOk` (L1618-1625) requires both legs `fTxNow`:
    - **leg1:** `type 'conversion'`, `source {wallet_operations, opId}`, currency = `currency`, 2 lines, `lines[0].amount == amount` (the whole amount, fee included, leaves the wallet), `lines[1].accountId == 'platform_'+currency`.
    - **leg2:** `type 'conversion'`, same source, currency = `toCurrency`, 2 lines, `lines[0].accountId == 'platform_'+toCurrency`, `lines[1].amount == receiveAmount`, `userIds == [uid]`.
  - leg2 credits `wallet_{uid}_{toCur}`, creating it by first credit if it is missing.

---

### R.5 Transfers and bills

#### R.5.1 `money_transfers/{transferId}` (L1635-1689)

**Read:** `uid ∈ participantIds`. A list query uses `participantIds array-contains uid`.

**Create** (`fTransferCreateOk`):
- **Keys** ⊆ `id, senderId, senderName, recipientId, participantIds, channel, recipient, recipientName, recipientVerified, currency, amount, fee, total, receiveAmount, note, funding, createdAt, status, reference, txId, completedAt`.
- **Field values:**
  - `id` optional; `senderId==uid`.
  - `senderName` ≤200, `recipientName` ≤200, `note` ≤500 (all optional).
  - `recipient`: a map with ≤12 entries.
  - `currency ∈ transfers.currencies`.
  - `amount` passes `fPos`; `fee` passes `fNonNeg`; `total == amount+fee`; `receiveAmount == amount`.
  - `reference`: 1..40 chars; `createdAt` == now.
- **Channel config** `ch = transfers.channels[channel]`:
  - `ch.enabled == true`; min/max on `amount`.
  - `fee >= fFee(ch, cur, amount)`.
- **Re-auth:** **`fReauthOk(platform_settings/transfers, cur, amount)`**.
- **Funding:** `funding == {method:'wallet'}` (and then `'wallet' ∈ transfers.sourceMethods`), or `funding` is a gateway map `{method, reference}`.
- **Restriction:** **`!fRestricted('transfers')`**.

**Internal channel** (L1656-1663):
- `status 'completed'`; `completedAt` == now; `recipientVerified == true`.
- `recipientId` passes `fIdOk` and `!= uid`.
- `participantIds == [uid, recipientId]`, in **that exact order**.
- Posting:
  - `type 'transfer'`, `funding 'wallet'`, `source {money_transfers, id}`, same currency.
  - `lines[1].amount == amount`, and `getAfter(lines[1].accountId).userId == recipientId`.
  - `lines[0].amount == total`.
  - Lines: 2 if `fee==0`, else exactly 3 with `lines[2].amount == fee`.
  - Path: sender wallet → recipient wallet (+ fee line to `platform_{CUR}`).

**External channel** (L1667-1672):
- `channel ∈ [mobile_money, wave, bank]`; `status 'processing'`.
- No `recipientId` or `completedAt` keys; `participantIds == [uid]`.
- Posting: `type 'transfer_out'`, `source {money_transfers, id}`, same currency, 2 lines, `lines[0].amount == total`. Wallet → `platform_{CUR}`.

**Update, the sender's cancel request** (L1676-1682):
- `o.senderId==uid`, `o.channel != 'internal'`, `o.status=='processing'`.
- `o.adminLockedAt` null or absent; `o.cancelRequested != true`.
- Changed ⊆ `{cancelRequested, cancelRequestedAt}`.
- `cancelRequested == true`; `cancelRequestedAt` stamp.

**Delete:** none.

#### R.5.2 `transfer_beneficiaries/{id}` (L1692-1702)

**ID:** `^ben_{uid}_.{1,300}$`.

**Read:** owner (`userId==uid`).

**Create:**
- Keys ⊆ `userId, channel, displayName, detail, recipient, createdAt, lastUsedAt`. **No `id` key.**
- `userId==uid`; `recipient` (required) is a map with ≤12 entries.
- `displayName` ≤200 and `detail` ≤200, optional.
- `channel` and the timestamps are not validated.

**Update:** owner; changed ⊆ `{lastUsedAt, displayName}`.

**Delete:** owner.

#### R.5.3 `utility_payment_requests/{requestId}` (L1704-1724)

**Read:** owner.

**Create:**
- **Keys** ⊆ `id, userId, billerId, billerName, category, account, customerName, packageCode, packageName, currency, amount, fee, total, status, reference, txId, funding, createdAt`.
- **Field values:**
  - `id` optional; `userId==uid`; `status 'processing'`; `createdAt` == now.
  - `account`: 1..64 chars; `reference`: 1..40 chars; `billerId` passes `fIdOk`.
  - `amount` passes `fPos`; `fee` passes `fNonNeg`; `total == amount+fee`.
- **Biller checks**, with `b = utility_billers/{billerId}`:
  - `b.published == true`; `currency == b.currency`.
  - `b.min` / `b.max` on `amount`.
  - `fee >= fFee(b, cur, amount)`, using the biller's `feePercent / feeFixed / feeMax`.
- **Re-auth:** **`fReauthOk(platform_settings/bills, cur, total)`**. Note the threshold is compared with the **total**.
- **Funding:** `{method:'wallet'}` or a gateway map. `bills.paymentMethods` is not checked.
- **Restriction:** **`!fRestricted('payments')`**.
- **Posting:** `type 'bill_payment'`, `source {utility_payment_requests, id}`, same currency, 2 lines, `lines[0].amount == total`. Wallet → platform.

**Update / delete:** none.

#### R.5.4 `utility_saved_accounts/{id}` (L1726-1735)

**ID:** `^acc_{uid}_.{1,300}$`.

**Create:**
- Keys ⊆ `userId, billerId, billerName, category, account, nickname, createdAt, lastUsedAt`.
- `userId==uid`; `account` 1..64 chars (required); `nickname` ≤60, optional.

**Update:** owner; changed ⊆ `{lastUsedAt, nickname}`.

**Delete:** owner.

---

### R.6 Virtual cards (L1737-1856)

#### R.6.1 `virtual_cards/{cardId}`

**Read:** owner.

**Create** (L1746-1757):
- **Keys** ⊆ `id, userId, label, currency, network, status, balance, termsVersion, acceptedAt, issuanceFee, feeTxId, payment, reference, createdAt, updatedAt`.
- **Field values:**
  - `id` optional; `userId==uid`; `status 'requested'`; `balance` absent or 0.
  - `label` ≤40, `network` ≤20, `reference` ≤40 (all optional).
  - `currency ∈ cards.currencies`.
  - `cards.termsVersion` is a number, and `d.termsVersion == cards.termsVersion`.
  - `acceptedAt` == now; `createdAt` == now; `updatedAt` stamp.
- **Issuance fee:** `issuanceFee` (default 0) == `fee`, where `fee = fPerCur(cards.issuanceFee, cur, 0)`.
- **Fee posting:** if `fee > 0`, `feeTxId` must be a posting created now with `type 'card_fee'`, `source {virtual_cards, cardId}`, same currency, and `lines[0].amount == fee` (wallet → platform).

**Update** (L1759-1786). Always: `o.userId==uid`, and `updatedAt` stampCh. One of these branches:
- **Freeze (no re-auth):** changed ⊆ `{status, frozenBy, frozenAt, updatedAt}`; `active` → `frozen`; `frozenBy=='user'`; `frozenAt` stampCh.
- **Unfreeze (fFresh):** changed ⊆ `{status, frozenBy, unfrozenAt, updatedAt}`; `o.status 'frozen'` with `o.frozenBy=='user'`; → `active`; `frozenBy` null or removed; `unfrozenAt` stampCh.
- **Termination request (fFresh):**
  - Changed ⊆ `{status, statusBefore, terminationRequestedAt, updatedAt}`; new status `termination_requested`.
  - From `active` or `expired`, or from `frozen` with `frozenBy 'user'`.
  - `statusBefore` absent or == `o.status`; `terminationRequestedAt` stampCh.
- **Label:** changed ⊆ `{label, updatedAt}`; `label` is a 0..40 char string.
- **Renewal (once):**
  - Changed ⊆ `{renewalRequestedAt, renewalFee, renewalTxId, renewalReference, renewalPayment, updatedAt}`.
  - `o.renewalRequestedAt == null`, and the new `renewalRequestedAt` == now.
  - `cards.capabilities.renew == true`; `o.status ∈ [active, expired]`.
  - `renewalFee` (default 0) == `fPerCur(cards.renewalFee)`.
  - If the fee is > 0: `renewalTxId` is a `card_fee` posting, `source {virtual_cards, id}`, `lines[0] == fee`.

#### R.6.2 `card_funding_requests/{requestId}` (L1788-1811, L1841-1845)

**Read:** owner.

**Create:**
- **Keys** ⊆ `id, userId, cardId, type, amount, fee, total, currency, status, txId, reference, payment, destination, recipientId, recipient, createdAt, updatedAt`.
- **Common field values:**
  - `id` optional; `userId==uid`.
  - Card c = `virtual_cards/{cardId}`: `c.userId==uid`, `c.status=='active'`, `currency == c.currency`.
  - `amount` passes `fPos`; `fee` passes `fNonNeg` (required); `status 'pending'`.
  - `createdAt` == now; `updatedAt` stamp; `reference` ≤40, optional.
- **`type 'fund'`** (no re-auth):
  - `total` absent or == `amount+fee`.
  - `cards.minFunding` / `cards.maxFunding`.
  - `fee >= round(amount * cards.fundingFeePercent / 100)`.
  - Posting `txId`: `type 'card_funding'`, `source {card_funding_requests, id}`, same currency, `lines[0].amount == amount+fee` (wallet → platform).
- **`type 'withdraw'` or `'transfer'`:**
  - `fee == 0`; **no `txId` key**.
  - **`fFresh()`**; `amount <= c.balance` (default 0).
  - **withdraw:** `cards.capabilities.withdraw == true`, and `destination` is a map.
  - **transfer:** `recipientId` passes `fIdOk` and `!= uid`; `recipient` is a map with ≤6 entries.

#### R.6.3 `card_limit_settings/{cardId}` (L1813-1832, L1847-1851)

**Read:** get only (no list), owner or missing doc.

**Create, and update by its owner** (`resource.data.userId==uid`) — the same checks apply to the whole resulting doc:
- **`fFresh()`** is required.
- **Keys** ⊆ `userId, cardId, perTransaction, daily, monthly, allowOnline, allowInternational, status, updatedAt, appliedAt, reason`.
- **Field values:**
  - `userId==uid`; `cardId == docId`.
  - Card owned by the caller, with status `active` or `frozen`.
  - `status=='pending'`; `updatedAt` == now.
- **Limit values:**
  - `perTransaction`, `daily`, `monthly` are each null or `fPos`, and ≤ their ceiling: `cards.limits.maxPerTransaction`, `maxDaily`, `maxMonthly` (per currency).
  - Order: `perTransaction ≤ daily ≤ monthly`, and `perTransaction ≤ monthly`.
  - `allowOnline` and `allowInternational` are null or bool.

**Other card collections**
- `card_transactions`: read where `userId==uid` (L1853-1855).
- `virtual_cards_private`: admin only.

---

### R.7 Savings (L1858-1988)

#### R.7.1 `savings_goals/{goalId}`

**Read:**
- get: missing doc, or `uid ∈ memberIds`, or `uid ∈ invitedIds`.
- list: `memberIds array-contains uid` or `invitedIds array-contains uid`.

**Create** (L1864-1879):
- **Keys** ⊆ `id, ownerId, memberIds, invitedIds, name, purpose, description, currency, targetAmount, savedAmount, deadline, schedule, status, accountId, createdAt, updatedAt`.
- **Owner and members:**
  - `id` optional; `ownerId==uid`; `memberIds==[uid]`.
  - `invitedIds` (default `[]`) is a list without `uid`.
  - A non-empty `invitedIds` requires `savings.groupGoals == true`.
  - `1 + invitedIds.size ≤ savings.maxMembers` (default 10).
- **Content:**
  - `name`: 1..80 chars; `purpose ∈ savings.purposes`; `description` ≤1000, optional.
  - `currency ∈ savings.currencies`; `targetAmount` passes `fPos`; `savedAmount == 0`.
  - `status 'active'`; `accountId` absent or `'goal_'+id`.
  - `createdAt` == now; `updatedAt` stamp; `deadline` passes `fDate`.
  - `schedule`: null or exactly `{frequency ∈ savings.frequencies, amount fPos}`.
- **Same-batch account:** `getAfter(financial_accounts/goal_{id}).refId == id`. The empty pool account is created in the same batch, optionally with `memberIds:[uid]`.
- **Restriction:** **`!fRestricted('savings')`**.

**Update** (L1912-1933). Always: `updatedAt` stampCh. One of these branches:
1. **Owner edit:**
   - Changed ⊆ `{name, description, deadline, schedule, updatedAt}`; owner; status `active`.
   - Same validations as create. `schedule` may be deleted.
2. **Owner invites:**
   - Changed ⊆ `{invitedIds, updatedAt}`; owner; status `active`.
   - New `invitedIds` ⊇ old ones (use arrayUnion), no duplicates, none already a member.
   - `groupGoals == true`; `memberIds.size + invitedIds.size ≤ maxMembers`.
3. **Invitee answers:**
   - Changed ⊆ `{invitedIds, memberIds, updatedAt}`.
   - `uid ∈ old invitedIds`, and new invitedIds set == old set − `{uid}`.
   - Decline: `memberIds` unchanged.
   - Accept: `memberIds == old + [uid]` (appended at the end), goal `active`, `old memberIds.size < maxMembers`, and **`!fRestricted('savings')`**.
4. **Counter with posting:**
   - Changed ⊆ `{savedAmount, lastTxId, status, cancelledAt, updatedAt}`; must change `savedAmount` and `lastTxId`; `cancelledAt` stampCh.
   - `fTxNow(lastTxId)`; goal `o.status 'active'`; `uid ∈ o.memberIds`.
   - **Contribution posting:** `type savings_contribution`, `lines[1].accountId == 'goal_'+id`, `savedAmount = old + lines[1].amount`, status unchanged.
   - **Withdrawal posting:** `type savings_withdrawal`, `lines[0].accountId == 'goal_'+id`, owner only, `savedAmount = old − lines[0].amount ≥ 0`. Either status unchanged, or `status 'cancelled'` with `savedAmount == 0` and `source == {savings_goals, id}`.
5. **Owner cancels an empty solo goal:**
   - Changed ⊆ `{status, cancelledAt, updatedAt}`; `active` → `cancelled`.
   - `memberIds` == `{uid}`; `savedAmount == 0`.
6. **Owner requests closure of a group goal:**
   - Changed ⊆ `{status, cancellationRequestedBy, cancellationRequestedAt, updatedAt}`; `active` → `cancellation_requested`.
   - `memberIds.size > 1`; `cancellationRequestedBy == uid`.

#### R.7.2 `savings_contributions/{id}` (L1935-1945)

**Read:** `userId==uid`, or a member of `goalId`. A list query filters on `userId==uid` or `goalId==X`.

**Create:**
- **Keys** ⊆ `id, goalId, userId, amount, currency, status, reference, txId, funding, gateway, createdAt`.
- **Field values:**
  - `id` optional; `userId==uid`; `goalId` passes `fIdOk`.
  - Goal (pre-state): `uid ∈ memberIds`, status `active`, and `currency == goal.currency`.
  - `amount` passes `fPos`; `status 'succeeded'`; `reference` 1..40 chars; `createdAt` == now.
- **Posting:** `type 'savings_contribution'`, `source {savings_contributions, id}`, `lines[1] == goal_{goalId}` with `amount`.
- **Funding and same-batch goal write:**
  - `funding` (optional string) == the posting's funding.
  - `getAfter(goal).lastTxId == txId`. The goal counter update happens in the same batch.
- **Not restricted.**
- Funding source: from a wallet, or from `platform_{CUR}` with a gateway receipt.

#### R.7.3 `savings_withdrawals/{id}` (L1950-1967)

**Read:** same as contributions.

**Create:**
- **Keys** ⊆ `id, goalId, userId, amount, currency, destination, reason, status, reference, txId, createdAt, completedAt`.
- **Common field values:**
  - `userId==uid`; a member; goal `active`; same currency.
  - `amount` passes `fPos` and `≤ g.savedAmount`.
  - `createdAt` == now; `reason` ≤500, optional.
- Then one of two forms:
  - **Group goal request** (`memberIds.size > 1`): `status 'requested'`, no `txId` or `completedAt`. No money moves; the admin decides.
  - **Solo owner** (`memberIds.size==1`, owner): `status 'completed'`.
    - Requires `savedAmount ≥ targetAmount`, or `savings.earlyWithdrawal.allowed == true`.
    - `completedAt` == now.
    - Posting: `savings_withdrawal`, `source {savings_withdrawals, id}`, `lines[0] == goal_{goalId}` with `amount`.
    - `getAfter(goal).lastTxId == txId`.
- **Not restricted.**

---

### R.8 Tontines (L1990-2214)

**ID formats:**

| Doc | ID |
|---|---|
| member | `tontine_members/{tid}_{uid}` |
| cycle | `tontine_cycles/{tid}_{n}` |
| contribution | `tontine_contributions/{cycleId}_{uid}` |
| payout | `tontine_payouts/{cycleId}` |
| pot account | `financial_accounts/tontine_{tid}` |

`fTontineMember(tid)` = `uid ∈ tontines/{tid}.memberIds`.

#### R.8.1 `tontines/{tontineId}`

**Read:** get/list for members only (list: `memberIds array-contains uid`). An invitee **cannot** read the tontine.

**Create** (L1998-2012):
- **Keys** ⊆ `id, name, description, rules, currency, contributionAmount, frequency, membersLimit, payoutOrderMethod, startDate, status, adminIds, memberIds, currentCycle, potAccountId, createdBy, createdAt, updatedAt`.
- **Creator and status:**
  - `createdBy==uid`; `adminIds==[uid]`; `memberIds==[uid]`; `status 'forming'`.
  - `currentCycle` absent or 0; `potAccountId` absent or `tontine_{id}`.
- **Content:**
  - `name` 1..80 chars; `description` ≤1000 and `rules` ≤5000, optional.
  - `currency`, `frequency`, `payoutOrderMethod` must be in the `tontines.*` lists.
  - `contributionAmount` passes `fPos` and `≥ tontines.minContribution[cur]` (default 1).
  - `membersLimit` is an int in [`minMembers` (default 2), `maxMembers` (default 30)].
  - `startDate` passes `fDate`; `createdAt` == now; `updatedAt` stamp.
- **Restriction:** **`!fRestricted('tontines')`**.
- **Same-batch docs:**
  - `getAfter(tontine_members/{id}_{uid}).role == 'admin'`.
  - `getAfter(financial_accounts/tontine_{id}).refId == id`, an empty pot opened in the same batch.

**Update** (L2014-2038). Always: `updatedAt` stampCh. One of these branches:
1. **Invitee joins:**
   - Changed ⊆ `{memberIds, updatedAt}`; status `forming`; `uid ∉ memberIds`.
   - `memberIds == old + [uid]`; `old size < membersLimit`.
   - `get(tontine_members/{id}_{uid}).status == 'invited'` and `getAfter(...).status == 'active'`.
   - **`!fRestricted('tontines')`**.
2. **Admin starts:**
   - Changed ⊆ `{status, currentCycle, nextDueAt, startDate, startedAt, updatedAt}`; `uid ∈ adminIds`.
   - `forming` → `active`; `currentCycle == 1`; `startedAt` stampCh.
   - `memberIds.size ≥ tontines.minMembers`.
   - `getAfter(cycle {id}_1).status == 'collecting'`.
   - `getAfter(cycle {id}_{N}).number == N`, where N = `memberIds.size`.
3. **Admin advances after a payout:**
   - Changed ⊆ `{currentCycle, nextDueAt, status, completedAt, updatedAt}`; admin; status `active`.
   - Current cycle: `get` status `payout_pending` and `getAfter` status `paid`.
   - If `currentCycle < N`: `currentCycle + 1`, status stays `active`, and `getAfter(next cycle).status == 'collecting'`.
   - Otherwise: `status 'completed'`, same `currentCycle`, and `completedAt` stampCh.

#### R.8.2 `tontine_members/{tid}_{uid}` (L2041-2088, L2183-2188)

**Read:** own doc, or a member of the tontine. A list query filters on `userId==uid` or `tontineId==X`.

**Create — common:**
- `tontineId` passes `fIdOk`; `memberId == tontineId+'_'+userId`; `id` optional.
- `displayName` ≤200, `email` ≤200, `tontineName` ≤200 (optional).
- `createdAt` stamp.

**Create — creator's admin membership** (L2041-2046):
- Keys ⊆ `id, tontineId, tontineName, userId, displayName, email, role, status, payoutPosition, joinedAt, createdAt`.
- `userId==uid`; `role 'admin'`; `status 'active'`; `payoutPosition 1`.
- `getAfter(tontine).createdBy==uid` and `createdAt == now`, i.e. the same batch as the tontine create.

**Create — invitation** (L2050-2058):
- **Keys** ⊆ `id, tontineId, tontineName, userId, displayName, email, role, status, invitedBy, invitedByName, contributionAmount, currency, frequency, membersLimit, startDate, rules, payoutOrderMethod, invitedAt, createdAt, respondedAt, joinedAt`.
- **Invitee and inviter:**
  - `role 'member'`; `status 'invited'`; `invitedBy==uid`.
  - `userId` passes `fIdOk` and `!= uid`.
- **Tontine state:** `uid ∈ adminIds`; tontine `forming`; `userId ∉ memberIds`; `memberIds.size < membersLimit`.
- **Terms copied from the tontine:**
  - `contributionAmount`, `currency`, `frequency`, `membersLimit` all equal the tontine's.
  - `rules` (default `''`) equal; `payoutOrderMethod` absent or equal; `startDate` (default null) equal (same timestamp).
- **Other:** `invitedAt` stamp; `invitedByName` ≤200.

**Update** (L2067-2081). `id`, `tontineId`, `userId`, `role` never change. One of these branches:
- **Invitee answers:**
  - `o.userId==uid`; `o.status 'invited'`.
  - Changed ⊆ `{status, respondedAt, joinedAt}`. **`updatedAt` is not allowed here.**
  - `respondedAt` and `joinedAt` stampCh.
  - Either `declined`, or `active` with `uid ∈ getAfter(tontine).memberIds` and **`!fRestricted('tontines')`**.
- **Admin re-invites after a decline:** `o.status 'declined'` and the full invitation check passes on the new doc.
- **Admin sets the payout position:**
  - Changed ⊆ `{payoutPosition, updatedAt}`; the member doc is `active`.
  - Admin; tontine pre-state `forming`.
  - Either `payoutOrderMethod=='fixed'`, or the tontine's after-status is `active` (a random draw happens in the start batch).
  - `payoutPosition` is an int in 1..`membersLimit`.

#### R.8.3 `tontine_cycles/{tid}_{n}` (L2091-2125, L2190-2195)

**Read:** members only. A list query filters on `tontineId==X`.

**Create** (in the start batch only):
- **Keys** ⊆ `id, tontineId, number, dueDate, beneficiaryUserId, expectedAmount, collectedAmount, currency, status, createdAt`.
- **Field values:**
  - `number` is an int; `cycleId == tontineId+'_'+number`.
  - Admin; tontine pre-state `forming` and after-state `active`.
  - `1 ≤ number ≤ memberIds.size`; `beneficiaryUserId ∈ memberIds`.
  - `expectedAmount == contributionAmount × memberIds.size`; `collectedAmount 0`.
  - `currency` absent or equal to the tontine's.
  - `status == (number==1 ? 'collecting' : 'upcoming')`.
  - `dueDate` passes `fDate`; `createdAt` stamp.

**Update.** Always: `updatedAt` stampCh. One of these branches:
- **Collect:**
  - Changed ⊆ `{collectedAmount, status, lastTxId, updatedAt}`; must change `collectedAmount` and `lastTxId`.
  - `fTxNow`; old status `collecting`; `type tontine_contribution`.
  - `lines[1] == tontine_{tid}`; `source == {tontine_contributions, cycleId+'_'+uid}`.
  - `collectedAmount = old + lines[1].amount ≤ expectedAmount`.
  - `status == (collected ≥ expected ? 'payout_pending' : 'collecting')`.
- **Paid:**
  - Changed ⊆ `{status, paidAt, updatedAt}`; `payout_pending` → `paid`; `paidAt` stampCh.
  - The payout doc goes `pending_approval` → `paid` in the same batch.
- **Next cycle opens:**
  - Changed ⊆ `{status, updatedAt}`; `upcoming` → `collecting`; `number > 1`.
  - The previous cycle goes `payout_pending` → `paid` in the same batch.

#### R.8.4 `tontine_contributions/{cycleId}_{uid}` (L2129-2142)

The id is create-only, so each member can contribute once per cycle.

**Read:** own contribution, or a member.

**Create:**
- **Keys** ⊆ `id, tontineId, cycleId, cycleNumber, userId, amount, currency, status, reference, txId, funding, gateway, paidAt, createdAt`.
- **Membership and cycle:**
  - `uid ∈ memberIds`; tontine `active`.
  - `cycle.tontineId` matches; cycle status `collecting`; `cycleNumber == cycle.number`.
- **Field values:**
  - `amount == contributionAmount`; same currency; `status 'paid'`.
  - `reference` 1..40 chars; `createdAt` == now; `paidAt` stamp.
- **Posting:** `type tontine_contribution`, `source {tontine_contributions, id}`, `lines[1] == tontine_{tid}` with `amount`.
- **Funding and same-batch cycle write:**
  - `funding` optional, == the posting's funding.
  - `getAfter(cycle).lastTxId == txId`.
- **Not restricted.** Funding is from a wallet, or from platform with a gateway receipt.

#### R.8.5 `tontine_payouts/{cycleId}` (L2145-2164)

**Read:** members.

**Create** (in the contribution batch that completes the pot):
- Keys ⊆ `id, tontineId, cycleId, cycleNumber, beneficiaryUserId, amount, currency, status, createdAt`.
- `cycleId == docId`; `tontineId`, `cycleNumber`, and `beneficiaryUserId` match the cycle.
- `amount == cycle.expectedAmount`; `currency` absent or matching.
- `status 'pending_approval'`; `createdAt` == now.
- Cycle pre-state `collecting`, after-state `payout_pending`.

**Update — approval:**
- `pending_approval` → `paid`.
- Changed ⊆ `{status, txId, reference, approvedBy, approvedAt, paidAt, updatedAt}`.
- `approvedBy==uid`; `paidAt` and `approvedAt` stamp.
- Posting `type tontine_payout`, `source {tontine_payouts, id}`.
- The approver checks (admin, not the beneficiary) are made in `fPotDebitOk`.

**Typical approval batch:** posting, payout update, cycle → `paid`, next cycle → `collecting`, tontine `currentCycle+1` (or `completed`).

#### R.8.6 `tontine_disputes/{id}` (L2166-2172)

**Read:** `raisedBy==uid`, or a member.

**Create:**
- Keys ⊆ `id, tontineId, raisedBy, againstUserId, subject, description, status, createdAt`.
- `raisedBy==uid`; caller is a member.
- `subject` 1..200 chars; `description` 1..5000 chars.
- `status 'open'`; `createdAt` == now; `againstUserId` null or `fIdOk`.

---

### R.9 Member loans (L2216-2465)

`groupId` is a tontine id. `fLoanParty` = borrower, a lender, or an eligible voter.

#### R.9.1 `loan_applications/{loanId}`

**Read:**
- get: `fLoanParty`.
- list: `borrowerId==uid`, `eligibleVoterIds array-contains`, or `lenderIds array-contains`.

**Create** (L2233-2250):
- **Keys** ⊆ `id, borrowerId, borrowerName, groupId, groupName, status, currency, amount, fundedAmount, outstandingAmount, repaidAmount, durationMonths, repaymentFrequency, purpose, description, eligibleVoterIds, lenderIds, votes, documents, createdAt, updatedAt`.
- **Borrower and group:**
  - `borrowerId==uid`; `status 'submitted'`.
  - `groupId` passes `fIdOk`; `uid ∈ tontines/{groupId}.memberIds`; `groupName` ≤200.
- **Voters:** `eligibleVoterIds` is non-empty and its set == group members − `{uid}`. It must be the whole rest of the group.
- **Terms against `lending.*`:**
  - `currency ∈ lending.currencies`.
  - `amount` in [`minAmount[cur]` (default 1), `maxAmount[cur]`].
  - `durationMonths ∈ durationsMonths`; `repaymentFrequency ∈ repaymentFrequencies`.
  - `purpose ∈ purposes` (only if that list is non-empty).
- **Initial values:**
  - `votes == {yes:0, no:0}`; `fundedAmount 0`; `outstandingAmount 0`; `repaidAmount` absent or 0.
  - `lenderIds == []`; `documents` absent or `[]`; `description` ≤2000.
  - `createdAt` == now; `updatedAt` stamp.
- **Restriction:** **`!fRestricted('loans')`**.

**Update** (L2252-2324). Always: `updatedAt` stampCh. One of these branches:
1. **Add a document:**
   - Changed ⊆ `{documents, updatedAt}`; borrower.
   - Status ∈ `[submitted, under_review, voting]`.
   - Exactly +1 entry (arrayUnion), ≤20 total.
2. **Cancel:**
   - Changed ⊆ `{status, cancelledAt, updatedAt}`; borrower.
   - Status ∈ `[submitted, under_review, voting]` → `cancelled`.
3. **Vote count:**
   - Changed ⊆ `{votes, updatedAt}`; status `voting`; `uid ∈ eligibleVoterIds`.
   - `getAfter(loan_votes/{loanId}_{uid}).at == now`.
   - `votes` keys ⊆ `{yes, no}`, and the matching counter is +1 (client sends `votes.yes: increment(1)` or `votes.no: increment(1)`).
4. **Close the vote:**
   - Changed ⊆ `{status, reason, votingClosedAt, updatedAt}`; status `voting`; caller is the borrower or an eligible voter.
   - Allowed when `votingEndsAt` is a timestamp and has passed, or when `cast ≥ eligible`.
   - `pass = eligible > 0 && cast×100 ≥ eligible × lending.voting.quorumPercent (default 101) && yes×100 ≥ cast × lending.voting.approvalPercent (default 101)`.
   - If pass: `status 'funding'`, `reason` untouched. Otherwise: `status 'rejected'`, `reason 'vote'`.
   - `votingClosedAt` stampCh.
5. **Funded:**
   - Changed ⊆ `{fundedAmount, lenderIds, status, fundedAt, updatedAt}`, must change `fundedAmount`; status `funding`.
   - The posting is read via `getAfter(financial_accounts/loan_{id}).lastTxId`, which must be `fTxNow`: `type loan_funding`, `lines[1] == loan_{id}`, `source.kind loan_fundings`, and that funding's after-state `lenderId==uid`.
   - `fundedAmount = old + lines[1].amount ≤ amount`.
   - `lenderIds`: unchanged if the caller is already a lender, else old + `[uid]`.
   - If now fully funded: `status 'agreement_pending'`, `fundedAt` stampCh, and `getAfter(loan_agreements/{id}).version == 1`. Otherwise status stays `funding` and `fundedAt` is not touched.
6. **Accept and pay out:**
   - Changed ⊆ `{status, acceptedAt, agreementVersion, disbursedAt, outstandingAmount, repaidAmount, updatedAt}`; borrower.
   - `agreement_pending` → `active`; `acceptedAt` == now; `disbursedAt` stamp.
   - `agreementVersion == agreement.version`; `agreement.acceptedAt` (pre-state) null.
   - `outstandingAmount == agreement.totalRepayable`; `repaidAmount` 0.
   - The loan account's posting is `fTxNow` with `type loan_disbursement`.
   - **`!fRestricted('loans')`**.
7. **Repaid:**
   - Changed ⊆ `{outstandingAmount, repaidAmount, status, repaidAt, updatedAt}`, must change `outstandingAmount`; borrower; status `active` or `overdue`.
   - The loan account's posting is `fTxNow`: `type loan_repayment`, `lines[1] == loan_{id}`, `source.kind loan_repayments`, and that repayment's after-state `loanId == id`.
   - `outstanding = old − amount ≥ 0`; `repaidAmount = old + amount`.
   - If outstanding reaches 0: `status 'repaid'` and `repaidAt` stampCh. Otherwise status unchanged and no `repaidAt`.

**Admin-only transitions:** `under_review`, `voting` (with `votingEndsAt`), `overdue`, `defaulted`.

#### R.9.2 `loan_votes/{loanId}_{uid}` (L2328-2338)

**Read:** the voter only.

**Create:**
- Keys ⊆ `loanId, voterId, approve, comment, at`. **No `id` key.**
- `voterId==uid`; `approve` is a bool; `comment` ≤500; `at` == now.
- Caller is an eligible voter and not the borrower; status `voting`.
- `votingEndsAt` null/absent, or `request.time < votingEndsAt`.
- The loan's after-state `votes` must be +1 in the matching counter.
- **`!fRestricted('loans')`**.

**Update:** none, so each voter votes once.

#### R.9.3 `credit_assessments/{loanId}`

Read by the borrower only. No client writes (L2418-2421).

#### R.9.4 `loan_fundings/{loanId}_{uid}_{n}` (L2341-2355, L2423-2432)

**ID:** matches `^{loanId}_{uid}_[0-9]{1,4}$`.

**Read:** `lenderId==uid` or `borrowerId==uid`.

**Create:**
- **Keys** ⊆ `id, loanId, lenderId, borrowerId, amount, currency, status, funding, reference, txId, requestKey, collected, createdAt`.
- **Lender and loan:**
  - `lenderId==uid`; `borrowerId` absent or equal to the loan's.
  - Caller is an eligible voter and not the borrower; loan status `funding`.
- **Amount and values:**
  - `amount` passes `fPos`; `fundedAmount + amount ≤ loan.amount`; same currency.
  - `status 'succeeded'`; `collected` absent or 0; `createdAt` == now; `reference` 1..40 chars.
- **Same-batch loan write:** `getAfter(loan).fundedAmount == old + amount`.
- **Posting:** `type loan_funding`, `source {loan_fundings, id}`, `lines[1] == loan_{loanId}` with `amount`; `funding` optional and equal to the posting's.
- **Restriction:** **`!fRestricted('loans')`**.
- The first funding creates `financial_accounts/loan_{loanId}` by first credit.

**Update:** lender only; changed ⊆ `{collected, updatedAt}`; `collected` is an int greater than the old value; `updatedAt` stampCh.

#### R.9.5 `loan_agreements/{loanId}` (L2361-2377, L2434-2441)

**Read:** get by the borrower or a lender.

**Create** (by the last funder, in the funding batch):
- **Keys** ⊆ `loanId, borrowerId, version, principal, currency, interestMethod, annualInterestPercent, fee, totalRepayable, latePenaltyPercent, durationMonths, repaymentFrequency, terms, installments, createdAt, acceptedAt`.
- **Loan match:**
  - `loanId == docId`; `version == 1`; `borrowerId` absent or matching.
  - Loan pre-state `funding`, after-state `agreement_pending`; caller is an eligible voter.
  - `principal == loan.amount`; same currency; `durationMonths` and `repaymentFrequency` absent or matching.
- **Terms against `lending.*`:**
  - `interestMethod == lending.interest.method`.
  - `annualInterestPercent == lending.interest.annualPercent`.
  - `latePenaltyPercent` (default 0) `== lending.latePenaltyPercent` (default 0).
  - `fee` passes `fNonNeg`, `≤ round(amount × lending.feePercent / 100)`, and `< amount`.
- **Repayment total:**
  - `installments` is a list of 1..600.
  - `totalRepayable` passes `fPos` and `≥ principal`.
  - `totalRepayable ≤ principal + ceil(principal × annualPercent × (durationMonths+1) / 1200) + installments.size`.
- **Other:** `acceptedAt` null/absent; `createdAt` stamp; `terms` ≤20000.

**Update:** only `acceptedAt`, from null to now. Caller is the borrower (pre-state loan), and the loan's after-status is `active`.

#### R.9.6 `loan_schedules/{loanId}` (L2443-2454)

**Read:** get by the borrower or a lender.

**Create:**
- Keys ⊆ `loanId, borrowerId, currency, installments, createdAt, updatedAt`.
- `loanId` absent or == docId; `installments` is a list of ≤600.
- Borrower; loan pre-state `agreement_pending`, after-state `active` (the accept batch).

**Update:**
- Changed ⊆ `{installments, updatedAt}`; same list length; borrower.
- The loan's after-state `outstandingAmount` must be lower than before (a repayment batch).

#### R.9.7 `loan_disbursements/{loanId}` (L2379-2388)

**Read:** get by the borrower or a lender.

**Create:**
- Keys ⊆ `id, loanId, borrowerId, amount, fee, currency, status, reference, txId, paidAt`.
- `id` optional == loanId; `loanId == docId`; `borrowerId==uid` and the loan's borrower is the caller; same currency.
- `status 'succeeded'`; `paidAt` stamp.
- Posting: `type loan_disbursement`, `source {loan_disbursements, loanId}`.
- `amount == lines[1].amount`; `fee == (3 lines ? lines[2].amount : 0)`.
- The fee is **not** cross-checked against the agreement's fee; the app should use the agreement's fee.
- The posting is `loan_{id}` → borrower wallet with debit = `fundedAmount`, plus an optional fee line.

#### R.9.8 `loan_repayments/{id}` (L2390-2401)

**Read:** borrower or lender of the loan. A list query filters on `loanId==X`.

**Create:**
- Keys ⊆ `id, loanId, borrowerId, amount, currency, status, funding, reference, txId, requestKey, createdAt`.
- `borrowerId==uid` and the loan's borrower is the caller; loan `active` or `overdue`.
- `amount` passes `fPos` and `≤ outstandingAmount`; same currency.
- `status 'succeeded'`; `reference` 1..40 chars; `createdAt` == now.
- `getAfter(loan).outstandingAmount == old − amount`.
- Posting: `type loan_repayment`, `source {loan_repayments, id}`, `lines[1] == loan_{loanId}` with `amount`; `funding` optional and matching.
- **Not restricted.**

---

### R.10 Investments (L2467-2519)

#### R.10.1 `investment_subscriptions/{id}`

**Read:** owner.

**Create:**
- **Keys** ⊆ `id, userId, fundId, fundName, assetClass, currency, amount, fee, termsVersion, signatureName, riskAcknowledged, acceptedAt, status, txId, reference, payment, createdAt, updatedAt`.
- **Fund checks**, with `f = investment_funds/{fundId}`:
  - `f.published == true`; `f.status == 'open'`.
  - `currency == f.currency`; `termsVersion == f.termsVersion`.
- **Consent and status:**
  - `riskAcknowledged == true`; `signatureName` 2..120 chars.
  - `acceptedAt` == now; `createdAt` == now; `updatedAt` stamp; `status 'paid'`.
- **Amount:**
  - `amount` passes `fPos`; `fee` (default 0) passes `fNonNeg`.
  - A holder (`investment_holdings/{uid}_{fundId}` exists with `units > 0`) needs `amount ≥ minAdditional` (falling back to `minInvestment`, then 0). Anyone else needs `amount ≥ minInvestment`.
- **Posting:** `type investment_subscription`, `source {investment_subscriptions, id}`, same currency, `lines[0].amount == amount`.
  - Wallet → platform, 2 lines. `fee` is informational and is not added to the debit.
- **Not restricted.**

#### R.10.2 `investment_redemptions/{id}`

**Read:** owner.

**Create:**
- **Keys** ⊆ `id, userId, fundId, fundName, currency, full, amount, destination, status, reference, createdAt, updatedAt`.
- **Holding check**, with `h = investment_holdings/{uid}_{fundId}`: `h.userId==uid` and `h.units > 0`.
- **Fund checks:** `fund.status != 'suspended'`; `fund.redemption.allowed == true`; same currency.
- **Field values:**
  - `status 'submitted'`; `createdAt` == now; `updatedAt` stamp.
  - `destination`: a map with ≤12 entries.
- **Amount:**
  - `full == true` with `amount` null/absent, OR
  - `full == false` with `fund.redemption.partial == true`, `amount` passing `fPos`, and `amount ≤ h.redeemableValue`.

**Update:** owner cancels while `submitted` → `cancelled`; changed ⊆ `{status, cancelledAt, updatedAt}`; `cancelledAt` stamp.

#### R.10.3 Read-only investment records

`investment_holdings`, `investment_transactions`, `investment_reports`: read where `userId==uid`.

---

### R.11 Insurance (L2521-2670)

**ID formats:** a policy is `insurance_policies/{quoteId}`; its first premium is `insurance_premiums/{policyId}_1`.

#### R.11.1 `insurance_quotes/{quoteId}`

**Read:** owner.

**Create:**
- **Keys** ⊆ `id, userId, productId, productName, partnerName, category, currency, answers, frequency, coverStart, termMonths, status, createdAt, updatedAt`.
- **Product check**, with `p = insurance_products/{productId}`: `p.published == true`; `p.status` (default `'open'`) == `'open'`; `currency == p.currency`.
- **Field values:**
  - `status 'requested'`; `createdAt` == now; `updatedAt` stamp.
  - `answers`: a map with ≤50 entries.
  - `frequency`: 1..20 chars.
  - `coverStart`: **key required**, value null, timestamp or string.
  - `productName` ≤200, `partnerName` ≤200, `category` ≤60 (optional).

**Update.** Always: owner, `updatedAt` stampCh. One of these branches:
- **Decline:** changed ⊆ `{status, declinedAt, updatedAt}`; `quoted` → `declined`.
- **Accept:**
  - Changed ⊆ `{status, acceptedAt, signatureName, policyId, updatedAt}`; `quoted` → `accepted`.
  - `request.time < o.validUntil`; `acceptedAt` == now; `signatureName` 2..120 chars; `policyId == quoteId`.
  - `getAfter(policy {quoteId}).quoteId == quoteId`.
  - `getAfter(premium {quoteId}_1)`: `createdAt` == now, `status 'paid'`, `amount == quote.installmentAmount` (falling back to `premium`), and `fTxNow(txId)`.

#### R.11.2 `insurance_policies/{quoteId}`

**Read:** owner.

**Create** (in the accept batch):
- Keys ⊆ `id, userId, quoteId, productId, productName, partnerName, category, currency, premium, frequency, installmentAmount, deductible, coverages, coverStart, coverEnd, termsVersion, signatureName, acceptedAt, autoRenew, status, createdAt, updatedAt`.
- `quoteId == docId`; `userId==uid`; the quote is the caller's.
- Quote pre-state `quoted`, after-state `accepted`.
- `status 'pending_activation'`; `autoRenew` absent or false; `createdAt` == now; `acceptedAt` stamp.
- These fields must equal the quote's (null-defaulted): `productId, currency, premium, installmentAmount, frequency, termsVersion, deductible, coverStart, coverEnd, coverages`.

**Update.** Always: owner, `updatedAt` stampCh. One of these branches:
- **autoRenew:** changed ⊆ `{autoRenew, updatedAt}`; status `active` or `renewal_due`; value is a bool.
- **Cancellation request:**
  - Changed ⊆ `{status, statusBefore, cancellationReason, cancellationRequestedAt, updatedAt}`.
  - `active` or `renewal_due` → `cancellation_requested`.
  - `statusBefore` absent or == old status; `cancellationReason` ≤500.
- **Renewal paid:**
  - Changed ⊆ `{renewalRequestedAt, renewalPaidAmount, renewalTxId, renewalReference, renewalPayment, updatedAt}`.
  - Status `renewal_due`; `renewalPremium` passes `fPos`; `o.renewalRequestedAt == null`.
  - New `renewalRequestedAt` == now; `renewalPaidAmount` absent or == `renewalPremium`.
  - `renewalTxId` is a posting `type insurance_premium`, `source {insurance_policies, id}`, same currency, `lines[0] == renewalPremium`.

#### R.11.3 `insurance_premiums/{policyId}_1` and later premiums

**Read:** owner.

**Create (first premium only):**
- Keys ⊆ `id, userId, policyId, amount, currency, dueDate, status, paidAt, txId, reference, payment, createdAt, updatedAt`.
- `id == policyId+'_1'`; `userId==uid`.
- Policy after-state: owned by the caller, `pending_activation`, and created in this batch (`createdAt` == now).
- `status 'paid'`; `amount == policy.installmentAmount` (falling back to `premium`); same currency.
- `paidAt` == now; `createdAt` == now.
- Posting: `type insurance_premium`, `source {insurance_premiums, id}`, same currency, `lines[0] == amount`.

**Update — pay a due premium:**
- Owner; status `due`, `overdue` or `failed` → `paid`.
- Changed ⊆ `{status, paidAt, txId, reference, payment, updatedAt}`; `paidAt` == now.
- Posting: `insurance_premium`, `source {insurance_premiums, id}`, same currency, `lines[0] == o.amount`.

#### R.11.4 `insurance_claims/{claimId}`

**Read:** owner.

**Create:**
- Keys ⊆ `id, userId, policyId, policyNumber, productName, currency, incidentDate, description, amountClaimed, documents, status, createdAt, updatedAt`.
- Policy owned by the caller with status `active` or `renewal_due`.
- `status 'submitted'`; `createdAt` == now; `updatedAt` stamp; same currency.
- `description` 1..5000 chars; `amountClaimed` passes `fPos`.
- `incidentDate`: key required (`fDate`).
- `documents`: a list of ≤20; `policyNumber` ≤100; `productName` ≤200.

**Update.** Always: owner, `updatedAt` stampCh. One of these branches:
- **Answer the insurer:** changed ⊆ `{status, documents, respondedAt, updatedAt}`; `info_requested` → `under_review`; `documents` a list of ≤40; `respondedAt` == now.
- **Withdraw:** changed ⊆ `{status, withdrawnAt, updatedAt}`; from `submitted`, `under_review` or `info_requested` → `withdrawn`.

#### R.11.5 `insurance_claims/{claimId}/events/{eventId}`

**Read:** the claim owner.

**Create** (same batch as the answer):
- Keys ⊆ `id, type, userId, authorId, message, documents, createdAt`.
- `type 'customer_response'`; `userId==uid`; `authorId` absent or `uid`.
- `message`: 0..2000 chars (required).
- `documents`: a list of ≤20; `createdAt` == now.
- `getAfter(claim).respondedAt == now`.

`insurance_partners` is admin only.

---

### R.12 Project financing (L2672-2754)

Settings are read from `platform_settings/financing`.

#### R.12.1 `financing_projects/{projectId}`

**Read:** owner (`ownerId==uid`).

**Create:**
- Keys ⊆ `id, ownerId, name, sector, country, city, description, stage, employees, foundedYear, website, createdAt, updatedAt`.
- `ownerId==uid`; `createdAt` == now.
- `fProjectOk`:
  - `name` 1..200 chars; `sector ∈ financing.sectors`.
  - `country` ≤60, `city` ≤100 (optional).
  - `description` 1..5000 chars.
  - `stage`: null or in `financing.stages`.
  - `employees`: null or `fNonNeg`; `foundedYear`: null or int; `website` ≤300.

**Update:** owner; changed ⊆ `{name, sector, country, city, description, stage, employees, foundedYear, website, updatedAt}`; `updatedAt` stampCh; `fProjectOk`. Optional fields may be deleted.

#### R.12.2 `financing_applications/{id}`

**Read:** owner, or `uid ∈ reviewerIds`.

**Create:**
- Keys ⊆ `id, ownerId, projectId, projectName, financingType, amount, currency, durationMonths, useOfFunds, status, reviewerIds, createdAt, updatedAt`.
- `ownerId==uid`; `status 'draft'`; `reviewerIds` absent or `[]`; `createdAt` == now; `projectName` ≤200.
- The project is owned by the caller.
- `fFinancingAmountOk`:
  - `currency ∈ financing.currencies`.
  - `amount` in [`minAmount[cur]`, `maxAmount[cur]`].
  - `financingType ∈ financingTypes`.
  - `useOfFunds` 1..5000 chars.
  - `durationMonths`: null or in `durationsMonths`.

**Update.** Always: owner, `updatedAt` stampCh. "Editable" means status `draft` or `additional_info_required`. One of these branches:
- **Edit:** changed ⊆ `{financingType, amount, currency, durationMonths, useOfFunds, updatedAt}`; editable; `fFinancingAmountOk`.
- **Submit:**
  - Changed ⊆ `{status, declarationAccepted, declarationAcceptedAt, submittedAt, ownerMessage, reason, updatedAt}`; editable → `submitted`.
  - `declarationAccepted == true`; `submittedAt` == now; `declarationAcceptedAt` stampCh.
  - `reason` null/absent; `ownerMessage` ≤2000.
- **Withdraw:** changed ⊆ `{status, withdrawnAt, updatedAt}`; from `draft`, `submitted`, `under_review` or `additional_info_required` → `withdrawn`.

#### R.12.3 `financing_documents/{id}`

**Read:** owner.

**Create:**
- **Keys** ⊆ `id, ownerId, applicationId, type, name, storagePath, contentType, size, status, note, uploadedAt`.
- **Application check:** the application is the caller's and editable.
- **Field values:**
  - `ownerId==uid`.
  - `type ∈ financing.documentTypes`; `name` 1..200 chars.
  - `status 'received'`; `note` absent or `''`; `uploadedAt` == now.
- **File checks:**
  - `storagePath` matches `^financing_documents/{uid}/{applicationId}/[^/]{1,200}$`.
  - `contentType ∈ financing.allowedContentTypes`.
  - `size` passes `fPos` and `≤ financing.maxFileBytes`. The default is 0, so the setting is required.

**Delete:** owner; status `received`; the application is still editable.

`financing_reviews`: read by the owner; the admin writes them.

---

### R.13 Intelligence, coach, chat, KYC, admin-written records

#### R.13.1 Investor profile, watchlist, opportunity interest, coach

- **`investor_profiles/{uid}`:** get own. Create/update own (whole-doc check):
  - Keys ⊆ `currency, sectors, countries, types, minTicket, maxTicket, maxRisk, maxHorizonMonths, updatedAt`.
  - `currency` valid.
  - `sectors` a list of ≤50; `countries` ≤100; `types` ≤20.
  - `minTicket` passes `fNonNeg`; `maxTicket` passes `fPos`; `min ≤ max`.
  - `maxRisk` is an int in 1..7; `maxHorizonMonths` passes `fNonNeg`; `updatedAt` == now.
- **`investor_watchlists/{uid}`:** own. Keys ⊆ `securityIds, updatedAt`; `securityIds` a list of ≤50; `updatedAt` == now.
- **`opportunity_interests/{opportunityId}_{uid}`:** create, or update by the owner (L2781-2796):
  - Keys ⊆ `opportunityId, userId, interested, message, name, email, createdAt, updatedAt`.
  - `userId==uid`; `interested` is a bool; `message` ≤500.
  - **`createdAt` and `updatedAt` must be absent or serverTimestamp on every write.** Re-send `createdAt: serverTimestamp()` on updates, as the tests do.
  - If `interested`: `name` ≤200 and `email` ≤200. If not: no `name` or `email` keys (delete them).
  - The opportunity must be `published == true` with `status 'open'`.
- **Read-only:**
  - `investor_matches`: read where `userId==uid`.
  - `coach_consents/{uid}`: get own.
  - `financial_coach_sessions`: read where `userId==uid`; its `messages` are readable by the session owner.

#### R.13.2 KYC (L2809-2898)

**`kyc_applications/{id}`**
- **Read:** owner.
- **Create:**
  - Keys ⊆ `id, userId, level, accountType, status, revision, personal, business, reason, createdAt, updatedAt`.
  - `userId==uid`; `status 'draft'`; `revision 1`; `reason` null/absent.
  - `kyc.levels[level]` is a map, and `accountType ∈ kyc.levels[level].accountTypes`.
  - `createdAt` == now; `updatedAt` stamp.
  - `personal`: null or keys ⊆ `fullName, dateOfBirth, nationality, idNumber, address, city, country`, each an optional string ≤200.
  - `business`: null or keys ⊆ `companyName, registrationNumber, taxNumber, registeredAddress, country`, each ≤200.
- **Update.** Always: owner, `updatedAt` stampCh. One of these branches:
  - **Details:** changed ⊆ `{personal, business, updatedAt}`; status `draft` or `additional_info_required`.
  - **Submit:** changed ⊆ `{status, submittedAt, updatedAt}`; `draft` or `additional_info_required` → `submitted`; `submittedAt` == now.
  - **Reopen:** changed ⊆ `{status, revision, reason, updatedAt}`; `rejected` → `draft`; `revision + 1`; `reason` null/removed.
  - `under_review`, `additional_info_required`, `approved`, `rejected`, and `users.kycLevel` / `kycStatus` are admin-only.

**`kyc_documents/{id}`**
- **Read:** owner.
- **Create:**
  - Keys ⊆ `id, applicationId, userId, type, side, status, storagePath, contentType, size, revision, createdAt`.
  - The application is the caller's, with status `draft` or `additional_info_required`.
  - `type` is a key of the `kyc.documentTypes` map; `side ∈ kyc.documentTypes[type].sides`.
  - `status 'uploaded'`; `createdAt` == now.
  - `storagePath` matches `^kyc/{uid}/{applicationId}/[^/]{1,200}$`.
  - `contentType` null or in `kyc.allowedContentTypes`.
  - `size` null, or `fPos` and `≤ kyc.maxFileBytes`.
- **Update (supersede):** owner; status `!= superseded` → `superseded`; changed ⊆ `{status, supersededBy, updatedAt}`; the application is still editable.

**`kyc_reviews/{id}`**
- **Read:** owner.
- **Create:**
  - Keys ⊆ `id, applicationId, userId, action, reason, at`.
  - `userId==uid`; `at` == now; `reason` null/absent; the application is the caller's.
  - `action 'submit'`: application pre-state `draft` or `additional_info_required`, after-state `submitted`.
  - `action 'reopen'`: application pre-state `rejected`, after-state `draft`.
  - Written in the same batch as the step.

#### R.13.3 Chat: `finance_chats/{chatId}` (L2900-2952)

**ID formats:** `dm_{a}_{b}`, with uids sorted so `a < b`; or `tontine_{tid}`.

**Read:**
- get: missing doc, or a member. For `type 'tontine'` that means `chatId == 'tontine_'+tontineId` and `uid ∈ tontines/{tid}.memberIds`; otherwise `uid ∈ memberIds`.
- list: `memberIds array-contains uid`. This covers direct chats only; tontine chats are read by id.

**Create:**
- Keys ⊆ `id, type, memberIds, tontineId, lastMessage, updatedAt, lastReadAt`.
- `lastMessage` is exactly `{text 1..1000, senderId==uid, at==now}`; `updatedAt` == now.
- `lastReadAt` (default `{}`) is a map with keys ⊆ `[uid]`.
- **Direct:** no `tontineId`; `memberIds` has 2 entries including `uid`, with `memberIds[0] < memberIds[1]`; `chatId == 'dm_'+m0+'_'+m1`.
- **Tontine:** no `memberIds`; `chatId == 'tontine_'+tontineId`; caller is a tontine member.
- The app writes the doc with `set(merge)` together with the first message.

**Update:**
- Caller is a member; changed ⊆ `{lastMessage, updatedAt, lastReadAt}`.
- `lastMessage` valid as above; `updatedAt` stampCh.
- `lastReadAt` may change only the caller's own key, set to now. Use `update({'lastReadAt.<uid>': serverTimestamp()})`.

**`messages/{messageId}`**
- **Read:** chat member.
- **Create:**
  - Membership is checked on `getAfter(chat)`.
  - Keys ⊆ `id, senderId, senderName, text, createdAt`.
  - `senderId==uid`; `text` 1..1000 chars; `senderName` ≤200; `createdAt` == now.
- No update or delete.

#### R.13.4 Admin-written owner records (L2954-2957)

- `finance_summaries/{uid}`: get own.
- `ledger_entries`: read where `userId==uid`.

#### R.13.5 Catalogs and configuration (L2959-2983)

- **`platform_settings/{id}`:** any signed-in user reads.
- **Published-only catalogs:** read if `resource.data.published == true`. A list query **must** include `where('published','==',true)`, and an unfiltered list is refused. These are: `investment_funds`, `insurance_products`, `utility_billers`, `financial_resources`, `economic_indicators`, `investment_opportunities`, `market_securities`, `ipo_listings`, `stock_collections`, `finance_news`.
- **Unconditional signed-in reads:** `investment_valuations`, `economic_indicator_history`, `exchange_rate_snapshots`, `market_price_history`.
- **Writes:** admin only, via the wildcard.

---

### R.14 Cross-cutting lists

#### R.14.1 Re-authentication (`auth_time` < 5 minutes old)

**Threshold-based (`fReauthOk`).** Fresh auth is needed unless `amount < reauthAbove[cur]` and that threshold is > 0:

| Write | Settings doc for `security.reauthAbove{CUR}` | Compared value |
|---|---|---|
| `wallet_operations` withdrawal (L1590) | `platform_settings/wallet` | `amount` |
| `money_transfers` create, internal + external (L1647) | `platform_settings/transfers` | `amount` |
| `utility_payment_requests` create (L1713) | `platform_settings/bills` | `total` |

**Always required (`fFresh`):**
- `virtual_cards` unfreeze (L1768).
- `virtual_cards` termination request (L1772).
- `card_funding_requests` with type `withdraw` or `transfer` (L1796).
- `card_limit_settings` create and update (L1823).

**Never required:** deposits, conversions, card top-up (`fund`), card freeze, and every other write.

#### R.14.2 `financeRestriction` scope checks

| Scope | Where it is checked |
|---|---|
| `wallet` | plain deposit, i.e. without `purpose` (L1571); withdrawal (L1590); conversion (L1614) |
| `transfers` | `money_transfers` create (L1650) |
| `payments` | `utility_payment_requests` create (L1715) |
| `savings` | goal create (L1878); invitee accepting a goal (L1895) |
| `tontines` | tontine create (L2009); join via the `tontines.memberIds` update (L2023); `tontine_members` invited → active (L2076) |
| `loans` | loan apply (L2249); `loan_votes` create (L2337); `loan_fundings` create (L2354); loan accept via the `loan_applications` update (L2313); disbursement posting debit (L1420) |

**Never checked:**
- Contributions (savings, tontine), loan repayments, savings withdrawals.
- Gateway deposits with `purpose`, receiving money, declining invitations.
- Cards, investments, insurance, financing, KYC, chat.

#### R.14.3 `platform_settings` fields the rules read

| Doc | Fields |
|---|---|
| `wallet` | `deposit.{enabled,min,max}`; `withdraw.{enabled,methods,min,max,feePercent,feeFixed,feeMax}`; `convert.{enabled,currencies,feePercent,maxRateAgeHours}`; `security.reauthAbove` (`wallet.currencies` is NOT read) |
| `transfers` | `currencies`; `sourceMethods`; `channels.{internal,mobile_money,wave,bank}.{enabled,min,max,feePercent,feeFixed,feeMax}`; `security.reauthAbove` |
| `bills` | `security.reauthAbove` (the doc must exist). Fees and limits come from `utility_billers/{id}.{published,currency,min,max,feePercent,feeFixed,feeMax}` |
| `cards` | `currencies`; `termsVersion`; `issuanceFee`; `renewalFee`; `capabilities.{renew,withdraw}`; `minFunding`; `maxFunding`; `fundingFeePercent`; `limits.{maxPerTransaction,maxDaily,maxMonthly}` |
| `savings` | `groupGoals`; `maxMembers` (default 10); `purposes`; `currencies`; `frequencies`; `earlyWithdrawal.allowed` |
| `tontines` | `currencies`; `frequencies`; `payoutOrderMethods`; `minContribution`; `minMembers` (default 2); `maxMembers` (default 30) |
| `lending` | `currencies`; `minAmount`; `maxAmount`; `durationsMonths`; `repaymentFrequencies`; `purposes`; `voting.quorumPercent` (default 101); `voting.approvalPercent` (default 101); `interest.method`; `interest.annualPercent`; `latePenaltyPercent`; `feePercent` |
| `financing` | `currencies`; `minAmount`; `maxAmount`; `financingTypes`; `durationsMonths`; `sectors`; `stages`; `documentTypes`; `allowedContentTypes`; `maxFileBytes` |
| `kyc` | `levels.{level}.accountTypes`; `documentTypes.{type}.sides`; `allowedContentTypes`; `maxFileBytes` |

#### R.14.4 Admin-owned state the customer rules depend on (for the PHP panel)

**Accounts and users**
- `financial_accounts/platform_{CUR}` must exist before go-live: `{id, kind:'platform', currency, balance:int, normalSide:'credit', status:'active', lastTxId:''}`.
- Any account with `status != 'active'` cannot move.
- `users/{uid}.financeRestriction = {status:'restricted', scopes:[...], reason, since}`, plus `kycLevel` and `kycStatus`.

**Rates and catalogs**
- `exchange_rate_snapshots/{id}`: `from`, `to`, `rate` (a number > 0, in major units), `observedAt` (a timestamp). The app queries by `pair` and `observedAt`.
- Catalog `published` must be the bool `true`.
- `investment_funds`: `status` (`open`; `suspended` blocks redemptions), `currency`, `termsVersion`, `minInvestment`, `minAdditional`, `redemption.{allowed,partial}`.
- `investment_holdings/{uid}_{fundId}`: `{userId, units, redeemableValue}`.
- `insurance_products`: `{published, status, currency}`.
- `investment_opportunities`: `{published, status:'open'}`.

**Status fields and flags on customer records**
- `insurance_quotes`: `{status:'quoted', validUntil:timestamp, premium, installmentAmount, frequency, termsVersion, deductible, coverStart, coverEnd, coverages}`.
- `insurance_policies`: `status active / renewal_due`, `renewalPremium`. The admin clears `renewalRequestedAt` after renewing.
- `money_transfers.adminLockedAt` blocks the sender's cancel request.
- `virtual_cards`: `frozenBy:'admin'` blocks the user's unfreeze; also `status` and `balance`.
- `loan_applications`: `under_review`, then `voting` with `votingEndsAt` (a timestamp), then `overdue` / `defaulted`.
- `kyc_applications` decisions, with `reason`.
- `financing_applications`: statuses and `reviewerIds`.
- `card_limit_settings` application (`appliedAt`, `reason`).
- `payment_receipts.verified`: reconciled by the admin.

#### R.14.5 Implementation notes for the web client

1. **Ledger batch shape.** This is the shape `plan()` in `fixtures.js` builds:
   - The posting.
   - Each line's account, either `update({balance: increment(±amount), lastTxId, updatedAt: serverTimestamp()})` or a first-credit `set`.
   - The request doc, which names the posting via `txId`, `feeTxId`, `renewalTxId` or `txIds`.
   - For gateway funding, `payment_receipts/{method}_{ref}` with `{method, reference, txId, amount, currency, userId, verified:false, createdAt}`.
   - Every `createdAt` that must equal `request.time` uses `serverTimestamp()`.
2. **Recipient wallet:** `get(financial_accounts/wallet_{rid}_{CUR})`.
   - Not-found: create it as the credit line.
   - Permission-denied: it exists, so update it with `increment`.
3. **Gateway payment for types outside `fGatewayTypes`:** batch 1 is a deposit with `purpose:{kind, id}`; batch 2 is the wallet-funded posting.
4. **Integers:** all amounts are integers. JS numbers that are safe integers are encoded as integers by the SDK.
5. **Order-sensitive lists:**
   - `participantIds` (internal transfer) = `[sender, recipient]`.
   - `accountIds` = the line order.
   - Goal `memberIds` grow by append (arrayUnion).
   - Tontine `memberIds == old.concat([uid])`.
6. **Doc ids:**
   - Doc ids used as `fIdOk` values (`source.id`, account ids, `goalId`, etc.) must match `[A-Za-z0-9_-]{1,200}`.
   - `txId` must match the `tx_` regex.
   - Conversion leg 2 needs its own valid `txId`; the tests use `txId + 'b'`.
