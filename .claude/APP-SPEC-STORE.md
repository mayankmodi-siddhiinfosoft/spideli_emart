# App Spec — Store Panel

**Panel:** Spideli eMart store / vendor panel (`spideli-emart-store`)
**Written:** 24 September 2026  
**Last changed:** 30 September 2026 — `wholesaleBusinessOnly`, a sale type
column on the items list, and variants no longer flattening the price ladder
**Status:** everything below is **built** unless the section says otherwise. The
25 September items — wholesale tiers, sale type, the takeaway relabel, and the
website's tier pricing — went up that day, and the 28 September item — tiers and
the pack minimum in both Point Of Sale screens — followed it. The **30
September** items — the business-only switch, the sale type column on the items
list, and the variant ladder fix across all three panels — went up the same day.
**Nothing in this file is waiting to be uploaded.**

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
| 3b | Product custom delivery charges (store app) | bug point 60 | ✅ store app (9 Oct) |
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
  "wholesaleBusinessOnly": false,
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
| `wholesaleBusinessOnly` | bool | Withhold the tier prices from customers without an **approved** business account. Written `false` whenever wholesale is off or `saleType` is `"retail"` |
| `wholesaleDetails` | string | Rich text (HTML) — a price table, minimum order terms, packaging or delivery notes |
| `wholesalePrice` | string | **Tier one's price.** Kept for readers that predate tiers |
| `wholesaleMinQty` | string | **Tier one's quantity.** Same reason |

Variants carry `variant_wholesale_price` on `item_attribute.variants[]` — see
"A variant shifts the ladder" below. It is **optional**, and blank is the
normal case.

### Tier one is written twice, deliberately

`wholesalePrice` and `wholesaleMinQty` are **not** abandoned. The panel writes
tier one into them on every save, so anything reading the older pair keeps
working untouched and sees the entry-level offer. Nothing has to be migrated,
and nothing has to be changed in step.

The store app does the same. If the app edits a product the panel saved, or the
other way round, both shapes stay in agreement.

### A variant shifts the ladder, it does not replace it — 30 September

**This was wrong until 30 September and it cost real money.** The rule is
recorded here in full because three controllers and one browser file now
implement it, and they must agree.

`variant_wholesale_price` is **that variant's TIER-ONE price**, not its only
price. The product's tiers own the quantity breaks and the steps between them;
a variant shifts the whole ladder to start at its own figure.

```
product tiers      10 -> 949    50 -> 849    150 -> 749

variant blank   =>  949   849   749     the product's ladder, unchanged
variant 949     =>  949   849   749     identical - the commonest case
variant 999     =>  999   899   799     fifty more, throughout
variant 899     =>  899   799   699     fifty less, throughout
```

Steps are kept as **differences, not ratios**: a store setting 949/849/749 means
"a hundred rupees a step", and that stays true when a size costs fifty more. A
tier that would fall to zero or below is **dropped, not clamped** — a ladder
that deep means the figures are wrong, and inventing a price would hide it.

**Read the old way it destroyed the ladder.** Taken as "this variant's only
wholesale price", a product with tiers at 10/50/150 charged the entry price at
every quantity the moment sizes were added — and the item form *required* a
figure on every variant, so there was no way to configure it correctly. Reported
live on 30 September: 50 of a tiered kurti charged 959 instead of 859.

**Nothing had to be re-entered.** A variant carrying the product's own tier-one
price — which is what the form obliged every store to enter — resolves to the
identical ladder, so existing products started pricing correctly on upload.

**The field is optional now.** Blank means "no opinion" and the product's tiers
apply as written, which is what a store wants when the sizes cost the same.
Requiring a figure was the cause, not the symptom. When one *is* given it must
still be below that variant's own price.

**Implemented in four places, which must not drift:**

| Where | Function |
|---|---|
| Customer website | `variantWholesaleTiers()` in `layouts/footer.blade.php` |
| Store panel POS | `variantWholesaleTiers()` in `pos/index.blade.php` |
| Admin panel POS | `variantWholesaleTiers()` in `pos/index.blade.php` |
| Both item forms | the validation that made the figure optional |

> **Still not possible:** a variant with its own *quantity breaks*. A size gets
> one figure and the product's shape. And with variants the deeper tiers are
> **per size** — a 150 tier needs 150 of one size, not 150 across a mixed pack.
> Whether a mixed pack should reach it is the app team's open "per line or
> across the basket" question.

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

| | Tiers | `saleType` | `wholesaleDetails` | `wholesaleBusinessOnly` |
|---|---|---|---|---|
| Store panel, item form | ✅ live 25 Sep | ✅ live 25 Sep | ✅ live 25 Sep | ✅ **30 Sep** |
| **Store panel, items list** | shown as the entry tier | ✅ **30 Sep** column | — | ❌ not shown |
| **Store panel, POS** | ✅ **28 Sep** | ✅ **28 Sep** | — | ❌ deliberate |
| Store app | ✅ | ✅ | — | ✅ reads it per product |
| Customer website | ✅ live 25 Sep | ✅ **live 25 Sep** | ✅ | ❌ gates per **account** instead |
| **Admin panel, POS** | ✅ **28 Sep** | ✅ **28 Sep** | — | ❌ deliberate |
| Admin panel, item form | ❌ | ❌ | ❌ | ❌ |
| Customer app | ❌ | ❌ | ❌ | ❌ |

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

### `wholesaleBusinessOnly` — built 30 September, and it does nothing on the website

The store app has carried this switch for some time — *"Only verified Business
customers get wholesale prices"* — and `APP-SPEC-STORE-APP.md` §5 names the
field without describing it. The behaviour is defined in
`APP-SPEC-CUSTOMER-APP.md` §6: *"Business-only wholesale prices apply only to an
approved account."*

**The panel now has the same switch**, under the tier list on Create and Edit
Item. It is shown only while wholesale is on **and** `saleType` is not
`"retail"` — with no wholesale price there is nothing to withhold — and it is
**cleared, not merely hidden**, when it stops applying, so a `true` cannot be
stranded on a product with no wholesale pricing.

"Verified" is not the customer's own claim. It is
`accountType == "business"` **and** `businessProfile.status == "approved"`, the
admin panel's decision (ADMIN §18). Pending or rejected buys nothing.

> ⚠️ **The panel and the website apply this idea at different levels.**
>
> | | Scope |
> |---|---|
> | Store app, and now this panel | **per product** — this product's tiers need a business account |
> | Customer website, since 30 Sep | **per account, for everything** — no approved business account means no wholesale anywhere |
>
> The client's words were *"wholesale products/items only will be show to the
> Customer who have a Business account"* — a blanket rule, and that is what
> WEB §19 built. **So the switch changes nothing on the website today**: the
> site already withholds every tier from unapproved customers, whatever this
> field says. Only the app reads it per product.
>
> This is on the record as a question for the app team, not a defect on either
> side. Two things follow from it:
>
> - **The default is `false`.** If the website were ever changed to honour the
>   field, every existing product would open up to ordinary customers — quietly
>   undoing the 30 September decision. Whoever builds that must treat absent or
>   `false` as "business only" or migrate the data first.
> - **Neither POS reads it**, deliberately. Staff serving a walk-in is a
>   different situation from a customer shopping online, and that should be a
>   decision rather than an oversight.

**What the customer app does with it (answered 7 Oct 2026).** The customer app
now applies the same blanket rule as the website **and** honours this flag on
top of it (`customer/lib/models/product_model.dart`,
`wholesaleBlockedForCustomer`): wholesale is withheld from a customer unless
`accountType == "business"` **and** `businessProfile.status == "approved"`;
`wholesaleBusinessOnly` is ORed in, so it can only tighten, never grant. For a
customer without an approved business account:

| Product | What the app does |
|---|---|
| **wholesale only** (`saleType: "wholesale"` with usable tiers) | **hidden** from every listing, and refused on a direct link with a pointer to the business-account application |
| **mixed** (retail and tiers) | **visible at retail**: the tiers, the tier price, the badge, the ladder and the pack minimum are withheld |

So the flag **withholds the wholesale price** (and, for a wholesale-only
product, hides the product); today it changes nothing beyond the blanket rule,
exactly as on the website.

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

## 3b. Product custom delivery charges — store app (bug point 60, 9 Oct 2026)

Source: `APP-SPEC-PRODUCT-DELIVERY-CHARGES.md` §2–3. Store app half only; the
customer app's cart rule (sum of each product's charge × quantity) is specified there.

- **When it shows:** the Add / Edit Product screen reads
  `sections/{sectionId}.is_delivery_charge_customization` **fresh** every time it
  opens (`FireStoreUtils.getSectionDeliveryChargeCustomization`, which returns
  null when the section cannot be read). The section id is the vendor
  document's `section_id`, else the user's `sectionId`, else the section chosen
  at login. Only `true` shows the "Delivery Charges" section. The app does not
  check `serviceTypeFlag` itself — the admin panel only sets the flag on
  `ecommerce-service` / `multivendor-delivery-service`.
- **One charge per product (client rule, 9 Oct 2026; replaces "up to 5"):**
  a single card with *Delivery Charges Per Km*, *Minimum Delivery Charges
  (<store currency symbol, else code>)* and *Minimum Delivery Charge Within
  Km*; decimal keyboard, digits with at most 2 decimals (`,` is accepted as the
  separator), no sign. No add / remove buttons.
- **Save, flag on:** the charge is **required** — all 3 values numeric and
  `>= 0`, else *"Please enter the delivery charge: all 3 fields are
  required."* and nothing is saved. Written as a one-entry array (field
  structure unchanged, so the customer app's calculation is unchanged):
  `vendor_products/{id}.delivery_charges: [{delivery_charges_per_km,
  minimum_delivery_charges, minimum_delivery_charges_within_km}]`, numbers
  (whole values as ints).
- **Save, flag off:** the card is hidden and `delivery_charges` is written as
  **`null`**. If the section could not be read the field is left as stored.
- **Products saved with several tiers** (before the one-charge rule): the
  editor shows the tier with the smallest *within km*, and any write of the
  field (an edit, or importing an admin catalogue product) keeps only that one
  (`DeliveryChargeTier.single`).
- **Read:** numbers or numeric strings; entries with none of the three values
  usable are dropped, a single missing value reads `0`.
- **Field-preserving:** product saves use `setKnownFields`, and
  `delivery_charges` is in the write **only** from the Add / Edit Product save
  (above) or an admin catalogue import that carries the field. Every other
  product save (the publish switch, bulk "Apply Tax") leaves it alone.
- **Add / Edit Store:** when the selected section has the flag
  (`SectionModel.isDeliveryChargeCustomization`, read-only), the store's
  Delivery Charge card (the read-only "Delivery Settings" switch and the three
  charge fields) is hidden and `vendors.DeliveryCharge` is saved with
  `delivery_charges_per_km`, `minimum_delivery_charges` and
  `minimum_delivery_charges_within_km` all `0`.
- **Admin panel** (not in this repo): with the flag on the product Delivery
  Charge is mandatory there too; with it off the option is hidden and the
  field saved as `null`, and the store's delivery charge applies to the whole
  order (the customer app already does this when the flag is off).
- Code: `vendor/lib/utils/product_delivery_charges.dart` (rules),
  `vendor/lib/app/product_screens/product_delivery_charges_section.dart`
  (UI), `DeliveryChargeTier` in `vendor/lib/models/product_model.dart`,
  `AddRestaurantController.productDeliveryCharges` (store card);
  tests in `vendor/test/product_delivery_charges_test.dart`.

---

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

**Corrected 28 Sep 2026 against the code.** The shapes below were written
from the proposal and several field names never matched what the panel
actually writes — `name`/`duration`/`points`/`regionIds` do not exist. These
are the real ones, taken from `customer_subscriptions/create.blade.php` and
from what the store and admin panels read back.

```json
// vendor_subscription_plans — what a store offers
{
  "id": "…",
  "vendorID": "…",
  "regionId": "…",          // singular: a plan belongs to one store,
  "sectionId": "…",         // and a store to one region and one section
  "title": "Daily bread — monthly",
  "description": "…",
  "photo": "…",
  "price": 15000,
  "expiryDay": "30",         // days; "-1" never expires
  "plan_points": ["…"],     // what the customer actually gets
  "isEnable": true,
  "createdAt": "<Timestamp>"
}
```

```json
// vendor_subscriptions — who is subscribed
{ "id": "…", "planId": "…", "vendorID": "…", "customerId": "…",
  "plan": { … },            // a SNAPSHOT of the plan, not a reference
  "startDate": "<Timestamp>", "expiryDate": "<Timestamp>|null",
  "status": "active", "createdAt": "<Timestamp>" }
```

```json
// vendor_subscription_payments
{ "id": "…", "planId": "…", "vendorID": "…", "customerId": "…",
  "amount": 15000, "adminCommission": 1500, "vendorEarning": 13500,
  "payment_method": "Wallet", "createdAt": "<Timestamp>" }
```

`plan` on the subscription is a **snapshot**, and both panels rely on it: the
Subscribers tab reads `subscription.plan.title` so a store renaming or deleting
a plan cannot change what an existing subscriber is shown.

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
| **A customer browses, subscribes and pays** | ✅ **built 28 Sep 2026** — customer web panel |

### The customer half — built 28 September 2026

On the **store's page** in the customer website, above the products. A store
with no plans renders nothing, which is every store today.

- Plans are `vendor_subscription_plans` where `vendorID` is this store and
  `isEnable` is true, dropped when `regionId` is set and differs from the
  customer's region. A plan with no `regionId`, or a customer with no resolved
  region, is shown rather than hidden — the same rule the rest of the panel
  uses for an unresolved region.
- Priced in **the store's** region currency, not the browsing region's.
- Paid from the wallet, or **by any gateway the customer's region carries** -
  the plan is remembered, the customer tops the wallet up for the shortfall
  through the existing flow, and the subscription completes by itself on the
  way back. Client decision, 28 Sep: the alternative was an eighth copy of all
  twelve gateway integrations, each untestable without live keys.
- The purchase itself is one Firestore transaction with the balance re-read
  inside it, so a double click cannot pay twice.
- **The price is re-read when a topped-up purchase completes**, never taken
  from what was saved. A plan whose price changed, or which was switched off,
  while the customer was paying buys nothing and says so - the money is in the
  wallet and the decision is theirs.

**Four writes, all or none:**

```
users/{customerId}                    wallet_amount = balance - price
wallet/{new}                          the customer's own ledger line
vendor_subscriptions/{new}            what the Subscribers tab reads
vendor_subscription_payments/{new}    what the Payments tab reads
```

**Nothing is written onto the customer document beyond the debit.**
`subscriptionPlanId`, `subscription_plan` and `subscriptionExpiryDate` belong
to the platform's own plan; a store plan must never overwrite them, or a
customer's bread subscription would silently replace their order-history plan.

**The commission is deducted, not added.** Document 1: *"The application's
commission must also be deducted from this service."* So the customer pays the
store's price and the platform's cut comes out of it — the opposite of a
product, where commission is added on top of the vendor's price. The rate is
the store's own `adminCommission` when it has one, otherwise the section's, and
it is **capped at the price** so a fixed cut larger than a cheap plan cannot
hand the store a negative earning. It is written onto the payment and never
re-derived.

A plan the customer already holds and has not used up shows a *Current plan*
badge with its button shut, and the check is repeated where the money moves.
The customer also sees everything they hold from any store on the
**Subscriptions** screen, expired ones included — a customer asking what
happened to their bread delivery needs to see that it ran out.

### Expiry — nothing runs, and nothing needs to

A subscription stops granting anything the moment its `expiryDate` passes,
because every screen works that out as it reads. **`status` is written
`"active"` at purchase and nothing ever changes it**, so the obvious query
`where('status','==','active')` counts lapsed subscribers too — it caught the
plan list on this panel, fixed 28 Sep by counting on the date instead.

What is genuinely missing is that **nobody is ever told** a subscription has
lapsed. A scheduled job is specced in `app-spec-subscription-expiry.md` in the
admin repo's `docs\`, with the flow, the fields and the setup for both a Laravel
cron and a Cloud Function. Not built, and it needs the client's word first.

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

## 5a. What the store app does, for the panel to match (7 Oct 2026)

- **Order writes are guarded transactions**
  (`vendor/lib/utils/store_order_write.dart`): each re-reads the order and
  writes only its own fields, so nothing the dispatch Cloud Function or a
  driver wrote is overwritten. Accept only from `Order Placed`; own delivery
  man (`In Transit`, `driverID` = `driverId` = him, his `driver` snapshot);
  courier (`Order Shipped`) only from `Order Placed`; reject / cancel only
  while the status is unchanged since the reason sheet opened, with the reason
  fields in the same write; complete while the order is live. The store never
  notifies or names a platform driver: `deliveryDispatch` does that on
  `Order Accepted` (`.claude/DRIVER-DISPATCH-CONTRACT.md`).
  `Driver Pending` / `Driver Rejected` show as **"Waiting for a delivery
  partner"** (warning tone); "With the delivery man" only at
  `Driver Accepted`, `Order Shipped`, `In Transit` with a driver set.
- **Point 58, product deletion:** a confirmation dialog first; on confirm the
  app deletes `vendor_products/{id}`, then (in the background) the product's
  own photos under `profileImage/{uid}/` that nothing else uses (other
  products of the owner's stores, store and profile pictures, exact URL
  matches in `vendor_products` and `admin_products`). If any of those checks
  cannot be read, no photo is deleted. Variant images (`images/{variantId}.png`)
  and digital product files (`digitalProducts/...`) are left alone. The
  Storage rules must let the uploader delete `profileImage/{uid}/...`.
- **Doc 37:** the app never rewrites `isDocumentVerify` / `isAutoVerify` on an
  existing user; only sign-up and the creation of a delivery man / employee
  write the starting value.

## 6. Open questions

**With the client:**

- [ ] **Per-store subscription price — ANSWERED 22 Sep: confirmed final**,
      *"store wise subscription"*. A vendor with three stores pays three
      subscriptions. No longer provisional.
- [ ] Is store→customer subscription meant to create recurring **deliveries**,
      or only to record who paid? (§4)
- [x] ~~What should **"Wholesale only"** do to a retail customer?~~ **Answered
      25 Sep, built 28 Sep**: it is not sold singly, and the floor is the entry
      tier. Live on the website and both POS screens (§3).
- [ ] **Per product or per account?** The store app — and now this panel —
      marks wholesale business-only **per product**. The website, on the
      client's 30 September instruction, withholds wholesale from unapproved
      customers **for everything**. Under the website's rule the per-product
      switch can never do anything. Which is intended? (§3)
- [ ] Should a product ever be **both** delivery and takeaway? It cannot be
      today, and making it possible is customer-site work (§3a).

**With the app developer:**

- [ ] Credit `vendors/{id}.wallet_amount` on order completion (§2).
- [ ] The customer half of §4 — browsing and paying for a store's plan.
- [ ] Wholesale in the cart: does the app apply the threshold per line, or
      across the basket? The website applies it **per line** (§3).
- [ ] Do the customer app and the admin panel need to show tiers, or is the
      website enough for now? (§3)
- [x] ~~**`wholesaleBusinessOnly` has no documented behaviour.**~~
      **Answered 7 Oct:** the customer app withholds the wholesale price (a
      mixed product stays at retail) and hides a wholesale-only product; the
      flag is ORed with the platform rule (§3, "What the customer app does
      with it").

**Closed:** legacy wallet balances. The client said on 22 September that the
current data is temporary and will be replaced, so **no migration is being
built**. That is a reason not to migrate, **not** authority to delete anything —
the cutover has never been written down.
