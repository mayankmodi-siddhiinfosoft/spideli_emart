# Spideli Finance – Customer App: Feature Coverage Summary

Date: 15 October 2026. **Verified** = run by hand in the app against the test backend (Firebase emulators, security rules on), results checked in the database. **Unit-tested only** = covered by the 887 automated app tests and/or the 79 security-rules tests, not run by hand this time. Nothing below is marked verified without a recorded scenario in `01_FINANCE_TEST_REPORT.md`.

## 1. Verified features

| Module | Verified by hand |
|---|---|
| Dashboard | Greeting, balance and other currencies, privacy eye (all figures, after BUG-19), actions, Needs your action (vote, agreement), Coming up, This month (after BUG-04), Your money tiles, Recent activity live (after BUG-03), references (after BUG-01) |
| Services / Insights | All 9 services listed by family; Insights in / out / net and 30-day breakdown recomputed independently from the ledger |
| Wallet | History by day, search, type filter, transaction details and copy; statement PDF (totals equal the balance) |
| Add money | Amount validation; correct refusal when no gateway is configured (**gateway payment itself: blocked**, see 3) |
| Withdraw | Balance check, fee rule (1 % + 100, cap 5 000), payout account required, saved Mobile Money number, double-tap protection, re-authentication rule, admin payout (live Completed + payout reference), admin failure (full refund + reason) |
| Convert | XAF → EUR at the peg and XAF → USD (new wallet), fee, exact receive amount, both currency ledgers balanced |
| Money transfer | Unknown / own / malformed recipient refused, name shown before paying, free internal transfer, Mobile Money with fee, cancel request + refund, password above the threshold (wrong password refused), offline payment (after BUG-08), transfer history (after BUG-07) |
| Bill payment | Account format check, fee, processing → completed with prepaid code and Copy, package biller (TV), refund with reason, saved account |
| Virtual card | Card request with fee and terms, issue (live), top-up, card purchase from the issuer, freeze, unfreeze with password, limits validation and request, card → wallet |
| Collective savings | Group goal with invitee, contribution, member joins (live), early-withdrawal warning, group withdrawal as a request, admin approval |
| Tontine | Create, invite, join (live), start with schedule, contributions, pot complete, sole-admin payout via Spideli, next cycle opens, group chat |
| Member loans | Request (by another member through the rules), admin review / score / vote, votes (repeat vote refused), close the vote, lend twice, agreement figures, credit score shown to the borrower only, acceptance and pay-out, repayment, lender collection with rounding |
| Investments | Funds list, risk filter, fund page, minimum enforced, risks + terms + e-signature, allocation, portfolio and allocation, partial redemption and settlement, return simulator (exact maths) |
| Insurance | Product, quote estimate (exact maths), range validation, quote priced, accept + first premium, activation, cover-not-started message (after BUG-15), claim, information request and answer, payment of the claim |
| Markets / opportunities | Indicators, exchange rates and converter; opportunity, interest with message, interest shown again and withdrawn (after BUG-17) |
| Project financing | Resources, project form, loan application, required documents, missing-document block, 3 PDF uploads to Storage, declaration, submission |
| AI assistant | Coach shown as "not available yet" (disabled by design), return simulator |
| Identity verification | Unverified banner, basic level: details, passport + face photo from the gallery, submission, admin review and approval (live), next level offered |
| Restrictions | Notice with scope and reason (on Home and, after BUG-18, on the blocked service), transfer refused with nothing moved |
| Messages / notifications / security | Tontine group chat, unread dot, notification preference saved, two-step verification page (asks for a verified e-mail) |

## 2. Implemented but not run by hand this time (unit-tested only)

- **Wallet:** withdrawal to a bank account; Wave and bank transfer channels (disabled in the test settings); statement for a custom period.
- **Transfers:** recipient by phone number; deleting a saved recipient.
- **Bills:** "amount due" biller (water); deleting a saved bill account.
- **Cards:** card → card, renew, delete card (termination), secure card details (hidden until an issuer provides a secure page).
- **Savings:** solo goal withdrawal and cancellation, editing the plan, inviting from the goal page, accepting / declining in the invitee's own app, group cancellation.
- **Tontine:** declining an invitation, random payout order, a non-beneficiary admin approving a payout, disputes.
- **Loans:** the application form itself in the app (the request was made through the rules as another member), declining a vote, withdrawing a request, overdue / penalties (admin side).
- **Investments:** full redemption, cancelling a redemption, reports.
- **Insurance:** declining a quote, auto-renew switch, cancelling a policy, paying a due premium, renewal, claim photos.
- **Markets:** stocks, bonds, IPOs, collections and news tabs, watchlist, investor preferences and matching.
- **Financing:** editing / withdrawing an application, removing a document.
- **Identity:** additional information requested, rejection and "start again", business verification.
- **Messages:** direct (one-to-one) chats.
- **Not checked this round:** Arabic / right-to-left, dark mode, large text and screen readers, and the live Firebase project on a real phone.

## 3. Blockers (need a partner or a setting)

| Feature | What it needs |
|---|---|
| Add money / pay through Orange Money, Stripe, Flutterwave… | The provider's sandbox (test) and live credentials in the gateway settings. The app correctly says no method is available until then. |
| Real virtual cards | A card issuer (tested with simulated issuing by the admin script). |
| Two-step verification by SMS | Firebase Identity Platform with SMS multi-factor enabled. |
| Push notifications for finance events | The push relay (`sendPush`, see the specs) or the apps' current mechanism; not part of this test. |
| AI financial coach | A server holding the AI provider key; the coach is disabled in settings. |
| Going live | Merge and deploy `firestore.rules.draft` and the indexes; create the settings and platform accounts (see the admin spec go-live checklist). |

## 4. Unresolved issues and notes

- **App Check (real devices):** on the user's phone the log shows "App attestation failed" for the debug build. Sign-in still worked; if App Check enforcement is turned on, register the debug token or test with a release build.
- **Minor:** the transfer e-mail field can show its format error while the address is still being typed (seen once, not changed).
- **Demo video:** narrated by a computer-generated voice; no human presenter was available in this environment. This is disclosed in the video's opening card and in the script.
