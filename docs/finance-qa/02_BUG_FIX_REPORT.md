# Spideli Finance – Customer App: Bug Fix Report

Date: 15 October 2026 · 19 defects found during testing, **all fixed and retested**. Severity: **Critical** (money or data could go wrong), **High** (a customer is misled about money or blocked), **Medium** (wrong or confusing information), **Low** (cosmetic).

After the fixes: 887/887 app tests, 79/79 security-rules tests, analyzer clean, test ledger consistent.

| ID | Severity | Area | What was wrong | Fix | Retest |
|---|---|---|---|---|---|
| BUG-08 | **Critical** | Every payment | A payment confirmed while offline was queued by Firestore. The app said "Payment not completed" after 45 s, yet the queued write went through when the network came back: Amina −60 000, Jean +60 000, without her knowing. | Money writes are now committed as an online-only transaction (`FinanceLedger.commit`): they reach the server or fail, never later. A lost connection says "Payment not confirmed" and explains that Try again settles it and never pays twice. Applies to all finance writes (`FinancePaymentService.commit`, `FinanceDirect.commit`). | T-14r: offline confirm → "Payment not confirmed"; network back → **nothing moved**; Try again → exactly one posting. PASS |
| BUG-03 | High | Dashboard, Wallet | Recent activity and wallet history were read once: a new payment, transfer or refund did not appear until the screen was rebuilt. | Transaction lists watch the user's newest posting and reload when it changes (`TransactionList`, `FinanceService.latestTransaction`). | D-03r: a transfer received while the home was open appeared within 3 s. PASS |
| BUG-04 | High | Dashboard "This month", Insights | A refunded withdrawal counted its refund as money in (in 505 150, net +484 850 while the balance was 479 700). | The cash-flow totals skip a reversed posting **and** the reversal that undid it (`FinanceSummaryBuilder`). Unit test added. | Net +479 700 = balance; Insights recomputed independently from the ledger, equal. PASS |
| BUG-10 | High | Wallet history | A conversion into a new currency (XAF → USD) was listed as "0.00 USD" with an outgoing arrow: the list did not yet know the wallet that posting created. | The user's own standard wallets count even before the account list updates (`LedgerView.signedAmount(uid:)`); the list also re-reads accounts on reload. Unit test added. | "+16.40 USD", money in, live. PASS |
| BUG-06 | High | Money transfer | After a transfer, Back returned to the still-filled form: one more tap could send the same money again. | The transfer page replaces both the confirmation and the form. | Back → transfers list. PASS |
| BUG-11 | High | Bill payment | Same as BUG-06 for bills (Back returned to the filled bill form). | Same fix for bills. | Back → bills page. PASS |
| BUG-19 | High | Dashboard privacy | The eye hid only the balance card; This month (whose net equalled the balance), Coming up, Your money tiles and Recent activity still showed every amount. | All figures of the Home and Wallet tabs follow the eye (`FinPrivacy.watch` / `maskAll`, used by `FinInOut`, `FinTileGrid`, `FinListTile(private:)`). Words and progress bars stay. Unit test added. | Every figure masked; reopening shows them again. PASS |
| BUG-15 | High | Insurance claim | On a policy whose cover starts tomorrow, "Make a claim" opened a form whose date picker could not open (unhandled assertion: initial date after the last date). | Before the cover starts the policy says "Your cover starts on 16 Oct 2026: you can claim for incidents from that day."; the picker range is fixed. | Message shown; with an active cover the picker allows 1–15 Oct only. PASS |
| BUG-17 | Medium | Opportunities | After "I am interested", reopening the opportunity offered "I am interested" again, and there was no way to take back the name and e-mail shared with the project owner. | The page reads the saved answer live, shows "Interest sent" and offers "Withdraw my interest" (confirmation; name, e-mail and message removed). | Saved answer shown after restart; withdrawal removed name, e-mail and message in Firestore. PASS |
| BUG-18 | Medium | Restrictions | A customer restricted for transfers learnt it only after filling the form and confirming. | The restriction notice appears at the top of the service it blocks (Transfers, Bills). | Notice at the top of Money transfer. PASS |
| BUG-14 | Medium | Tontine | While forming, the header showed "Pot per cycle 25 000" (one member so far) although the creation summary promised 75 000. | Shows "Pot per cycle when full 75 000"; the real pot once started. | PASS |
| BUG-16 | Medium | Insurance claim | On a paid claim, the insurer's (answered) question still appeared under "Reason". | The question shows only while it waits for an answer; a reason only for a refusal. | Paid claim shows no stale note. PASS |
| BUG-07 | Medium | Transfer history | A transfer with a fee was listed as −15 000 while its page said −15 150. | The list shows what left the wallet (fee included). | −15 150 in both. PASS |
| BUG-05 | Medium | Refunded transfer | The reason showed the code "cancelled_by_sender"; nothing said where the money was. | Reason codes read as sentences on every finance page (`financeReasonText`); refunded transfers say "the money is back in your wallet". Unit test added. | PASS |
| BUG-09 | Low | Transfer result | The sender of a transfer saw "Payment received – Your payment was received." | "Money sent – Jean Mbarga received the money." | PASS |
| BUG-12 | Low | Refunded bill | No "money back" notice on a refunded bill. | "This bill was not paid: the money is back in your wallet." | PASS |
| BUG-02 | Low | All forms | Field hints were cut to one line ("1 000 XAF – 1 000 000 XAF · Av…"), hiding the available balance. | Design-system inputs let hints wrap (up to 3 lines). | Full hint visible. PASS |
| BUG-01 | Low | References | References showed with underscores (SPF_261015_…) on the Android 17 emulator: the non-breaking hyphen is missing from the font there. | Plain hyphens with an invisible word joiner (still never broken across lines). Copy keeps the raw reference. Unit test added. | SPF-261015-8CNG3L. PASS |
| BUG-13 | Low | Card activity | A card-to-wallet row had the shopping-bag (purchase) icon. | Outgoing arrow for non-purchase card debits. | PASS |

## Files changed (customer app)

`lib/main.dart` (debug-only emulator switch), `lib/service/finance_ledger.dart`, `finance_payment_service.dart`, `finance_direct.dart`, `finance_service.dart`, `finance_intel_service.dart`, `lib/utils/finance_rules.dart`, `finance_summary_builder.dart`, `lib/screen_ui/finance/` (`transactions_screen`, `transfer_screens`, `bill_screens`, `card_screens`, `insurance_screens`, `intelligence_screens`, `tontine_screens`, `finance_widgets`, `finance_restriction`, `fin_ds`, `fin_kit`, `finance_home_screen`, `wallet_screens`, `lending_screens`, `investment_screens`), `lib/themes/ds/` (input hints), `lib/lang/app_en.dart`, `app_ar.dart` (new strings in English and Arabic).

New tests: `finance_reference_display_test`, `finance_reason_text_test`, `finance_signed_amount_test`, `finance_privacy_test`, plus a new case in `finance_summary_builder_test`.

Commits (local, not pushed): `ee430068`, `cae3e78b`, `09a7e7ee`, `047f602e`, `8fb90ba5`.

## Observed, not changed

- The e-mail field of a transfer can show "Enter a valid email address" while the address is still being typed (seen once during recording). It does not block anything; left as is.
- On the emulator, uploads to the Storage emulator took up to ~25 s with the loader shown; this is the emulator's speed, not the app.
