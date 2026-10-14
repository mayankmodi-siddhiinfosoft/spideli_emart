# Spideli Finance: requirement-by-requirement checklist

**Sources:** "Document 2: Spideli Feature for Digital Finance" (9 pages) and "Overview of Spideli Finance Features" (1 page).
**Scope (decided 14 Oct 2026):** **customer level** implemented in the customer app on Firestore (direct writes + security rules); **admin level** delivered as a specification for the PHP admin panel (`docs/FINANCE-ADMIN-PHP-SPEC.md`), not implemented here; other stakeholders (insurance companies, fund managers, banks, rating agencies, microfinance institutions) out of scope.
**Audit baseline:** commit `e2ffdd7a`. Every finance callable function answered **404** (none deployed): before this work, every customer action that writes (start a verification, send, save, contribute, apply…) failed; only the screens that read worked.

Legend: **C** customer level · **A** admin level (PHP spec) · **X** other stakeholder (out of scope) · Audit: ✅ present and working · ⚠️ present in the app but not working end to end (needed a server) · ❌ missing.

## A. User management

| # | Requirement | Level | Audit (before) | Delivered in |
|---|---|---|---|---|
| A1 | Registration: individual or business account | C | ✅ sign-up; business = Business account + business identity verification | — |
| A2 | Registration by email | C | ✅ | — |
| A3 | Registration by phone | C | ✅ phone + OTP | — |
| A4 | Social authentication: Google, Apple | C | ✅ | — |
| A5 | Social authentication: Facebook | C | ❌ (needs the Facebook SDK and a Facebook app) | dependency |
| A6 | Social authentication: LinkedIn | C | ❌ | LinkedIn via Firebase OpenID Connect, shown when configured |
| A7 | Secure login | C | ✅ Firebase Auth, App Check | — |
| A8 | Multi-factor authentication | C | ❌ | Two-step verification (SMS second factor), sign-in challenge |
| A9 | Password reset | C | ✅ | — |
| A10 | Profile: personal information, contact details | C | ✅ | — |
| A11 | Profile: identity documents | C | ⚠️ verification screens (writes failed) | direct writes |
| A12 | Profile: Mobile Money accounts | C | ✅ saved payment methods | — |
| A13 | Profile: bank accounts | C | ❌ | saved bank accounts (payouts) |
| A14 | KYC: national ID, passport, business registry, photo (face) | C | ⚠️ configured (`platform_settings/kyc`), writes failed | direct writes |
| A15 | KYC validation: document verification, manual or automated validation, rejection with reason | A (customer sees status and reason) | ⚠️ | PHP spec; app shows status, reason, history |

## B. Investment module

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| B1 | Fund catalog: list, description, risk level, historical performance, downloadable documentation | C (A publishes) | ✅ reads | — |
| B2 | Subscription: online subscription, electronic signature, digital payment | C | ⚠️ (callable) | direct writes + gateway / wallet payment; A executes |
| B3 | Portfolio: valuation, asset allocation, transaction history, gains and losses | C | ⚠️ (server summary never maintained) | totals worked out on the device from the holdings |
| B4 | Redemption: partial, full, processing tracking | C | ⚠️ | direct writes; A executes |
| B5 | Reporting: portfolio statements, periodic reports, PDF download | C (A generates) | ✅ reads | — |
| B6 | Return simulators / financial calculators | C | ✅ | — |
| B7 | Bonds | C | ✅ as a fund asset class | + bonds in Markets |
| B8 | IPO tracking | C | ❌ | Markets > IPOs |
| B9 | Stocks and stock markets (also live) | C | ❌ | Markets > Stocks (live as the feed updates), watchlist |
| B10 | Managed funds | C | ✅ | — |
| B11 | Stock collections | C | ❌ | Markets > Collections |
| B12 | Funding, manage projects | C | ⚠️ | project financing direct writes |
| B13 | Analyses, news | C | ❌ (indicators only) | Markets > News; indicators and rates |
| B14 | Fund management: create products, configure, update returns | A | ❌ | PHP spec |

## C. Tontine module

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| C1 | Create a tontine in minutes; invite members via the app; manage groups, associations, communities | C | ⚠️ (callables) | direct writes; invitations carry the terms |
| C2 | Real-time contribution tracking, individual payments, history for authorized members | C | ⚠️ reads ✅, payments failed | direct writes (one contribution per cycle and member) |
| C3 | Cycle management: payment rounds, successive beneficiaries, automatic cycle structuring | C | ⚠️ | start creates every cycle; payout approval moves the pot to the beneficiary |
| C4 | Financial transparency: shared visibility, fewer manual errors, progress | C | ✅ | — |
| C5 | Notifications and reminders: due dates, payments, group activity | C (A sends SMS / e-mail / scheduled reminders) | ⚠️ (server templates) | pushes from the app on group events; reminders in PHP spec |
| C6 | Blacklisting of insolvent individuals | A (customer sees it) | ❌ | `users.financeRestriction` (PHP sets it); the app shows it and blocks; rules refuse |
| C7 | Tontine management: consultation, suspension, audit | A | ❌ | PHP spec |
| C8 | Tontine group chat | C | ❌ | Finance chat (group per tontine) |

## D. Collective savings

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| D1 | Goals: real estate, education, travel, health, entrepreneurial project | C | ⚠️ (create failed) | direct writes |
| D2 | Goal tracking: graphic progress | C | ⚠️ progress bar | + progress chart over time |
| D3 | Payment history | C | ✅ reads | — |
| D4 | Completion projection | C | ✅ | — |

## E. Loan module (between members)

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| E1 | Loan request | C | ⚠️ | direct writes |
| E2 | Request review | A | ❌ | PHP spec (status, credit assessment, open the vote) |
| E3 | Member voting | C | ⚠️ | direct writes (one vote per member, counts +1); closing the vote by the members |
| E4 | Fund disbursement | C | ⚠️ | members fund the loan account; disbursed to the borrower when the agreement is accepted |
| E5 | Repayment schedule, automatic tracking | C | ⚠️ | schedule written with the agreement; repayments update it; lenders collect their share |
| E6 | Reminders, penalties | A (customer sees them) | ⚠️ | PHP spec; the app shows due / overdue / penalty |
| E7 | Credit scoring | A (borrower sees it) | ✅ reads | PHP spec writes `credit_assessments` |
| E8 | Blacklisting of insolvent individuals | A (customer sees it) | ❌ | as C6 |

## F. Online insurance

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| F1 | Insurance catalog | C (A publishes) | ✅ | — |
| F2 | Quote request, rate simulation, online subscription, electronic signature | C | ⚠️ | direct writes; A prices the quote |
| F3 | Contract management: consultation, renewal, cancellation, document download | C | ⚠️ | direct writes; A activates / renews / cancels |
| F4 | Claims: online declaration, document upload, processing tracking, notifications | C | ⚠️ | direct writes; A decides |
| F5 | Insurance management: catalog, partner management, contract administration, claims management | A | ❌ | PHP spec |
| F6 | Insurance company portal ("Insurance Company – manage this feature") | X | — | out of scope |

## G. Communication

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| G1 | Individual chat ("chat with another user") | C | ❌ (store / driver chats only) | Finance chat (direct) |
| G2 | Tontine group chat | C | ❌ | Finance chat (group) |
| G3 | Notifications: mobile push | C | ⚠️ (server templates) | template pushes from the app; Notification Center |
| G4 | Notifications: SMS, e-mail | A (customer chooses) | ❌ | preferences in the app; sending in PHP spec |

## H. User dashboard

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| H1 | Investments: capital invested, realized gains, return | C | ⚠️ (summary never maintained), no return | totals on the device + return % |
| H2 | Tontines: active, upcoming contributions | C | ⚠️ | totals on the device |
| H3 | Savings: goals, progress | C | ⚠️ | totals on the device |
| H4 | Insurance contracts | C | ⚠️ | totals on the device |
| H5 | Statistics: overall history, financial activity, analysis | C | ⚠️ | cash flow from the ledger on the device |

## I. Payment methods, virtual cards, transfers, bills

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| I1 | Mobile Money (Cameroon, Gabon, Guinea, Côte d'Ivoire, Senegal, Rwanda), Wave | C | ⚠️ (server collection) | the app's gateways (configured per region by the admin) |
| I2 | PayPal | C | ❌ in Finance (✅ in the shopping wallet) | gateway reused in Finance |
| I3 | Visa / Mastercard | C | ❌ in Finance (✅ Stripe in the shopping wallet) | gateway reused in Finance |
| I4 | Bank transfer | C | ⚠️ (transfer channel, callable) | direct writes; A pays out |
| I5 | Virtual Visa cards: instant creation, deletion, freeze / unfreeze, renewal | C | ⚠️ | direct writes; A / issuer issues and closes |
| I6 | Secure view: number, expiry, CVV | C | ⚠️ (issuer link via callable) | needs the issuer's secure page (dependency) |
| I7 | Card settings: daily and monthly limits | C | ⚠️ | direct writes; A applies |
| I8 | Top up with Mobile Money | C | ⚠️ | card top-up and **wallet "Add money"** via gateways |
| I9 | Withdrawals to wallet | C | ⚠️ | card → wallet request; wallet withdraw to Mobile Money / Wave / bank |
| I10 | Money transfers: internal; external Mobile Money, e-mail, bank | C | ⚠️ | internal instant (ledger); external processed by A |
| I11 | Card to card in the app | C | ❌ | "Send to another card" |
| I12 | Multi-currency wallet | C | ⚠️ (one wallet per currency, no conversion) | conversion between own wallets |
| I13 | Push notifications: deposit, withdrawal, payment, transfer | C | ⚠️ | pushes from the app + Notification Center |
| I14 | SMS for critical transactions; e-mail receipts and alerts | A | ❌ | PHP spec (honours the user's preferences) |
| I15 | Transaction history: amount, date, type, status, reference | C | ✅ | — |
| I16 | Bills: electricity, water, TV (+ taxes, products) | C | ⚠️ | direct writes; A pays the biller; categories taxes / products |

## Administrator back-office (all A → PHP spec)

User management (creation, activation, suspension, deletion) · KYC management (file validation, document control, validation history) · fund management (financial products, fund configuration, return updates) · tontine management (consultation, suspension, audit) · insurance management (catalog, partners, contracts, claims) · payment management (complete history, manual validation, bank reconciliation) · incident management (complaints, customer support, tickets) · reporting (users, assets under management, contribution volumes, activity) · security (MFA / 2FA, sessions) · data protection (encryption, password encryption, automatic backups) · audit (complete logging, action traceability).

## Other features

| # | Requirement | Level | Audit | Delivered in |
|---|---|---|---|---|
| O1 | Project owners / companies space: online submission of financing files | C | ⚠️ | direct writes |
| O2 | File status tracking (submitted, under review, approved) | C (A reviews) | ✅ reads | PHP spec for reviews |
| O3 | Support: guides, business plan templates, regulatory FAQ | C (A publishes) | ✅ | — |
| O4 | Real-time macroeconomic indicators (exchange rates, inflation, reserves) | C (A publishes) | ✅ reads | — |
| O5 | Investor / opportunity matchmaking | C | ⚠️ (profile and interest via callables) | direct writes |
| O6 | AI-assisted financial coach | C | ⚠️ (needs the AI function) | dependency: a server holding the AI key |
| O7 | Financial company / institution portals | X | — | out of scope |



---

## Completion report (14 Oct 2026)

Verified against the code: `flutter analyze` (no error or warning), `flutter test` (871 tests), Firestore rules emulator suite `finance/rules-test` (79 tests). ✅ done in the customer app on Firestore · 📄 specified for the PHP admin panel · ⛔ needs a provider, a contract or a console setting (listed with what is missing).

| Group | ✅ Customer level, integrated | 📄 Admin level, specified | ⛔ Dependencies |
|---|---|---|---|
| A. User management | A1-A4, A7, A9-A14; A6 LinkedIn (shown when configured); A8 two-step verification (SMS second factor, all sign-in paths) | A15 KYC validation (PHP §4) | A5 Facebook (SDK + app), A6 LinkedIn OIDC provider, A8 Identity Platform SMS multi-factor |
| B. Investment | B1-B7, B10, B12, B13 (news, analyses, indicators); B8 IPO tracking, B9 stocks and markets (live as published, watchlist), B11 collections — read-only | B14 fund management (PHP §6); order execution; reports | licensed market-data feed; a broker to buy stocks / IPOs |
| C. Tontine | C1-C5 (pushes for group events), C8 group chat; C6 restriction shown and enforced | C6 blacklisting, C7 consultation / suspension / audit (PHP §3, §7); reminders (§12) | — |
| D. Collective savings | D1-D4 (progress chart added) | group withdrawals and cancellations (PHP §5.2) | — |
| E. Loans | E1, E3 (voting and closing), E4 (funding, disbursement), E5 (schedule, repayments, lenders collect); E7 and E8 shown to the customer | E2 review, E6 reminders and penalties, E7 credit scoring, E8 blacklisting (PHP §8) | — |
| F. Insurance | F1-F4 | F5 catalog, partners, contracts, claims (PHP §9) | F6 insurer portals: out of scope |
| G. Communication | G1 individual chat, G2 tontine group chat, G3 push; G4 preferences per channel | G4 SMS and e-mail sending (PHP §12) | SMS / e-mail provider |
| H. Dashboard | H1-H5 (totals on the device, return %) | reporting (PHP §13) | — |
| I. Payments, cards, transfers, bills | I1-I3 (the app's gateways: Mobile Money, Wave, Visa / Mastercard, PayPal), I4, I5, I7, I8 (card top-up and wallet Add money), I9 (card → wallet, wallet withdraw), I10, I11 (card → card), I12 (conversion), I13, I15, I16 (+ taxes, products) | payouts, card operations, biller payments, reconciliation (PHP §5, §10); I14 SMS / e-mail | card issuer (I5 issuance, I6 secure card details), biller lookup APIs, gateway webhooks |
| Back-office | — | user management, KYC, funds, tontines, insurance, payments, incidents / tickets, reporting, security, data protection, audit (PHP §3-§13) | — |
| Other | O1-O5 | financing reviews, resources, opportunities (PHP §11) | O6 AI coach: a server holding the AI key; O7 institution portals: out of scope |

**Conflicts found and resolved:**
- **The backend.** The contract assumed Cloud Functions that were never deployed (every callable answered 404). The app now writes directly to Firestore under security rules, and the admin steps move to the PHP panel.
- **Dashboard totals.** `finance_summaries`, which nobody maintained, is replaced by totals worked out on the device.
- **Two wallets.** The shopping wallet and the Finance wallet remain separate. Finance reuses the shopping wallet's payment gateways.
- **Tontine invitations.** Invitees could not see the terms before joining; invitations now carry them.
- **Two-step verification.** It would have locked users out of every sign-in path, so the code challenge is now handled in each one.
- **Duplicate helpers.** The restriction helpers were merged into one.

**Outstanding (see `docs/FINANCE-FLOW.md` §9):**
- merge and deploy the rules and indexes;
- build the PHP panel;
- create the wallet and markets settings, the platform accounts and the chat template;
- reconcile gateway payments;
- decide on user-profile privacy;
- set up the provider dependencies above.

