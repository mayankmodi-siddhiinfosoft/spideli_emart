# Client Bug Report 01 — Admin Panel

**Source:** `REPORT-OF-BUGS-01.pdf`, sent by the client 1 October 2026.
**Scope of this file:** the items in that report that belong to **this panel**.
The store panel and the customer website have their own files
(`BUG-REPORT-01-STORE.md`, `BUG-REPORT-01-WEB.md`), and **everything belonging
to the apps is in `BUG-REPORT-01-APP.md`** — which also lists what we changed in
the panels that the apps must match. `BUG-REPORT-01-STATUS.txt` carries every
point in one list.

**The report numbers 1–29.** Item 30 is a heading with no text and no
screenshot — the document simply ends. Worth asking what was meant.

---

## Contents

| # | Item | State |
|---|---|---|
| 28 | Links inject the record id into the domain | ✅ **fixed and live, 1 Oct** |
| 22 + 23 | Documents screen could not draw provider or worker rows | ✅ **fixed and live, 1 Oct** |
| 16 | Zone list ignored the region on the EDIT screens | ✅ **fixed and live, 1 Oct** |
| 9 | "No driver found" assigning from the list | ✅ **fixed and live, 1 Oct** |
| 24 + 25 | Nowhere to review a provider's or worker's documents | ✅ **fixed and live, 1 Oct** |
| 18 | A company driver is not listed under carrier management | not started |
| 7 | Company drivers missing from the drivers list | not started |
| 02#1 | Errors completing an order on POS | ✅ **fixed and live, 1 Oct** |
| 2 | Show the selected store location clearly | shared with the store panel |
| 17 | `null` in displayed addresses | cross-panel |
| 5, 20, 25, 26, 29 | partly ours, partly the apps | see each |

---

## 28. Links injected the record id into the domain — FIXED

> *"The link on these button below is incorrect and leads to an error page! It
> should normally start with spideli.com/…"*

### What it was

Links were built from an **absolute** route URL with `id` standing in for the
record, then `.replace("id", value)` — which changes the **first** match. On
`spideli.com` the first `id` sits inside the domain, `sp·id·eli.com`:

```
https://sp76bdmwmt2gugelpful5ybeblstj3eli.com/admin/parcel_orders/id
```

The host was corrupted and the real placeholder at the end survived untouched,
which is exactly what the client's screenshots show.

**It could only ever fail on the live domain.** Development runs on
`192.168.1.9`, which contains no `id`, so the identical code produced correct
links. That is why it reached production.

### Scale

**121 call sites in 45 views** — the client found two. Zero in the store panel,
zero in the customer website.

### The fix

`spideliRouteWithId(template, value)` in `layouts/app.blade.php`, replacing `id`
only where it is a whole path segment or a whole query value:

```js
template.replace(/([/?=&])id(?=$|[/?#&])/, function (match, delimiter) {
    return delimiter + value;
});
```

Three shapes had to keep working, because the panel produces all three:

| Route | Produces | Becomes |
|---|---|---|
| `parcel_orders.driver` | `/admin/parcel_orders/id` | `/admin/parcel_orders/<id>` |
| `orders` (takes no parameter) | `/orders?id` | `/orders?driverId=<id>` |
| `url("items?brandID=id")` | `/items?brandID=id` | `/items?brandID=<id>` |

15 assertions cover it, including four host variants left untouched
(`spideli.co.id` among them), dev hosts still working, a path containing
`identity/videos` unharmed, and a value containing `$&` inserted literally.

The rewrite was applied mechanically and **baselined**: the JS of all 45 files
was extracted before and after — 17 checker limitations before, the same 17
after, identical file list. Nothing was introduced.

> **Never clicked by us.** We cannot sign into the live panel. The client
> confirmed it working on 1 October.

---

## 22 + 23. The Documents screen — FIXED

> *"Error in the admin web panel when creating a verification document for
> service providers"*
> *"DataTables warning: table id=documentTable — Requested unknown parameter
> '4' for row 5, column 4"*

**One fault, reported twice** — 22 is what the admin was doing, 23 is what they
saw. Creating a document redirects to the list, and the list is what threw.

### What it was

`buildHTML()` chose the "Document For" cell with an if / else-if chain over
**driver, vendor and owner — and no else**:

```js
if (val.type == "driver") { html.push(…) }
else if (val.type == "vendor") { html.push(…) }
else if (val.type == "owner") { html.push(…) }
```

But the create and edit screens have **always offered five types** — `provider`
and `worker` as well. A provider document pushed **nothing**, so its row was one
cell short, every later cell shifted left, and DataTables was asked for a column
that did not exist.

### The record was never at fault

**A correction to our own first assessment.** From the client's screenshot we
said a document had been *"saved without a Document For"* and that this needed a
data fix as well as a code fix. **That was wrong, and we had not checked.**

Read from live Firestore on 1 October:

| Title | Type |
|---|---|
| Indentity Card | **provider** |
| ID Card | vendor |
| ID Card | driver |
| ID Card | owner |
| FSSAI Certificate | vendor |
| Driving License | driver |

`Indentity Card` is a correctly saved provider document. Nothing is wrong with
the data. **The list simply could not draw it.** No data change is needed and
none was made.

### The fix

A lookup covering all five types, and **one `push` that always runs**:

```js
var documentForLabels = {
    'vendor': …, 'driver': …, 'owner': …, 'provider': …, 'worker': …
};

html.push(documentForLabels[val.type] || val.type || '-');
```

A type nobody has a label for falls back to the raw value rather than an empty
cell — an untranslated heading is a small annoyance; a row that breaks the whole
screen is not. All five labels already existed in both `en` and `ar`.

**The create path needed no change.** `documentTargetFor()` already handles all
five types, including workers living in `providers_workers` rather than `users`.

### Verified

20 assertions: every one of the five types plus an unknown one plus a missing
one yields a **full row** at both permission levels (5 cells with delete rights,
4 without); the old code is shown to be one cell short for exactly `provider`
and `worker`; and the live `Indentity Card` record now renders its label.

JS baselined before and after — 0 failures both ways. `php -l` and `view:cache`
clean.

> **Live since 1 October**, confirmed working by the client. We never saw the
> screen draw — we cannot sign into the live panel. Worth creating a **worker**
> document too, since that type was equally broken and nobody has reported it.

---

## 16. Zone list ignored the region — FIXED

> *"During store or driver registration, selecting a region must dynamically
> filter the zone dropdown/selection list to display only the zones assigned to
> that specific region."*

### A correction to our first reading

We first said *"confirmed in code — no region filter at all"*, from grepping the
Firestore query:

```js
var refZone = database.collection('zone').where('publish', '==', true);
```

**That was wrong.** The filter exists and is applied **client-side after the
fetch**, which the grep never saw. The create screens have filtered all along.

### What was actually wrong — the edit screens

| Screen | Before |
|---|---|
| admin drivers / fleet drivers / stores **create** | filtered |
| admin stores **edit** | filtered |
| admin drivers **edit** | **not filtered** |
| admin fleet drivers **edit** | **not filtered** |

A driver could not be *created* outside the region but could be **edited into
one** — open the record, change a phone number, save, and the zone list offered
the whole world.

**The store panel was worse**, and is covered in `BUG-REPORT-01-STORE.md`: its
deliveryman form already resolved the store's region, with a comment saying a
deliveryman *"inherits that store's region"*, and then offered every zone anyway.

### The data was fine

Checked before building, because a filter over unassigned zones is useless.
**All five zones carry `regionIds`:**

| Zone | Regions |
|---|---|
| Junagadh-GJ, Ahmedabad-GJ | India |
| Worldwide | **a deleted region**, and India |
| Yaounde | Yaounde-Cameroun |
| Douala | Douala-Cameroun |

> `Worldwide` references a region id that is not in `regions`. It still resolves
> through India, so nothing breaks — but the stale id should be cleaned. Raised
> with the client.

### Two rules, applied everywhere

**Fails open.** No region on the record, or a zone never assigned to one, still
offers the zone. An empty dropdown stops the user working altogether — much
worse than one zone too many. This matches the panel's standing rule that an
unresolved region shows everything.

**An edit never drops the current zone.** A record already in a now-mismatched
zone keeps it in the list. Otherwise opening the form and saving would silently
move them: a fix that corrupts data is worse than the bug.

### Implementation

Both edit screens loaded zones **before** the record, so the region was not yet
known. The inline load became `loadDriverZones(regionId, currentZoneId)`, awaited
once the record is in hand and before the current zone is selected.

### Verified

10 assertions against the **live** zone data: a Yaounde store sees only Yaounde,
an India store sees its three including Worldwide, a Cameroon store can no longer
reach Ahmedabad, the stale region id matches nothing and harms nothing, and an
edit keeps a mismatched record's zone while still hiding the others.

JS baselined before and after — 0 failures both ways. `php -l` and `view:cache`
clean.

> **Live since 1 October.** We never opened the screens — we cannot sign into
> the live panel. The tests that matter most are saving an unchanged driver and
> confirming their zone did not move.

---

## 9. "No driver found" when assigning from the list — FIXED

> *"Orders cannot be assigned directly without opening the order details on the
> dashboard; attempting to do so triggers a 'No driver found' error."*

### The two screens asked different questions

| Screen | Query |
|---|---|
| `orders/edit` (works) | `where('vendorID', '==', vendorID)` — the store's **own** delivery men |
| `orders/index` (failed) | the **automatic dispatch** rules — who would the system *offer* this job to |

The second is the wrong question for a **manual** assignment. An administrator
choosing a driver by hand is making a deliberate decision, not waiting for
dispatch to find somebody.

### Three rules emptied it, each confirmed against live data

Read from Firestore on 1 October: **244 drivers, 21 of them active.**

| Rule | Effect |
|---|---|
| `if (driver.vendorID) return;` | skipped every store-owned driver — including **the only active driver in Cameroon**. A self-delivery order could never be assigned at all |
| `if (!driver.fcmToken) return;` | 20 → 8. Assignment still writes the order; only the push notification is lost |
| zone mismatch | the remaining 8 are all in India, the order was in Cameroon → **0** |

The distance radius was *not* a factor: `driverRadios` is 15000 km, effectively
global.

**This is the same self-delivery setup item 5 describes**, which is worth
remembering when that one is picked up.

### Hard rules and soft rules

**Hard — still excluded entirely:** works for a *different* store, already
rejected this order, already holding a job while `singleOrderReceive` is on, or
below `minimumDepositToRideAccept`.

**Soft — now only annotate:** no `fcmToken`, different zone, beyond the dispatch
radius. The driver is listed with the reason in brackets.

Sorted: the store's own drivers first and labelled as such, then those meeting
every rule, then the rest.

### A quieter bug fixed alongside

```js
.where('wallet_amount', '>=', minimumDepositToRideAccept)
```

**A Firestore inequality silently drops every document that lacks the field** —
33 of the 244 drivers — whatever the minimum is, *including zero*, which is the
live value. Now fetched without the inequality and filtered in memory, with a
missing balance read as zero.

The hardcoded English `"No drivers found"` became a translated key. Five keys
added in **both** `en` and `ar`.

### Verified

11 assertions against the real 21 active drivers and a Cameroon order from the
store that owns `Driver 2`:

- **old rules → 0 drivers**, reproducing the reported fault exactly
- **new rules → 21**, with the store's own Cameroon driver first and labelled
- a driver belonging to a *different* store is still excluded
- a balance below a non-zero minimum is still excluded
- a missing balance reads as zero rather than vanishing

JS baselined before and after — 0 failures both ways. `php -l` on all three
files, `view:cache` clean.

> **Live since 1 October.** Not clicked by us — we cannot sign into the live
> panel.

> **Worth telling the client, and we have:** 223 of their 244 drivers are
> inactive. Not a fault, but it is why the pool is thin.

---

## 24 + 25. Reviewing a holder's documents — FIXED (the panel half)

> *"For Services Providers: We didn't see where we can validate their documents
> in admin web panel."*
> *"For Drivers: How can they upload their documents … after registering."*

### The client was right, and the data proves it

`documents_verify` held **154 records on 1 October, three of them providers**,
with real uploaded images. **Providers have been sending documents with nowhere
in the panel to act on them.**

Drivers, vendors and owners each had a review screen. **Providers had none. Nor
did workers** — though `documents/create` has always offered Worker as a type.

The record shape is role-independent:

```
documents_verify/{holderId}
    id, type
    documents: [ { documentId, status, frontImage, backImage } ]
```

Live statuses: `uploaded`, `rejected`, `approved`. A required document with no
entry reads as `pending`.

### One screen, parameterised by role

`DocumentReviewController` + `documents/holder_list.blade.php`, at
`documents/review/{role}/{id}`, reached from a document icon on the providers
and workers lists.

**The three existing screens are deliberately untouched.** Normalising the role
word, `drivers/document_list` and `owners/documentIndex` differ by **29 lines of
313**, and their upload screens by **4 of 353**. Adding a fourth and fifth copy
would mean every future change landing in five places. They can be pointed at
this view later by changing a route — which is why the role map here mirrors
`documentTargetFor()` in `documents/create`. **Keep the two in step.**

### Four decisions

**`isActive` is NOT touched for providers or workers.** The driver screen sets
`isDocumentVerify` *and* `isActive` together. Copying that would switch a
provider on — or off — that the admin never chose to. `documentTargetFor()`
already records `activates: true` for drivers alone. The role config carries the
flag, so a role can opt in later. **Raised with the client as a one-line change
if they want driver behaviour.**

**Nothing is decidable until it is sent.** A `pending` document shows "Waiting
for upload" and no buttons. The driver screen offers approve on a document that
does not exist.

**One read, not one per row.** The driver screen re-reads the same
`documents_verify` document inside its loop — one read per required document.

**Re-read before writing.** The holder may have re-uploaded while the page sat
open; writing back a stale array would discard it. A document that has vanished
is refused with a message rather than written blind.

Also carried over from earlier fixes today: every row emits every cell (items 22
and 23), both Bootstrap 4 and 5 attribute namings, and Storage URLs escaped for
an attribute **without** `encodeURI`, so `%2F` survives.

### Verified

**25 assertions** against the live record shape: the status→buttons rules, a
row keeping three cells whatever is missing, image links only when the document
asks for that side *and* it was sent, the verified flag false while any required
document is unapproved or unsent, an extra approved document being harmless,
`isActive` untouched for these roles, and `%2F` surviving.

`php -l` on all seven, `view:cache` clean, no empty `e()`, JS 0 failures with
the two changed list screens baselined at 0 beforehand. The route builds for
both roles.

### Not built

**No admin-side upload screen** for provider or worker — the equivalent of the
existing pencil icon. Item 25's upload half is the **app's**: drivers upload from
their phone. The reviewing was what this panel owed. Offered to the client.

**126 of the 154 `documents_verify` records are orphans** — no matching user or
worker. The screen never shows them, since it looks up by holder id, but they
are worth clearing.

> **Live since 1 October.** Not opened by us — we cannot sign into the live
> panel. The test that matters most: approve every document for a provider and
> confirm their active state did **not** change.

---

### A route addition needs `route:clear` — and the screen should not depend on it

**Live fault on 1 October, within an hour of the upload.** The providers list
returned a 500:

```
Symfony\Component\Routing\Exception\RouteNotFoundException
Route [documents.review] not defined.
    resources/views/providers/index.blade.php:480
```

**Two separate mistakes, ours both.**

**1. The upload list said "AFTER UPLOADING, RUN NOTHING."** That was true of every
other upload that day — views and language files — but **this one added a
route**, and a server with a cached route table does not see a new route until
`php artisan route:clear`. The instruction should have said so.

> **Rule: any upload that ADDS OR RENAMES A ROUTE must tell the client to run
> `php artisan route:clear`.** Views and language files need nothing; routes do.

**2. One missing route took down the whole screen.** `route()` **throws** when a
route is not registered, and the call sat inside the row builder — so the entire
providers list failed, not just the one icon it was building.

Both links are now wrapped:

```blade
@if (Route::has('documents.review'))
… the document icon …
@endif
```

**Proven, not assumed:** rendering the same construct against a deliberately
absent route throws `RouteNotFoundException` unguarded and renders cleanly
guarded, with the icon simply absent.

> **This is the same shape as the footer sweep and the Documents table**: one
> missing thing costing a whole screen rather than the one feature that needed
> it. `providers/index` builds every row's action links inline, so any `route()`,
> `.data()` or field read that fails there costs the entire list. **The other
> admin list screens are worth the same pass** — not done.

---

## 18. Company driver not listed under carrier management

> *"When a driver registers as a 'Company', the company entity must
> automatically be listed among the available carrier management (in admin web
> panel) and this company should be able to manage their carrier management
> setting through the app."*

Two halves. **Ours:** a company registering must produce a carrier record this
panel lists. **Not ours:** the company managing its carrier settings from the
app.

Relates to `APP-SPEC-ADMIN.md` §19's standing item — *linking carriers to
drivers* — which has been open with the app developer since September. Until a
carrier is linked to its drivers, its orders are still offered to every driver.

---

## 7. Company drivers missing from the drivers list

> *"Creating a driver under the 'Company' type fails (no response or action
> occurs upon submission) and no entries display on admin web panel for
> drivers"*

The creation failure is the app's. **The listing is ours** — if a company driver
is written to `users` with a shape this panel's query does not match, it will
never appear however it was created.

Investigate what a "company" driver actually looks like in `users` before
assuming the list is at fault.

---

## 02#1 (was 01#1). Errors completing an order on POS — FIXED

> *"In admin and store web panel: We get errors when completing an order on
> POS."*

**Report 02 added "on POS".** We had asked five times for the error text; the
screen name was as good, and the cause was found without it.

### The fault

```js
let vendorAuthor = vendorDetails.author;   // the OWNER'S user id
…
await database.collection('vendors')
    .doc(vendorAuthor)                      // used as a STORE document id
    .update({ 'subscriptionTotalOrders': … });
```

**Firestore's `update()` rejects when the document does not exist.** Of the 26
live stores on 1 October, **not one** has an `author` that is also a `vendors`
document id. The write always failed.

**The store panel's POS already carried the fix**, with a comment describing
exactly this — corrected during the per-store wallet work in September. **This
panel never received it.**

### Why it looked intermittent

The write runs only when `parseInt(subscriptionTotalOrders) != -1`:

| `subscriptionTotalOrders` | stores | outcome |
|---|---|---|
| `-1` | 21 | skipped, sale works |
| a limited count | 2 | **throws** |
| **absent** | 3 | **throws** — `parseInt(undefined)` is `NaN`, and `NaN != -1` |

**5 of 26 — about one store in five.**

### Why it was silent

The throw landed **after** `manageInventory()` and **before** the order write,
in an async handler with no `try/catch`. Stock reduced, no order, no message,
spinner turning.

### Fixed

| | Panel |
|---|---|
| the subscription write targets `orderVendorID` | admin |
| `snapshotsnew.docs[0].data()` guarded — **6 of 26** stores name an author who is no longer a user | admin + store |
| `total_tax_amount` / `orderTaxAmount` reset per sale | admin + store |
| `try/catch` so a failure reports instead of freezing; vendor-not-found path hides the spinner | admin + store |
| credit via `applyVendorWalletDelta` so the **store's own balance** moves, not only the owner's account | admin |

The tax reset matters more than it looks: both are **page-level** variables, so
a retry after a failed sale added the previous sale's tax on top and
over-credited the store. With sales failing, retries were likely.

The wallet change closes `ADMIN-REMAINING-WORK` §1 for the POS path — the panel
was crediting the account alone, so a store's own balance never moved on a POS
sale.

### Verified

**15 assertions** against the live store data: the old target throws for exactly
the stores with the field set or absent, the new target succeeds for all three
shapes, the guard returns null rather than throwing, the reset stops the
double-count, and the credit reaches store and owner together.

Both panels: `php -l`, `view:cache` clean, no empty `e()`, JS baselined 0 → 0.

### Deliberately not changed

The order is still **inventory → wallet → order write**. A failure still stops
the sale with stock already reduced. Writing the order first would be more
robust — the order is the record of truth and a missing wallet credit is
visible and fixable, where missing stock with no order is neither. **Not done:
it reorders money and stock operations the client did not ask about.** Raised
with them.

> **Live since 1 October.** No sale put through by us — we cannot sign into
> the live panels.

---

## 2, 17, 5, 20, 25, 26, 29 — shared or partly ours

| # | Ours | Theirs |
|---|---|---|
| 2 | show the chosen store location on the admin's store form | also the store panel |
| 17 | format addresses so `null` never shows, in this panel | the stored `null`s are data; the apps display them too |
| 5 | if "Mark as Completed" is a panel button | if it is the app's |
| 20 | any setting that makes the receipt code mandatory | enforcing it at delivery is the app's |
| 25 | reviewing uploaded driver documents — see 24 | drivers uploading them is the app's |
| 26 | this panel has a worker create screen with a location field | *"crashes and closes"* reads as a mobile app |
| 29 | any proof-of-delivery record the panel must show | capturing it is the app's |

**26 needs the client to say which screen they meant** — a panel does not
"close automatically"; that wording describes an app.

---

## What we need from the client

1. **The error text for item 1.** Blocking.
2. **Item 26** — which application, the web panel or a mobile app?
3. **Item 30** — the report ends at a bare "30." with no content.
4. **Items 22/23** — set the bad record's "Document For", or delete it?
5. **Item 16** — confirm zones have been assigned to regions, otherwise the
   filter will correctly show an empty list.
