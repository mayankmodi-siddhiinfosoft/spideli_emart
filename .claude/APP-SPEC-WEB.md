# App Spec — Customer Web Panel

**Panel:** Spideli customer website (`spideli-emart-web`)
**Written:** 24 September 2026, last updated 30 September 2026
**Status:** everything below is **built and live**, including all five parts of
the 30 September upload — the business-account gate, the product's business-only
flag, and the variant pricing fixes that went up alongside the store and admin
panels.

**A page render is part of checking this panel.** `php artisan view:cache`
compiles views without executing them, so a Blade fault survives it — a `{{ }}`
written inside a *JavaScript comment* in `layouts/footer.blade.php` compiled
cleanly and took every page down on 28 September, because the footer is on all
of them. After touching a shared view, serve a page and look at the body.

**Live but never exercised in a browser**, and worth clearing in one sitting:
the PDF receipt on an order carrying **tax** (§8), a **wholesale-only** product
(§10), **payment methods by region** on checkout (§12), the **top-up → subscribe**
return path (§11) and the two **purchase emails** (§13).

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
| 10 | Wholesale pricing, in tiers | point 17 | ✅ live; **variant ladder fixed 30 Sep** |
| 11 | Store-sold subscriptions | point 19 | ✅ live |
| 12 | Payment methods by region | point 2 | ✅ live |
| 13 | Subscription purchase emails | — | ✅ live |
| 14 | Service groups on the section list | page 9 | ✅ live |
| 14a | The Document 2 services, and a redirect loop | page 9 | ✅ live, **no icons yet** |
| 15 | Parcel receipt, QR code and public tracking | points 16, 18, 22 | ✅ live |
| 16 | Business account application | — | ✅ live |
| 17 | Saved payment methods — mobile money | point 10 | ✅ live |
| 18 | The footer sweep — unguarded Firestore reads | — | ✅ live |
| 19 | Wholesale for approved business accounts only | point 17 | ✅ live |
| 20 | Open questions | — | — |

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

### A variant shifts the ladder, it does not replace it — 30 September

**This was wrong until 30 September and customers were overcharged.**

`variant_wholesale_price` is that variant's **tier-one** price, not its only
price. The product's tiers own the quantity breaks and the steps; the variant
shifts the ladder to start at its own figure — `variantWholesaleTiers()` in
`layouts/footer.blade.php`.

```
product tiers      10 -> 949    50 -> 849    150 -> 749

variant blank   =>  949   849   749     the product's ladder, unchanged
variant 949     =>  949   849   749     identical - the commonest case
variant 999     =>  999   899   799     fifty more, throughout
```

Steps are **differences, not ratios**. A tier that would fall to zero or below is
dropped rather than clamped.

**Read as "this variant's only price" it destroyed the ladder**: a product with
tiers at 10/50/150 charged the entry price at every quantity once sizes existed.
Reported live — 50 of the tiered kurti charged 959 instead of 859. The store
panel's item form *required* a figure on every variant, so no store could
configure it correctly.

**No product needed re-entering.** A variant carrying the product's own tier-one
price — which the panel obliged everyone to enter — resolves to the identical
ladder.

**The same function exists in the store POS and the admin POS.** All three must
agree or the same basket costs a different amount depending where it is rung up.

### A size that cannot make up a pack says so — 30 September

Found looking at the above, not reported.

A wholesale-only product opens its quantity box at the entry tier. If the chosen
size has **less stock than that minimum**, every route out is a dead end — the
box will not go lower and the stock will not go higher — and add-to-cart failed
with `invalid_stock_qty`, which says nothing about which size is short or that
another would work. The size was silently unbuyable.

Now the note turns red, names the shortfall, and **disables Add to Cart and Buy
Now** until a workable option is chosen. The page also stops advertising a tier
the chosen size cannot physically reach — 60 left in a size, and "749 from 150
units, add 90 more" was an invitation into a stock error.

### A wholesale-only product shows a price a customer can pay — 30 September

The kurti's page read **₹1,509.00** — its retail price. The product is sold only
in wholesale quantities, so a single piece is not for sale at any price, and the
real figure sat further down in the wholesale notes.

It now shows the **entry tier**, per selected size, with the minimum beneath it:

```
₹959.00
per piece, from 10 units
```

`wholesaleHeadlinePrice()` for products without variants,
`variantWholesaleHeadline()` for the selected variant. **Retail and mixed
products keep their retail headline** — there that figure is honest, so the
check is on `saleType === 'wholesale'` alone.

> **Listing cards still show the retail price** for wholesale-only products,
> with the wholesale price as a badge beside it. Less misleading than the
> product page was, because the badge is right there, but not consistent. It is
> seven screens rather than one, so it is a decision rather than a reflex.

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

## 11. Store-sold subscriptions

Client point 19, the restaurant selling a monthly bread delivery. **The store
and admin panels have had this since before this panel existed**; a vendor
could create a plan and nobody could buy it. This is the customer half.

The authoritative spec is `APP-SPEC-STORE.md` §4 in the **store** repo's
`docs/`. Read that for the field shapes; this section is what the website does.

### It must not touch the platform's own subscriptions

This is the **third** subscription system:

| System | Collection | Who sells |
|---|---|---|
| Platform → vendor | `subscription_plans`, `planFor: "vendor"` | Spideli |
| Platform → customer (§5) | `subscription_plans`, `planFor: "customer"` | Spideli |
| **Store → customer** | `vendor_subscription_*` | a store |

**Nothing is written onto the customer document beyond the wallet debit.**
`subscriptionPlanId`, `subscription_plan` and `subscriptionExpiryDate` belong to
§5. A customer can hold a platform history plan and a bakery's bread plan at the
same time, and one pair of fields cannot hold both — so a store plan writes its
own row in `vendor_subscriptions` instead.

### Where the customer meets it

`resources/views/partials/store_subscriptions.blade.php`, included by the store
page above the products. A store with no plans renders nothing — which is every
store today.

- `isEnable` true, `vendorID` this store, and dropped when the plan's
  `regionId` is set and differs from the customer's region. No `regionId`, or no
  resolved region, shows it rather than hiding the store's own offer.
- Priced in **the store's** region currency, not the browsing region's.
- Plan points are listed, so the customer sees what they are buying.

### Paying — any method the region carries

Two routes, both ending in the same transaction:

| Route | What happens |
|---|---|
| **Wallet**, when the balance covers it | bought outright |
| **Any other method** | the plan is remembered, the customer goes to the wallet top-up with the amount pre-filled, pays by any gateway §12 allows, and the subscription **completes by itself** on the way back |

**Only the shortfall is topped up.** 2,000 in the wallet against a 2,500 plan
asks for 500.

**Why not the gateways on the subscription screen.** Every payment screen in
this panel carries its own copy of all twelve integrations — checkout, parcel,
rental, gift cards, on-demand, extra charge, service charge. A subscription
screen would have been the eighth, each gateway untestable without live keys for
it. Routing through the top-up reuses twelve that already work, and the customer
still picks any method their region carries. **Client decision, 28 Sep.**

`completePendingStoreSubscription()` in the footer finishes the job, called from
`transactions/success.blade.php` after the wallet row is written — so the
balance the purchase re-reads is the credited one.

**Three things stop a wrong charge:**

- **The price is re-read at completion**, never taken from the saved intent. If
  the store changed it while the customer was paying, nothing is bought and they
  are told. Charging a price they never agreed to is worse than asking them to
  press the button again.
- A plan **switched off or deleted** in the meantime buys nothing, same reason.
- An intent **older than an hour** is dropped, so someone who wandered off
  mid-payment is not charged tomorrow.

**The money is never at risk.** Every failure after payment leaves it in the
wallet, and every message the customer sees says so.

### The write

One transaction with the balance re-read inside it, the same shape §5 uses. Four
writes, all or none:

```
users/{customerId}                    the debit, and nothing else
wallet/{new}                          the customer's own ledger line
vendor_subscriptions/{new}            the Subscribers tab in both panels
vendor_subscription_payments/{new}    the Payments tab in both panels
```

`plan` on the subscription is a **snapshot**, because the store panel reads
`subscription.plan.title` — a store renaming or deleting a plan must not change
what an existing subscriber is shown.

### The commission is deducted, not added

Document 1: *"The application's commission must also be deducted from this
service."* The customer pays the store's price and the platform's cut comes out
of it — **the opposite of a product**, where the commission is added on top.

The rate is the store's own `adminCommission` when it has one, otherwise the
section's, and zero when commission is switched off. It is **capped at the
price**, so a fixed cut larger than a cheap plan cannot hand the store a
negative earning, and it is written onto the payment rather than re-derived
later.

### Seeing what you hold

The **Subscriptions** screen lists everything the customer holds from any store,
expired and cancelled ones included — someone asking what happened to their
bread delivery needs to see that it ran out. The plan details come from the
snapshot; only the store's name is looked up.

### Not covered

**No fulfilment.** Buying a bread subscription records the subscription and the
payment; nothing creates the daily deliveries. That is how the store panel was
built and it is flagged provisional there — the client's *"to deliver bread to
customers' homes"* reads like recurring delivery, which is a much larger feature
and has never been confirmed. **Worth settling before this is shown to them.**

**No cancellation from the customer side**, and **no renewal reminder** — a
lapsed subscription simply stops counting and nobody is told. A scheduled job to
expire subscriptions and notify both sides is specced in
`app-spec-subscription-expiry.md` in the admin repo's `docs\`. It is not needed
for correctness — entitlement is worked out from the date on every read — but it
is the only way anyone finds out.

> **Live since 28 September, and not exercised** — no store has created a plan,
> so nothing on the site can reach it until one does.

---

## 12. Payment methods by region

Client point 2 — *"Ability to define available payment methods by region or
country"*. The admin panel has offered `regionIds` on each gateway settings
document for some time. **This panel was ignoring it entirely**: every screen
revealed a gateway on `isEnabled` alone, so the setting had no effect on a
customer.

### Enforced once, not in 109 places

Nine screens offer gateways — checkout, wallet top-up, gift cards, parcel, two
rental screens, on-demand, extra charge, service charge — with **109 places
between them** that reveal one. `enforcePaymentMethodRegions()` in the footer
applies the rule once, on ready, by **removing** the options the region excludes.

**Removal is what makes the ordering safe.** Each screen reveals its gateways
inside its own Firestore callback, so there is no reliable moment "after" them;
but `$('#x_box').show()` on an element no longer in the document quietly does
nothing. Removing early and removing late both end with the option gone.

| | |
|---|---|
| `regionIds` empty or absent | offered everywhere — the same rule sections and plans use |
| Region unresolved | every method shows, as every store shows |
| Settings document unreadable | **fails open**, the method still shows |

Failing open is deliberate: a method that turns out not to apply is a failed
payment, while hiding them all is a customer who cannot pay at all.

The twelve documents are `CODSettings`, `walletSettings`, `razorpaySettings`,
`stripeSettings`, `paypalSettings`, `payFastSettings`, `payStack`,
`flutterWave`, `MercadoPago`, `xendit_settings`, `midtrans_settings` and
`orange_money_settings`.

> **Live since 28 September.** It changes **checkout**, not only subscriptions:
> a gateway with regions set is now genuinely hidden from customers outside
> them. If a customer reports a missing payment method, check that gateway's
> regions before treating it as a fault.

---

## 13. Subscription purchase emails

Two templates in the admin panel's **Email Templates**, edited by the client
like the other nine rather than written into the code:

| `type` | Goes to |
|---|---|
| `subscription_purchased` | the customer |
| `subscription_purchased_admin` | the admin |

Sent for **both** subscription systems — the platform's own order-history plan
(§5) and a plan a store sells (§11) — including the top-up route, because that
completes through the same function.

### Placeholders

`{username}` `{customeremail}` `{planname}` `{plantype}` `{storename}`
`{price}` `{paymentmethod}` `{expirydate}` `{date}`

`{storename}` is empty for the platform's own plan, which no store sells. A
token with nothing behind it is emptied rather than left showing as `{price}`.

### Two rules

**Sent after the transaction commits, never inside it.** The money has already
moved; a mail failure must not roll anything back or make a successful purchase
look failed. Every path is wrapped — a missing template, a missing address or a
failed send is logged and dropped.

**A missing template means no email**, not a hardcoded English one, which would
ignore the client's wording and go out in the wrong language.

### The admin address stays server-side

`SendEmailController::sendMail` takes a `to_admin` flag and addresses the mail
from `MAIL_TO_ADDRESS` itself. The browser asks for the admin to be mailed; it
is never told the address. Putting it in the page would publish it in the page
source and let anyone post mail at it.

**With no address configured the admin copy is skipped**, and the customer's own
email still goes. Neither the email nor the purchase may depend on that setting
being filled in.

### Seeding, because there is no create screen

The admin panel's Type field is read-only and it has no "create template"
screen — the original nine were seeded with the product. So the Email Templates
index creates any expected template that is missing when it opens. **Idempotent:
a type that already exists is left exactly as it is, wording included.**

### Worth knowing

`isSendToAdmin` exists on every template document and **nothing has ever read
it** — not the admin panel, not this one. It is decorative. Two templates were
built instead, which also gives each audience its own wording.

### Not covered

**No email when a subscription expires.** Nothing runs when nobody is looking;
that needs the job in `app-spec-subscription-expiry.md`.

> **Live since 28 September.** Two things to confirm on the server, neither
> visible in code: that **Email Templates has been opened once** (that is what
> creates the two rows, 9 → 11), and that **`MAIL_TO_ADDRESS` is set** — it is
> empty in the local `.env`, and without it the admin copy is skipped silently.

---

## 14. Service groups on the section list

Document 1 page 9: services presented in groups — *Online shopping &
Restaurant*, *Transport & Delivery*, *Finance*, *On demand services*, *Others*.
**The admin panel has offered this since 21 September**; this panel read neither
field, so the grouping the client set up was invisible.

Spec: `app-spec-service-groups.md` in the admin repo's `docs/`.

### Where

The section list — the "Select Section" modal, in both places it appears: the
one that opens by itself when no section is chosen, and the one the customer
opens from the header. **Both were building that list separately**, with
near-identical code; they now share `renderSectionList()`.

### The rules

| | |
|---|---|
| Groups | `service_groups`, `publish === false` dropped, ordered by `order` |
| Membership | `sections.serviceGroup` holds a group id, or `""` |
| **The five are not hardcoded** | they are only what the admin panel seeds; the client renames, reorders, adds and unpublishes them |
| Region | applied **first**, grouping second — a service not offered where the customer is appears under no heading |

### Three decisions, provisional until the client says otherwise

The spec left two of these open. They are answered here by what the code does,
and either can be changed in one line.

**An ungrouped service goes under "Others" — corrected 29 Sep.** This shipped on
28 Sep listing them first with no heading, which was wrong: the answer was
already settled with the client and recorded in the admin repo's
`MESSAGES-AND-QUESTIONS-LOG.txt` — page 9 lists Others as one of their own five
groups. Only when Others itself has been deleted or unpublished does such a
service fall to the top with no heading, so it is never lost. (Spec question 1,
closed.)

**An empty group is not drawn.** A heading with nothing beneath it reads as a
fault. Finance will be empty until such services exist. (Spec question 2.)

**A section pointing at a deleted or unpublished group is treated as
ungrouped**, not dropped. Never hide a service because of a setting on
something else.

### Degrading

No `service_groups` collection, or a failed read, gives the flat list this panel
has always shown — never an empty screen.

### Not covered

**The circular home screen** of `Spideli_upgrade.docx` #20. Page 8 shows a
"More" button opening a dropdown, which reads like the same screen as page 9 —
spec question 5 asks the client to confirm whether they are one feature or two.
This is the grouping half only, and it is the half that needed no mockup.

### The modal had to change with it

Five headings on top of twelve tiles outgrew the window, which had always sized
itself to its content.

**Bootstrap's `modal-dialog-scrollable` is the wrong tool here** and was tried
first. Alongside `modal-dialog-centered` it sets `max-height: calc(100% - 1rem)`
against the centred `min-height: calc(100% - 1rem)`, pinning the dialog to
exactly the viewport height — it fills the screen top to bottom and looks stuck
to the bottom edge.

The dialog stays **centred**, as it always was, and `#select_store_model
.modal-body` is capped at `65vh` with `overflow-y: auto`. The heading and close
button stay put while the list scrolls, and it adapts to the screen rather than
to a pixel height.

The rule lives beside the modal in `layouts/footer.blade.php` rather than in
`public/css/style.css`, which is theme-supplied and may be replaced.

> The theme already carries `#select_store_model .modal-dialog { max-height:
> 800px }`, which cannot scroll anything on its own — presumably why the list
> overflowed before. Left alone, but it is dead weight.

---

## 14a. The Document 2 services, and the redirect loop they exposed

Document 1 page 9 lists **Tontine, Loan and Investment** under Finance and **AI
Assistant** under Others. All four are **Document 2** features and exist in no
panel, so the two groups were empty and hidden.

The client asked for them anyway, on 28 September. They now exist, and the
honest way to carry them needed three things.

### Four new service types

`services` had six entries and **no admin screen** — it is seeded product data,
so these were written straight to Firestore, shaped like the existing six
(`{id, name, flag}` and nothing else):

| name | flag |
|---|---|
| Tontine Service | `tontine-service` |
| Loan Service | `loan-service` |
| Investment Service | `investment-service` |
| AI Assistant Service | `ai-assistant-service` |

They appear in the admin's Service Type dropdown with no upload, because that
form reads the collection live.

### A screen that says what is true

`home_page/coming_soon_home.blade.php` names the service the customer tapped —
"Tontine", not something generic, taken from the `section_name` cookie — says
it is not open yet, and offers a way back to the section list. Without that last
part the customer is stranded on an empty screen.

### The loop it exposed

`HomeController::index()` sent **any** unrecognised `service_type` to
`set-location`. That was harmless while every type had a screen. It stops being
harmless the moment a type exists without one: the customer picks the service,
lands here, is sent back to choose, picks it again, and **loops** with no way
out but choosing something else.

Now an unknown type gets the coming-soon screen. **An empty `service_type` still
goes to `set-location`** — that is someone who has chosen nothing at all, which
is a different thing.

> **Also worth knowing:** `services` populates the driver filters in the admin
> panel, so four odd-looking options appear there. Harmless.

### When a feature lands

Give its type its own view in `HOME_VIEWS` and delete its coming-soon entry.
Nothing else needs to change — the section, its group and its type all stay.

> **Live since 28 September.** All five groups from page 9 now show, with the
> four new services under Finance and Others. **They have no images yet**, so
> they render as blank tiles until someone supplies four 82×82 PNGs with
> transparent backgrounds, ideally from one icon set.

---

### The Select Sections window opened empty from anywhere but one button

Reported 29 Sep. `renderSectionList()` was bound to a **click on
`#select_store_model_call`** — the right-hand "Select Section" tab — rather
than to the modal it fills. Any other trigger of `#select_store_model` opened it
empty, which is what the *Choose another service* button on this screen did, and
what anything added later would have done.

It now loads on the modal's own **`show.bs.modal`**, bound **twice on purpose**:
this theme carries Bootstrap 4 *and* 5, and BS4 fires that event through jQuery
(invisible to a native listener) while BS5 dispatches a real DOM event
(invisible to a jQuery handler). The click binding is kept as well — it is
triggered programmatically for a visitor arriving with no section, and it is the
one path that does not depend on either Bootstrap handling the modal.

With three handlers now able to fire in one tick, the old
`container.html() != ''` test was no longer enough: each one awaits, and the
first await returns to an equally empty container, so all three would query
Firestore and draw the list three times. `renderSectionList` now holds an
in-flight flag and delegates the drawing to `drawSectionList`.

**Verified in a browser** against the running panel: from the coming-soon
button, 12 services under all five headings; after a reload, the same list from
the right-hand tab; 17 child nodes either way, so nothing is drawn twice.

---

### Three unguarded Firestore reads in the shared footer

Reported 29 Sep: saving a delivery address failed with *"Cannot read properties
of undefined (reading 'data')"*, and the header showed neither an account name
nor a Sign in link. **One root cause, and a third fault found beside it.**

All three are the same shape — **a Firestore document read and used without
checking it came back** — and all three are in `layouts/footer.blade.php`, which
is on every page, so one missing record costs the whole header rather than the
one feature that wanted it.

| Where | Was | Now |
|---|---|---|
| `saveShippingAddress` | `userSnapshots.docs[0].data()` on an empty result, inside a `.then` with **no `.catch`** — an unhandled rejection, and the address silently not saved | falls back to `saveShippingAddressToCookies()`, which is what the signed-out path always did and what every screen actually reads the address from |
| the account button | guarded, so it appended nothing — and an empty `dropdown-toggle` has nothing to click. Blade already knew the visitor was signed in, so no Sign in link either | labels the button "My Account" with the placeholder avatar, so the menu stays reachable |
| `sections/{cookie}` | `sectionRef.data().adminCommision` on a section that no longer exists | guarded; logs and carries on |

**`cuser_id` and `user_uuid` both come from MySQL** (`VendorUsers.uuid`) while the
document they name lives in Firestore, so the two can disagree — most easily by
**deleting the customer in the admin panel while they are still signed in**.
That is the likely origin of the reported case; the code no longer breaks, but a
deleted record is not restored.

The section read is the worst of the three: the cookie lasts a **year** and the
read sits **near the top of the ready handler**, so a section deleted in the
admin panel would blank the header on every page for anyone who had used it.
Not reported — found while looking at the other two.

**Verified in a browser** against the running panel: signed-out save writes the
cookies and reloads; a signed-in save with a deliberately unmatched `cuser_id`
now saves to cookies and reloads instead of throwing.

> **This shape of fault remains elsewhere in the same file** — several more
> `.data()` and `docs[0]` reads are unguarded. Not swept, deliberately: broad
> edits to the footer are how the whole site went down on 28 Sep. Fix on sight,
> or schedule a sweep with testing time set aside.

---

## 15. Parcel receipt, QR code and public tracking

Document 1 points **16** (*"Generate a QR code for each delivery order and
enable tracking"*), **18** (*"print the receipt for a parcel/mail delivery
order"*) and **22** (*"a barcode (which is the order number)… present along with
the QR code on the order receipt"*).

**Parcel is formally paused** (14 Sep) and two of its four parts stay blocked:
pickup points exist nowhere, and the rate tables cannot be built while the
client's weight bands overlap (`0.1–500g` then `5.1g–2kg`, asked and
unanswered). **This part depends on neither** — no pricing answer can invalidate
a receipt or a tracking page.

### The receipt

`partials/order_receipt.blade.php`, the same one §8 uses, now draws a QR code
and a barcode **when the screen supplies them**. Every other order screen leaves
them unset and is unchanged.

| | |
|---|---|
| Barcode | **is the order number**, per Document 1. CODE128, with the number printed beneath for anyone keying it by hand |
| QR | the **public tracking URL**, so scanning reaches tracking rather than a bare number |
| Libraries | `JsBarcode` and `qrcodejs` from cdnjs, beside jsPDF, loaded only where the partial is included |

**Both are drawn last.** If either library fails the customer still gets the
whole receipt — a receipt without a barcode beats no receipt.

### One structural change

The receipt was built for screens showing **one** order and filling a single
global. Parcel orders is a **list**, so its button carries `data-receipt-id` and
the page exposes `window.resolveOrderReceipt(id)`. The three status tabs each
hand their already-computed figures to one recorder, so the arithmetic is not
repeated a fourth time.

### The public tracking page

`ParcelTrackingController` + `parcel/tracking.blade.php`, at
`track-parcel/{id}`.

**The person scanning is the receiver, not the customer** — no account, no
delivery address, and no reason to make either before finding out where their
parcel is. So:

- **No auth middleware and no `requireLocation()`.** `ParcelController` has
  both, which is why this is a separate controller.
- The route name is **also on `LOCATION_EXEMPT_ROUTES`**, so a later change
  there cannot start redirecting a stranger to "set location".
- **Standalone page** — no header, no nav, no footer. The footer opens the
  "choose your location" window at any visitor without an address, and loads
  the whole shop; neither belongs in front of someone checking a parcel at the
  door.
- The Firebase config comes from cookies set in `AppServiceProvider::boot()` on
  **every** request, so a first-time visitor has it before the page's scripts
  run.

### The progress bar

Five steps, mapped from the order's own statuses:

| Step | Statuses |
|---|---|
| Order registered | `Order Placed` |
| Accepted | `Order Accepted`, `Driver Pending` |
| Picked up | `Driver Accepted`, `Order Shipped` |
| In transit | `In Transit` |
| Delivered | `Order Completed` |

`Driver Pending` sits under Accepted rather than getting a step: from the
receiver's side nothing has happened, and a marker meaning "we are looking for
someone" is not worth one.

**A cancelled or rejected parcel shows no bar at all.** A half-filled bar beside
"Cancelled" reads as though it is still coming. An unmapped status leaves the
parcel at step one rather than at none.

### What the page deliberately does not show — needs the client's word

The link is public to anyone holding it, and a parcel receipt can be
photographed, forwarded or left in a box. So the page shows the **last part of
the address** rather than the whole of it, and the **last four digits** of the
phone rather than the number — enough for the receiver to recognise their own
parcel, not enough to be worth harvesting.

The reference screenshot the client sent shows a full address and phone, but
that page is reached from an email to the customer, not from a QR on a printed
label. **If they want the full details shown, it is a two-line change** — but it
should be their decision, on the record.

> **Live since 29 September.** The page loads publicly (200, no redirect, no
> session). **Not yet exercised with a real parcel**: the QR and barcode have
> not been seen in a produced PDF, and the scan has not been tried on a device
> that has never used the site — which is the case the feature exists for.

---

## 16. Business account application

**The customer half of `APP-SPEC-ADMIN.md` §18.** The mobile app has written
these requests since 24 September; the admin panel has been able to decide them
since 29 September. **The website was the only side with no way in at all** — a
customer who does not use the app could neither apply nor find out what had
become of an application made from it.

Route `business-account`, `BusinessAccountController`,
`users/business_account.blade.php`. Linked from the account menu and the header
dropdown, beside My Account.

### The record

**Every field shape is fixed by working code** — the app that writes them and
the admin screen that reads them. Nothing here is invented.

```
users/{uid}
    accountType: "business"
    businessProfile: {
        companyName, registrationNumber,
        documentUrl,                    Firebase Storage
        submittedAt,                    ISO STRING, not a Timestamp
        status: "pending"
    }
```

The document uploads to `business_documents/{uid}/{uuid}.{ext}`, with a fresh
uuid each time — a file named after the company would otherwise be guessable
from another account. Images and PDFs, 5 MB.

### What the customer sees

| State | Screen |
|---|---|
| never applied | the form |
| `pending` | "being reviewed", with what they sent. No form |
| `approved` | a green tick and their details. No form |
| `rejected` | **the admin's reason, in full**, and the form again, prefilled |

**A refusal without its reason is the whole point of showing state at all.** A
customer told only "no" simply applies again, unchanged, and the admin gets the
same request twice.

A profile carrying no `status` reads as **pending**: the request exists, so
something is awaiting a decision either way.

### Three rules this screen keeps

**It never decides.** It writes `status: "pending"` and nothing else — never
`approved` or `rejected`, and never `reviewedAt` or `reviewedBy`, which belong
to the admin panel alone.

**It writes `businessProfile` as a WHOLE MAP, the opposite of the admin
panel's dotted paths.** The admin writes one field and must not erase the
evidence around it. This write *supplies* all of that evidence, and replacing
the map is what clears a previous refusal's `rejectionReason`, `reviewedAt` and
`reviewedBy`. Leaving them would show an old refusal's reason against a new
request.

**The status is re-read immediately before the write.** A tab left open since
before an admin decided would otherwise overwrite that decision with a fresh
pending request.

### Two traps this panel has hit before, avoided here

**A Firebase Storage URL is never `encodeURI`d.** It arrives already
percent-encoded, so `encodeURI` turns `%2F` into `%252F` — a 404 and a broken
link with nothing in the console. The URL is used exactly as stored and only
the characters that would break out of an HTML attribute are escaped.

**No modal and no tooltip.** The theme loads Bootstrap 4 *and* Bootstrap 5, and
both components need doubled attributes to work in either. Every state here is
an inline panel instead, which needs neither.

`regionId` is never written to a customer document — a region is not a property
of a customer (§1).

### What approval grants: nothing

> **An approved business account changes no price today.** `APP-SPEC-CUSTOMER-APP.md`
> §6 says business-only wholesale prices apply to an approved account, but **no
> panel can mark a product business-only** — store wholesale is a quantity
> threshold alone. Approval records a decision. Business-only pricing is a
> separate feature and the client has not asked for it. The open question below
> is unchanged by this screen.

> ⚠️ **A customer can still approve themselves.** Firestore rules are unchanged
> by decision (22 Sep), so nothing stops a customer writing
> `businessProfile.status: "approved"` to their own document — as the admin
> panel found on a live record on 29 Sep. Harmless while approval grants
> nothing; it matters the day business-only pricing lands. Same gap covers
> `subscriptionPlanId` and `subscriptionExpiryDate`, where it is **not**
> harmless.

---

## 17. Saved payment methods — mobile money

Document 1's last outstanding web-panel item, built 30 Sep. **Mobile money
only.** Saved cards need gateway tokenisation and the client has chosen no
gateway, so that half stays unbuilt rather than half-built.

Route `payment-methods`, `PaymentMethodController`,
`users/payment_methods.blade.php`, linked from the account menu and the header
dropdown.

### The shape is the app's, and was read from live data

`APP-SPEC-CUSTOMER-APP.md` §7 defines it; a **live record written by the app**
confirmed it on 30 Sep, which settled three things the spec left open:

```
users/{uid}.savedPaymentMethods: [
    { id, type: "mobile_money" | "wave", operator, number,
      label?, isDefault, regionId? }
]
```

- `operator` is a **display string** — the live value is `"Orange Money"`.
- **the app does write `regionId`**, so this does too.
- `label` is genuinely optional and was absent on the live record.

### THIS SCREEN STORES; IT DOES NOT SPEND

§7 says saved methods are *"prefilled at checkout for the gateways that take a
number"*. **That is true of the app and not of this panel.** Every payment
method here is a hosted redirect or an email-and-name form — Orange Money hands
off to Orange's own page, Paystack returns an `authorization_url`, Xendit,
Midtrans and PayFast redirect, and Flutterwave's inline form passes
`customer[email]` and `customer[name]`. **No gateway in this panel collects a
number, so there is nothing at checkout to prefill.**

Confirmed with the user on 30 Sep: *"We have save the customer's payment methods
that's it."* The website is where a customer manages the numbers; **the app is
what reads them.**

`type: "wave"` likewise has no counterpart here — there is no Wave gateway in
the admin settings or among this panel's twelve methods. It is app-only, and is
written when the customer types Wave as their operator, so the customer never
has to understand a distinction they do not care about.

### The three write rules, and why they are named

`pmApplyDefault`, `pmApplyDelete`, `pmApplyUpsert` each take the list **as
stored** and return the list to store. Pulled out of the click handlers so each
rule is stated once and can be tested without a browser — **33 assertions pass**
in a `vm` sandbox.

| Rule | Why |
|---|---|
| The **first** method saved is the default, whatever the box said | one saved method that is not the default is a state with no meaning |
| Deleting the default **promotes the first remaining one** | saved methods with none marked hands the app a silent choice |
| An unresolved region **never clears** a `regionId` the app wrote | this browser failing to resolve is not evidence about the method |

**Every write re-reads first** and applies the change to what is actually
stored. The app writes this same array, so writing back the copy this page
loaded would silently drop a number added on the phone while the tab sat open.

`regionId` is taken from the active region. **This is not the forbidden "region
on a customer"** (§1): it belongs to the *method* — a mobile money number is
usable where its operator operates — and it matches what the app writes.

### The operator list

Free text with a `datalist`, not a fixed `select`. Only **Orange Money** is
confirmed from live data; MTN, Moov, Wave and Free Money are common in these
markets but are **not a list the client has given us**, and a customer whose
operator is missing must not be stuck.

> **Live since 30 September.** The rules are proven in a sandbox (33
> assertions) and the page renders. **Never exercised signed in**: adding,
> editing, defaulting and deleting against a real account has not been done,
> and neither has the round trip with the app — a number saved here appearing
> on the phone, and one saved on the phone appearing here.

---

## 18. The footer sweep — unguarded Firestore reads

Done 30 Sep, completing the work §14a left open after three of these broke the
delivery-address save and the header on 29 Sep.

**`layouts/footer.blade.php` is on every page**, so a read that throws there
costs the whole page, not the one feature that wanted the record. The fault is
always the same: **a document is read and used without checking one came back.**
`.data()` on a document that does not exist is `undefined`; `docs[0]` on an
empty result is `undefined`.

**All 67 read sites were classified.** 56 were already safe — `doc.data()`
inside a `forEach` or `for…of` over `docs`, `snapshot.exists ? … : null`,
`docs.length ?` or an explicit `.empty` return. **Eleven were not, and all
eleven are now guarded.**

| Site | What it read | Why it mattered |
|---|---|---|
| `email_templates` × **3** | `new_order_placed`, `new_ondemand_book`, `new_parcel_book` | **The worst of them.** `docs[0]` on an empty result, inside the mail send that runs **as an order is placed** — so an admin renaming or deleting a template failed the *order*, not just the email. Now returns without sending, matching §13's rule that no template means no email rather than a hardcoded English one |
| `settings/vendor` × **2** | `subscription_model` | **`await`ed**, so a throw rejected the caller — and the caller decides which stores and services a visitor may see |
| `settings/googleMapKey` × **2** | `key`, `placeHolderImage` | one is `await`ed and loads the maps script every address field needs |
| `zone.area` | the delivery polygon | **a zone saved without its polygon stopped the loop dead**, and this decides the delivery zone for *every* visitor. The zone screen was rewritten on 29 Sep, so a half-saved zone is not hypothetical. The broken zone is skipped; the rest survive |
| `settings/DriverNearBy` | `selectedMapType` | leaves `mapType` as `''`, which every reader already treats as "not google" |
| `settings/placeHolderImage` | `image` | cosmetic |
| `settings/globalSettings` | `appLogo` | cosmetic |

### Verified

A harness re-implements each guarded site **exactly as patched** and feeds it
the state that used to throw — a settings document that does not exist, an empty
query result, a zone with no polygon. **All ten hold**, and the zone case also
asserts the *good* zone still comes through, so the guard skips rather than
abandons. Plus a rendered page, `node --check` on all seven inline blocks, and
no empty `e()` in any compiled view.

> **What this does not claim.** Only `footer.blade.php` was swept. The same
> shape exists in other views, and a *field* read off a document that does
> exist — `zone.area` was one — is a separate class this pass only caught where
> it sat next to a document read.

---

## 19. Wholesale for approved business accounts only

**The client's decision, 30 September**, closing the question open since 25
September in §10. Wholesale is for **approved** business accounts. A customer
without one sees the shop without it.

### What "wholesale" means here — a judgement call, on the record

The client's words were *"wholesale products/items only will be show to the
Customer who have a Business account"*. That leaves one thing unsaid, decided
this way and put to them explicitly:

| Product | Ordinary customer sees |
|---|---|
| **wholesale-only** (`saleType: "wholesale"`) | **nothing — it is hidden** |
| **mixed** (retail price *and* tiers) | the product, at **retail**. No badge, no ladder, no tier price however many they buy |
| retail | unchanged |

Gating mixed products entirely would empty most of the catalogue for ordinary
shoppers. **If the client wants those hidden too it is a one-line change.**

"Approved" is `accountType == "business"` **and**
`businessProfile.status == "approved"` — the admin panel's decision
(ADMIN §18), not the customer's request. Pending or refused buys nothing.

### One switch on the client

`processVendorData` computes
`wholesaleEnabled = productData.wholesaleEnabled && customerMayBuyWholesale`.
The badge, the tier ladder, `minimumOrderQuantity` and the price charged were
**already** gated on that flag, so withholding it there withholds wholesale
across all seven screens at once rather than in seven places.

`loadBusinessAccountStatus()` runs once and is awaited as `businessAccountReady`,
the same shape `discoveryRegionsReady` uses. **It fails closed**: signed out, a
read error, a missing document — all mean retail. Withholding a discount from
someone entitled to it is a support call; handing it to everyone when Firestore
hiccups is the client's margin.

### Hiding, and why the filter reads the RAW product

Listings call `withoutHiddenWholesale(array)` **before** the card loop, not a
`return` inside it, so an all-hidden result falls through to each screen's own
empty message instead of drawing a blank row — and the `count == 1`
row-opening logic several screens use still fires on the first card drawn.

**`hiddenWholesaleOnlyProduct()` reads the product document, not the computed
price object.** `fetchVendorPriceData()` returns `{}` outright when
`adminCommissionSettings` is missing from localStorage — which happens whenever
the section cookie points at a section that no longer exists (§18). Keying the
filter on the price object would leak **every** wholesale-only product in
exactly that state.

**Favourites is the one exception**: it draws a placeholder card per favourite
record and fills it in afterwards, so the product document is not in hand. It
uses `final_price.wholesaleOnlyHidden`, which carries the same verdict.

Screens changed: product list, new arrivals, search, store page, ecommerce home,
multivendor home, favourites.

### The server gates, because the cart is priced in PHP

The browser posts the wholesale fields, and a posted field is whatever the
poster says it is.

| Where | What it does |
|---|---|
| `applyWholesalePrice` | strips the tiers, charges retail, records no applied tier |
| `enforceSaleTypeQuantity` | does **not** raise to the pack minimum — the one way such a customer could end up with a basket of fifty |
| `addToCart` | **refuses** a wholesale-only line outright |

`Controller::isApprovedBusinessCustomer()` reads Firestore over REST with the
existing `storage/app/firebase/credentials.json`, **cached ten minutes in the
session** so an approval takes effect without signing out and a cart operation
costs no round trip. Every failure path returns false.

Called through **`static::`, not `self::`** — late static binding, so the rule
can be overridden in a subclass. A first test harness silently passed the
ordinary-customer cases and failed the business ones because `self::` binds
early and the override never ran.

The refusal needed a browser change too: the add-to-cart success handler ignored
`status` and did `$('#cart_list').html(data.html)`, so a refusal would have
**blanked the cart panel and still said "added to cart"**.

**A direct link** to a hidden product is refused by the detail page itself,
which offers the business account application — a listing filter does not cover
bookmarks or shared URLs.

### Dead categories, and an older fault it exposed

Reported 30 Sep, straight after the upload: an ordinary customer opening a
store still saw a category whose only product was wholesale-only — a heading
leading nowhere.

**`getCategories()` collected category ids from every product**, then counted
each with a **separate unfiltered query per category**. Both passes now count
only visible products, from the single read already happening — which also
removes one Firestore query per category (the store page is now 1 read, not
1 + N). `catHaveProducts()` on **both home screens** had the same blind spot and
now uses `.some()` over the visible products.

**And an older fault surfaced.** `getProducts()` hid the overlay only inside
`if (html != '')`, while `buildProductsHTML()` has `if (alldata.length > 0)`
with **no else** — so an empty category returned `''` and **the spinner ran
for ever**. This predates wholesale entirely and was simply unreachable, because
a listed category always had products in it. It now hides the overlay whatever
comes back, renders "no results", and carries a `.catch` so a failed read does
not hang either.

7 assertions cover it, against the real reported data — ABC Fashion Zone with a
mixed product in Men's wear and the wholesale-only Kurti in Women's Wear —
including that an all-wholesale store lists **no** categories rather than dead
links.

### Three things this does not do

> **It is a business rule, not a security boundary.** This panel posts *prices*
> from the browser, so a determined person can still send a low one. The server
> check stops the ladder applying merely because the browser asked. It does not
> make pricing tamper-proof.

> ⚠️ **THE FIRESTORE RULE IS NOW URGENT.** A customer can write
> `businessProfile.status: "approved"` to their own document, and **one live
> record already is** (found 29 Sep, no `reviewedAt`, no `reviewedBy`). That was
> harmless while approval granted nothing. **It is now a discount anyone can
> grant themselves.** Needs console access and reopening the 22 Sep decision to
> leave rules unchanged. The same gap covers `subscriptionPlanId` and
> `subscriptionExpiryDate`.

> ⚠️ **The app is unchanged, and is now the more permissive side.** The same
> customer gets wholesale on their phone and not on the website.
> `APP-SPEC-CUSTOMER-APP.md` §8 documents wholesale applying to everyone and
> needs rewriting; §6's *"business-only wholesale prices"* describes a category
> **no field can express** — there is no `businessOnly` flag in any of the four
> panels. Store and admin **POS** are deliberately untouched: staff serving a
> walk-in is a different thing, and that should be a decision rather than an
> oversight.

> **Update 7 Oct 2026: the customer app now matches.** It applies the same
> blanket rule (`accountType == "business"` **and** `businessProfile.status ==
> "approved"`) and ORs the store's
> per-product `wholesaleBusinessOnly` on top, so the flag can only tighten.
> For a customer without an approved business account a **wholesale-only**
> product is hidden from every listing and refused on a direct link; a
> **mixed** product stays visible at retail with the tiers, tier price, badge,
> ladder and pack minimum withheld
> (`customer/lib/models/product_model.dart`). The phone is no longer the way
> around the rule. The rules draft also stops an account turning itself into
> an approved business account (`firestore.rules.draft`, `accountTypeOk`).

> ⚠️ **Live since 30 September, never exercised signed in.** 26 assertions
> pass (13 client, 13 server) and every affected page renders, but no real
> approved account has been through it. The step that matters: have the admin
> **refuse** an approved customer, reload, add 100 of a tiered product, and
> confirm retail applies — everything before it can pass on browser behaviour
> alone.

---

## 20. Open questions

> **Almost everything left in this panel is waiting on one of these.** The
> build queue is short not because the work is done but because the next
> decisions are the client's. The exception is the testing debt listed at the
> top of this file.

**With the client:**

- [x] ~~**The free allowance is 5 or 8.**~~ **Settled 28 Sep: 8, across the
      whole history**, not per tab. `settings/OrderHistory.freeOrderLimit` is
      8 on the live server. See §6.
- [ ] **One plan, one price, several currencies.** The customer plan is sold
      in Cameroon, France, Ivory Coast and Senegal and holds a single price,
      so it reads as 2000 FCFA in Cameroon and 2000 EUR in France. Either it
      is not offered outside the CFA countries, or plans need a price per
      region.
- [ ] **Should month names be translated?** See §9.
- [x] ~~**What should "Wholesale only" do to a retail customer?**~~ **Settled
      25 Sep: it blocks small quantities.** The product is still listed, and
      cannot be bought below its entry tier — in this panel and, since 28 Sep,
      in both POS screens. Whether it should additionally be restricted to
      approved business accounts is the separate question below.
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
- [x] ~~**Is a minimum order quantity wanted?**~~ **Answered by `saleType`.** A
      product marked *wholesale only* is already sold in packs. A minimum on a
      product that is **not** wholesale-only would still need a separate
      `minOrderQty` field; nobody has asked for one.
- [ ] **Should wholesale be restricted to business accounts?** Nothing in
      Document 1 or the Update asks for it — the only Individual/Business
      account type is in **Document 2**, the financial platform. But it is the
      most likely thing the client *meant* by "wholesale and retail sales", and
      `saleType` makes it sharper: a wholesale-only product is currently
      buyable in packs by anyone. Would need an account type, an approval path,
      and hiding wholesale prices and products from everyone else.

**With the app developer:**

- [ ] The app should match §5's transaction shape, including the balance
      re-read, or agree a different owner for the write.
- [ ] Service availability — the customer's location, or their account?

**Not built here, and not planned without a decision:**

- [ ] A **region picker**. Deliberately dropped — a blank badge is the settled
      behaviour for an unresolved visitor (§2).
- [x] ~~The **customer half of store→customer subscriptions**~~ — **built 28
      Sep**, §11. What is still missing is **recurring fulfilment**: a "daily
      bread" plan takes payment and creates no deliveries. **Settle that before
      this is demonstrated.**
- [ ] **Parcel** — paused by the client. No parcel screen is region-scoped.
- [ ] **Saved payment methods** (client point 17) — a customer keeping a Visa
      card or a mobile money account against their profile. Not started.
- [ ] **Circular home screen.** The **grouping by type** half is built (§14,
      28 Sep). The circular presentation itself is not, and page 8's "More"
      button opening a dropdown reads like the same screen as page 9's grouped
      list — the client needs to confirm whether they are one feature or two
      before it is worth drawing.
- [ ] **Document 2** — the financial platform (tontine, loans, investment,
      insurance, KYC, MFA). Nothing of it exists in this panel. **Scoped 29
      Sep** in `app-spec-document2-scope.md` in the admin repo's `docs\`: it is
      a second product, roughly one module in thirteen has foundations here,
      and it is **blocked on regulatory advice** before any code. The four
      placeholder services (§14a) are signage, not progress.
