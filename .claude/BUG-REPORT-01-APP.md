# Client Bug Report — What Belongs to the Apps

**Date:** 1 October 2026
**From:** the web panel work (admin, store, customer website)
**Sources:** `REPORT-OF-BUGS-01.pdf`, then `REPORT-OF-BUGS-02.pdf` after the
client meeting.

**Report 02 is the same list as Report 01, renumbered**, with the client's own
DONE marks and **one new point**. Numbers below are **Report 02's**, with
Report 01's in brackets.

The three web panels have their own files — `BUG-REPORT-01-ADMIN.md`,
`BUG-REPORT-01-STORE.md`, `BUG-REPORT-01-WEB.md` — and
`BUG-REPORT-01-STATUS.txt` carries every point in one list.

---

## Why you are getting this

**14 of the 30 points are app-only, and 5 more are split between us.** None of
them can be closed from the panels.

Three sections matter to you even where the point is not yours:

1. **§2** — points that are entirely yours.
2. **§3** — points where we have done our half and the rest is yours.
3. **§4** — **what we changed in the panels that your apps must match.** This is
   the section most likely to cause drift if it is missed.

---

## 1. What is already done, so you are not chasing it

| 02# | 01# | Point | Done |
|---|---|---|---|
| 1 | 1 | Errors completing an order on POS | both panels, 1 Oct |
| 10 | 9 | "No driver found" assigning from the orders list | admin, 1 Oct |
| 17 | 16 | Region not filtering the zone list | admin + store, 1 Oct |
| 23 | 22 | Error creating a provider verification document | admin, 1 Oct |
| 24 | 23 | DataTables warning on the Documents screen | admin, 1 Oct |
| 25 | 24 | Nowhere to review a provider's documents | admin, 1 Oct |
| 29 | 28 | Links leading to an error page | admin, 1 Oct |
| 19 + 8 | 18 + 7 | Companies and their drivers | **nothing structural left for you** — we had this wrong, see §3 |

---

## 2. Yours alone

| 02# | 01# | Point |
|---|---|---|
| 3 | 3 | Real-time chat notifications, like push notifications |
| 4 | 4 | Order tracking — the map does not display (customer app) |
| 6 | 6 | Driver app chat shows a blank white screen |
| **7** | — | **NEW IN REPORT 02.** Store app: blank screen when tapping an employee's photo |
| 11 | 10 | Independent drivers cannot act on an order assigned to them |
| 12 | 11 | An audible order alert on the vendor app when it is closed or backgrounded |
| 14 | 13 | Customer app chat — the keyboard covers the text field |
| 16 | 15 | Customer app, multivendor view — move the search box into the block with map view and QR scan |
| 20 | 19 | Drivers receive no automatic push notifications for any service |
| 22 | 21 | Typing a quantity directly instead of tapping + |
| 30 | 29 | Proof of delivery for multivendor and ecommerce orders |

### 02#22 — already works on the website

`products/detail.blade.php` renders the quantity as a normal text input with
`change keyup` and `blur` handlers that revalidate and reprice as the customer
types. **This is an app-side request only.**

One thing to know before copying the behaviour: a **wholesale-only** product
starts at its pack minimum and the box corrects a smaller number upward. That is
deliberate (`APP-SPEC-WEB.md` §10) and can read as "it won't let me type".

### 02#7 — the new one

Reported after the client meeting. Same family as 02#6 and 02#14: a screen that
opens blank or is obscured. Nothing in the panels touches it.

---

## 3. Split — our half is done or specified, yours is not

### 02#26 (01#25) — uploading documents

> *"For Drivers: How can they upload their documents … after registering."*

**Client has marked this "DONE in ADMIN", which is exactly right.**

**Ours, done 1 Oct:** reviewing. A screen listing what a provider or worker has
uploaded, with approve and reject, notifying the holder on decision.

**Yours:** the uploading itself, from the phone, after registration.

The record you write is unchanged and we match it:

```
documents_verify/{holderId}
    id, type: "driver" | "vendor" | "owner" | "provider" | "worker"
    documents: [ { documentId, status, frontImage, backImage } ]
```

`status` is `uploaded` when you write it; the panel sets `approved` or
`rejected`. A required document with no entry reads as `pending`.

> **126 of the 154 live records are orphans** — the holder they name no longer
> exists. Harmless to us because we look up by holder, but worth knowing if you
> ever list them the other way round.

### 02#19 (01#18) + 02#8 (01#7) — companies and their drivers

> **This section replaces what was here before. Most of what it told you to do
> was wrong, and we are sorry — it would have cost you a sprint.** The
> correction is below, and the short version is that **there is far less for you
> to do than we said**.

#### What we got wrong

We told you that no driver anywhere belonged to a company, and asked you to
start writing `users/{driverId}.companyId`.

**`companyId` is not a field this system uses.** We invented it, because we had
not found the admin panel's existing owners module — it was hidden from most of
the panel by a service-type condition in the sidebar. **Nothing reads
`companyId`, and nothing ever did.**

We also described a "Companies waiting to become carriers" tab in Carrier
Management, and `ownerId` / `carrierId` fields written on `delivery_carriers`.
**All of that has been withdrawn.** A company and a carrier are two different
things; the client confirmed it. Carrier Management is back to one plain table.

#### The field is `ownerId`, and your app is already writing it

The panel's owners module — which has existed all along — works like this:

```
an owner      users where role == 'driver' AND isOwner == true
its drivers   users where role == 'driver' AND ownerId == <the owner's user id>
```

Read from live data on 2 October, every `users` document, unfiltered:

| | |
|---|---:|
| drivers (`role == 'driver'`) | 247 |
| of which `isOwner == true` — the Owners list | 12 |
| of which `driverType == 'company'` | 6 |
| **`ownerId` filled in** | **7** |
| `ownerId` present but empty | 46 |
| `ownerId` field absent | 194 |
| `companyId` filled in | **0** |

**All seven `ownerId` values point at a real owner. None dangles.** So the link
works, and the app is writing it.

**All six companies are already flagged `isOwner: true`**, so all six already
appear in the panel's Owners list. Two of them have a driver attached today:

```
IT ADVISORY      1 driver
best company     1 driver
```

#### So what is actually left for you

**Nothing structural.** The claim that "no driver belongs to any company" was an
artefact of measuring a field that does not exist.

The one thing worth checking on your side: **46 drivers carry `ownerId` as an
empty string and 194 have no such field at all.** That is expected for an
independent driver and is not a bug — but if any of those 240 were *meant* to
have signed up under an owner, the sign-up path that produced them is not
writing `ownerId`. We cannot tell which from the data. **You can.**

> **Do not "fix" this by back-filling.** An empty `ownerId` is the correct state
> for an independent driver, and a Firestore equality filter drops documents
> that lack the field entirely — so writing `ownerId: ''` onto all 194 would
> change which records your own queries return.

#### 02#8: creation is NOT failing

Unchanged from before, and still true. **Six companies exist**, all written by
the Android app between 28 September and 1 October, carrying `driverType:
"company"` (older records use `isCompany: true`), `companyName`,
`companyAddress`, and their registration and licence fields.

They did not appear in the panel's *drivers* list because that list asks for
`isOwner == false` and a company is correctly `isOwner == true`. **They were
always in the Owners list instead** — which the client could not see, for the
sidebar reason above. **There is nothing to fix on your side for 02#8.**

#### Still yours: managing carrier settings from the app

02#19 also asks that *"this company should be able to manage their carrier
settings through the app"*. **That part is unchanged and still yours.**

What has changed is that we are no longer offering you `ownerId` /`carrierId` on
`delivery_carriers` as the way in — those were part of the withdrawn work.
**`delivery_carriers` is back to its original shape.** If you need a company
tied to a carrier record, tell us what the app expects and we will build that
side to match, rather than guessing a second time.


### 02#28 (01#27) — on-demand booking

**Yours:** the "Booking Date & Slot" field being unresponsive in the app.
**Ours:** *"the order cannot be placed on web customer"* — not investigated; we
have asked the client what actually happens on screen.

### 02#21 (01#20) — delivery proof

**Yours:** making the receipt code mandatory at delivery. Any setting that
switches it on would be ours, but nothing has been asked for yet.

### 02#18 (01#17) — "null" in displayed addresses

> *"123 Yaounde St, null, Tsinga"*

**Two separate problems, and the apps have both:**

1. **Display** — build the address from the parts that exist instead of joining
   fixed fields. Each panel and each app fixes its own.
2. **Data** — addresses already stored contain literal nulls. No display fix
   repairs those; it is a one-off clean-up and the client's decision.

We have not started either half. **Worth agreeing the display rule once** so the
apps and the panels do not each invent their own.

---

## 4. What we changed in the panels that your apps must match

**This is the section that causes drift if it is missed.**

### Wholesale is now for approved business accounts — the website only

Settled with the client on 30 September and **live on the customer website**:

- a **wholesale-only** product is hidden from a customer without an approved
  business account
- a normal product with bulk tiers stays visible at retail; the ladder and the
  tier price are withheld
- "approved" means `accountType == "business"` **and**
  `businessProfile.status == "approved"`

> ⚠️ **The app is unchanged and is now the more permissive side.** The same
> customer gets wholesale on their phone and not on the website — so **the phone
> is currently the way around the client's own rule.**

> `APP-SPEC-CUSTOMER-APP.md` **§8 documents wholesale applying to every
> customer** and needs rewriting. **§6's "business-only wholesale prices"**
> describes a category that, at the time, no field could express — the store
> panel's per-product `wholesaleBusinessOnly` has since been wired into the
> website, ORed with the platform rule so it can only tighten, never loosen.
> **`APP-SPEC-STORE-APP.md` §5 names that field and says nothing about what it
> does** — please say whether the app hides the product or withholds the price.

### Firestore rules — now urgent, not housekeeping

Rules were left unchanged by decision on 22 September. Since the wholesale gate
went live, **a customer writing `businessProfile.status: "approved"` to their own
document grants themselves a discount.** A record was found in exactly that state
on 29 September.

The same gap covers `subscriptionPlanId` and `subscriptionExpiryDate` — a
customer can give themselves a paid plan.

**`APP-SPEC-CUSTOMER-APP.md` §6 and §13 already flag this as needed.** It now has
a price attached.

### POS sales now credit the store as well as the owner

The admin panel's POS was crediting `users/{ownerId}.wallet_amount` only. It now
moves the store and the account together, as the store panel already did.

**This does not change what the apps write** — but it is the same
`applyVendorWalletDelta` shape, and `APP-SPEC-CUSTOMER-APP.md` §13 still lists
**crediting the store's wallet on order completion** as the apps' outstanding
job. That remains true.

> **Worth telling the client, and we have:** POS tax was not reset between sales,
> so a retry after a failed sale credited the previous sale's tax again. Some
> store balances may be **overstated**. If your apps read a balance and act on
> it, be aware the figure may be wrong until the client checks.

### Driver assignment no longer requires an `fcmToken`

An admin assigning a driver by hand can now choose one who has never opened the
app. **The assignment is written exactly as before; only the push notification is
skipped**, and the driver is labelled "app not installed" in the list.

If your app relies on the push to learn it has been assigned, **a driver may now
hold an order they were never notified about.** Worth confirming the app also
picks the assignment up from the order record.

---

## 5. What we need from you

1. **02#8 / 02#19 — WITHDRAWN. Please ignore it.** We asked you to write
   `companyId`; that field does not exist in this system and nothing reads it.
   The real field is `ownerId` and **your app is already writing it correctly**.
   Nothing structural is left for you here. See §3.
2. **The wholesale gate** — will the apps match it? Until they do, the phone is
   the way around it.
3. **`wholesaleBusinessOnly`** — does the app hide the product or withhold the
   price?
4. **The Firestore rules** — these are yours to the extent the app writes those
   fields. Someone has to deploy them.
5. **02#22** — confirm the website already does what the client wanted, so we can
   close our half.
6. **Driver assignment without a push** — does the app notice an assignment from
   the order record alone?

---

## 6. Unclear — the client has been asked, and the answer decides whose it is

| 02# | 01# | Question |
|---|---|---|
| 5 | 5 | "Mark as Completed" unresponsive in self-delivery — **which screen, a panel or an app?** Worth retesting after the 1 Oct POS fix; it is the same area |
| 9 | 8 | The schedule calendar fails "across the entire application (customer, store…)" — where exactly? |
| 27 | 26 | Worker account creation crashes on location input — **a panel does not "close automatically"**, which reads as an app |
| 31 | 30 | **Empty in both reports.** Each ends with a bare number and no text |
