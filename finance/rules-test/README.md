# Spideli Finance - Firestore rules tests

Emulator tests of the **Spideli Finance** block of `firestore.rules.draft`
(repo root), the rules of `.claude/FINANCE-DIRECT-FIRESTORE.md`. Nothing is
deployed and no real project is touched: the emulator runs the `demo-spideli`
project (a `demo-` id never reaches Firebase).

## Run

```sh
cd finance/rules-test
firebase emulators:exec --only firestore --project demo-spideli "node --test --test-concurrency=1 test/"
```

Needs the Firebase CLI (it starts the cached Firestore emulator, Java 11+) and
Node 20+. There are **no npm dependencies**: the tests use Node's `node:test`
and a small client for the emulator's REST API (`lib/firestore-rest.js`),
because `finance/functions/node_modules` is an empty skeleton and nothing may
be downloaded. Each test file loads `../../firestore.rules.draft` into the
emulator through its rules API (`firebase.json` cannot point at a file outside
this folder) and re-seeds the data before every test.

Last run (14 Oct 2026): **79 tests, 79 pass** (~35 s).

## Layout

| File | What |
|---|---|
| `lib/firestore-rest.js` | emulator client: unsigned ID tokens (with `auth_time`), `Bearer owner` seeding, batches written like the Flutter SDK (`set`, `update` with dotted paths, `set(merge)` with leaf paths, `serverTimestamp`, `increment`, `arrayUnion`, `delete`) |
| `lib/fixtures.js` | seed data (users, `platform_settings/*`, platform and user accounts) and `plan()`, a port of the app's `FinanceLedger.plan`, so each test builds the batch the app builds and then breaks one thing |
| `test/ledger.test.js` | ledger core, deposits, transfers, withdrawals, bills, conversions, replay, reads |
| `test/groups.test.js` | savings goals and tontines |
| `test/loans.test.js` | member loans |
| `test/kyc_cards.test.js` | KYC, users' finance fields, virtual cards |
| `test/products.test.js` | chat, catalogs, investments, insurance, financing, intelligence, restriction scopes |
| `test/flows.test.js` | the app's other write shapes (must be accepted) and their misuse |

## What the tests prove

**Reads.** Own wallet readable, someone else's refused, a missing account
reads as missing (the app's "does the recipient's wallet exist?"); account
lists only `where userId == me`; postings only for their `userIds`;
transfers for their participants; receipts for their payer; goals for
members and invitees; tontines and their records for active members, an
invitation for its invitee only; loans for borrower, voters and lenders; the
credit assessment for the borrower only (a voter is refused); catalogs only
`published == true`, and a list query without that filter is refused.

**Gateway deposit.** Allowed with its `payment_receipts/{method}_{ref}` and
moves exactly the amount (`platform -amount`, wallet `+amount`); refused when
the receipt is reused (same user or another), missing, names another
posting, or a lower amount; refused when crediting someone else's wallet;
above the deposit maximum (a plain deposit); the wallet is created by its
first credit.

**Internal transfer.** Allowed (sender `-amount-fee`, recipient `+amount`,
platform `+fee`), also creating the recipient's wallet; refused as an
overdraft, debiting someone else's wallet (only the debit authorization
differs from an allowed batch), crediting oneself from another wallet, with
unbalanced lines, an account changed by more / less than its line, a line's
account not written, zero / negative amounts, a fee below the configured fee,
a record naming another recipient, a posting without its request; above
`reauthAbove` only with a sign-in under 5 minutes; a gateway payment is a
deposit first (a direct `platform -> recipient` posting is refused).

**Replay and direct edits.** An old posting cannot be applied to an account
again; no balance change without a posting of the same request; no kind /
status change; no account delete; postings are never updated or deleted; a
frozen account (status not `active`) cannot move; admin-only types
(`reversal`) are refused.

**Withdrawal, external transfer, bill, conversion.** Withdrawal debits amount
+ fee, refused with a low fee, a method not offered, or stale auth above the
threshold; external transfer posts the total and its cancel request is the
sender's, once; a receipt that names no posting is refused; bill with the
biller's fee (skipping it refused); conversion at the published rate (inverse
pair, minor-unit exponents) allowed, a better rate or a missing rate snapshot
refused.

**Savings.** Owner creates a goal with an empty account (money in it, or for
someone else, refused); invitee joins (a stranger cannot); a contribution's
`savedAmount` must move by exactly the posting (other delta, no counter, a
counter without posting, a stranger: refused); gateway contribution with its
receipt; solo withdrawal to the owner's own wallet only and within the
saved amount; group goals only request; solo cancel returns the whole
balance (a partial counter refused).

**Tontines.** The app's create / invite / accept / start batches (non-admin
invite, changed terms, joining without an accepted invitation, a cycle with
another pot, inviting after the start: refused); one contribution per member
and cycle (create-only id), `collectedAmount` by exactly the posting, never a
stranger, never another amount, never an upcoming cycle; the contribution
that completes the pot (paid by a gateway: the heaviest batch) opens the
payout, and refusing to move to `payout_pending` is refused; the payout is
approved by an admin who is not the beneficiary, to the beneficiary's wallet,
once (self-approval, a non-admin, redirecting the pot: refused).

**Loans.** Apply (a user restricted for `loans`, a non-member, chosen voters,
above the maximum, a skipped review: refused); votes are +1, once, by an
eligible voter (twice, +2, a no counted as yes, a count without its vote, the
borrower: refused) and only before `votingEndsAt`; closing follows quorum and
approval; funding never beyond the amount, never by the borrower, with
`fundedAmount` equal to the postings and the agreement capped by the
configured interest; the pay-out is the borrower's, the whole funded amount,
once; repayments lower `outstandingAmount` exactly; lenders collect at most
`floor(repaid x lent / amount) - collected` per funding (6001 of a 6000
share refused; 4000 + 2000 allowed, then +1 refused).

**KYC.** Drafts only (approved status, unknown level, another user:
refused); details while draft, 200 characters max; documents only under
`kyc/{uid}/{app}/`, never self-accepted; submit with its `submit` history
entry (an `approve` entry refused); the customer never moves a submitted
application to `under_review` / `approved` / `rejected` /
`additional_info_required`; reopen after a rejection with revision + 1 only.

**Users.** `kycLevel`, `kycStatus`, `financeRestriction` never written by the
user (nor at sign-up, nor lifted by the restricted user, nor set on someone
else); `financeNotificationPrefs` written by the account only, bools only;
ordinary sign-up and `savedPaymentMethods` still work.

**Cards.** A request pays its issuance fee (active, funded, free, outdated
terms: refused); freeze is instant; unfreeze only the user's own freeze and
re-authenticated (an admin freeze refused); termination and limits
re-authenticated, limits within the ceilings and in order; top-up posts
amount + fee (fee below `fundingFeePercent` refused); card withdrawal /
card-to-card re-authenticated and within the card balance; renewal once.

**Chat.** Direct: the two members of `dm_{sorted uids}` only, own read time
only, members never changed; messages by their sender, 1..1000 characters,
never edited or deleted; a tontine group: its active members only (the first
message creates the conversation).

**Restriction scopes** (`users.financeRestriction`, admin only; no scopes =
all): `savings` (create / join a goal), `tontines` (create / join), `loans`
(apply, vote, fund, accept), `transfers`, `payments` (bills), `wallet` (add
money, withdraw, convert). Declining an invitation, receiving money and the
gateway step of an obligation stay allowed.

**Products.** Investment subscription paid by its posting, under the current
terms and above the minimum (`minAdditional` for a holder), never completed
by the client; redemptions by holders, partial only when the fund allows it,
cancelled only while submitted. Insurance: quote request (a self-priced quote
refused), acceptance only with the first premium paid in the batch, never an
active policy; premium payment, renewal at `renewalPremium`, auto-renew,
cancellation request, claim on an active policy, answer and withdrawal.
Financing: own project / application / documents under the owner's Storage
folder, submit with the declaration, never an approval; a document removed
only while the application is editable. Intelligence: own profile,
watchlist and opportunity interest only.

## Emulator facts the rules rely on (measured, `scratchpad` probes)

- 10 distinct documents read per write, 20 per batch; reads of the same
  document (get, getAfter, exists) are cached across the batch.
- 1000 evaluated expressions per write (not per batch).
- In a batch writing one document twice, `request.resource` is the final
  state for both writes (an account changed twice in one batch shows the sum
  of both deltas, so "each account once per batch" holds).
- A list rule on a defaulted field (`resource.data.get('published', true)`)
  lets an unfiltered query return unpublished documents: catalog list rules
  use `resource.data.published == true`.
- `/` on integers truncates; `math.round` returns an int, `math.floor` a float.

## Required app change found by the tests

- **Conversions** (`WalletRules.convertWrites`): add `rateSnapshotId` (the
  `exchange_rate_snapshots` document id used) to the `wallet_operations`
  document. The rules read the snapshot to bound `receiveAmount`; without it
  the second leg would be an unbounded `platform_B` debit, so a conversion is
  refused until the field is sent.

## Not provable by the rules: the admin's reconciliation

- **Gateway payments are device-reported.** Every gateway-funded posting has
  a create-only receipt (`verified: false`); the PHP panel must check each one
  with the provider (index `payment_receipts (verified, createdAt)`) and
  reverse a fake one. A gateway deposit with a `purpose` skips the wallet
  deposit limits and the `wallet` restriction (it is a step of another
  request).
- Daily / monthly transfer limits, "one open request" per user (KYC, loans),
  `maxCardsPerUser`, tontine `active + invited <= membersLimit` (the join is
  refused when full), uniqueness of payout positions: counts across
  documents.
- List contents: loan schedules and installment statuses (written by the
  borrower; the binding figures are `outstandingAmount` / `repaidAmount`),
  bill packages (amount equal to a package), claim / loan document paths.
- The loan agreement's schedule (the total is bounded by flat interest over
  the duration; the borrower accepts it explicitly).
- Conversion rate freshness within `maxRateAgeHours` (the client may pick any
  published snapshot inside the window).
- `platform_{CUR}` accounts must be created by the admin before go-live; they
  are a write hot spot (every fee and payout touches them).
- Insurance renewals: the admin clears `renewalRequestedAt` when it renews,
  so the next renewal can be paid.
