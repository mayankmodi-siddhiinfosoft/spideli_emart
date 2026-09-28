# App Spec — Store Panel

**Panel:** Spideli eMart store / vendor panel (`spideli-emart-store`)
**Written:** 24 September 2026  
**Last changed:** 28 September 2026 — the POS now honours tiers and sale type
**Status:** everything below is **built** unless the section says otherwise. The
25 September items — wholesale tiers, sale type, the takeaway relabel, and the
website's tier pricing — went up that day. The **28 September** item, tiers and
the pack minimum in this panel's Point Of Sale and the admin panel's, is built
and **waiting to be uploaded**: `UPLOAD-FILE-LIST-28-09-2026.txt`.

**This file replaces three separate specs** — `app-spec-multiple-stores.md`,
`app-spec-vendor-subscription.md` and `app-spec-wholesale-pricing.md`. Those
stay on disk as history. **Edit this one.**

> **`APP-SPEC-ADMIN.md` in the admin repo is the master.** Fields shared across
> panels — regions, currency, payment methods, platform subscriptions, service
> groups — are defined there and are **not repeated here**. This file covers
> what the store panel owns or reads differently.

---

## Contents, against the client's own list

| § | Feature | Client's list | Built |
|---|---|---|---|
| 1 | The panel follows the region, and writes one | points 1, 2 | ✅ |
| 2 | Multiple stores on one account | point 3 | ✅ |
| 3 | Wholesale pricing, in tiers | point 17 | ✅ panel, POS, store app and website |
| 3a | "Takeaway Option" means takeaway ONLY | — | ✅ relabelled |
| 4 | Subscriptions a store sells to its customers | point 19 | ✅ selling side |
| 5 | The store's own platform subscription | Document 1 | ✅ |
| 6 | Open questions | — | — |

---

## 1. The panel follows the region

Region fields are defined in `APP-SPEC-ADMIN.md` §1. What is specific here:

- A vendor's stores, orders and figures stay inside their region.
- **Store creation asks for the region first**, then offers only the zones
  belonging to it. Getting that order wrong was a real bug — a zone from
  another region could be attached to a store.
- The region falls back, in order, to: an explicit choice → the owning user's
  `regionId` → the vendor record's `regionId`.

### What the store panel WRITES a region onto

The panel is not only a reader. Three screens stamp a `regionId` at creation
time, and if they stop doing it the records arrive unplaced and vanish from a
region-bound admin's lists:

| Screen | Writes | Region comes from |
|---|---|---|
| Vendor registration (`auth/register`, `auth/phone_register`) | `users/{id}.regionId` | the region chosen on the form — **required**, registration is blocked without it |
| Driver creation (`deliveryman/create`) | `users/{driverId}.regionId` | `resolveVendorRegionId(vendor)` — the creating store's region |
| POS orders (`pos/index`) | the order's `regionId` | `resolveVendorRegionId(vendor)` |

`resolveVendorRegionId()` follows the rule in `APP-SPEC-ADMIN.md` §1: the
vendor's own `regionId` first, and its zone only when that zone serves exactly
one region.

---

## 2. Multiple stores on one account

### The field that changed meaning, not shape

```json
// users/{ownerId}
{ "vendorID": "store_a" }
```

`vendorID` stays a single store id, but now means **"the store currently
selected in the panel"** rather than "the one store this user owns". Every
existing read keeps working. Switching store writes a different id here.

**A user's stores are derived, not stored:** `vendors where author == {userId}`.
There is no array of store ids to keep in step.

### The owner lookup that was wrong

`users where vendorID == storeId` asks *"whose **selected** store is this?"* —
which is wrong the moment a vendor holds several. Read `vendors/{id}.author`.

This was fixed on 17 September. Anywhere still using the old pattern will
silently attribute a store to whoever happens to have it selected.

### What each store now carries separately

| | |
|---|---|
| **Wallet** | Each store has its own `wallet_amount` and its own payout requests |
| **Subscription** | Checked against the **store**, not the account, so one store expiring does not close the others. Expiry writes the store as well as the account |
| **Employees** | Attached to a store; the Employees list has a store filter |
| **Sections** | Deleting a section removes an owner's login **only when they have no stores left** |

### Deliberately not changed

`payoutRequests/provider/*` owner lookups. Providers are one-person service
people and are unaffected by multi-store.

### Two known gaps

> **Nothing credits `vendors/{id}.wallet_amount` on order completion.** The app
> must do it. Until then a vendor cannot withdraw what they earned.
>
> **`subscription_history` rows carry no store id.**

---

## 3. Wholesale pricing

Client point 17, Document 1's Commercial Management, extended on 25 September
by the client's own example: *"For 15 items or more, the price is 3,500. For
100 items or more, 2,500. For 500 items or more, 2,000."*

```json
// vendor_products/{id}
{
  "wholesaleEnabled": true,
  "wholesaleTiers": [
    { "minQty": "15",  "price": "3500" },
    { "minQty": "100", "price": "2500" },
    { "minQty": "500", "price": "2000" }
  ],
  "saleType": "both",
  "wholesaleDetails": "<p>Sold in cases of 12…</p>",

  "wholesalePrice": "3500",
  "wholesaleMinQty": "15"
}
```

| Field | Type | Notes |
|---|---|---|
| `wholesaleEnabled` | bool | **Off by default** — the *"certain products"* of the client's wording |
| `wholesaleTiers` | array | Up to **5** `{minQty, price}`, sorted smallest quantity first. The shape the store app already writes |
| `saleType` | string | `"retail"`, `"wholesale"` or `"both"`. Written `"retail"` automatically whenever `wholesaleEnabled` is false |
| `wholesaleDetails` | string | Rich text (HTML) — a price table, minimum order terms, packaging or delivery notes |
| `wholesalePrice` | string | **Tier one's price.** Kept for readers that predate tiers |
| `wholesaleMinQty` | string | **Tier one's quantity.** Same reason |

Variants carry `variant_wholesale_price` on `item_attribute.variants[]`. **A
variant has one wholesale price, not a ladder** — tiers are a product-level
thing, and a variant's own price replaces them rather than layering on top.

### Tier one is written twice, deliberately

`wholesalePrice` and `wholesaleMinQty` are **not** abandoned. The panel writes
tier one into them on every save, so anything reading the older pair keeps
working untouched and sees the entry-level offer. Nothing has to be migrated,
and nothing has to be changed in step.

The store app does the same. If the app edits a product the panel saved, or the
other way round, both shapes stay in agreement.

### The price-resolution rule

Applied in this order, and **the retail path is unchanged** when wholesale is
off:

1. `wholesaleEnabled` is false or absent → retail, exactly as today
2. no tier the quantity reaches → retail
3. otherwise → the **highest** tier whose `minQty` the quantity has reached

**Every unit on the line gets that price**, not only the units above the
threshold. 500 units at the 500 tier is 500 × 2,000, not 15 at one price and
the rest at another.

**A tier that is not cheaper than what the customer would otherwise pay is
skipped.** The test is per tier, so a product on promotion can have its first
tier undercut by the discount while a deeper tier still applies.

**A discount does not stack on a wholesale price.** Wholesale already *is* the
reduced price; applying `disPrice` on top of it discounts twice.

### Validation the panel enforces

- At most 5 tiers
- Each `minQty` at least **2**, each price **below** the retail price
- Quantities strictly increasing, prices strictly decreasing — a larger order
  can never cost more per unit

Tier one is created the moment wholesale is switched on and cannot be deleted
while it is on, because it is what the older pair is written from.

### Where this is built

| | Tiers | `saleType` | `wholesaleDetails` |
|---|---|---|---|
| Store panel, item form | ✅ live 25 Sep | ✅ live 25 Sep | ✅ live 25 Sep |
| **Store panel, POS** | ✅ **28 Sep** | ✅ **28 Sep** | — |
| Store app | ✅ | ✅ | — |
| Customer website | ✅ live 25 Sep | ✅ **live 25 Sep** | ✅ |
| **Admin panel, POS** | ✅ **28 Sep** | ✅ **28 Sep** | — |
| Customer app | ❌ | ❌ | ❌ |

**The customer app is the only side left.** It prices from tier one and will
sell a single unit of a wholesale-only product, so an app order can differ from
the same basket on the website or at either counter.

**The website resolves tiers on the server**, in
`ProductController::applyWholesalePrice()`, and reprices a line whenever its
quantity changes — including *downwards*, so a customer who drops from 500 to 5
goes back to retail. The product page shows the tier in force and what the next
one up would cost.

**Both Point Of Sale screens now run the same function**, on their own cart keys
(`original_base_price` rather than `item_price`). Three controllers, one rule —
if they drift, the same basket prices differently over the counter and on the
website, which is exactly what this section exists to prevent.

### `saleType` — what "wholesale only" does — 28 September

Answered by the client on 25 September and now built everywhere except the app.
**A wholesale-only product is not sold singly.** The floor is the **entry tier**
— the cheapest quantity that unlocks a wholesale price, not the deepest. A
product sold in tens with a better price at fifty still sells tens.

| | How the floor is held |
|---|---|
| Website | the quantity box opens at the minimum, the stepper will not go below it, a typed quantity is corrected on blur, and the server raises anything lower |
| Both POS screens | the modal has no quantity picker, so adding puts a **pack** in the cart; minus stops at the minimum and says why |
| Everywhere | **removing the line always works.** A customer who cannot buy five of something sold in tens is the store's decision; one who cannot empty their cart is a fault |

The product card and the cart line say "Sold in a minimum of N units", and the
cart line also says **which** tier is running — which matters once a product
carries three of them.

### How the rule is checked

`applyWholesalePrice()`, `saleTypeMinimum()`, `enforceSaleTypeQuantity()` and
`normaliseSaleType()` are exercised directly through reflection in each of the
three controllers — 29 checks on the website, 34 on each POS. They cover every
step of the ladder, a discount undercutting every tier, a tier list arriving as
JSON text, a product with no tiers at all, the pack floor per sale type, and
unrecognised `saleType` values falling back to `both`. **Run these against any
change to the rule**; the browser side of the POS has not been driven, since it
needs a signed-in account.

---

## 3a. "Takeaway Option" means takeaway ONLY

Not wholesale, but it sits on the same form and was corrected in the same pass.

`takeawayOption` has always meant **takeaway only**, on every side:

- the store app writes `takeawayOption = takeaway && !delivery`
- the website filters with `takeawayOption == <the customer's mode>`, a strict
  equality — so a product is takeaway-only or delivery-only, never both

The data was never in dispute. **The panel's label was.** It read *"Takeaway
Option"*, which reads as *adding* takeaway to a product, when ticking it in fact
**hides the product from every delivery customer**. A vendor could lose their
delivery trade on a product by ticking a box they thought was additive.

Renamed to **"Takeaway only"** on 25 September, with the consequence spelled out
underneath it. Wording only — no stored data changed and no existing product was
touched.

> **"Both" is not expressible today.** The app's `fulfilment: ["delivery",
> "takeaway"]` array can say it, but the website's strict equality cannot act on
> it. Supporting it properly means changing the customer site's filter, not just
> adding a field.

## 4. Subscriptions a store sells to its customers

Client point 19 — the restaurant-delivers-bread example. **This is the third
subscription system and it must not touch the other two.**

| System | Collection | Who sells | Who buys |
|---|---|---|---|
| Platform → vendor | `subscription_plans`, `planFor: "vendor"` | Spideli | a store |
| Platform → customer | `subscription_plans`, `planFor: "customer"` | Spideli | a customer |
| **Store → customer** | `vendor_subscription_*` | **a store** | **a customer** |

The third uses **its own collections** precisely so it cannot collide with the
shared `subscription_plans`.

```json
// vendor_subscription_plans — what a store offers
{
  "id": "…",
  "vendorID": "…",
  "name": "Daily bread — monthly",
  "price": 15000,
  "duration": 30,
  "points": ["…"],
  "isEnable": true,
  "regionIds": ["…"]
}
```

```json
// vendor_subscriptions — who is subscribed
{ "planId": "…", "vendorID": "…", "customerId": "…", "expiryDate": "<Timestamp>" }
```

```json
// vendor_subscription_payments
{ "planId": "…", "vendorID": "…", "customerId": "…",
  "amount": 15000, "adminCommission": 1500, "createdAt": "<Timestamp>" }
```

**The commission is recorded on each payment**, not read from the store's
current rate. Changing the platform's cut later must never rewrite what an
older payment earned. **Preserve this when writing a payment.**

### What is built, and what is not

| Part | State |
|---|---|
| A store creates and edits its plans, and picks which of its stores a plan belongs to | ✅ built |
| A plan carries its points — what the customer actually gets | ✅ built |
| The store sees its subscribers and their payments | ✅ built |
| The platform sees every plan, subscriber and payment | ✅ built in admin |
| **A customer browses, subscribes and pays** | ⬜ **missing** |

> **It is provisional.** These screens were built against an option with **no
> automatic fulfilment**. A restaurant can sell a monthly bread subscription
> and see who bought it, but nothing creates the daily deliveries. The client's
> wording — *"to deliver bread to customers' homes"* — reads like recurring
> delivery, which is a far larger feature and has not been confirmed.

---

## 5. The store's own platform subscription

A store buys and renews its own plan from Spideli. The payment is recorded
against the **store** rather than the account, which is what makes §2's
per-store expiry work.

Plans are read from `subscription_plans` filtered by `sectionId` — which is
exactly why customer plans carry `sectionId: null` (see `APP-SPEC-ADMIN.md` §9).
They are invisible to these screens by construction, with no filter needed.

> **Store plans now carry `regionIds`, but nothing reads it.** The store
> subscription screens still offer plans by section alone. Recorded
> deliberately — per-region subscription *pricing* was never asked for in
> either client document, and one price is correct while regions share the
> pegged XAF/XOF.

---

## 6. Open questions

**With the client:**

- [ ] **Per-store subscription price — ANSWERED 22 Sep: confirmed final**,
      *"store wise subscription"*. A vendor with three stores pays three
      subscriptions. No longer provisional.
- [ ] Is store→customer subscription meant to create recurring **deliveries**,
      or only to record who paid? (§4)
- [ ] What should **"Wholesale only"** do to a retail customer on the website —
      hide the product, block small quantities, or require a business account?
      The field is stored and nothing acts on it (§3).
- [ ] Should a product ever be **both** delivery and takeaway? It cannot be
      today, and making it possible is customer-site work (§3a).

**With the app developer:**

- [ ] Credit `vendors/{id}.wallet_amount` on order completion (§2).
- [ ] The customer half of §4 — browsing and paying for a store's plan.
- [ ] Wholesale in the cart: does the app apply the threshold per line, or
      across the basket? The website applies it **per line** (§3).
- [ ] Do the customer app and the admin panel need to show tiers, or is the
      website enough for now? (§3)

**Closed:** legacy wallet balances. The client said on 22 September that the
current data is temporary and will be replaced, so **no migration is being
built**. That is a reason not to migrate, **not** authority to delete anything —
the cutover has never been written down.
