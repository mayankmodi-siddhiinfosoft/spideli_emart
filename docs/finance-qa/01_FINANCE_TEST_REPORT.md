# Spideli Finance – Customer App: Complete Test Report

Date: 15 October 2026 · App: `customer/` (Flutter, branch `feature/restaurant-app-panel-parity`) · Tester: Claude (automated + hands-on)

## 1. Summary

- **110 test scenarios** run by hand on the real app, plus **887 automated app tests**, **79 security-rules tests** and a **ledger integrity check** after every money operation.
- **19 defects found, all fixed and retested** (one critical: a payment confirmed offline could go through later after the app said it had failed). See `02_BUG_FIX_REPORT.md`.
- **1 scenario blocked:** adding money through a real payment gateway (needs the provider's sandbox / live credentials).
- Final state: 887/887 app tests pass, 79/79 rules tests pass, `dart analyze` reports no errors or warnings, and the test ledger is consistent (47 postings, XAF balances sum to 0).

## 2. Test environment (no real money, no real customers)

| Item | Setup |
|---|---|
| Backend | Local Firebase emulators (Auth, Firestore, Storage) started by `finance/qa-env/start.sh`, with the finance security rules of `firestore.rules.draft`. Nothing reaches the live project. |
| App | Debug build with `--dart-define=USE_FIREBASE_EMULATOR=true` (a debug-only switch added for this work; release builds are unchanged) on an Android emulator (Pixel 10 Pro image, Android 17 / API 37). |
| Data | `finance/qa-env/seed.py`: 3 fictional customers (Amina Diallo, Jean Mbarga, Fatou Ndiaye), finance settings (same values as the live seed), opening balances as balanced ledger postings, and clearly labelled sample catalogs (test billers, a demo fund, a sample insurance product, sample indicators, a sample opportunity). |
| Admin steps | `finance/qa-env/admin.py` performs the admin panel's steps (payouts, refunds, approvals, card issuing, pricing, claims, KYC decisions) exactly as `docs/SPIDELI_FINANCE_ADMIN_WEB_SPEC.md` describes. |
| Other customers | `finance/qa-env/customer.mjs` acts as Jean or Fatou **through the security rules** (transfers, joins, contributions, votes, chat) while the app stays open as Amina. |
| Verification | `finance/qa-env/verify.py ledger` recomputes every account from its postings after each operation: every posting balanced, every balance equal to its history, no negative wallet. |

## 3. Automated tests

| Suite | Result |
|---|---|
| Flutter app tests (`customer/test`, incl. 268 finance tests and new tests for every fix) | 887 / 887 pass |
| Firestore security-rules tests (`finance/rules-test`, emulator) | 79 / 79 pass |
| Static analysis (`dart analyze lib test`) | 0 errors, 0 warnings |

## 4. Manual test scenarios

Status key: **PASS** as expected · **FAIL → fixed (BUG-xx), retest PASS** defect found, fixed and verified again · **BLOCKED** cannot be run in this environment.

### Dashboard and Insights

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| D-01 | Dashboard | Open Spideli Finance as a verified customer with 500 000 XAF | Greeting, balance card 500 000 XAF, actions Add money / Send / Pay bills / Withdraw, this month, recent activity | As expected | PASS |
| D-02 | Dashboard | References in recent activity | Shown as stored (SPF-261015-8CNG3L) | Shown with underscores (SPF_261015_8CNG3L) on the Android 17 emulator | FAIL → fixed (BUG-01), retest PASS |
| D-03 | Dashboard | Recent activity after a new operation | New operation listed | Stale until the screen was rebuilt (list read once) | FAIL → fixed (BUG-03), retest below |
| D-04 | Dashboard | This month after a refunded withdrawal | Net = balance change (+479 700) | Money in 505 150 (refund counted), net +484 850 | FAIL → fixed (BUG-04), retest PASS: in 500 000, out 20 300, net +479 700 |
| D-03r | Dashboard | Jean sends 10 000 while Amina's home is open (retest of BUG-03) | Appears at once | Appeared within 3 s; this month and net updated (+464 700 = balance) | PASS |
| IS-01 | Insights | This month, cash flow, last 30 days after all the tests above | Recomputed independently from the ledger | In 688 901 / out 494 465 / net +194 436 (= balance); transfers 98 000, cards 21 000, withdrawals 20 300, bills 15 150 - all equal to the independent computation | PASS |
| D-05 | Dashboard | Privacy eye on the balance card | Every figure of the dashboard hidden | Only the balance card was hidden; This month, Coming up, Your money and Recent activity still showed the amounts (the net even equals the balance) | FAIL → fixed (BUG-19), retest PASS: all figures masked, words and progress bars kept |

### Wallet: add money, withdraw, payment methods, convert, statement

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| W-01 | Add money | Amount 100 XAF (minimum 500) | Inline error, Continue disabled | "The minimum is 500 XAF.", Continue disabled | PASS |
| W-02 | Add money | 10 000 XAF, no gateway configured for the region | Pay sheet says no method; Confirm disabled; nothing written | "No payment method is available for this currency right now."; Confirm disabled; no new record | PASS |
| W-03 | Add money | Pay 10 000 XAF through a gateway (Orange Money / Stripe / …) | Deposit + receipt + wallet credited | Not run: needs the provider's sandbox credentials | BLOCKED |
| W-04 | Withdraw | Helper under Amount on a phone | Limits and available balance readable | Cut off ("· Av…") | FAIL → fixed (BUG-02), retest PASS |
| W-05 | Withdraw | 600 000 XAF with 500 000 balance | Fee 1 % + 100 capped at 5 000 → 5 000; error, Continue disabled | Fee 5 000, total 605 000, "The amount and its fee are more than your balance." | PASS |
| W-06 | Withdraw | 20 000 XAF, no payout account saved | Sheet asks to add one, Confirm disabled | "Add a Mobile Money number…", Manage payment methods link | PASS |
| W-07 | Payment methods | Add Mobile Money with an invalid number, then a valid one | Invalid refused; valid saved as default | "Please enter a valid phone number"; +237650000101 saved, Default | PASS |
| W-08 | Withdraw | 20 000 XAF, fee 300, double-tap Confirm | One request, pending; wallet −20 300; platform +20 300 | One wallet_operations doc (pending), one posting, balance 479 700 live, ledger consistent | PASS |
| W-09 | Withdraw | Admin pays out | Page updates to Completed with payout reference, receipt button | Live update, Step 3/3, payout reference, "Share the receipt" | PASS |
| W-10 | Withdraw | 5 000 XAF (fee 150), admin cannot pay out | Reversed; full 5 150 back; reason shown | Status Refunded, reason shown, balance back to 479 700, reversal posting, ledger consistent | PASS |
| W-11 | Convert | 100 000 XAF → EUR at the EUR/XAF peg 655.957, fee 1 % | Fee 1 000; receive floor(99 000 / 655.957 × 100) = 150.92 EUR; two postings; EUR wallet created | Rate 1 XAF = 0.001524 EUR; fee 1 000; receive 150.92 EUR; XAF −100 000; EUR wallet 15 092 cents; platform accounts mirror; ledger consistent in both currencies; receipt button | PASS |
| W-12 | Convert | XAF → USD (new USD wallet) while the wallet list is open | New credit listed as + 16.40 USD | Listed "0.00 USD" with an outgoing arrow (the list's accounts did not include the wallet just opened) | FAIL → fixed (BUG-10), retest PASS (+16.40 USD, money in) |
| W-13 | Statement | Last month's statement PDF | Holder, period, totals per currency, one row per posting; totals match the balance | 15 rows; XAF in 530 300 / out 238 600 (net 291 700 = balance); EUR and USD lines; reversals listed with a note; shared through the system sheet | PASS |

### Money transfer

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| T-01 | Transfer | Unknown e-mail | Refused before confirming | "We could not find a Spideli account with these details." | PASS |
| T-02 | Transfer | Own e-mail | Refused | "You cannot send money to yourself." inline, Continue disabled | PASS |
| T-03 | Transfer | Invalid e-mail text | Refused | "Enter a valid email address, like name@example.com." | PASS |
| T-04 | Transfer | Amount hint on the form | Limits and balance readable | Wraps, "Available balance: 479 700 XAF" (after BUG-02 fix) | PASS |
| T-05 | Transfer | 25 000 XAF to Jean, note, wallet | Confirm card with name found; one posting; both wallets move; record completed | "Spideli account found: Jean Mbarga"; Amina 479 700→454 700, Jean 300 000→325 000; money_transfers completed, recipientVerified; ledger consistent | PASS |
| T-06 | Transfer | Result message for the sender | Says the money was sent | Says "Payment received - Your payment was received." | FAIL (minor wording) |
| T-07 | Transfer | Transfer page | Completed, recipient verified, details, receipt | As expected | PASS |
| T-08 | Transfer | Mobile Money 15 000 XAF to a number with name | Fee 1 % = 150, total 15 150; status processing; posting wallet → platform | As expected; recipient name saved; ledger consistent | PASS |
| T-09 | Transfer | Ask to cancel while processing | Confirmation sheet; cancelRequested set; notice; button gone | As expected ("Cancellation requested") | PASS |
| T-10 | Transfer | Admin refunds the cancelled transfer | Cancelled; 15 150 back; clear reason | Money back (464 700), ledger consistent; but reason shown as raw code "cancelled_by_sender" and no "money back" notice | FAIL → fixed (BUG-05), retest PASS |
| T-11 | Transfer | Back after a completed transfer | Returns to where the user started | Returned to the still-filled form (accidental second send possible) | FAIL → fixed (BUG-06), retest below |
| T-12 | Transfer | History amount of a transfer with a fee | Same as the transfer page (total paid) | List −15 000, page −15 150 | FAIL → fixed (BUG-07), retest PASS (−15 150) |
| T-13 | Transfer | 60 000 XAF (≥ 50 000 threshold), wrong then right password | Password asked; wrong refused with nothing written; right continues | "Confirm it is you"; "Incorrect password." and no posting; correct password opened the pay sheet | PASS |
| T-14 | Transfer | Network lost while confirming (airplane mode), then back | Clear failure; nothing moves later without the customer knowing | After 45 s "Payment not completed"; when the network came back the queued batch went through anyway (Amina −60 000, Jean +60 000) while the app still said "not completed" | FAIL (critical) → fixed (BUG-08), retest below |
| T-14r | Transfer | Retest of BUG-08: offline confirm, network back, then Try again | "Payment not confirmed"; nothing moves until Try again; then exactly one posting | "Payment not confirmed" + note; ledger unchanged after the network returned (11 postings); Try again → one posting (12), Amina −2 000, Jean +2 000 | PASS |
| T-11r | Transfer | Retest of BUG-06 | Back from the transfer page → transfers list | Transfers list | PASS |
| T-06r | Transfer | Retest of the sender message (BUG-09) | "Money sent" | "Money sent - Jean Mbarga received the money." | PASS |

### Bill payment

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| BL-01 | Bills | Meter number 12345 (pattern 11 digits) | Inline error, Continue disabled | "This number is not in the expected format. Expected: 11 digits." | PASS |
| BL-02 | Bills | City Power, 15 000 XAF (fee 1 %, cap 2 000) | Fee 150, total 15 150; processing; posting; account saved | As expected; utility_payment_requests processing; utility_saved_accounts created; ledger consistent | PASS |
| BL-03 | Bills | Admin pays the biller with a prepaid token | Completed; token card with Copy, units, customer name | Live update, token "4821 0937 …", Units 48.5 kWh, Copy, customer A. DIALLO | PASS |
| BL-04 | Bills | Back after paying a bill | Bills page | Returned to the filled bill form | FAIL → fixed (BUG-11), retest PASS (bills page) |
| BL-05 | Bills | TV package biller: smart card 10 digits, choose "Family" | Amount from the package, no fee | 12 000, Free; package recorded (packageCode family) | PASS |
| BL-06 | Bills | Admin cannot pay the biller (refund) | Refunded; reason; money back | Refunded, reason shown, 12 000 back (balance 276 550), ledger consistent; added "money is back" notice | PASS (after small fix BUG-12) |

### Virtual card

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| C-01 | Cards | Card form: fees, limits, capabilities, terms v1; Create disabled until terms accepted | As specified | As expected | PASS |
| C-02 | Cards | Request a card (fee 1 000 from the wallet) | Card requested; fee posting | virtual_cards requested, feeTxId posting wallet → platform, ledger consistent | PASS |
| C-03 | Cards | Admin issues the card | Card face live: last 4, holder, expiry, Active | •••• 3649, AMINA DIALLO, 10/29, Active | PASS |
| C-04 | Cards | Top up 20 000 (fee 0 %) | Pending request + posting; admin completes → card balance | Request + posting; after the admin step balance 20 000 and a Top-up row | PASS |
| C-05 | Cards | Card purchase from the issuer (simulated webhook, 7 500) | Listed, balance 12 500 | As expected | PASS |
| C-06 | Cards | Freeze (no password) / Unfreeze (password) | Frozen look; unfreeze asks the password | "Card frozen"; unfreeze asked "Confirm it is you"; "Card unfrozen" | PASS |
| C-07 | Cards | Limits: per payment 150 000 above daily 100 000; then 50 000, abroad off | Inline error; then pending request | "The limit per payment cannot be above the daily limit."; card_limit_settings pending with the right fields | PASS |
| C-08 | Cards | Card → wallet 5 000 | In progress; admin completes → card −5 000, wallet +5 000 | "In progress" row; after the admin step card 7 500, wallet 260 550 (+5 000, card_withdrawal posting) | PASS |
| C-09 | Cards | Icon of a card-to-wallet row | Outgoing arrow | Shopping bag (purchase icon) | FAIL (cosmetic) → fixed (BUG-13), retest PASS |

### Collective savings

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| S-01 | Savings | New group goal "Family house deposit", target 2 000 000, invite Jean by e-mail | Goal active, Jean invited, empty pool account | savings_goals active, invitedIds [Jean], goal account created; goal page with plan and projection | PASS |
| S-02 | Savings | Add 50 000 from the wallet | Pool +50 000, wallet −50 000, contribution "Received", progress, projection | Goal 50 000 (3 %), wallet 210 550, chart and projection (15 Jan 2030), ledger consistent | PASS |
| S-03 | Savings | Jean accepts the invitation (through the rules) while Amina's page is open | Members 2 live | Members 2, Jean listed with Message | PASS |
| S-04 | Savings | Early withdrawal warning, then group withdrawal 10 000 | Warning; request only (no money moves) | Warning sheet; "Ask to withdraw?"; savings_withdrawals requested; ledger unchanged | PASS |
| S-05 | Savings | Admin approves the group withdrawal | Pool −10 000, wallet +10 000, Completed live | Goal 40 000, wallet 220 550, chart updated, Completed | PASS |

### Tontine

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| TN-01 | Tontine | Create "Douala Market Women Tontine": 25 000 XAF, monthly, 3 members, fixed order | Forming, admin = creator, pot account; summary pot 75 000 | Created; schedule cycle 1 · You | PASS |
| TN-02 | Tontine | Page header while forming | Shows the pot agreed at creation (75 000) | Showed 25 000 (pot of the 1 member so far) | FAIL → fixed (BUG-14): "Pot per cycle when full 75 000" |
| TN-03 | Tontine | Invite Jean and Fatou by e-mail; both accept (through the rules) | Invitations listed; members 3/3 live | "Invitation sent"; Invited; then 3/3 and payout order You / Jean / Fatou | PASS |
| TN-04 | Tontine | Start (start button disabled until 3 members) | Active; 3 cycles with beneficiaries and due dates; cycle 1 collecting | "More members are needed to start" at 1/3; started: cycles 22 Oct / 22 Nov / 22 Dec, 75 000 each | PASS |
| TN-05 | Tontine | Amina pays, then Jean and Fatou pay (through the rules) | Progress live; at 3/3 payout pending + payout request | 25 000 → 75 000 / 75 000, 3 of 3 paid, "Payout pending", pot 75 000 | PASS |
| TN-06 | Tontine | Sole administrator is the beneficiary | Cannot approve own payout; told Spideli approves | No approve button; "You are the only administrator: Spideli approves your own payout." | PASS |
| TN-07 | Tontine | Admin approves the payout | Pot → beneficiary wallet; cycle 2 opens for Jean | Wallet +75 000, pot 0, cycle 2 collecting (next 22 Nov), live | PASS |

### Member loans

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| L-01 | Loans | Jean applies (100 000, 3 months, monthly) through the rules; admin reviews, scores and opens a 48 h vote | Voters = the rest of the group; Amina asked to vote | Needs your action "Vote on a loan request", deadline shown | PASS |
| L-02 | Loans | Amina approves with a comment; Fatou approves; Fatou votes again | One vote each; live tally; second vote refused | 1/2 then 2/2 live; "You voted to approve"; repeat vote refused by the rules (403) | PASS |
| L-03 | Loans | Close the vote once everyone voted | Approved → Being funded | "Everyone has voted: any member can close the vote"; approved; Being funded | PASS |
| L-04 | Loans | Amina lends 60 000 then 40 000 (risk disclosure) | Loan account holds the money; last funding creates the agreement | Risk sheet; 60 % then 100 %; agreement: declining 12 %/yr, 3 × (34 002, 34 002, 34 003) = 102 007, fee 2 % = 2 000 | PASS |
| L-05 | Loans | Borrower (Jean) sees the credit score; lender does not | Score and factors to the borrower only | 712 "good" with 2 factors for Jean; not shown to Amina | PASS |
| L-06 | Loans | Jean accepts the agreement | 98 000 to Jean, 2 000 fee to the platform, loan account 0, dated schedule | "Agreement accepted. The loan was paid into your wallet."; Jean 353 000 → 451 000; schedule 15 Nov / 15 Dec / 15 Jan | PASS |
| L-07 | Loans | Jean repays instalment 1 (34 002) | Loan account +34 002; instalment Paid; outstanding 68 005 | As expected; next instalment prefilled | PASS |
| L-08 | Loans | Amina collects her share | floor per funding: 20 401 + 13 600 = 34 001; 1 XAF rounding left | "Available to collect 34 001"; collected; wallet 204 551; loan account 1; available 0 | PASS |

### Investments

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| I-01 | Investments | Funds list, risk filter with no match, fund page (risk 2/7, key facts, fees, eligibility, performance, price history) | As specified | "No fund matches these filters" + Show all; fund page complete; change +2.37 % = 1 052.4 / 1 028 | PASS |
| I-02 | Investments | Subscribe 5 000 (min 10 000), then 50 000 with risks, terms and e-signature | Below minimum refused; paid subscription; posting of 50 000 | "The minimum is 10 000 XAF."; subscription paid (fee estimate 500), wallet −50 000, ledger consistent | PASS |
| I-03 | Investments | Admin allocates units at 1 052.4 | 47.0353 units; value 49 500; invested 50 000; unrealized −500 | Portfolio and holding live, allocation 100 % money market | PASS |
| I-04 | Investments | Partial redemption 20 000 to the wallet | Estimate 19.0041 units, fee 100, ~19 900; request submitted | As expected; "Request sent" | PASS |
| I-05 | Investments | Admin settles | Wallet +19 900; holding 28.0312 units; realized −302, unrealized −298 (= fees) | Exactly as expected, live; history shows both orders | PASS |

### Insurance

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| IN-01 | Insurance | Product page (cover, deductible, waiting period, covered / not covered) | As specified | As expected | PASS |
| IN-02 | Insurance | Quote form: age 75 (range 18-70); then 42, 2-4 people, monthly | Range error; estimate 60 000 × 1.3 × 2.2 = 171 600/yr, monthly +5 % = 15 015 | "Outside the accepted range: 18 - 70"; 15 015 monthly, 180 180 a year | PASS |
| IN-03 | Insurance | Admin prices the quote | Quote ready live with validity and cover | "Quote ready", valid until 29 Oct, cover 16 Oct 2026 - 16 Oct 2027 | PASS |
| IN-04 | Insurance | Accept: terms + signature + first premium 15 015 from the wallet | Policy pending activation; premium 1 paid; posting | As expected; ledger consistent | PASS |
| IN-05 | Insurance | Admin activates | Active, policy number, next payment, premiums schedule | POL-QA-…, next 14 Nov, 2 upcoming + 1 paid | PASS |
| IN-06 | Insurance | Make a claim while the cover starts tomorrow | Clear message; never a broken control | Date picker did not open (unhandled assertion: initial date after last date); Make a claim available | FAIL → fixed (BUG-15): "Your cover starts on 16 Oct 2026: you can claim for incidents from that day." |
| IN-07 | Insurance | Claim 45 000 for 12 Oct (date limited to the cover) | Submitted, Step 1/4 | As expected | PASS |
| IN-08 | Insurance | Admin asks for information; customer answers | "The insurer asks …"; answer moves it back to review | As expected (status under_review, event saved) | PASS |
| IN-09 | Insurance | Admin approves 35 000 and pays | Paid; wallet +35 000; no stale notes | Paid, approved/paid 35 000, wallet +35 000; but the answered question still shown as "Reason" | FAIL → fixed (BUG-16), retest PASS |

### Markets and opportunities

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| M-01 | Markets | Indicators (Cameroon): value, trend vs previous, period, source, updated | As published, labelled as sample | 3 indicators with Up / Down, previous values, "QA sample data (not real figures)" | PASS |
| M-02 | Markets | Exchange rates: converter and latest rates | 1 EUR = 655.96 XAF; Official / Indicative chips | As expected | PASS |
| O-01 | Opportunities | List, opportunity page (raised 38 %, key facts, risk warning) | As specified | As expected | PASS |
| O-02 | Opportunities | I am interested with a message | Name, e-mail and message shared; no money | Saved interested=true with name, e-mail, message; "Interest sent" | PASS |
| O-03 | Opportunities | Reopen the opportunity later | Shows the interest already sent; lets the customer withdraw it | Showed "I am interested" again; no way to withdraw (only "Not for me", which hides) | FAIL → fixed (BUG-17): live read of the saved answer, "Interest sent" + "Withdraw my interest" |
| O-04 | Opportunities | Withdraw the interest (retest of BUG-17) | Confirmation; name, e-mail and message removed | Confirmation sheet; record now interested=false, message empty, no name / e-mail | PASS |

### Project financing

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| F-01 | Financing | Resources tab and a guide | Published guides readable, "for information only" note | 3 guides; reading view with updated date and note | PASS |
| F-02 | Financing | New application without a project | Project form first; required fields enforced | "Add a project" first; Save disabled until name + description (≥ 30) | PASS |
| F-03 | Financing | Loan application 50 000 000 XAF, 24 months, use of funds | Draft with the required documents for a loan | Draft; Business plan, Company registration, Financial statements required | PASS |
| F-04 | Financing | Submit with documents missing | Blocked with the list | "Still missing: …"; Submit disabled | PASS |
| F-05 | Financing | Upload 3 PDFs through the system picker, declaration, submit | Files in Storage under the owner's folder; Submitted | 3 financing_documents "received", storage paths financing_documents/{uid}/{app}/…; status Submitted, Step 1/5 | PASS |

### AI assistant

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| AI-01 | AI assistant | Financial coach (coach disabled in settings) | Says it is not available; no AI call | "The financial coach is not available yet." | PASS |
| AI-02 | AI assistant | Return simulator: 100 000 start, 10 000/month, 5 %, 10 years | Monthly compounding: value 1 706 521, put in 1 300 000 | Exactly 1 706 521 / 1 300 000 / +406 521; empty monthly field refused | PASS |

### Identity verification (KYC), restrictions, security, notifications, messages

| ID | Area | Scenario | Expected | Actual | Status |
|---|---|---|---|---|---|
| CH-01 | Messages | Tontine group chat: open, send a message | Message saved and shown with time and day | "Today", 19:25, saved in finance_chats/tontine_…/messages | PASS |
| SEC-01 | Security | Two-step verification page | Explains the steps; asks for a verified e-mail first | "Verify your email address" with Send verification email; phone list empty | PASS (SMS enrolment needs Identity Platform: not testable on the emulator) |
| SEC-02 | Notifications | Turn off "News and markets" push | Saved to the user's preferences; security notices always on | users.financeNotificationPrefs.push.news = false | PASS |
| K-01 | KYC | Unverified customer (Fatou): banner on Home; levels shown | "Verify your identity…"; Basic / Full; Individual / Business | As expected | PASS |
| K-02 | KYC | Start Basic: name, save details | Draft saved | "Saved"; To continue lists only the documents | PASS |
| K-03 | KYC | Upload passport and face photo from the gallery | Files under kyc/{uid}/{application}/…; 2 of 2; Submit enabled | As expected (upload slow on the emulator: ~25 s, loader stayed until done) | PASS |
| K-04 | KYC | Submit; admin starts review; admin approves | Live: Submitted → Under review → Verified; history; next level offered | Exactly so; users.kycLevel basic | PASS |
| R-01 | Restriction | Admin restricts Fatou for transfers | Notice on Home with scope, reason, date, support link | "Account restricted … Transfers. Reason … Since …" live | PASS |
| R-02 | Restriction | Fatou tries to send 1 000 | Refused before any money moves | "Your Spideli Finance account is restricted for this service." No posting (39 unchanged) | PASS |
| R-03 | Restriction | Transfer page while restricted | Said up front, before the form | Only after filling the form and confirming | FAIL (UX) → fixed (BUG-18): notice at the top of Transfers (and Bills for the payments scope) |
| CH-02 | Messages | Unread dot for another member | Dot on Messages for Fatou after Amina's message | Red dot shown | PASS |

## 5. Data checks performed in Firebase (test database)

| Check | How | Result |
|---|---|---|
| Every money operation is one balanced posting | `verify.py ledger` after each scenario | 47 postings, all balanced |
| Balances equal their history | recomputed from postings for all 11 accounts | equal, to the franc / cent |
| Platform position mirrors customer money | sum of XAF balances | 0 (as designed) |
| Failed / refunded operations leave balances unchanged | withdrawal refund, transfer cancel, bill refund, offline payment | money back in full; no posting left behind; the offline attempt created nothing |
| Double submission | double-tap Confirm (withdrawal), Try again after offline (transfer) | exactly one request and one posting |
| Customers see only their own records | rules tests + repeat vote / foreign reads refused (403) | refused |

Detailed coverage, untested features and blockers: `03_FEATURE_COVERAGE.md`.
