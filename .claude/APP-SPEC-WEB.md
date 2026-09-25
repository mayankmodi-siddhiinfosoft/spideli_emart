# App Spec — Customer Web Panel

**Panel:** Spideli customer website (`spideli-emart-web`)
**Written:** 24 September 2026, last updated 25 September 2026
**Status:** everything below is **built**. Items 1–7 are **live**; the PDF
receipts of §8 and the period selector of §9 are built but **not yet
uploaded**.

**This file consolidates the web panel's customizations.**
`WEB-SPEC-REGION-DETECTION.md` stays on disk as the long-form working record of
the region layer — this file is the summary. **Edit this one** for anything new.

> **`APP-SPEC-ADMIN.md` in the admin repo is the master.** Fields shared across
> panels — regions, currency, payment methods, subscription plans, service
> groups — are defined there and are **not repeated here**. This file covers
> what the website does with them.

The panel is **Blade with client-side Firestore**, the same shape as the admin
panel. Laravel controllers are thin `return view(...)` shells.

---

## Contents, against the client's own list

| § | Feature | Client's list | State |
|---|---|---|---|
| 1 | Working out the visitor's region | points 1, 2 | ✅ live |
| 2 | The region badge | — | ✅ live |
| 3 | Stores, items and services match the region | point 2 | ✅ live |
| 4 | Prices in the region's currency | point 2 | ✅ live |
| 5 | Customer subscription purchase | points 12, 19 | ✅ live, **never tested** |
| 6 | Free order-history limit | point 12 | ✅ live |
| 7 | Address controls and routing fixes | — | ✅ live |
| 8 | PDF order receipts | point 18 | ⚠️ built, **not uploaded** |
| 9 | Choosing the period of history | point 12 | ⚠️ built, **not uploaded** |
| 10 | Open questions | — | — |

---

## 1. Working out the visitor's region

### What a detected region is allowed to decide

**Agree this before reading any code.** The client settled on 22 September that
**the store's region decides pricing and payment methods** — not the customer's
location. A region is a property of platform data, never of a customer:
`users/{uid}` carries no `regionId` and **must not start carrying one**.

So the detected region has exactly one job: **discovery**.

| May decide | Must never decide |
|---|---|
| Which sections appear | The price of anything |
| Which stores appear in browse and search | Which payment methods are offered |
| Which currency to render **before a store is chosen** | The delivery charge |
| Which region a plan price is shown in, pre-purchase | What a customer is actually charged |

Once a store is in view, **that store's own `regionId` takes over** for every
item in the right-hand column. If this boundary is not held, the website
contradicts the admin panel — and it shows up as customers charged in the wrong
currency.

### The ladder

1. An explicit choice, if one was ever made
2. The **delivery zone** the customer's address falls in — used only when that
   zone serves exactly **one** region
3. The customer's **country**, matched on `countryCode` — **never on `code`**,
   which is a free-text label and reads `"GB"` for Gabon
4. `settings/RegionDefaults.defaultRegionId`
5. Nothing — which is safe: prices fall back to the active currency and nothing
   is filtered

### The same-country bridge

A visitor resolved to Douala sees **Cameroon and Yaoundé** stores, because they
are one country. Without it a region holding no stores of its own is a dead end.

---

## 2. The region badge

A small read-only pill beside the address box showing the region's `code` —
`IN`, `FR`, `YDE`. **An indicator, not a control.** There is no region picker.

**When the region is unresolved it shows nothing at all.** A blank badge is the
honest rendering of "we do not know"; a wrong code is worse than none. This is
settled behaviour for a visitor in a country the platform does not serve, not a
temporary state.

---

## 3. Stores, items and services match the region

### Why this was the actual complaint

**51 of 56 stores sit in the "Worldwide" zone**, and the home queries filtered
on `zoneId == user_zone_id`. Nearly every visitor matches Worldwide, so the
zone filter admitted everything — an Indian visitor saw the Cameroon stores.
**Region is what discriminates here; zone does not.**

### Where it is applied

Helpers in `layouts/footer.blade.php`: `loadDiscoveryRegionIds()`,
`storeMatchesRegion(store)`, `sectionMatchesRegion(section)`. Both tests are
synchronous, so they drop into the existing render loops. **An empty id list
lets everything through** — that is the fallback.

Wired into ten surfaces: both home screens, All Stores, stores by category
(two views), search (stores and products), product lists, new arrivals, dine-in,
and the section lists themselves.

Items follow their stores — the product queries are driven by the already
filtered store list. `catHaveStores()` is included, so a category whose only
stores sit in another region is not offered at all.

### Deliberately NOT filtered

**A customer's own records** — orders, bookings, dine-in history, favourites.
Hiding a customer's own past order because they travelled would be losing their
data, not scoping it.

---

## 4. Prices in the region's currency

Before this, **all 52 money-rendering views** read
`currencies where isActive == true`. Only one document carries that flag — XAF
— so every price rendered in FCFA, including the Indian and French stores.

All 52 were switched to `regionCurrencyRef()` **in one pass**, plus the
footer's own block.

**They had to go together.** Every such view re-declares the same page-level
globals the footer writes — `currentCurrency`, `currencyAtRight`,
`decimal_degits`. While both read the same document that is invisible; convert
one and not the other and the displayed currency becomes a race between two
network calls. **Partial conversion was the one thing that could not be done
safely.**

### Each record in its own currency — 24 September

A customer who ordered in Cameroon and now browses from India sees that past
order **in FCFA, not rupees**. Orders carry their own `regionId`, and the order
screens now resolve currency per record rather than once per page.

The single remaining `isActive == true` query is the intentional fallback
inside the helper itself.

---

## 5. Customer subscription purchase

**This answers the question that was blocking the app developer: the web panel
owns the write. No backend endpoint exists or is needed.** The app may do the
same or call whatever it prefers, but the shape is now fixed by working code.

### Offering plans

`subscription_plans` where `planFor == "customer"` and `isEnable == true`, then
dropped if `regionIds` is non-empty and excludes the customer's region. Absent
or empty `regionIds` means sold everywhere. **A customer whose region could not
be resolved is shown every plan rather than none.**

### Paying — from the wallet

The wallet is already funded by the existing top-up flow, which carries all
twelve gateways, so buying a plan needed **no new gateway integration, only a
debit**. Card gateways can be added beside this later without changing anything
below, because what is written does not depend on how the money arrived — only
`payment_type` changes.

### What is written, in ONE Firestore transaction

All three documents are written together or none are. **The balance is re-read
inside the transaction and the purchase rejected if it moved**, so a double
click or a second tab cannot pay twice. **The app should do the same** — the
stock read-then-write pattern used elsewhere in these panels can double-spend.

```
users/{customerId}
    wallet_amount           balance - plan.price
    subscriptionPlanId      plan.id
    subscription_plan       the whole plan document, as a snapshot
    subscriptionExpiryDate  Timestamp(now + expiryDay days), or null
                            when expiryDay is "-1"

wallet/{newId}
    id, user_id, amount = plan.price, date = serverTimestamp,
    isTopUp = false, note = "Subscription purchase",
    payment_method = "Wallet", payment_status = "success",
    transactionUser = "user"

subscription_history/{newId}
    id, user_id, subscription_plan (the same snapshot),
    expiry_date (the same Timestamp or null),
    payment_type = "Wallet", createdAt = serverTimestamp
```

`subscription_plan` is a **snapshot, not a reference**, matching the vendor
flow — a later price change never alters what the customer bought.

### Reading it back

A plan counts as a customer subscription only when
`subscription_plan.planFor == "customer"`. A vendor plan on a record, or the
field absent, is never counted — **absent means vendor**.

> ⚠️ **The purchase path has never been run against a real wallet.** It is on
> the live server untested. Fund a test wallet and buy a plan before telling
> the client it works.

---

## 6. Free order-history limit

Reads `settings/OrderHistory` (`isLimitEnabled`, `freeOrderLimit`) — see
`APP-SPEC-ADMIN.md` §8. An active customer subscription whose plan has
`features.fullOrderHistory == true` lifts it.

**Applied PER TAB, not across the whole history — client decision, 24 Sep.**
The order screen has four tabs (completed, pending, rejected, cancelled) and
each shows its own most recent `freeOrderLimit` orders. Capping the combined
list leaves tabs empty, which reads as a fault rather than a limit.

**It applies only to a customer viewing their own history.** Nothing shared.

The period selector of §9 is applied in the **same funnel** as this limit, so
the two can never disagree about which orders a customer may see.

---

## 7. Address controls and routing fixes

The header address box and the delivery-address window had several faults; the
address a customer sets is what now drives §1 to §4. Also fixed: a blank page
on arrival, two broken links, and Terms / Privacy / Contact reachable without
signing in.

---

## 8. PDF order receipts — built, not uploaded

Client point 18, Document 1's *"printable and downloadable order receipts in
PDF format"*, and its *"print the receipt for a parcel/mail delivery order or
any other order"*.

`resources/views/partials/order_receipt.blade.php` holds the whole thing;
each order screen includes it and hands it the figures. jsPDF 2.5.1 with
jspdf-autotable 3.5.24 from cdnjs — the same pair and versions the admin
panel uses, loaded on the receipt screens only rather than in the shared
footer.

| Screen | Heading |
|---|---|
| Completed, pending | Receipt |
| Cancelled, rejected | **Order Summary** |
| Rental booking | Receipt, or Order Summary when the booking's own status is cancelled or rejected |

**Cancelled and rejected orders are never headed "Receipt"** — not on the
button, not in the document, not in the file name. Those orders were never
paid for, and a document headed Receipt would be passed on as though they
had been.

**The PDF is built from the strings the screen has already rendered**, not
from a second calculation. The item rows are pushed from the same loop that
builds the table. It therefore reads in the order's own currency (§4) by
construction, and a discount that did not apply is absent from both.

**The app should do the same** — take the figures from wherever the screen
got them rather than recomputing for the PDF. Two copies of the arithmetic is
how a receipt comes to disagree with the order it describes.

### Two faults fixed alongside it — 25 September

Both were introduced by §4's currency work on 24 Sep and were live for a day.

- **`orderCurrency` was out of scope for `renderTaxSection()`.** That
  function sits at the top level of each page script; the variable was
  declared inside the async fetch callback. Any order carrying tax threw
  `ReferenceError` and the screen stopped rendering there — all four order
  screens and the rental screen. Now declared at page scope.
- **Item rows still read the global currency** while the totals below them
  read the order's own, putting two symbols on one screen. The rental screen
  had the same split between its package figures and its tax lines (10 call
  sites on `getFormattedPrice`, which reads the browsing region).

> ⚠️ **Not on the live server yet.**

### Not covered

Parcel orders and bookings, which are paused. Document 1 also wants a **QR
code and a barcode (the order number)** on the parcel receipt; that belongs
with the parcel work, not here.

---

## 9. Choosing the period of history — built, not uploaded

Client point 12 asks for two things and §6 was only the first: the
subscription buys the full history **and** the ability to *"choose the month
or period for which they want to view their orders"*. This is the second.

**Entirely client side. No new field, no index, no additional read.** The
customer's order query already returns their whole history ordered by
`createdAt` descending; the period narrows what is already in memory.
`getOrders()` was split into a fetch and a `renderOrders()` that the picker
calls, so changing period never returns to the server.

| Option | Behaviour |
|---|---|
| All time | the default |
| One entry per month | **only months the customer has orders in**, newest first — an empty month cannot be chosen |
| A date span | both ends **inclusive**; either end alone is valid ("since March", "up to March") |

Applies to all four tabs at once. A span does nothing until Apply is pressed,
so a half-typed date cannot blank the list. The free-limit notice is cleared
before each redraw, or it would linger after the customer narrowed to a month
that was under the limit anyway.

### Two rules the app should match

- **Entitled customers only.** A customer on the free allowance does not get
  the picker. Offering it would let them step through their whole history
  `freeOrderLimit` orders at a time, which defeats §6 entirely. The check is
  the same `hasFullOrderHistory()` §6 uses, and it **fails open** — a customer
  is never shut out of their own orders because a lookup errored.
- **An order with no usable `createdAt` is kept, not dropped.** Hiding a
  customer's own order because its timestamp is odd reads as lost data.

### Known limitation

Month names come from the browser (`toLocaleString`), so they read in English
whatever the site language is. Translating them is an addition, not a rework.

> ⚠️ **Not on the live server yet.**

---

## 10. Open questions

**With the client:**

- [ ] **The free allowance is 5 or 8.** `Document 1 details.pdf` says "a
      maximum of 8 orders"; `Document 1 - Update and Enhancement` says "the
      last five orders". `settings/OrderHistory.freeOrderLimit` is 5. One
      field either way — but the two documents disagree.
- [ ] **One plan, one price, several currencies.** The customer plan is sold
      in Cameroon, France, Ivory Coast and Senegal and holds a single price,
      so it reads as 2000 FCFA in Cameroon and 2000 EUR in France. Either it
      is not offered outside the CFA countries, or plans need a price per
      region.
- [ ] **Should month names be translated?** See §9.

**With the app developer:**

- [ ] The app should match §5's transaction shape, including the balance
      re-read, or agree a different owner for the write.
- [ ] Service availability — the customer's location, or their account?

**Not built here, and not planned without a decision:**

- [ ] A **region picker**. Deliberately dropped — a blank badge is the settled
      behaviour for an unresolved visitor (§2).
- [ ] The **customer half of store→customer subscriptions**
      (`APP-SPEC-STORE.md` §4). Separate from §5, which is the platform's own.
- [ ] **Parcel** — paused by the client. No parcel screen is region-scoped.
- [ ] **Wholesale and retail pricing** (client point 17). Nothing in this
      panel references it, and no live product carries `wholesaleEnabled`,
      `wholesalePrice` or `wholesaleMinQty`.
- [ ] **Saved payment methods** (client point 17) — a customer keeping a Visa
      card or a mobile money account against their profile. Not started.
- [ ] **Circular home screen** with services grouped around it, and the
      service grouping by type (Online shopping & Restaurant / Transport &
      Delivery / Finance / On demand / Others). Not started.
- [ ] **Document 2** — the financial platform (tontine, loans, investment,
      insurance, KYC, MFA). Nothing of it exists in this panel. It is a
      second product, not a change to this one.
