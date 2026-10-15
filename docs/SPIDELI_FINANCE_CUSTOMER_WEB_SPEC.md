# Spideli Finance — Customer Web Specification

`SPIDELI_FINANCE_CUSTOMER_WEB_SPEC.md` · version 1.0 · 15 October 2026

**For:** the developer of the Spideli Finance **customer website**.
**Companion document:** `SPIDELI_FINANCE_ADMIN_WEB_SPEC.md` (the admin panel, built by another developer at the same time).
**Supersedes:** `docs/FINANCE-FLOW.md` for the customer side.

## How to use this document

- **One Firebase architecture, no separate backend.** The website, the Flutter customer app (`customer/`) and the PHP admin panel all read and write the **same** Firestore collections, documents and fields, described once in sections 1–4. The website talks to Firebase directly with the Firebase **Web SDK**. There are no finance Cloud Functions and no finance REST API, and you must not add any.
- **Security is enforced by the Firestore rules.** Every write the website makes is checked by the finance block of `firestore.rules.draft`. Section 6 gives the exact batch for every action; Appendix R lists every check behind it. A batch that differs from them (an extra field, a missing `serverTimestamp()`, a wrong id) is refused with `permission-denied`.
- **The reference implementation is the mobile app.** Its services (`customer/lib/service/finance_*.dart`) and rule helpers (`customer/lib/utils/finance_*_rules.dart`) make exactly these writes, and the website must behave the same. When this document and the rules disagree, the rules win; report the difference.
- **Do not change the data model.** No new collection, field, status or id format without agreement with the admin-panel developer and an update of the rules and of both documents.
- **What the admin does.** Every request that needs a person or a partner (payouts, KYC decisions, card issuance, fund orders, insurance pricing and claims, loan reviews) stays `pending` / `processing` / `submitted` until the admin panel completes it. Each module says what happens next ("Admin next").

| Sections | Content | Shared with the admin specification |
|---|---|---|
| 1–4 | Platform foundation, settings, data model, money movement | yes, identical |
| 5 | Website architecture: stack, authentication, routes, design system, common behaviours | no |
| 6 | Every customer feature: screens, flows, validations, exact writes | no |
| 7–9 | Queries and indexes, acceptance tests, dependencies | no |
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
- [5. Customer website: architecture](#5-customer-website-architecture)
  - [5.1 Stack requirements](#51-stack-requirements)
  - [5.2 Authentication and account security](#52-authentication-and-account-security)
  - [5.3 Information architecture (routes)](#53-information-architecture-routes)
  - [5.4 Design system (web)](#54-design-system-web)
  - [5.5 Common behaviours (every module)](#55-common-behaviours-every-module)
- [6. Customer features](#6-customer-features)
  - [6.1 Finance dashboard](#61-finance-dashboard)
  - [6.2 Identity verification (KYC) (`/finance/kyc`)](#62-identity-verification-kyc-financekyc)
  - [6.3 Wallet](#63-wallet)
  - [6.4 Money transfer — restriction scope `transfers`](#64-money-transfer--restriction-scope-transfers)
  - [6.5 Payment (bills) — restriction scope `payments`](#65-payment-bills--restriction-scope-payments)
  - [6.6 Virtual cards](#66-virtual-cards)
  - [6.7 Collective savings — restriction scope `savings` (new goals, joining)](#67-collective-savings--restriction-scope-savings-new-goals-joining)
  - [6.8 Tontine — restriction scope `tontines` (create, join)](#68-tontine--restriction-scope-tontines-create-join)
  - [6.9 Member loans — restriction scope `loans` (apply, vote, fund, accept)](#69-member-loans--restriction-scope-loans-apply-vote-fund-accept)
  - [6.10 Project financing (companies, institutions)](#610-project-financing-companies-institutions)
  - [6.11 Investment](#611-investment)
  - [6.12 Online insurance](#612-online-insurance)
  - [6.13 Markets, intelligence and opportunities (`/finance/markets`)](#613-markets-intelligence-and-opportunities-financemarkets)
  - [6.14 Finance chat (`/finance/messages`)](#614-finance-chat-financemessages)
  - [6.15 AI assistant (`/finance/assistant`)](#615-ai-assistant-financeassistant)
  - [6.16 Notifications (customer side)](#616-notifications-customer-side)
- [7. Queries and indexes](#7-queries-and-indexes)
- [8. Acceptance criteria and test plan](#8-acceptance-criteria-and-test-plan)
- [9. Dependencies and limits](#9-dependencies-and-limits)
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

## 5. Customer website: architecture

### 5.1 Stack requirements

- **Firebase JS SDK (modular, v10+)**: `firebase/auth`, `firebase/firestore` (with `writeBatch`, `runTransaction`, `serverTimestamp`, `increment`, `arrayUnion`, `arrayRemove`, `deleteField`), `firebase/storage`, `firebase/app-check` (reCAPTCHA Enterprise), `firebase/messaging` (web push, optional).
- Any SPA framework (React / Vue / Angular) with client-side routing; all finance pages require a signed-in user.
- **Real-time:** every status, balance and list shown is a Firestore `onSnapshot` listener (statuses change when the admin acts). Share one listener per source across components (profile, accounts, totals), unsubscribe when the page leaves.
- **No server of your own for finance writes.** The website writes to Firestore exactly as section 3 and the module sections below say. A write that does not match the rules fails with `permission-denied`.
- **Gateway checkouts** use each provider's browser integration with **publishable** keys only (Stripe Payment Element / Checkout, PayPal JS SDK, Flutterwave Inline, Orange Money web payment, PayStack Inline…). The checkout result must give a provider transaction id (the `reference`).
- **PDF statements and receipts** are generated in the browser (e.g. pdf-lib / jsPDF) from Firestore data.
- **i18n:** English and Arabic with full RTL layout; translation keys identical to the app's (`customer/lib/lang/app_en.dart`, `app_ar.dart`).

### 5.2 Authentication and account security

| Feature | Implementation |
|---|---|
| Sign-up / sign-in | email + password; phone + SMS OTP (`RecaptchaVerifier` + `signInWithPhoneNumber`); Google (`GoogleAuthProvider`, popup); Apple (`OAuthProvider("apple.com")`); LinkedIn (`OAuthProvider(settings/authProviders.linkedinProviderId)`) only when `settings/authProviders.linkedin == true`. Facebook is not offered (SDK not configured). |
| Profile document | create `users/{uid}` at first sign-in with the same fields as the app's sign-up (first / last name, email, phone, country code, `role: "customer"`, `active: true`, `createdAt`); never write `kycLevel`, `kycStatus`, `financeRestriction`, `role: "admin"` |
| Password reset | `sendPasswordResetEmail` |
| **Two-step verification** (Finance › Profile › Security) | Firebase multi-factor with SMS: `multiFactor(user).getSession()` → `PhoneAuthProvider.verifyPhoneNumber({ phoneNumber, session })` → `PhoneMultiFactorGenerator.assertion(cred)` → `multiFactor(user).enroll(assertion, "Phone")`; list `multiFactor(user).enrolledFactors`; remove with `unenroll` after re-authentication. Requires a verified e-mail (offer "Send verification email"); phone-only accounts already sign in with SMS. `auth/operation-not-allowed` → "Two-step verification is not available yet." |
| Second factor at sign-in | catch `auth/multi-factor-auth-required` on **every** sign-in path → `getMultiFactorResolver(auth, error)` → send the SMS to the phone hint → `resolver.resolveSignIn(assertion)` |
| Re-authentication (4.7) | `reauthenticateWithCredential` (password), `reauthenticateWithPopup` (Google, Apple, LinkedIn), SMS code for phone accounts; the multi-factor challenge applies here too. Skip when the last sign-in is less than 4 minutes old; after success refresh the ID token (`getIdToken(true)`). |
| Notification preferences (Finance › Profile › Notifications) | update `users/{uid}.financeNotificationPrefs` with the **complete** map `{ push, sms, email }` × `{ payments, groups, loans, investments, insurance, news }`; note "Security notices are always sent" |
| Saved payment methods (Profile › Payment methods) | update `users/{uid}.savedPaymentMethods` (Mobile Money: operator + number; Wave: number; **bank account**: bank name, optional bank code, holder name, account number / IBAN — used only to receive money) |
| Restriction | read `users/{uid}.financeRestriction`; show a danger notice ("Your Spideli Finance account is restricted for: Loans, Tontines…", the reason, "Contact support") on Home, Profile and in the restricted modules, and disable the blocked actions (4.8) |

### 5.3 Information architecture (routes)

The Finance area has five top-level sections (desktop: left navigation rail; tablet / mobile web: bottom bar), each keeping its scroll position:

| Section | Route | Content (section 6) |
|---|---|---|
| Home | `/finance` | 6.1 |
| Wallet | `/finance/wallet` | 6.3 |
| Services | `/finance/services` | 6.1.3 |
| Insights | `/finance/insights` | 6.1.4 |
| Profile | `/finance/profile` | 6.1.5 |

Module routes: `/finance/actions`, `/finance/kyc`, `/finance/wallet/add`, `/finance/wallet/withdraw`, `/finance/wallet/convert`, `/finance/wallet/operations/:id`, `/finance/transfers`, `/finance/transfers/new/:channel`, `/finance/transfers/:id`, `/finance/bills`, `/finance/bills/category/:category`, `/finance/bills/pay/:billerId`, `/finance/bills/requests/:id`, `/finance/cards`, `/finance/cards/new`, `/finance/cards/:id`, `/finance/cards/:id/limits`, `/finance/savings`, `/finance/savings/new`, `/finance/savings/:id`, `/finance/tontines`, `/finance/tontines/new`, `/finance/tontines/:id`, `/finance/loans`, `/finance/loans/apply`, `/finance/loans/:id`, `/finance/financing` (+ `/projects/:id`, `/applications/:id`, `/resources/:id`), `/finance/investments` (+ `/funds/:id`, `/funds/:id/subscribe`, `/holdings/:fundId`, `/orders/:kind/:id`, `/simulator`), `/finance/insurance` (+ `/products/:id`, `/products/:id/quote`, `/quotes/:id`, `/policies/:id`, `/policies/:id/claim`, `/claims/:id`), `/finance/markets` (+ `/indicators/:id`, `/rates/:pair`, `/securities/:id`, `/ipos/:id`, `/collections/:id`, `/news/:id`, `/opportunities/:id`, `/preferences`), `/finance/messages`, `/finance/messages/:chatId`, `/finance/security`, `/finance/notifications`, `/finance/statement`.

### 5.4 Design system (web)

Match the app's finance design system so both look like one product:

| Token | Light | Dark |
|---|---|---|
| Ink / brand (navy) | `#0B2A4A` | `#8DB4FF` (text, icons) |
| Ink card background | `#0B2A4A` | `#14263F` |
| Page background | `#F4F6F9` | the dark background |
| Surface | white, 1 px border, radius 12 | raised dark surface |
| Brass (verified, highlights) | `#8A6A2F` on white, badge `#E3C17A` | `#E3C17A` |
| Families | pay `#1D4ED8` / save `#0F766E` / borrow `#8A5A00` / help `#6D28D9` with soft tints | `#8DB4FF` / `#5EEAD4` / `#F2C14E` / `#C4B5FD` |
| Money in | success green; money out: default text (never red); red only for failures / overdue | |

Components:
- **Ink card**: balance with the currency code smaller, an eye that hides the amounts, key figures in an inset panel, faint guilloche line pattern.
- **Round action buttons**: 52 px circles.
- **Section title**: uppercase overline with an optional link ("See all", 48 px target).
- **List row**: icon or date badge, title, subtitle, amount, status chip with icon and text.
- **Status chip**: tone + icon + label; colour is never the only cue.
- **Progress bar**, **calendar date badge** (month + day), **in / out bars** with net and an arrow-and-words comparison.
- **Product tiles** and **service tiles**: 2 per row, 1 when narrow.
- **States**: skeleton while loading; error with Retry; empty with what to do next; "no longer available" for a missing document.

Accessibility: WCAG 2.1 AA contrast, 44-48 px targets, keyboard navigation and visible focus, labels on every input, live regions for status changes, reduced motion respected, amounts and references left-to-right in Arabic.

Responsive: content max width ~1100 px; 2-column layouts on desktop (list + detail); forms single-column, max ~560 px; no horizontal scrolling at 320 px.

### 5.5 Common behaviours (every module)

- **Settings first:** load the module's `platform_settings` document once. Missing or invalid → "… is not available yet"; failed read → error with Retry.
- **Identity gate:** money actions require `users/{uid}.kycLevel` non-empty; otherwise disable them and show "Verify your identity to save, pay and withdraw" with a link to `/finance/kyc`.
- **Forms:**
  - every field has a label; required ones are marked;
  - inline errors appear once a field has been left;
  - "To continue: …" lists what is missing above a disabled submit button;
  - amounts are entered in major units and converted to minor units (the conversion rule below);
  - entered values are preserved across errors;
  - a confirmation step summarises figures, fees and terms before every money or binding action.
- **Amount input → minor units:** accept digits, spaces and one decimal mark (`.` or `,`); refuse more decimals than the currency allows ("Enter a whole amount, without decimals." / "Enter an amount with at most N decimals."); zero → "Enter an amount greater than zero."; then `minor = major × 10^exponent`.
- **After a write:** show the result screen or toast, then follow the document live.
- **Pushes to other people** (best effort, after the batch commits, never to the sender): the event's `dynamic_notification` template sent to the recipient's `users/{uid}.fcmToken`. **The website must never hold FCM or Admin SDK credentials** (1.6). Send through the push relay of 1.6 when `settings/notification_setting.serverPushUrl` is set (the signed-in user's ID token + the message, `kind` = the template type); while it is not set, the website sends no pushes (the events still appear live on the recipient's screens, and the admin panel notifies its own decisions).

## 6. Customer features

Each feature lists: screens, the flow, validations, **the exact Firestore writes** (one batch unless stated; "+ posting" = section 4.1 with the given type, accounts and `source`), what the admin does next, and acceptance criteria.

### 6.1 Finance dashboard

#### 6.1.1 Home (`/finance`)

Top to bottom:
1. **Greeting:** the date ("WEDNESDAY 14 OCTOBER") and "Good morning / afternoon / evening, {firstName}".
2. **Restriction notice** when `financeRestriction` applies (4.8).
3. **Verification banner** while `kycLevel` is empty. Its text depends on the latest application:
   - none: "Verify your identity to use Spideli Finance services." → Verify my identity
   - `additional_info_required`: "Your verification needs more information." → Open verification
   - `rejected`: "Your verification was not approved. You can submit it again." (danger tone)
   - `draft`: "Finish your verification and submit it."
   - otherwise: "Your documents are being reviewed." (info tone)
4. **Balance card** (ink card, privacy eye). It shows:
   - "Available balance": the user's main wallet, i.e. the active wallet in the dashboard currency, else the first one;
   - its currency code, set smaller than the amount;
   - "Also: 1 200 EUR · …" for the other wallets, or "Your wallet opens with your first deposit." when the user has none;
   - inset figures: Invested, Saved so far, Still to repay (only when the user has them).
   - On a read error: "Could not load your balances." and a **Retry** action.
5. **Round actions** (four):
   - **Add money** if `wallet.deposit.enabled`
   - Send
   - Pay bills
   - **Withdraw** if `wallet.withdraw.enabled`
   - then Save and Invest to fill up to four.
6. **Needs your action** (top 3, "See all" → `/finance/actions`; hidden when empty), 6.1.6.
7. **Coming up** (up to 4, soonest first), each with a calendar badge, a relative line ("Today", "Tomorrow", "Thursday · In 3 days", "In 9 days", "Past due") and the amount:
   - an overdue loan ("Repay now to avoid late payment penalties", danger);
   - otherwise the next loan instalment;
   - the next tontine contribution;
   - the next insurance renewal.
8. **This month** (link "Insights"): the net with its sign, then Money in and Money out as bars, each with "↑ 12 % vs Sep 2026 (500 000 XAF)".
9. **Your money** tiles (each opens its module):
   - Collective savings: saved amount, progress bar, "54% of the target · 1 active";
   - Investment: current value, "Return +4.3 % · +4 300 XAF";
   - Loan: still to repay (or "Repayment overdue", danger), plus what the user lent when there is some;
   - Tontine: next contribution, "2 active";
   - Online insurance: "1 policy", "0 open claims".
10. Footnote "From your Spideli Finance records · Updated 14 Oct, 20:52".
11. **Recent activity**: the last 5 ledger transactions; "See all" → Wallet.

Top bar: Messages (with an unread dot), Download statement.

#### 6.1.2 Dashboard totals (computed in the browser)

No server keeps totals; compute them live from the user's own records. Use **one currency**: the user's largest active wallet, else the most frequent currency among their records, else `XAF`. Records in another currency are left out.

| Source (listener) | Gives |
|---|---|
| `financial_accounts` where `userId == uid` | wallets, sides |
| `investment_holdings` where `userId == uid` | invested = Σ `investedAmount`, value = Σ `currentValue`, realized / unrealized gains, allocation by `assetClass`; return % = (realized + unrealized) × 100 / invested |
| `savings_goals` where `memberIds` contains uid, status `active` | count, Σ `savedAmount`, Σ `targetAmount`, progress |
| `tontines` where `memberIds` contains uid | active count; next contribution = earliest `nextDueAt` of active tontines (moved one period later when `tontine_contributions/{tid}_{currentCycle}_{uid}` exists with `paid`), amount = `contributionAmount` |
| `loan_applications` where `borrowerId == uid` (limit 50) + `loan_schedules/{loanId}` of `active` / `overdue` loans | still to repay = Σ `outstandingAmount`; overdue count; next instalment = first instalment not `paid`, amount `amountDue − paidAmount` |
| `loan_applications` where `lenderIds` contains uid (limit 50) + `loan_fundings` where `lenderId == uid` | lent outstanding = Σ (`amount` − `collected`) of `succeeded` fundings of loans still open |
| `insurance_policies`, `insurance_claims` where `userId == uid` (limit 50) | active policies (`active`, `renewal_due`), next renewal (`renewalDate` or `coverEnd`), open claims (`submitted`, `under_review`, `info_requested`, `approved`) |
| `ledger_transactions` where `userIds` contains uid and `createdAt ≥ now − 366 days`, order `createdAt` desc, limit 500 | per month (yyyy-MM, last 12): money in = Σ positive signed amounts, money out = Σ negative; last 30 days by kind: deposits (`deposit`), withdrawals (`withdrawal`), transfers (`transfer`, `transfer_out`), card payments (`card_funding`, `card_fee`), bill payments (`bill_payment`). Skip `reversed` transactions. |

**Signed amount of a transaction for the user** = Σ over its lines on the user's own accounts of (+amount if `direction == account.normalSide` else −amount).

#### 6.1.3 Services (`/finance/services`)

Headline "What would you like to do?", subtitle "Every Spideli Finance service, by what it helps you do.", then four families of tiles (icon on the family tint, title, one-line description):

| Family (colour) | Services |
|---|---|
| Pay and send (blue) | Money transfer · Payment (bills) · Virtual card |
| Save and invest (teal) | Collective savings · Tontine · Investment |
| Borrow and protect (amber) | Loan · Online insurance |
| Get help (violet) | AI assistant |

#### 6.1.4 Insights (`/finance/insights`)

1. **This month:** the in / out comparison (as on Home).
2. **Cash flow:** a bar chart of money in and money out for the last 12 months. Tapping a month shows its figures. The legend has colour **and** labels. With no data: "No figures for this period yet." Footnote: "Money in and out of your Spideli Finance accounts, as recorded."
3. **Last 30 days:** one bar per kind, largest first (deposits, withdrawals, transfers, card payments, bill payments).
4. **Plan and understand** tiles:
   - AI assistant;
   - Markets: indicators, exchange rates, stocks, bonds, IPOs and news;
   - Account statement (6.3.5).

#### 6.1.5 Profile (`/finance/profile`)

1. **Identity card** (ink). It shows:
   - the photo or initials in a ring, brass once verified;
   - name and contact;
   - the badge: "Verified" (brass, seal icon) or the application status;
   - three facts: Identity (status), Wallets (currencies), Two-step (On / Off, from `enrolledFactors`).
   - Clicking it opens the profile editor.
2. **Spideli Finance:** Document verification (status chip), Groups (tontines, savings goals, loan groups), Wallets ("One per currency: XAF"), Messages, Account statement, Security (two-step verification), Notifications (preferences).
3. The site's general account options (profile, payment methods incl. bank accounts, password, language, dark mode, help and support, privacy, terms, log out, delete account).

#### 6.1.6 Needs your action (`/finance/actions`)

A live list built from these sources:

| Item | Source and condition | Urgent | Opens |
|---|---|---|---|
| Answer a tontine invitation | `tontine_members` where `userId == uid` and `status == "invited"` | | Tontines |
| Answer a savings goal invitation | `savings_goals` where `invitedIds` contains uid | | Savings |
| Vote on a loan request | `loan_applications` where `eligibleVoterIds` contains uid, `status == "voting"`, now < `votingEndsAt`, no `loan_votes/{loanId}_{uid}`, not the borrower | | the loan |
| A loan in your group is collecting funds | same query, `status == "funding"`, `amount > fundedAmount` | | the loan |
| Accept your loan agreement | own loan `agreement_pending` | yes | the loan |
| Loan repayment overdue | own loan `overdue` | yes | the loan |
| Your insurance quote is ready | `insurance_quotes` of the user, `quoted`, now < `validUntil` | | Insurance › Quotes |
| The insurer needs more information | `insurance_claims` of the user, `info_requested` | yes | Insurance › Claims |

Order: urgent first, then the soonest due date. Re-evaluate every minute (deadlines). A source the user cannot read counts as empty.

### 6.2 Identity verification (KYC) (`/finance/kyc`)

**Reads:**
- `platform_settings/kyc`;
- `kyc_applications` where `userId == uid` (sort by `createdAt` in the browser);
- `kyc_documents` where `applicationId == X` and `userId == uid`;
- `kyc_reviews` where `applicationId == X` and `userId == uid` (sort by `at`).

**Start** (no open application):
- Individual | Business tabs. Business only when a level allows it.
- The levels not yet approved, nor covered by an approved one.
- **Start verification** writes:

```
kyc_applications/{autoId} create { id, userId: uid, level, accountType: "individual"|"business", status: "draft", revision: 1,
    personal: {}, business: {} (business accounts only), reason: null, createdAt, updatedAt }
```

If an open application of that level exists, open it instead.

**Details form** (only while `draft` / `additional_info_required`; strings trimmed, ≤ 200 characters):
- personal: full name\*, date of birth (`yyyy-MM-dd`, at least 16 years old), nationality, ID number, address, city, country (searchable country list);
- business accounts add: company name\*, registration number\*, tax number, registered address, country.

"Save details" writes: `kyc_applications/{id}` update `{ personal: {…}, business?: {…}, updatedAt }`.

**Documents:**
- Show the groups as "Provide one of these", with "Documents provided: x of y".
- Each row shows one type and side, with status Added / Accepted / Rejected / Missing.
- Upload (camera or file):
  - JPEG, longest side ≤ 2400 px, quality 0.85;
  - refuse files over `maxFileBytes`;
  - Storage `kyc/{uid}/{applicationId}/{type}-{side}-{epochMillis}.jpg` (`contentType: image/jpeg`).
- Then:

```
kyc_documents/{applicationId}_{type}_{side}_{epochMillis} create { id, applicationId, userId, type, side, status: "uploaded",
    storagePath, contentType, size, revision, createdAt }
+ every earlier document of the same type and side not already superseded: update { status: "superseded", supersededBy: <new id>, updatedAt }
```

**Submit for review:**
- The button stays disabled until every required field and document group is present.
- It saves the form, then writes:

```
kyc_applications/{id} update { status: "submitted", submittedAt, updatedAt }
kyc_reviews/{autoId} create { id, applicationId, userId, action: "submit", reason: null, at }
```

**Start again** (only from `rejected`):

```
kyc_applications/{id} update { status: "draft", revision: old + 1, reason: null, updatedAt }
kyc_reviews/{autoId} create { …, action: "reopen", at }
```

**Display:**
- Status chip and reason (`additional_info_required`, `rejected`).
- The review history (Submitted, Review started, More information requested, Approved, Not approved, Started again).
- The status shown everywhere is the **latest application's**, not `users.kycStatus`.

**Admin next:** review → `under_review` → `additional_info_required` / `approved` (sets `users.kycLevel`) / `rejected`.

**Acceptance:** a draft can be saved and resumed; submitting needs every requirement; an approved user's money actions unlock without reloading.

### 6.3 Wallet

#### 6.3.1 Wallet page (`/finance/wallet`)

1. **Ink card:**
   - the balance of the main wallet, with the privacy eye;
   - "Also: …" for other wallets;
   - round actions: Add money, Withdraw, Send, Convert (when `convert.enabled`), Pay bills, Statement.
2. **In progress:** the user's `wallet_operations` with status `pending`.
3. **History** (`ledger_transactions` where `userIds` contains uid, `orderBy createdAt desc`, pages of 20 via `startAfter`):
   - **Search** by reference, description or type label. Debounce 300 ms. When fewer than 20 loaded rows match, load up to 4 more pages automatically, then offer "Search older transactions".
   - **Filters:** a date range (`createdAt ≥ from` and `< to + 1 day`) and type chips (all, deposit, withdrawal, transfer, adjustment, reversal; server-side `where type ==`).
   - **Rows**, grouped by day (Today / Yesterday / date):
     - a round in / out icon;
     - the description or type label;
     - the time and the reference;
     - the signed amount (+ green for money in, − in normal text for money out);
     - a "Reversed" chip on reversed transactions, with the amount muted.
   - "Load more" button.
4. **Detail drawer:** amount, status (Completed / Reversed), description, type, date, reference (copy button), "Reverses" (`reversalOf`).

Type labels: deposit → Deposit, withdrawal → Withdrawal, transfer / transfer_out → Transfer, manual_adjustment → Adjustment, reversal → Reversal, bill_payment → Bill payment, card_funding → Card top-up, card_fee → Card fee, card_withdrawal → Card withdrawal, savings_contribution → Savings contribution, savings_withdrawal → Savings withdrawal, tontine_contribution → Tontine contribution, tontine_payout → Tontine payout, loan_funding → Loan funding, loan_disbursement → Loan disbursement, loan_repayment → Loan repayment, loan_lender_payout → Loan repayment received, investment_subscription → Investment, investment_redemption → Investment redemption, insurance_premium → Insurance premium, insurance_claim_payout → Insurance claim payment, conversion → Currency conversion, fee → Fee; other → Transaction.

#### 6.3.2 Add money (`/finance/wallet/add`) — restriction scope `wallet`

1. Choose the currency (`wallet.currencies`) and the amount, within `deposit.min` and `deposit.max`.
2. Choose a gateway: one of `deposit.methods` that is enabled for the user's region and can charge the currency (4.5).
3. Run the checkout. On success, write:

```
wallet_operations/{method}_{reference} create { id, userId, type: "deposit", status: "completed", currency, amount, fee: 0, total: amount,
    accountId: <wallet id>, gateway: { method, reference }, txId, reference: <SPF ref>, createdAt, completedAt }
payment_receipts/{method}_{reference} create { method, reference, txId, amount, currency, userId, verified: false, createdAt }
+ posting "deposit": platform_{CUR} → wallet (create wallet_{uid}_{CUR} if missing), funding "gateway", gateway { method, reference },
    source { kind: "wallet_operations", id }
```

4. Result: the money is in the wallet at once.

**Admin next:** reconcile the receipt.

#### 6.3.3 Withdraw (`/finance/wallet/withdraw`) — restriction scope `wallet`

1. Enter the amount. Fee = withdraw fee rule (2.2); total = amount + fee. Refuse when total > balance ("The amount and its fee are more than your balance.").
2. Show "You receive" and "Taken from your wallet".
3. Choose the destination: a saved Mobile Money, Wave or bank account (`withdraw.methods`).
4. Re-authenticate (4.7: skipped only below a `wallet.security.reauthAbove[CUR]` > 0), then write:

```
wallet_operations/{requestKey} create { id, userId, type: "withdrawal", status: "pending", currency, amount, fee, total, accountId,
    destination, txId, reference, createdAt }
+ posting "withdrawal": wallet → platform_{CUR} of total (2 lines), source { wallet_operations, id }
```

**Admin next:** pay out → `completed` (+ `payoutReference`, `completedAt`), or `failed` / `reversed` + `reason` + a reversal posting.

The operation page (`/finance/wallet/operations/:id`) follows the status live: "Spideli Finance is paying out this withdrawal…", or "This withdrawal could not be paid out: the money is back in your wallet."

#### 6.3.4 Convert (`/finance/wallet/convert`) — restriction scope `wallet`

1. Choose From and To currencies (`convert.currencies`) and the amount, from the From wallet.
2. Rate = the newest `exchange_rate_snapshots` where `pair == "{from}_{to}"`, else the inverse pair (rate = 1 / rate). Its `observedAt` must be newer than `maxRateAgeHours`; otherwise "No exchange rate is available for these currencies right now."
3. Compute: fee = round(amount × `convert.feePercent` / 100) (no fixed part, no cap); receive = floor((amount − fee) × R × 10^(exp(To) − exp(From))), where R = `rate` when the snapshot's `from` is the From currency, else 1 / `rate`, and exp = 0 for XAF / XOF / GNF / RWF, else 2. Example: 100 000 XAF → EUR, fee 1 000, snapshot EUR→XAF 655.957: receive = floor(99 000 / 655.957 × 100) = 15 092 (150.92 EUR). The rules refuse any receive amount above this cap and any snapshot older than `maxRateAgeHours` (default 48).
4. Confirm, then re-read the rate. If the receive amount changed, ask again.
5. Write one batch:

```
wallet_operations/{requestKey} create { id, userId, type: "conversion", status: "completed", currency: from, amount, fee, total: amount,
    accountId: fromWallet, toCurrency, toAccountId: toWallet, rate, rateSource, rateObservedAt, rateSnapshotId: <snapshot doc id>,
    receiveAmount, txId, txIds: [txA, txA + "b"], reference, createdAt, completedAt }
+ posting "conversion" A: fromWallet → platform_{FROM} of amount, id txA
+ posting "conversion" B: platform_{TO} → toWallet of receiveAmount, id txA+"b" (creates the To wallet if missing); same reference
```

#### 6.3.5 Statement (`/finance/statement`)

Pick a period (default: the last month).

1. Read the transactions in pages of 200, at most 2 000. Beyond that: "This period has too many transactions for one statement…".
2. Build a PDF with: the holder, the period, money in and out per currency, then one row per transaction (date and time, reference, type, status, signed amount).
3. Download it.

Nothing is written.

### 6.4 Money transfer — restriction scope `transfers`

**Settings:** `platform_settings/transfers`.

**List page** (`/finance/transfers`):
- **Send to:** one row per enabled channel with its delay.
- **Recent recipients:** `transfer_beneficiaries` where `userId == uid`, `orderBy lastUsedAt desc`, limit 20. Each can be re-used, or deleted after a confirmation.
- **History:** `money_transfers` where `participantIds` contains uid, `orderBy createdAt desc`, limit 50.
  - Filters: All, Sent (`senderId == uid`), Received, In progress, Completed, Not completed.
  - Incoming transfers show `+receiveAmount`; outgoing ones `−total`.
  - "Showing your latest 50 transfers" when the limit is reached.

**Form** (`/finance/transfers/new/:channel`):

| Channel | Fields | Validation |
|---|---|---|
| Spideli user (`internal`) | e-mail or phone (tabs) | e-mail `^[^@\s]+@[^@\s]+\.[^@\s]{2,}$`; phone 8-15 digits (optional `+`, spaces / `-` / `.` / `()` stripped). Lookup in `users` by `email` / `phoneNumber` (whereIn the normalised variants, limit 2). Exactly one match → show **"Spideli account found: {name}"**; none → `recipient_not_found`; several → `recipient_ambiguous`; yourself → `self_transfer`. |
| Mobile Money | operator (from settings), number, name (optional) | number as above |
| Wave | number, name (optional) | |
| Bank | bank (searchable from the settings list), account holder (≥ 3 characters), account number or IBAN | IBAN (2 letters + 2 digits…) checked mod-97; otherwise 6-34 letters / digits |

All channels also have:
- Amount: ≥ `max(1, min[CUR])` and ≤ `max[CUR]`.
- "Available balance: X" when the wallet can pay.
- Note: optional, 140 characters.
- "Save this recipient": on by default.
- **Estimate:** amount, fee (rule 2.3; "Free" when 0), delivery delay, total.

**Confirm card** (before any payment): recipient and its details, channel, amount, fee, "The recipient receives", note, total to pay.

Re-authenticate (4.7: skipped only below a `transfers.security.reauthAbove[CUR]` > 0, compared with `amount`), then pay (4.5):

```
INTERNAL (status completed at once):
money_transfers/{requestKey} create { id, senderId: uid, senderName, recipientId, participantIds: [uid, recipientId], channel: "internal",
    recipient: { email } | { phone }, recipientName, recipientVerified: true, currency, amount, fee, total, receiveAmount: amount,
    note?, funding: { method: "wallet" } , status: "completed", reference, txId, createdAt, completedAt }
+ posting "transfer": sender wallet → recipient wallet_{rid}_{CUR} (created in the batch if missing, userId = recipient) of amount;
    lines[0] = total; a 3rd fee line to platform_{CUR} only when fee > 0; userIds [sender, recipient]
→ push "transfer_received" { amount, senderName } to the recipient

EXTERNAL (Mobile Money / Wave / bank):
money_transfers/{requestKey} create { … participantIds: [uid], channel, recipient: { … full number / account, bank also
    accountMasked: "•••• 6789" } (≤ 12 keys; only the sender and the admin can read it), recipientName, recipientVerified: false,
    status: "processing", … } — no recipientId, no completedAt
+ posting "transfer_out": wallet → platform_{CUR} of total
```

**After success**, as a separate write, save the recipient (when ticked):

```
transfer_beneficiaries/ben_{uid}_{channel}_{key} create { userId, channel, displayName, detail (masked), recipient, createdAt, lastUsedAt }
```

**Transfer page** (`/finance/transfers/:id`, live):
- Status track and chip.
- The recipient, with "Recipient verified" when verified.
- The reason, when there is one.
- "Ask to cancel": only when external, `processing`, no `adminLockedAt`, not already requested. It writes `money_transfers/{id}` update `{ cancelRequested: true, cancelRequestedAt }`.
- "Share the receipt" (PDF) when `completed` or `reversed`.
- An internal recipient sees: sender, amount received, note. Never the fee or the payment method.

| Status | Label |
|---|---|
| `completed` | Completed |
| `processing` | Processing ("Spideli Finance is sending the money…") |
| `failed` | Failed (shown only if the admin marks a transfer failed before any money moved; a paid transfer that fails ends `reversed`) |
| `cancelled` | Cancelled (refunded after the sender's cancel request) |
| `reversed` | Refunded |

**Admin next (external):** set `adminLockedAt`, pay out → `completed`, or refund → `reversed`. A cancel request not yet paid → reversal + `cancelled`.

### 6.5 Payment (bills) — restriction scope `payments`

**Page** (`/finance/bills`):
- "What do you want to pay?": one row per category of the settings:
  - Electricity, Water, Television, Internet, Phone credit, Gas, School fees;
  - Taxes ("Tax payments"), Products ("Pay for products and services"), Other.
- **My bills:** `utility_saved_accounts` where `userId == uid`, `orderBy lastUsedAt desc`, limit 20. Each can be re-used, or deleted after a confirmation.
- **History:** `utility_payment_requests` where `userId == uid`, `orderBy createdAt desc`, limit 50.

**Billers** (`/finance/bills/category/:category`): `utility_billers` where `published == true` and `category == X`, limit 100.
- Keep only `currencies` of the settings.
- Sort by `order`, then name.
- A search box (name or country) appears from 7 billers.

**Pay** (`/finance/bills/pay/:billerId`):
- **Account field:**
  - label `accountLabel` (default "Account or contract number"), helper `accountHint`;
  - validated against `accountPattern`, anchored as `^(?:pattern)$`;
  - digits-only keyboard when the pattern allows only digits.
- **Amount by `amountType`:**
  - `open`: min..max.
  - `packages`: choose one, searchable when there are more than 8.
  - `due`: no lookup API exists. The user types the amount on the bill, up to `max`, with the notice "Enter the amount shown on your bill. Spideli Finance pays the biller this amount for this account."
- **Estimate:** amount, fee (biller fee rule), total.
- "Save this account for next time" (on).

Re-authenticate (4.7: skipped only when the **total** is below a `bills.security.reauthAbove[CUR]` > 0), then pay (4.5):

```
utility_payment_requests/{requestKey} create { id, userId, billerId, billerName, category, account, packageCode?, packageName?,
    currency, amount, fee, total, status: "processing", reference, txId, funding, createdAt }
+ posting "bill_payment": wallet → platform_{CUR} of total
then (ticked) utility_saved_accounts/acc_{uid}_{billerId}_{account} create { userId, billerId, billerName, category, account, nickname: "",
    createdAt, lastUsedAt }
```

**Request page** (live):
- Biller, account, customer name (set by the admin), package, amount, fee, reference, biller reference.
- On `completed` with a `token`: a large card with `tokenLabel` (default "Your code"), the token, units, and a Copy button.
- Receipt PDF.
- Statuses: Processing, Completed, Failed, Refunded.

**Admin next:** pay the biller → `completed` (+ token for prepaid bills), or refund.

### 6.6 Virtual cards

**Settings:** `platform_settings/cards`. **Hidden** until `terms` and `termsVersion` are set.

**Cards** (`/finance/cards`): `virtual_cards` where `userId == uid`, `orderBy createdAt desc`, limit 20.
- Each card is drawn as a card face: `•••• •••• •••• {last4}`, "Valid thru MM/YY", holder, network. Greyed when not active.
- Balance and status.
- "Get a virtual card" while the cards in `requested` / `active` / `frozen` number fewer than `maxCardsPerUser`.

**New card** (`/finance/cards/new`):
- Card name (optional, ≤ 24 characters), currency.
- "Fees and limits": issuer, creation fee, monthly fee, top-up fee %, minimum and maximum top-up, maximum per payment.
- "What you can do": the capabilities.
- Terms: version, "Read the terms", accept checkbox.
- Identity gate.

Writes:

```
virtual_cards/{requestKey} create { id, userId, label, currency, network, status: "requested", balance: 0, termsVersion, acceptedAt,
    issuanceFee, reference, createdAt, updatedAt [, feeTxId, payment] }
+ when issuanceFee > 0: posting "card_fee": wallet → platform of the fee (paid via 4.5)
```

**Card page** (`/finance/cards/:id`, live) actions:

| Action | When | Re-auth | Writes |
|---|---|---|---|
| Top up | active | | Amount within min / max funding. Fee = round(amount × fundingFeePercent / 100). Confirm "The card receives / Top-up fee / You pay". `card_funding_requests/{key}` create `{ id, userId, cardId, type: "fund", amount, fee, total, currency, status: "pending", txId, reference, payment, createdAt }` + posting `card_funding` wallet → platform of `total` |
| Freeze | active | | `virtual_cards/{id}` update `{ status: "frozen", frozenBy: "user", frozenAt, updatedAt }` |
| Unfreeze | frozen and `frozenBy == "user"` | yes | update `{ status: "active", frozenBy: null, unfrozenAt, updatedAt }`. Frozen by the issuer / admin: "frozen for your security. Contact support." |
| Limits (`/limits`) | active or frozen | yes (save) | Per payment ≤ per day ≤ per month, each ≤ its ceiling (empty = issuer maximum). Online / abroad switches when supported. `card_limit_settings/{cardId}` set-merge `{ userId, cardId, perTransaction, daily, monthly, allowOnline?, allowInternational?, status: "pending", updatedAt }` (the rules check the whole merged document: `updatedAt == request.time`). Show "Your last change is waiting for the issuer." while `pending`. |
| To wallet | `capabilities.withdraw`, balance > 0 | yes | `card_funding_requests` create `{ type: "withdraw", amount ≤ balance − pending requests, fee: 0, destination: { method: "wallet" }, status: "pending", reference, … }` (no posting) |
| Send to another card | `capabilities.cardTransfer` | yes | Recipient by e-mail / phone, as for transfers. `card_funding_requests` create `{ type: "transfer", amount, fee: 0, recipientId, recipient: { userId, name, contact }, status: "pending", … }` |
| Renew | `capabilities.renew`, expired or expiring within 30 days, not replaced, `renewalRequestedAt` absent | | `virtual_cards/{id}` update `{ renewalRequestedAt, renewalFee [, renewalTxId, renewalReference, renewalPayment] }` (+ `card_fee` posting when there is a fee) |
| Delete this card | active, expired or frozen by the user | yes | confirm "Its balance is returned to your wallet" → update `{ status: "termination_requested", statusBefore, terminationRequestedAt, updatedAt }` |
| Show details | `secureDetails != "none"` | yes | needs the issuer's secure page; while none exists, hidden |

**Activity:**
- "In progress": `card_funding_requests` where `userId == uid` and `cardId == X`, `orderBy createdAt desc`, limit 10, status `pending`.
- Card transactions: `card_transactions` where `userId` and `cardId`, `orderBy createdAt desc`, limit 50, grouped by day; declined and reversed rows muted.

**Admin next:** issue, load, unload, transfer, apply limits, renew, close (admin spec).

### 6.7 Collective savings — restriction scope `savings` (new goals, joining)

**Settings:** `platform_settings/savings`. **Reads:**
- `savings_goals` where `memberIds` contains uid, `orderBy createdAt desc`;
- `savings_goals` where `invitedIds` contains uid;
- `savings_contributions` where `goalId == X`, `orderBy createdAt desc`, limit 50;
- `savings_withdrawals` where `goalId == X`, `orderBy createdAt desc`, limit 20.

**List** (`/finance/savings`):
- hero "Saved so far" (dashboard totals);
- invitations (Join / Decline);
- active goals and closed goals;
- "New savings goal".

**Create** (`/finance/savings/new`):

| Field | Rule |
|---|---|
| Name\* | required |
| Purpose\* | real estate, education, travel, health, business, other (settings) |
| Description | optional |
| Target\* and currency | > 0, currency from the settings |
| Deadline | optional, today to +30 years |
| Schedule | frequency (weekly, every two weeks, monthly) and "Amount each time" (required once a frequency is chosen) |
| Invite members (when `groupGoals`) | e-mails separated by comma, semicolon or space. Each is looked up in `users` by e-mail (lower case): unknown → "No Spideli account uses this email: {email}"; yourself → `invite_self`. Count + 1 ≤ `maxMembers` (`group_full`). |

```
savings_goals/{requestKey} create { id, ownerId: uid, memberIds: [uid], invitedIds: [invitee uids], name, purpose, description, currency,
    targetAmount, savedAmount: 0, deadline?, schedule?: { frequency, amount }, status: "active", accountId: "goal_{id}", createdAt, updatedAt }
financial_accounts/goal_{id} create { id, kind: "savings_goal", refId: goalId, currency, memberIds: [uid], balance: 0,
    normalSide: "credit", status: "active", createdAt, updatedAt }
→ push "savings_invite" { goalName, inviterName } to each invitee
```

**Goal page** (`/finance/savings/:id`, live):
- Hero: saved, of the target, remaining, progress.
- **Progress over time** chart: per month, saved at month end, added, withdrawn. Built from the contributions and withdrawals.
- **Projection:**
  - monthly rate = schedule amount × (weekly 52/12, every two weeks 26/12, monthly 1), or the average of the `succeeded` contributions per month since the first;
  - estimated completion date;
  - needed per month to meet the deadline;
  - on track or not.
- Plan (owner can **Edit** while active).
- Members, each with a "Message" button.
- Contributions, labelled "You" / "Goal owner" / "A member", with a "latest 50" note.
- Withdrawals.

**Actions:**

| Action | Who / when | Writes |
|---|---|---|
| Invite | owner, `groupGoals`, members + invited < `maxMembers`, not self, not already in | `savings_goals/{id}` update `{ invitedIds: arrayUnion([inviteeUid]), updatedAt }` |
| Join / Decline | the invitee (Join after a summary: purpose, target, saved, deadline, schedule, members) | update `{ invitedIds: arrayRemove([uid]), memberIds: arrayUnion([uid]) (join only), updatedAt }` |
| Edit | owner, active. Name, description, deadline (can be moved, not removed), schedule (or remove it). | update `{ name?, description?, deadline?, schedule? \| deleteField(), updatedAt }` (only changed fields) |
| Add money | a member, goal active, identity gate | pay (4.5): `savings_contributions/{requestKey}` create `{ id, goalId, userId, amount, currency, status: "succeeded", reference, txId, funding: "wallet" (the posting's funding), createdAt }` + posting `savings_contribution` wallet → `goal_{id}` + `savings_goals/{id}` update `{ savedAmount: increment(amount), lastTxId: txId, updatedAt }` |
| Withdraw (solo goal) | owner; `earlyWithdrawal.allowed` or target reached (else `withdrawal_not_allowed`); amount ≤ `savedAmount`; warning before an early withdrawal | `savings_withdrawals/{requestKey}` create `{ id, goalId, userId, amount, currency, destination: { method: "wallet", accountId }, reason?, status: "completed", reference, txId, completedAt, createdAt }` + posting `savings_withdrawal` `goal_{id}` → own wallet (created if missing) + goal update `{ savedAmount: increment(-amount), lastTxId, updatedAt }` |
| Withdraw (group goal) | a member | `savings_withdrawals/{requestKey}` create `{ id, goalId, userId, amount, currency, destination, reason?, status: "requested", reference, createdAt }`: **no** `txId`, **no** `completedAt`, **no** posting ("Spideli checks your request against the group's rules…"). The admin then completes or refuses it (`rejectionReason`). |
| Cancel (solo) | owner, active | posting of the whole `savedAmount` `goal_{id}` → owner wallet (`savings_withdrawal`, source `{ savings_goals, goalId }`) + goal update `{ status: "cancelled", savedAmount: increment(-balance), lastTxId, cancelledAt, updatedAt }` (no posting when nothing is saved) |
| Cancel (group) | owner | update `{ status: "cancellation_requested", cancellationRequestedBy, cancellationRequestedAt, updatedAt }` |

| Status | Labels |
|---|---|
| Goal | Active / Completed / Cancelled |
| Contribution | Received |
| Withdrawal | Requested / Completed / Rejected (with `rejectionReason`) |

**Admin next:** group withdrawals, group cancellations, optionally marking goals completed.

### 6.8 Tontine — restriction scope `tontines` (create, join)

**Settings:** `platform_settings/tontines`.

**Ids:**
- member `{tontineId}_{uid}`;
- cycle `{tontineId}_{n}`;
- contribution `{cycleId}_{uid}`;
- payout `{cycleId}`.

**Reads:**
- `tontines` where `memberIds` contains uid, `orderBy createdAt desc`;
- `tontine_members` where `userId == uid` and `status == "invited"`;
- `tontine_members` where `tontineId == X` (sort by `payoutPosition`);
- `tontine_cycles` where `tontineId == X`, `orderBy number`;
- `tontine_contributions` where `tontineId == X` and `cycleId == Y`;
- `tontine_payouts` where `tontineId == X`, `orderBy createdAt desc`;
- `tontine_disputes` where `tontineId == X`, `orderBy createdAt desc`.

**List** (`/finance/tontines`):
- hero "Next contribution";
- invitations: Join after a confirmation that shows the terms carried on the invitation and "By joining, you commit to paying the contribution every cycle until every member has received the pot." Without terms: "Ask {inviter} for the amount, the frequency and the rules before you join."
- your tontines;
- "Create a tontine";
- Messages button.

**Create** (`/finance/tontines/new`, identity not required; restriction `tontines`):
- Name\*, description, rules.
- Amount per member per cycle\*: ≥ `minContribution[CUR]`.
- Currency, frequency\*.
- Members\*: an integer between `minMembers` and `maxMembers`.
- First contribution date\*: today to +2 years, default +7 days.
- Payout order: "An order set by the administrator" (`fixed`) or "A random draw when the tontine starts" (`random`). Shown only when more than one method is allowed.
- Summary: pot per cycle = amount × members, start date, order.

```
tontines/{requestKey} create { id, name, description, rules, currency, contributionAmount, frequency, membersLimit, payoutOrderMethod,
    startDate, status: "forming", adminIds: [uid], memberIds: [uid], currentCycle: 0, potAccountId: "tontine_{id}", createdBy: uid,
    createdAt, updatedAt }
tontine_members/{id}_{uid} create { id, tontineId, tontineName, userId, displayName, email, role: "admin", status: "active",
    payoutPosition: 1, joinedAt, createdAt }
financial_accounts/tontine_{id} create { id, kind: "tontine_pot", refId, currency, balance: 0, normalSide: "credit", status: "active",
    createdAt, updatedAt }
```

**Tontine page** (`/finance/tontines/:id`): Overview / Members / History / Disputes, plus a group chat button.

| Action | Who / when | Writes |
|---|---|---|
| Invite (by e-mail lookup) | an admin, `forming`; active + invited < `membersLimit` | `tontine_members/{tid}_{invitee}` create `{ id, tontineId, tontineName, userId, displayName, email, role: "member", status: "invited", invitedBy, invitedByName, contributionAmount, currency, frequency, membersLimit, startDate, rules, payoutOrderMethod, invitedAt, createdAt }` (a previously `declined` doc is **updated** back to `invited`) → push `tontine_invite` |
| Join / Decline | the invitee; join refused when full or started (`invitation_closed`) | own member doc update `{ status: "active" \| "declined", respondedAt, joinedAt (join) }` + on join `tontines/{tid}` update `{ memberIds: arrayUnion([uid]), updatedAt }` |
| Payout order | an admin, `forming`, `fixed`. Drag rows, then Save / Discard. | each member doc update `{ payoutPosition: i + 1 }` |
| Start | an admin, `forming`, ≥ `minMembers` active members, `fixed` = positions cover every member. Confirmation shows the terms and the pot. | member docs `{ payoutPosition }` (random: drawn in the browser; or to fill gaps) + `tontines/{tid}` update `{ status: "active", currentCycle: 1, nextDueAt: <cycle 1 due>, startDate (today if the agreed date has passed), startedAt, updatedAt }` + for n = 1..members `tontine_cycles/{tid}_{n}` create `{ id, tontineId, number: n, dueDate, beneficiaryUserId: <member at position n>, expectedAmount: contributionAmount × members, collectedAmount: 0, currency, status: n == 1 ? "collecting" : "upcoming", createdAt }` → push `tontine_started`. Due dates: start date, then one period apart (monthly keeps the day, clamped to the month's end). |
| Pay my contribution | an active member, cycle `collecting`, not paid yet ("Payment in progress" while it confirms) | **transaction:** `tontine_contributions/{cycleId}_{uid}` create `{ id, tontineId, cycleId, cycleNumber, userId, amount: contributionAmount, currency, status: "paid", reference, txId, funding: "wallet", paidAt, createdAt }` + posting `tontine_contribution` → `tontine_{tid}` + cycle update `{ collectedAmount: increment(amount), lastTxId, updatedAt }`. When this completes the pot: also cycle `status: "payout_pending"` + `tontine_payouts/{cycleId}` create `{ id, tontineId, cycleId, cycleNumber, beneficiaryUserId, amount: expectedAmount, currency, status: "pending_approval", createdAt }` → push `tontine_payout_pending_approval` to the admins |
| Approve payout | an admin who is **not** the beneficiary (`payout_self_approval`); the payout's cycle = `currentCycle` | **transaction:** posting `tontine_payout` `tontine_{tid}` → `wallet_{beneficiary}_{CUR}` (created if missing; `createdBy` = approver) + payout `{ status: "paid", txId, reference, approvedBy, approvedAt, paidAt }` + cycle `{ status: "paid", paidAt, updatedAt }` + next cycle `{ status: "collecting", updatedAt }` + tontine `{ currentCycle: n + 1, nextDueAt, updatedAt }`; after the last cycle tontine `{ status: "completed", nextDueAt: deleteField(), completedAt, updatedAt }` → push `tontine_payout_paid`. If the beneficiary is the only admin, show "You are the only administrator: Spideli approves your own payout." |
| Raise a dispute | an active member. Subject ≥ 3 characters, "What happened" ≥ 10, optional member concerned. | `tontine_disputes/{requestKey}` create `{ id, tontineId, raisedBy, againstUserId?, subject, description, status: "open", createdAt }` → push `tontine_dispute_raised` |

**Transparency:**
- The current cycle shows each member's status (paid / being confirmed / not paid / overdue after the due date), "x of y members have paid", collected of expected, the beneficiary and the due date.
- The schedule shows every cycle with its beneficiary.

| Status | Labels |
|---|---|
| Tontine | Forming / Active / Completed / Suspended |
| Member | Invited / Member / Declined / Removed / Restricted |
| Cycle | Upcoming / Collecting / Payout pending / Paid out |
| Payout | Awaiting approval / Paid |
| Dispute | Open / Under review / Resolved / Rejected |

### 6.9 Member loans — restriction scope `loans` (apply, vote, fund, accept)

**Settings:** `platform_settings/lending`. **Reads:**
- `loan_applications` where `borrowerId == uid` / `eligibleVoterIds` contains uid / `lenderIds` contains uid, each `orderBy createdAt desc` limit 50;
- `loan_votes/{loanId}_{uid}`;
- `loan_schedules/{loanId}`, `loan_agreements/{loanId}`;
- `credit_assessments/{loanId}` (borrower only);
- `loan_repayments` where `loanId == X` `orderBy createdAt desc`;
- `loan_fundings` where `loanId == X` and `lenderId == uid`.

**Loans page** (`/finance/loans`): tabs Borrow / Group requests / Lent. The Lent rows show "You lent X", "X being confirmed" and "Available to collect".

**Apply** (`/finance/loans/apply`, identity gate):
- **Group\***: one of the user's tontines that is active or forming. With none: "You need to belong to a tontine group" and a link.
- Amount\* (min..max), currency, purpose, duration (chips from the settings), repayment frequency, "Why do you need this loan?".
- **Estimated repayments**, labelled an estimate:
  - n = months × (weekly 52/12, every two weeks 26/12, monthly 1), rounded;
  - period rate r = annual% / 100 / (52, 26 or 12);
  - flat: interest = round(P × r × n), split evenly, remainder on the last instalment;
  - declining: payment = P·r / (1 − (1 + r)^−n), interest = round(balance × r), the last instalment takes the remaining balance;
  - fee = round(P × feePercent / 100), taken from the pay-out;
  - shows each instalment, the late penalty %, and the total.
- Up to 5 photos.

```
loan_applications/{requestKey} create { id, borrowerId: uid, groupId, groupName, status: "submitted", currency, amount, fundedAmount: 0,
    outstandingAmount: 0, repaidAmount: 0, durationMonths, repaymentFrequency, purpose, description, eligibleVoterIds: <tontine memberIds − uid>
    (non-empty, else loan_no_voters), lenderIds: [], votes: { yes: 0, no: 0 }, documents: [], createdAt, updatedAt }
then for each photo: Storage loan_documents/{uid}/{loanId}/document-{n}-{ms}.jpg, then
loan_applications/{id} update { documents: arrayUnion([{ name: "Document n", storagePath }]), updatedAt }
(failed photos: "Try again" re-sends only them, or "Continue without them")
```

**Loan page** (`/finance/loans/:id`, live):
- header: amount, purpose · duration · frequency, group, status track;
- credit score: score, band, factors; borrower only;
- voting, funding, agreement, schedule and repayments sections.

| Step | Who / when | Writes |
|---|---|---|
| Vote | an eligible voter (never the borrower), `voting`, before `votingEndsAt`, once. Approve / Decline with an optional comment ("Your vote is final"). | batch: `loan_votes/{loanId}_{uid}` create `{ loanId, voterId, approve, comment, at }` + loan update `{ "votes.yes" or "votes.no": increment(1), updatedAt }` |
| Close the vote | the borrower or an eligible voter, after `votingEndsAt` or once everyone voted | transaction: loan update `{ status: approved ? "funding" : "rejected", reason: "vote" (rejected), votingClosedAt, updatedAt }`. Approved when `cast × 100 ≥ eligible × quorumPercent` and `yes × 100 ≥ cast × approvalPercent`. Show the tally: cast / eligible, needed, approve / decline, approval %. → push `loan_funding_open` / `loan_rejected` |
| Lend | an eligible member, not the borrower, `funding`. Amount ≤ amount − funded. Risk confirmation: "Lending carries a risk… Repayments are shared among the lenders in proportion to what each lent." | transaction: posting `loan_funding` wallet → `loan_{id}` (the first funding creates the loan account, kind `loan`, refId) + `loan_fundings/{loanId}_{uid}_{n}` (n = 1, 2, … the lender's next number on this loan) create `{ id, loanId, lenderId, borrowerId, amount, currency, status: "succeeded", funding, reference, txId, requestKey, collected: 0, createdAt }` + loan update `{ fundedAmount: <new total>, lenderIds: arrayUnion([uid]), updatedAt }`. **The last funder** also: loan `{ status: "agreement_pending", fundedAt }` + `loan_agreements/{loanId}` create `{ loanId, borrowerId, version: 1, principal, currency, interestMethod, annualInterestPercent, fee, totalRepayable (Σ instalments), latePenaltyPercent, durationMonths, repaymentFrequency, terms: settings.agreementTerms, installments: [{ number, amount, principal, interest }], createdAt, acceptedAt: null }` → push `loan_funded`, `loan_agreement_ready` |
| Accept the agreement | the borrower, `agreement_pending`, the version shown (else `agreement_outdated`). Checkbox, then "Accept the agreement". | transaction: posting `loan_disbursement` `loan_{id}` (debit the whole funded amount) → borrower wallet (funded − fee) + fee line to platform + `loan_disbursements/{loanId}` create `{ id, loanId, borrowerId, amount, fee, currency, status: "succeeded", reference, txId, paidAt }` + agreement `{ acceptedAt }` + loan `{ status: "active", acceptedAt, agreementVersion, disbursedAt, outstandingAmount: totalRepayable, repaidAmount: 0, updatedAt }` + `loan_schedules/{loanId}` create `{ loanId, borrowerId, currency, installments: [{ number, dueDate, amount, principal, interest, penalty: 0, amountDue, paidAmount: 0, status: "upcoming" }], createdAt, updatedAt }` (first due date one period after the pay-out) → push `loan_disbursed` |
| Repay | the borrower, `active` / `overdue`, outstanding > 0. Prefilled with the instalment due; shows penalty and outstanding. Amount ≤ outstanding. | transaction: posting `loan_repayment` wallet → `loan_{id}` + `loan_repayments/{loanId}_{requestKey}` create `{ id, loanId, borrowerId, amount, currency, status: "succeeded", funding, reference, txId, requestKey, createdAt }` + loan `{ outstandingAmount: increment(-amount), repaidAmount: increment(amount), updatedAt }` (at 0: `status: "repaid", repaidAt`) + schedule: instalments paid oldest first (`paidAmount`, `paid` / `partially_paid`) → push `loan_repayment_received` to the borrower, `loan_lender_repayment` to each lender, and `loan_repaid` when the outstanding reaches 0 |
| Collect my share | a lender; available = `floor(repaidAmount × funding.amount / loan.amount) − collected` > 0 (`nothing_to_collect`) | per funding document, transaction: posting `loan_lender_payout` `loan_{id}` → lender wallet + funding update `{ collected: increment(amount), updatedAt }` |
| Withdraw my request | the borrower; `submitted`, `under_review` or `voting` | loan update `{ status: "cancelled", cancelledAt, updatedAt }` |

| Status | Labels |
|---|---|
| Loan | submitted (Submitted), under_review (Under review), voting (Members are voting), funding (Being funded), agreement_pending (Agreement to accept), active (Active), overdue (Overdue), repaid (Repaid), rejected (Not approved), cancelled (Cancelled), defaulted (In default) |
| Instalment | Upcoming / Due / Paid / Partly paid / Overdue |

### 6.10 Project financing (companies, institutions)

**Settings:** `platform_settings/financing`. **Reads:**
- `financing_projects` where `ownerId == uid`, `orderBy createdAt desc`, limit 20;
- `financing_applications` where `ownerId == uid`, `orderBy createdAt desc`, limit 50;
- `financing_documents` where `ownerId == uid` and `applicationId == X`, `orderBy uploadedAt desc`;
- `financing_reviews` where `ownerId == uid` and `applicationId == X`, `orderBy at desc`;
- `financial_resources` where `published == true`, limit 200 (sort by `order`, then title).

**Page** (`/finance/financing`): tabs Applications / Projects / Resources. "New application" requires identity; with no project it starts with the project form.

**Project form:**
- Required: name (≥ 2 characters), sector, description (≥ 30).
- Optional: stage, country (searchable), city, employees, year founded (1900 to now), website.
- Writes: `financing_projects/{id}` create (or update) `{ id, ownerId, name, sector, country, city, description, stage?, employees?, foundedYear?, website?, createdAt, updatedAt }`. Emptied optional fields are deleted on update.

**Application form:**
- Fields: project (locked once saved), financing type, amount (min..max), currency, duration (`loan` / `mixed`), use of funds (≥ 30 characters).
- Lists the required documents for the type.
- Writes: `financing_applications/{id}` create `{ id, ownerId, projectId, projectName, financingType, amount, currency, durationMonths?, useOfFunds, status: "draft", reviewerIds: [], createdAt, updatedAt }`. Edits are allowed while `draft` / `additional_info_required`.

**Application page:**
- Status track, and the reason ("What the reviewers need" / "Reason").
- Details with Edit while editable.
- Required documents checklist.
- **Upload:**
  - Allowed: the settings' content types and `maxFileBytes` (≤ 50 MB).
  - First the file to Storage `financing_documents/{uid}/{applicationId}/{ms}-{name}`.
  - Then `financing_documents/{id}` create `{ id, ownerId, applicationId, type, name, storagePath, contentType, size, status: "received", note: "", uploadedAt }`.
  - A `rejected` document no longer counts ("To replace").
- **Remove** (confirmation): delete the document while it is `received` and the application is editable, then the Storage file.
- **Submit:**
  - Requires a declaration checkbox, an optional message (when information was requested) and every required document present (`financing_documents_missing`).
  - Writes: application update `{ status: "submitted", declarationAccepted: true, declarationAcceptedAt, submittedAt, ownerMessage, reason: null, updatedAt }`.
- **Withdraw:** allowed before `approved`; writes `{ status: "withdrawn", withdrawnAt, updatedAt }`.
- History from `financing_reviews`.

**Resources:**
- Type filter: template, guide, FAQ, regulation.
- Reading view: title, summary, updated date, body, "Download the template" / "Open the document", and "For information only…".

### 6.11 Investment

**Settings:** `platform_settings/investments`. **Reads:**
- `investment_funds` where `published == true`, limit 100 (sort by `order`, then name);
- `investment_funds/{id}`;
- `investment_valuations` where `fundId == X`, `orderBy date desc`, limit 90;
- `investment_holdings` where `userId == uid`;
- `investment_subscriptions` and `investment_redemptions` where `userId == uid`, `orderBy createdAt desc`, limit 50;
- `investment_transactions` where `userId == uid` and `fundId == X`, `orderBy createdAt desc`;
- `investment_reports` where `userId == uid`, `orderBy createdAt desc`, limit 24.

**Page** (`/finance/investments`), tabs Portfolio / Funds / Orders:
- **Portfolio:**
  - value, invested, unrealized and realized gains, return %;
  - **asset allocation** bar with the legend "class · share % · amount" (shares by largest remainder, summing to 100);
  - my funds;
  - statements and reports (PDFs);
  - "Return simulator".
- **Funding and markets** links: Invest in projects (Opportunities), Finance my project (Financing), Markets.
- **Funds:**
  - search and sort (from 5 funds): default order, name, lowest risk, highest risk;
  - asset-class chips and risk chips (low ≤ 2, medium ≤ 4, high);
  - each row: risk meter 1-7, status if not open ("Closed to new investments", "Suspended"), minimum, past 1-year return;
  - footnote "Past performance does not predict future returns."
- **Orders:** subscriptions and redemptions, newest first.

**Fund page** (`/finance/investments/funds/:id`):
- objective and description;
- key facts: unit price and date, minimums, subscription / management (a year) / redemption / performance fees, lock-up, redemptions (Not possible / Partial or full / Full only), "Paid out within N business days";
- eligibility, past performance, price history chart, documents, terms with version;
- "Simulate a return";
- **Invest / Invest more**: only when `status == "open"`, a `navPerUnit` and `termsVersion > 0`; identity gate.

**Subscribe** (`/finance/investments/funds/:id/subscribe`):
- Amount ≥ `minAdditional` for a holder, else `minInvestment` (`below_minimum`).
- **Estimate**, labelled as such: fee = round(amount × subscriptionPercent / 100); units ≈ floor4((amount − fee) / navPerUnit); "Units are bought at the unit price of the processing date".
- The admin's `riskDisclosure` + "I understand the risks" checkbox.
- The fund terms (version) + accept checkbox.
- **Electronic signature:** full name, ≥ 3 characters.
- Before writing, re-read the fund: still open (`fund_closed`), same `termsVersion` (`terms_outdated`).

```
pay (4.5), then:
investment_subscriptions/{requestKey} create { id, userId, fundId, fundName, assetClass, currency, amount, fee, termsVersion, signatureName,
    riskAcknowledged: true, acceptedAt, status: "paid", txId, reference, payment, createdAt, updatedAt }
+ posting "investment_subscription": wallet → platform_{CUR} of amount
```

**Holding page** (`/finance/investments/holdings/:fundId`, from `investment_holdings/{uid}_{fundId}`):
- units, invested capital, unrealized gain (with %), realized gain, unit price;
- lock-up: "Redeemable now X", `lockedUntil`;
- history.
- **Redeem** is shown only when redemptions are allowed, the fund is not suspended and `redeemableValue > 0`.
  - Choose part (≤ `redeemableValue`, only when `redemption.partial`) or all.
  - Estimate: units, fee, "You receive about", settlement days.
  - Choose where to receive: the wallet, or a saved Mobile Money / Wave / bank account.
  - Writes: `investment_redemptions/{requestKey}` create `{ id, userId, fundId, fundName, currency, full, amount (null when full), destination, status: "submitted", reference, createdAt, updatedAt }`.
- **Cancel a redemption** (only `submitted`): update `{ status: "cancelled", cancelledAt, updatedAt }`.

**Order page:**
- status track, reason, fee, net amount, units, unit price, terms version, dates (created, trade, expected settlement, settled), reference;
- subscriptions: Payment received (`paid`) → Processing → Units allocated (`completed`);
- redemptions: Submitted → Processing → Being paid out → Paid out;
- ended states: Not accepted (`rejected`, money refunded), Cancelled (redemptions only).

**Return simulator** (`/finance/investments/simulator`):
- Inputs: currency, initial amount, monthly addition, yearly return slider −10 % to +25 % (step 0.5; default the fund's 1-year return, else 5), years 1..`simulator.maxYears`.
- Model: monthly rate r = (1 + annual)^(1/12) − 1; each month value = value × (1 + r) + monthly.
- Output: yearly rows of contributed, value and gains.
- Note: "An illustration with a constant yearly return, before fees and taxes… not guaranteed".

**Admin next:** allocate units, settle redemptions, publish prices and reports.

### 6.12 Online insurance

**Settings:** `platform_settings/insurance`. **Reads:**
- `insurance_products` where `published == true`, limit 100;
- `insurance_quotes`, `insurance_policies`, `insurance_claims` where `userId == uid`, `orderBy createdAt desc`, limit 50;
- `insurance_premiums` where `userId == uid` and `policyId == X`, `orderBy dueDate`;
- `insurance_claims` where `userId == uid` and `policyId == X`.

**Page** (`/finance/insurance`), tabs My policies / Quotes / Claims / Insurance offers. Category chips use the settings order.

**Product** (`/finance/insurance/products/:id`):
- insurer and description;
- key facts: cover period, deductible, waiting period, payment frequencies;
- what is covered (with limits), what is not covered, documents, terms;
- "Get a quote" when `status == "open"` and `termsVersion > 0`.

**Quote request** (`/products/:id/quote`, identity gate):
- **Questions** from `rating.factors`:
  - `select` → a picker;
  - `number` → a field with its range in the helper and in the error.
- Payment frequency: annual / semiannual / quarterly / monthly, as allowed.
- Cover start: tomorrow by default, today to +180 days.
- **Estimated premium**, labelled an estimate:
  - premium = `basePremium` × the product of the factor multipliers (number factors: the first band with value ≤ `upTo`);
  - instalment = premium × (1 + loading %) / payments a year;
  - "Total for the year".

```
insurance_quotes/{requestKey} create { id, userId, productId, productName, partnerName, category, currency, answers, frequency,
    coverStart (Timestamp, midnight), termMonths, status: "requested", createdAt, updatedAt }
```

**Quote** (`/quotes/:id`, live):
- premium (`installmentAmount ?? premium`), frequency, insurer, "Valid until", cover dates, deductible, coverages, documents.
- Once `quoted` and before `validUntil` (else `quote_expired`):
  - terms + accept checkbox, signature (full name ≥ 3 characters);
  - **Accept and pay**, then (4.5) one batch:

```
insurance_quotes/{id} update { status: "accepted", acceptedAt, signatureName, policyId: <quote id>, updatedAt }
insurance_policies/{quoteId} create { id, userId, quoteId, productId, productName, partnerName, category, currency, premium, frequency,
    installmentAmount, deductible, coverages, coverStart, coverEnd, termsVersion (each equal to the quote's value, null when the quote has
    none), signatureName, acceptedAt, autoRenew: false, status: "pending_activation", createdAt, updatedAt }
    (no other quote field: answers, validUntil, terms, documents… are refused)
insurance_premiums/{quoteId}_1 create { id: "{quoteId}_1", userId, policyId, amount: installmentAmount ?? premium, currency, dueDate,
    status: "paid", paidAt, txId, reference, payment, createdAt }
+ posting "insurance_premium": wallet → platform_{CUR}, source { insurance_premiums, "{quoteId}_1" }
```

- **Decline** (`quoted` only): update `{ status: "declined", declinedAt }`.

**Policy** (`/policies/:id`, live):
- Notices: `pending_activation` ("You are covered only once the insurer confirms the policy"), `lapsed`.
- Premium and frequency, next premium due, cover period, deductible.
- **Premiums:** the payable ones first (`due` / `overdue`), each with "Pay". Paying = premium update `{ status: "paid", paidAt, txId, reference, payment, updatedAt }` + posting `insurance_premium` wallet → `platform_{CUR}` of the premium's `amount`, source `{ insurance_premiums, premiumId }`.
- **Renewal:**
  - "Renew and pay" when `renewal_due` and `renewalPremium > 0` and `renewalRequestedAt` is absent. Writes policy update `{ renewalRequestedAt, renewalPaidAmount: renewalPremium, renewalTxId, renewalReference, renewalPayment, updatedAt }` + posting `insurance_premium` wallet → `platform_{CUR}` of `renewalPremium`, source `{ insurance_policies, policyId }` (`renewalTxId` = its txId). The admin then renews the cover and clears `renewalRequestedAt`.
  - "Renew automatically" switch: update `{ autoRenew }`.
- Claims of the policy, coverages, documents.
- "Make a claim" (while `active` / `renewal_due`).
- "Cancel this policy": optional reason; update `{ status: "cancellation_requested", statusBefore, cancellationReason?, cancellationRequestedAt }`.

**Claim** (`/policies/:id/claim`):
- Incident date: from `coverStart` to today.
- Description ≥ 10 characters; amount claimed.
- Up to `claims.maxFiles` photos, uploaded first to `insurance_claims/{uid}/{claimId}/{ms}-{i}.jpg`.
- Writes: `insurance_claims/{requestKey}` create `{ id, userId, policyId, policyNumber, productName, currency, incidentDate, description, amountClaimed, documents: [{ name: "Photo n", storagePath }], status: "submitted", createdAt, updatedAt }`.

**Claim page:**
- Track: Submitted → Under review (shown as "More information needed" while `info_requested`) → Approved → Paid; ended states Not approved, Withdrawn.
- "The insurer asks: {reason}".
- **Send more information** (`info_requested`): message + photos. Writes claim update `{ status: "under_review", documents: arrayUnion(new), respondedAt }` + `insurance_claims/{id}/events/{key}` create `{ type: "customer_response", userId, authorId: uid, message, documents, createdAt }`.
- **Withdraw** (`submitted` / `under_review` / `info_requested`): update `{ status: "withdrawn", withdrawnAt }`.

**Admin next:** price quotes, activate, renew, cancel, decide claims and pay them.

### 6.13 Markets, intelligence and opportunities (`/finance/markets`)

**Settings:** `platform_settings/intelligence`. Each tab exists only when its part is enabled and valid.

- **Indicators:**
  - Query: `economic_indicators` where `published == true` and `country == X`, limit 100, sorted by `order`.
  - Country chips.
  - Each row: value, period, trend in words ("Up 0.3 %", "Down…", "Unchanged") vs `previousValue`, "Source · Updated".
  - Detail: history chart (`economic_indicator_history` where `indicatorId`, `orderBy periodEnd desc`, limit 40), high / low, source, "Open the source" (https only).
- **Exchange rates:**
  - Query: `exchange_rate_snapshots` where `to == base`, `orderBy observedAt desc`, limit 200; keep the newest per currency.
  - Converter (from, to, amount, swap).
  - Each rate with source, time, and an Official / Indicative chip.
  - Note: "Indicative rates for information. The rate applied to a payment is the one shown when you confirm it."
  - Rate history: `pair == X`, limit 90.
- **Stocks** (when `markets.stocks`):
  - Query: `market_securities` where `published == true`.
  - Market indices first, then stocks / ETFs; exchange filter.
  - Each row: price, change, change %, "Delayed" or "Live", updated time.
  - **Watchlist:** `investor_watchlists/{uid}` set-merge `{ securityIds (≤ 50; else watchlist_full), updatedAt }`.
  - Security page: price chart (`market_price_history` where `securityId`, `orderBy date desc`), key figures, source.
  - **"Invest through the funds"** instead of any buy button: "Spideli does not buy or sell shares: that needs a licensed broker."
- **Bonds:** coupon rate, yield, maturity.
- **IPOs:** `ipo_listings`, status Upcoming / Open for subscription / Subscription closed / Listed / Withdrawn, price range or offer price, dates, "Read the prospectus" (https). No subscription in Spideli.
- **Collections:** `stock_collections` with their securities; note "A themed selection for information. It is not a recommendation."
- **News:** `finance_news` where `published == true`, `orderBy publishedAt desc`. Categories (news, analysis, markets, economy, companies). Each item opens "Read the full article" (https). Note "Published by {source}. Spideli does not modify it."
- **Opportunities** (when `matching.enabled`):
  - "My investor preferences" (`/finance/markets/preferences`):
    - fields: currency, ticket from / to, max risk 1-7 (default 4), horizon (none, 12, 24, 36, 60, 120 months), sectors, countries, types ("none selected = all");
    - writes `investor_profiles/{uid}` set-merge `{ currency, sectors, countries, types, minTicket, maxTicket, maxRisk, maxHorizonMonths, updatedAt }`.
  - **Matching** (computed in the browser):
    - eligible = open and before `closingDate`, same currency, `minTicket ≤ maxTicket`, risk ≤ `maxRisk`;
    - score 0-100 = the weighted share of the met preferences (sector, country, type: an empty preference counts as met; ticket within the range; horizon, where 0 = no limit), weights from the settings;
    - "Suggested for you" when score ≥ `minScore`, with the reasons.
  - Then the other open opportunities, by closing date. Rows show "From {minTicket}" and a Raised progress bar.
  - Opportunity page: owner, raised / target, key facts, "Target return (not guaranteed)", risk warning.
    - **I am interested**: a sheet saying "Your name and email are shared with the project owner… No money is committed", with an optional message (≤ 500).
    - **Not for me** is the negative answer.
    - Writes: `opportunity_interests/{oppId}_{uid}` set-merge `{ opportunityId, userId, interested, message, name, email (only when interested; deleteField() otherwise), createdAt, updatedAt }`. Both stamps are `serverTimestamp()` on **every** write, including a change of answer (the rules refuse an older stored value). Refused when closed.

### 6.14 Finance chat (`/finance/messages`)

**Conversations:**
- your direct chats: `finance_chats` where `memberIds` contains uid, `orderBy updatedAt desc`;
- the group chat of each of your tontines: `finance_chats/tontine_{tid}`.
- Each shows the last message, its time, and an unread dot when `lastMessage.at > lastReadAt[uid]` and the sender is not you.

**Start:**
- a group chat from the tontine page;
- a direct chat from a "Message" button on a tontine or savings-goal member row. Chat id `dm_{min(uid, other)}_{max(uid, other)}`.

**Conversation** (`/finance/messages/:chatId`):
- `messages` `orderBy createdAt`, the latest 300; newest at the bottom; day separators; sender names.
- Text 1-1000 characters (`message_invalid`), with a counter from 80 %.
- Send (one batch):

```
finance_chats/{chatId}/messages/{autoId} create { id, senderId: uid, senderName, text, createdAt }
finance_chats/{chatId} set-merge { id: chatId, type: "direct" | "tontine", memberIds: [a, b] (direct) | tontineId (group),
    lastMessage: { text, senderId: uid, at: serverTimestamp() }, updatedAt, lastReadAt: { [uid]: serverTimestamp() } }
→ push "finance_chat_message" { senderName, chatName, message } to the other members
```

- Mark read when opened: update `{ "lastReadAt.{uid}": serverTimestamp() }`.
- Group chats: active tontine members only.

### 6.15 AI assistant (`/finance/assistant`)

- **Simulators:**
  - investment return (6.11);
  - insurance premium (the estimate on a product's quote form).
- **Financial coach:** shown as "not available yet" while `intelligence.coach.enabled` is false. It needs a server holding the AI key. **Never** call an AI provider from the browser.
- Note: "Simulations are estimates, not offers or guarantees."

### 6.16 Notifications (customer side)

- **Notification Center:** `users/{uid}/notifications`, newest first, mark read. Finance records have `source: "finance"` and are written by the admin.
- **Web push** (optional): FCM web with a VAPID key. Store the browser token as the platform does for `fcmToken`.
- **Preferences:** 5.2.

## 7. Queries and indexes

Every list query of section 6 is constrained so the rules can prove access (to the user, to a group the user belongs to, or to `published == true`). The composite indexes are in `.claude/firestore.indexes.json` (deployed with the mobile app); the website uses the same queries and needs no new index. If a query you write fails with "requires an index", use **exactly** the query of this document instead of adding one.

Main composite indexes:

| Collection | Fields |
|---|---|
| `ledger_transactions` | `userIds` CONTAINS, `createdAt` DESC; `userIds` CONTAINS, `type` ASC, `createdAt` DESC |
| `money_transfers` | `participantIds` CONTAINS, `createdAt` DESC |
| `transfer_beneficiaries`, `utility_saved_accounts` | `userId` ASC, `lastUsedAt` DESC |
| `utility_payment_requests`, `virtual_cards`, `investment_subscriptions`, `investment_redemptions`, `investment_reports`, `insurance_quotes`, `insurance_policies`, `insurance_claims`, `wallet_operations` | `userId` ASC, `createdAt` DESC |
| `card_transactions`, `card_funding_requests` | `userId` ASC, `cardId` ASC, `createdAt` DESC |
| `savings_goals`, `tontines` | `memberIds` CONTAINS, `createdAt` DESC |
| `savings_contributions`, `savings_withdrawals`, `tontine_payouts`, `tontine_disputes` | `goalId` / `tontineId` ASC, `createdAt` DESC |
| `tontine_cycles` | `tontineId` ASC, `number` ASC |
| `loan_applications` | `borrowerId` ASC / `eligibleVoterIds` CONTAINS / `lenderIds` CONTAINS, `createdAt` DESC |
| `loan_repayments` | `loanId` ASC, `createdAt` DESC |
| `investment_valuations` | `fundId` ASC, `date` DESC |
| `investment_transactions` | `userId` ASC, `fundId` ASC, `createdAt` DESC |
| `insurance_premiums` | `userId` ASC, `policyId` ASC, `dueDate` ASC |
| `financing_*` | `ownerId` ASC (+ `applicationId` ASC), `createdAt` / `uploadedAt` / `at` DESC |
| `economic_indicator_history` | `indicatorId` ASC, `periodEnd` DESC |
| `exchange_rate_snapshots` | `to` ASC, `observedAt` DESC; `pair` ASC, `observedAt` DESC |
| `market_price_history` | `securityId` ASC, `date` DESC |
| `finance_news` | `published` ASC, `publishedAt` DESC |
| `finance_chats` | `memberIds` CONTAINS, `updatedAt` DESC |

## 8. Acceptance criteria and test plan

**Environment:** a test Firebase project (or the emulator) with the finance rules, `platform_settings/*` created, `platform_{CUR}` accounts, gateways in **sandbox mode**, two verified test customers A and B.

| # | Journey | Expected |
|---|---|---|
| 1 | Sign in with e-mail, Google, phone; turn on two-step verification; sign out and in | the SMS code is asked at sign-in and before sensitive actions |
| 2 | A starts a verification, saves, uploads, submits; the admin approves | live status and history; money actions unlock |
| 3 | A adds money with a sandbox card | wallet credited; a `payment_receipts` record exists |
| 4 | A sends money to B (internal) | A debited amount + fee, B credited, both see it live |
| 5 | A sends to a Mobile Money number; asks to cancel; the admin refunds | `processing` → cancel request → `cancelled`, money back |
| 6 | A withdraws to a saved bank account; the admin pays out | `pending` → `completed` with the payout reference |
| 7 | A converts XAF → EUR | both wallets move by the published rate minus the fee |
| 8 | A pays a prepaid electricity bill; the admin completes it with a token | token shown with Copy; receipt PDF |
| 9 | A creates a savings goal, invites B; B joins; both add money; A cancels (group → request) | progress chart, contributors, `cancellation_requested` |
| 10 | A creates a tontine, invites B (B sees the terms), starts it, both pay; A is the only tontine admin, so the admin panel approves A's payout (cycle 1); both pay cycle 2 and A approves B's payout | each pot reaches its beneficiary's wallet; the next cycle opens; the tontine completes after the last cycle; group chat works |
| 11 | B applies for a loan; admin opens the vote; A votes; vote closed; A funds; B accepts; B repays; A collects | every balance moves as shown; schedule updated |
| 12 | A subscribes to a fund; admin allocates; A redeems part; admin settles | order and holding update |
| 13 | A requests a quote; admin prices it; A accepts; admin activates; A claims; admin requests information; A responds | each status shown live |
| 14 | A requests a card; admin issues; A tops up, freezes, unfreezes, sets limits, sends to B's card | requests completed by the admin |
| 15 | Admin restricts B for `loans` | B sees the notice; loan actions disabled and refused by the rules |
| 16 | A double-clicks "Confirm" on a transfer; refreshes during a payment | one transfer only; retry finishes without a second charge |
| 17 | Arabic, dark mode, 320 px width, keyboard only, screen reader | no overflow; RTL; all actions reachable; statuses announced |
| 18 | A stranger account reads A's records or writes A's wallet | refused (`permission-denied`) |

## 9. Dependencies and limits

- **Deployed rules required:** the finance block of `firestore.rules.draft` must be merged into the live rules and deployed before the website goes live; without it, writes are either refused or unprotected.
- **Admin panel required:** every request that needs the admin stays `pending` / `processing` until the admin panel processes it.
- **Not available until a provider is contracted:**
  - card issuance and secure card details (card issuer);
  - biller account lookup;
  - buying stocks / IPO subscriptions (broker);
  - the AI coach (a server holding the AI key);
  - Facebook sign-in.
- **Privacy:** recipient lookup reads `users` by e-mail / phone. The rules currently let any signed-in user read user profiles; a public-profile collection would narrow it (admin decision).
- **Trust:** gateway success is reported by the browser. The admin reconciles every receipt. Never send a gateway secret key to the browser.

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
