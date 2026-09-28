# App Spec — Customer Web Panel

**Panel:** Spideli customer website (`spideli-emart-web`)
**Written:** 24 September 2026, last updated 25 September 2026
**Status:** everything below is **built and live**. All four parts of the 25
September upload list, including §10's price tiers, are on the server.

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
| 5 | Customer subscription purchase | points 12, 19 | ✅ live, **proven 25 Sep** |
| 6 | Free order-history limit | point 12 | ✅ live |
| 7 | Address controls and routing fixes | — | ✅ live |
| 8 | PDF order receipts | point 18 | ✅ live |
| 9 | Choosing the period of history | point 12 | ✅ live |
| 10 | Wholesale pricing, in tiers | point 17 | ✅ live, **tiers 25 Sep** |
| 11 | Open questions | — | — |

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

### Already subscribed — 25 September

A plan the customer **already holds and has not used up** cannot be bought
again. Its card carries a *Current plan* badge and a green border, and its
button is disabled.

| State | Card |
|---|---|
| Same plan, in date | badge, disabled button |
| Same plan, **expired** | offered again, button reads *Renew* — a fresh purchase, not a repeat |
| A different plan | purchasable, so a customer can move between plans |

"In date" is `subscriptionExpiryDate` in the future, **or absent** — absent
means a plan that never expires, not a missing one.

**The same check is repeated inside the click handler, where the money
moves.** A disabled button is a courtesy, not a guard; the app should place
its own check at the payment, not only on the control.

The screen reads the customer document **once** for the wallet balance, the
plan they hold and its expiry — so the card and the summary above it can
never describe different states.

### Naming and layout — 25 September

The screen is **"Subscriptions"**, in the account menu and on the page. It
was "Order History Plans", which named what the single existing plan happens
to do rather than what the screen is; vendor-sold product subscriptions will
land here too.

It now uses the wrapper the other listing screens use (All Stores, Dine-in,
Offers): the `d-none` mobile bar, `siddhi-popular > container > py-5`, and
`@include('layouts.nav')`. It had none of those, so the title sat against the
site header and the bottom navigation was missing.

### Proven, 25 September

The purchase was run end to end on a test account: the wallet was debited by
the plan price, `subscriptionPlanId`, `subscription_plan` and
`subscriptionExpiryDate` were written, and the screen read them back. **The
shape above is no longer only a proposal.**

---

## 6. Free order-history limit

Reads `settings/OrderHistory` (`isLimitEnabled`, `freeOrderLimit`) — see
`APP-SPEC-ADMIN.md` §8. An active customer subscription whose plan has
`features.fullOrderHistory == true` lifts it.

**Applied ACROSS THE WHOLE HISTORY — client decision, 28 Sep**, replacing the
per-tab rule of 24 Sep. A customer without a subscription sees their most recent
`freeOrderLimit` orders **of any kind**; everything older is hidden whichever
tab it would sit in. The number is **8**.

The allowance is worked out **once per render**, in `applyFreeOrderAllowance()`,
before any tab is built — so all four tabs draw from one decision rather than
four. `limitOrderHistory()` then only narrows a tab to its own statuses within
what the allowance permits.

**A tab can be empty while orders of that kind exist**, because newer orders in
other tabs used the allowance up. The client was shown this and chose it
anyway; it is the rule, not a fault.

The notice appears **only when the allowance actually hid something** — on
reaching the ninth order, in the client's words, not merely on having eight.

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

## 8. PDF order receipts

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

> **Live since 25 September.** Still not exercised against an order that
> carries tax - the case the scope fault above was breaking.

### Not covered

Parcel orders and bookings, which are paused. Document 1 also wants a **QR
code and a barcode (the order number)** on the parcel receipt; that belongs
with the parcel work, not here.

---

## 9. Choosing the period of history

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

> **Live since 25 September.** Only a subscriber sees the picker, so it
> needs an account holding a plan to exercise.

---

## 10. Wholesale pricing, in tiers

Client point 17, *"Allow wholesale and retail sales for vendors"*. **The store
panel and the admin panel built this on 15 September**; this is the customer
half. The authoritative spec is **`APP-SPEC-STORE.md` §3** in the **store**
repo's `docs/` — read that first; this section is only what this panel does.
(`app-spec-wholesale-pricing.md` was folded into it and is history now.)

**Built in two passes, both live.** 25 September morning: one wholesale price
per product. 25 September afternoon: **price tiers**. Everything below
describes the tier version; where the two differ it is called out.

### Wholesale is a second price, not a second kind of product

A product with `wholesaleEnabled` is **still sold at retail**. Nothing stops a
customer buying one. Document 1 Update asks for *"separate pricing structures
for retail **and** wholesale sales"* — both prices exist on the same product and
**the quantity decides which applies**.

**The quantity decides which price, never whether the sale is allowed.** A
**minimum order quantity** — "this product can only be bought in tens" — is a
different feature, is in no panel, and is listed under §11. So is
*Wholesale only*, which the store panel can now set and this panel ignores.

### The tiers

The client's own wording, 25 September:

> *"We want it to be possible to add different wholesale prices depending on
> the quantity. For 15 items or more, the price is 3,500. For 100 items or
> more, 2,500. For 500 items or more, 2,000."*

```
vendor_products/{id}.wholesaleTiers = [ { minQty, price }, … ]   up to 5
```

The store panel and the store app both write this list, and **both also write
tier one into the older `wholesalePrice` + `wholesaleMinQty` pair**. So this
panel reads the list where it exists and falls back to the pair where it does
not — a product saved before tiers is simply a product with one tier.

### The rule

```
retail  = the price the line already has (disPrice when set and lower,
          else price, or the chosen variant's price)

tiers   = wholesaleTiers, sorted by minQty ascending
          (or the legacy pair as a single tier when the list is absent)

unit(q) = the HIGHEST tier where q >= tier.minQty AND tier.price < retail
              ? that tier's price
              : retail
```

Per **cart line**, and `applyWholesalePrice()` in `ProductController` is the
store panel's function on this panel's cart keys. The two must resolve a line
identically or the same basket prices differently over the counter and on the
website.

**The whole line is repriced, not the units past the threshold.** 500 units at
the 500 tier is 500 × 2,000 — not 15 at one price and the rest at another.

**The cheaper-than-retail test is per tier, not a blanket skip.** A product on
promotion can have its first tier beaten by the discount while a deeper tier
still applies. Walking the sorted list forwards and keeping the last match
gives both the highest-tier rule and this one in a single pass.

**The list is re-sorted on arrival.** `normaliseWholesaleTiers()` accepts the
list as an array or as the JSON the browser posts, drops rows with no quantity
or no numeric price, and sorts them. Nothing downstream depends on the order
the browser happened to send.

#### Worked example — the client's three tiers

Retail 4,000, tiers 15 / 3,500, 100 / 2,500, 500 / 2,000. Run against
`applyWholesalePrice()` with the tiers deliberately posted out of order:

| Quantity | Unit charged | Tier |
|---|---|---|
| 1–14 | 4,000 | none — retail |
| 15–99 | 3,500 | 15 |
| 100–499 | 2,500 | 100 |
| 500+ | 2,000 | 500 |

**Downwards as well.** A line taken to 500 and then dropped to 5 returns to
4,000. A line that stayed on a tier it no longer qualifies for is the failure
this has to avoid, and it is the case worth testing twice.

**With a discount of 3,000 on the same product:** 20 units pay 3,000 — tier one
is not cheaper, so it is skipped — while 120 units still pay 2,500 and 600
still pay 2,000.

#### Worked example — the single-price product, 25 Sep

`Veggie Burger`: price 150, `disPrice` 0, wholesale 120 from 10, admin
commission 15%.

| Quantity | Unit charged | Why |
|---|---|---|
| 1–9 | ₹172.50 | 150 + commission. `disPrice` is 0, so it is ignored |
| 10+ | ₹138.00 | 120 + commission |

With `disPrice` set to 130 instead, 1–9 charge ₹149.50 and 10+ still charge
₹138.00.

#### The case that looks wrong until you know the rule

A wholesale price that is **not actually cheaper** than the price the line
already has is ignored, so **buying more can never cost more**. With `disPrice`
at 110 (₹126.50) against a wholesale price of 120 (₹138.00), a customer buying
ten keeps ₹126.50.

The store panel refuses to save a wholesale price above `price`, but it cannot
see a `disPrice` added afterwards — which is why the comparison lives in the
cart as well as in the form.

### Where it is applied

| Place | What happens |
|---|---|
| `processVendorData` (footer) | builds `wholesale_tiers` with the admin commission on **every** tier, sorted, and lines the legacy two fields up with tier one |
| `addToCart` | the whole tier list travels with the line, and the line is priced |
| `changeQuantityCart` | **the line is re-priced**, up and down the ladder. It previously wrote the quantity and left the price alone |
| `products/detail` | the tier in force and the next one up, **tracking the quantity box** — see below |
| Six listings | a badge for the **entry** tier: product list, new arrivals, search, the store page, both home screens |
| `vendor/cart_item` | a line charged at a tier says so, and **names the tier** — a line of 500 reads "from 500 units" |
| `checkout` | `isWholesale` and `wholesaleMinQty` on the order line, `wholesaleMinQty` being the tier **actually applied** |

Two helpers in `layouts/footer.blade.php` — `wholesaleTierFor(tiers, qty,
retail)` and `nextWholesaleTier(tiers, qty)` — are the browser's copy of the
server rule. They exist so the page and the cart cannot drift in wording while
agreeing in price.

### The note on the product page

`updateWholesaleNote()` redraws under the quantity box on every change of
quantity and on every variant selection:

| Where the customer is | Note |
|---|---|
| Below the first tier | `Wholesale 3,500 from 15 units · add 14 more` |
| On a tier, with a better one above | green `Wholesale price applied - 3,500 each`, then `Wholesale 2,500 from 100 units · add 85 more` |
| On the deepest tier | green only — there is nothing left to offer |

**The step up is shown whether or not a tier is already running.** A customer
on the 15 tier should still be told what 100 would cost them; that is the whole
point of a ladder. It is suppressed only when the next tier is not actually
cheaper than what they are paying now.

A badge that never changed announced an offer the page then appeared not to
honour — the customer set the quantity to ten and the price above it did not
move, so the tier read as decoration until the cart. The server still decides
what is charged; this only reports where the customer stands.

**It must be declared at the top level of the page script.** It was first placed
beside the `.add-to-cart` handler, which sits *inside* `$(document).ready(...)`
despite its indentation, so `getProductDetail()` could not see it and the whole
screen stopped rendering at that point. Indentation in these views does not
track scope.

### Wholesale details under the description

`wholesaleDetails` on the product — **HTML**, written with the store panel's
editor — is rendered under the product description when the product has a
wholesale tier and the field says something. It is where a store puts a price
table, minimum order terms or packaging notes.

**It is rendered as HTML, and sanitised first.** A price table is the point of
the field, so escaping it would leave the buyer reading tags; but it is typed in
another panel, so `safeWholesaleDetails()` strips `script`, `iframe`, `object`,
`embed`, `link`, `style` and `form` tags, every `on*` attribute and every
`javascript:` URL before it goes near the page. Parsing into a detached element
executes nothing by itself, which is what makes stripping before insertion
effective rather than too late.

A store account must not be able to run code in a customer's browser. **The app
should do the equivalent** rather than handing the string to a raw HTML widget.

### Fixed on the same screen — not wholesale

Product addons rendered their price with a hardcoded `$`:

```js
' <span class="">+$' + FINAL_ADDON_PRICE + '</span>'
```

Every addon of every product in every currency, sitting next to a rupee price on
the same row. Now `getProductFormattedPrice(...)`. Stock behaviour.

### Two things worth knowing

**Every tier goes through the admin commission**, in `processVendorData()`,
exactly as `price` and `disPrice` do. Without that a bulk line would quietly
skip the platform's cut, and the larger the order the more it would skip — so
the deepest tier would skip the most.

**The order needs no new field for the money to be right.** `discountPrice`
carries the price actually charged, and every reader — the order screens, the
PDF receipt of §8, the admin order view, the app — already prefers it when set.
`isWholesale` is recorded so a wholesale sale is not mistaken for a discount
later.

### A variant has one price, not a ladder

A variant can carry `variant_wholesale_price`, and it is a single price. Where a
variant has one it **replaces** the product's tiers for that variant rather than
layering on top — charging a variant at a product tier it never offered would be
wrong. The variant's price is kept at the product's entry quantity, so it
behaves exactly as it did before tiers existed.

Whether variants should get tiers of their own is open (§11).

### Nothing breaks that worked before

- **A product with no tier list** falls back to `wholesalePrice` +
  `wholesaleMinQty` as the single tier it is. Those products price exactly as
  they did after the morning's upload.
- **A cart already open** when the files go up has no tier list on its lines.
  It falls back the same way. No cart is emptied and no price jumps.
- **The listing badges** read the older two fields, which the store panel keeps
  aligned with tier one. They needed no change and keep advertising the entry
  offer.

### Known gap — `saleType` is stored and ignored

The store panel can mark a product **Retail only / Retail and wholesale /
Wholesale only**, written as `saleType`. **This panel does not read it.** A
product marked *Wholesale only* is still shown and sold at retail to anyone.

What it should do — hide the product, block small quantities, or require a
business account — is a client question, not a developer's, and it is in §11.

### Sale type — sold only in packs

`saleType` on the product: `retail`, `wholesale` or `both`. Absent, empty or
unrecognised means `both`, which is how this panel behaved before the field
existed, so no older product changes.

`wholesale` means **not sold singly**. The floor is the **entry tier** — the
cheapest quantity that unlocks a wholesale price, not the deepest.

| Where | What holds the floor |
|---|---|
| Product page | the quantity box opens at the minimum; the stepper will not go below it; a typed quantity is corrected on blur |
| `addToCart` | `enforceSaleTypeQuantity()` raises a low quantity rather than trusting the request |
| `changeQuantityCart` | the same, and **zero still removes the line** |
| Product page, cart line, listing badge | "Sold in a minimum of N units" |

**The floor is enforced on the server, not only in the box.** The quantity box
is a courtesy; the request is what decides.

**Zero must keep removing the line.** A customer who cannot buy five of
something sold in tens is the store's decision; a customer who cannot get it
out of their cart is a fault.

### Verified

`applyWholesalePrice()`, `saleTypeMinimum()`, `enforceSaleTypeQuantity()` and
`normaliseSaleType()` are exercised directly through reflection — 29 checks
covering tier selection at 1 / 9 / 10 / 49 / 50 / 500, a discount that undercuts
every tier, a legacy product with no tier list, the pack floor for each sale
type, and the normalisation of junk values. The browser side has not been driven
with a wholesale-only product; no live product is set to one.

### Known gap — reorder

Reorder rebuilds a cart from a past order and carries that order's prices, so a
wholesale price carries over. It does **not** carry the tier, so changing the
quantity on a reordered line will not re-evaluate it. The reorder payload has no
wholesale price to pass and fetching the product again is a different change.

### Tested — 25 September

**The single-price version, end to end and live:** exercised against a real
product (Veggie Burger: 150 retail, 120 from 10 units, 15% commission →
₹172.50 and ₹138.00) — the listing badge, the product page note counting down
and turning green, add to cart, and the cart repricing in both directions.

**The tier version, logic verified before upload.** The resolution rule was run
directly against `applyWholesalePrice()` and covers: the client's three tiers
with the list posted out of order, every boundary (14/15, 99/100, 499/500), the
fall back to retail when a line drops from 500 to 5, a legacy-pair-only
product, rows with a missing quantity or a blank price, and a discount that
undercuts tier one while deeper tiers still apply. All correct.

**Not exercised by me on the server:** the browser side — the product-page
note, the cart badge and the saved order — against a real product. The steps
for that are in Part 4 of the 25 September upload list.

---

## 11. Open questions

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
- [ ] **What should "Wholesale only" do to a retail customer?** The store panel
      writes `saleType` as of 25 September and this panel ignores it, so such a
      product is still sold at retail to anyone. Hide it, block small
      quantities, or require a business account — it changes what a customer
      may buy, so it needs the client's word (§10).
- [ ] **Should variants have tiers of their own?** A variant carries one
      wholesale price today, and where it has one the product's tiers do not
      apply to it. Raised 25 Sep with the tier work (§10).
- [ ] **Do variants of one product aggregate toward the wholesale threshold?**
      6 of the 5kg variant and 6 of the 10kg — 12 units against a threshold of
      10, or two lines of 6 that both stay retail? This panel treats each line
      separately, matching the store POS. Open in the wholesale spec since 15
      Sep.
- [ ] **Does wholesale stack with coupons and special offers?** This panel
      applies both, as it does for any other line. Also open since 15 Sep.
- [ ] **Is a minimum order quantity wanted?** Raised 25 Sep looking at the live
      test product. Today a wholesale product is still sold singly, which is
      what Document 1 asks for — wholesale *pricing*, not wholesale-only
      *selling*. If the client wants "this product only in tens", that is a new
      `minOrderQty` field on the product, the store and admin item forms, the
      quantity box, a guard in the cart (where the quantity can be lowered) and
      the app. It changes what a customer may buy, not what they pay, so it
      needs the client's word rather than a developer's.

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
- [ ] **Saved payment methods** (client point 17) — a customer keeping a Visa
      card or a mobile money account against their profile. Not started.
- [ ] **Circular home screen** with services grouped around it, and the
      service grouping by type (Online shopping & Restaurant / Transport &
      Delivery / Finance / On demand / Others). Not started.
- [ ] **Document 2** — the financial platform (tontine, loans, investment,
      insurance, KYC, MFA). Nothing of it exists in this panel. It is a
      second product, not a change to this one.
