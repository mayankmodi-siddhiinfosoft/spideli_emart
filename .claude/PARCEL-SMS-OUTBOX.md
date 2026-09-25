# Parcel SMS outbox — the app-side trigger

Answers the open question of **APP-SPEC-ADMIN §17** ("who owns the SMS trigger?")
for the app half only. The panel's `SmsController` and `settings/SMSGateway`
(§16) already send. What was missing is anything that *asks* for a send, because
the apps write parcel statuses straight to Firestore and never pass through
Laravel.

The apps now write **one request document per message** into a new collection,
`parcel_sms_outbox`, in the same batch as the status change that triggered it.
Whatever sends — the panel, a Cloud Function or a cron — reads pending documents
and calls OBITSMS.

> **The apps never call the SMS API.** No API key, sender id or endpoint ever
> ships in an app binary; the apps do not even read those fields. They read
> `settings/SMSGateway.isEnabled` and `.parcelEvents` and nothing else from it.

> **Inert until the panel turns it on.** With `settings/SMSGateway` absent, or
> `isEnabled` anything other than `true`, the apps write nothing at all — the
> gateway document is read once per app session and cached.

---

## 1. The document

Collection **`parcel_sms_outbox`**, one document per message. Nothing else is
written; the sender owns `sendState`, `sentAt` and `error`.

| Field | Type | Written by the app |
|---|---|---|
| `id` | string | The document id, repeated in the body. `<orderId>_<status slug>` (status lower-cased, every run of non-alphanumerics becomes `_`), e.g. `9f3c…_out_for_delivery`. |
| `orderId` | string | `parcel_orders/{id}`. |
| `trackingNumber` | string | `SPD-yyMMdd-XXXXXX`. Always present — an order without one is not under the tracking contract and is never queued. |
| `parcelStatus` | string | The tracking status that triggered the message, exactly as written to `parcel_orders.parcelStatus`. |
| `to` | string | The receiver's number as **plain digits, country code first**, already normalised (see §4). This is the value to pass to OBITSMS `destination` — do not re-derive it. |
| `countryCode` | string | The dial code that was split off `to`, digits only (`237`). |
| `language` | string | The app's UI language code (`en`, `fr`, …) — the language `message` is written in. **Omitted** when the app has no locale. |
| `message` | string | The finished SMS body. Composed in the app from the translated template for `parcelStatus` (see §5). Send it as it stands. |
| `createdAt` | timestamp | `FieldValue.serverTimestamp()`. |
| `sendState` | string | Always `"pending"` on creation. |
| `source` | string | `"customer_app"` or `"driver_app"` — which app queued it. |

Example:

```json
{
  "id": "9f3c1b2a-…_out_for_delivery",
  "orderId": "9f3c1b2a-…",
  "trackingNumber": "SPD-250925-K7M2QX",
  "parcelStatus": "Out for delivery",
  "to": "237612345678",
  "countryCode": "237",
  "language": "fr",
  "message": "Your parcel SPD-250925-K7M2QX is out for delivery today.",
  "createdAt": "2025-09-25T09:14:03Z",
  "sendState": "pending",
  "source": "driver_app"
}
```

### Never twice for the same order + status

The document id is derived from `orderId` + `parcelStatus`, and the app **reads
that id first and skips when it exists** — in any state, including one the sender
already marked `sent`. Two devices racing on the same scan can at worst write the
same id once. A retried or re-recorded status therefore never queues a second
message, and the sender never has to de-duplicate.

**Consequence for the sender:** never delete a document to retry it — a delete
re-opens the id and a later status write could queue the same message again. Move
it to a failed state instead (§6).

---

## 2. When an app writes one

Always in the **same `WriteBatch` as the status write**, so a request cannot
exist for a status change that failed, and a status change never happens without
its request. When no message is due, the original single write is used unchanged
— the batch exists only when there is something to add to it.

The one exception is a **refused batch**: if the rules of §6.6 are missing, the
apps log it and fall back to the plain status write with no message queued. An
SMS must never cost a customer their booking or a driver their scan.

| App | Code | Statuses written there |
|---|---|---|
| customer | `ParcelShippingService.save()` — order created, and a priced quote being paid | `Created`, `Paid`, `Waiting drop-off` (only `Created` has a message) |
| customer | `ParcelShippingService.append(…, order: …)` — the customer cancels (both the booking list and the order detail) | `Cancelled` |
| driver | `ParcelTrackingService._writeStatus()` — every scan, the legacy *Pickup Parcel* and *Deliver Parcel* buttons, and the hand-over at a pickup point | `Collected`, `In transit`, `Arrived destination`, `At destination pickup point`, `Out for delivery`, `Delivered` |

`Returned` is in the default set for whoever records it; no app screen writes it
today, so it is the panel's status until one does.

Of those, only the statuses in §3 are actually queued. No existing write changed
its semantics, its idempotency or its proof rules; money, completion and the
wallet credit are untouched.

---

## 3. Gating

A document is written only when **all** of these hold:

1. `settings/SMSGateway.isEnabled == true`.
2. The order is a parcel order under the tracking contract — it has an id and a
   `trackingNumber`.
3. The status is in the configured event set (below).
4. The receiver's phone normalises (§4).
5. No document exists yet for this `orderId` + `parcelStatus`.

### `settings/SMSGateway.parcelEvents`

An **array of tracking-status strings**. Absent (or not an array) = the default
set. Present = exactly that set, intersected with the statuses the apps can
compose a message for; an empty array switches every message off while leaving
`isEnabled` alone. Panel UI: a checkbox list, defaulting to the six below.

**Default set** (what gets sent when `parcelEvents` is absent):

```
["Collected", "In transit", "At destination pickup point",
 "Out for delivery", "Delivered", "Returned"]
```

A home-delivered city parcel therefore costs 3 SMS (collected → out for delivery
→ delivered); a pickup-point parcel 3 (collected → in transit → at destination
pickup point).

**Also selectable, off by default:** `"Created"`, `"Arrived destination"`,
`"Cancelled"`. Anything else in the array is ignored — including
`"Paid"`, `"Waiting drop-off"` and `"At origin pickup point"`, which concern the
sender, not the receiver, and have no message template.

---

## 4. The receiver's number

`to` is normalised **in the app**, because the panel's `normaliseNumber()`
cannot invent a missing country code (§16). The app accepts, in order:

- `(+237) 6 12 34 56 78` — what the booking form writes (its own country-code
  field, then the number). The brackets hold the dial code.
- `+237612345678` — E.164, but the dial code can only be split off when it
  matches the platform's own `defaultCountryCode`.
- `612345678` — a bare national number: the platform's `defaultCountryCode` is
  assumed, and nothing else ever is.

Then: non-digits stripped, a leading trunk `0` dropped from the national part,
and the result rejected unless the dial code is 1–3 digits and the whole number
is 8–15 digits.

**A number that does not normalise is never queued.** The app skips the message
and logs why (`ParcelSmsOutbox: <tracking> / <status> not queued — the receiver
phone cannot be normalised…`); the status write itself is unaffected. A wrong
number costs money and OBITSMS code **902**, so this is deliberate.

---

## 5. The message

Composed in the app from the per-status templates in
`customer/lib/service/parcel_sms_outbox.dart` and
`driver/lib/services/parcel_sms_outbox.dart`. The templates are ordinary
translation keys (`.tr`, keyed by the English text, as everywhere else in these
apps) with `{tracking}` and `{code}` substituted by the app; the English text
lives in each app's `lib/lang/app_en.dart`, and a locale without an entry falls
back to English. The pickup-point message appends the order's `pickupCode` when
it has one — that code is how the receiver collects the parcel.

The sender must **not** rewrite, re-translate or template the body. It may
truncate only if OBITSMS rejects the length; every template is one short
sentence and stays inside a single 160-character segment in English.

---

## 6. What the sender must implement

1. **Watch or poll** `parcel_sms_outbox` for `sendState == "pending"`, oldest
   `createdAt` first. A Cloud Function on document-create is the cheapest and is
   the only trigger that fires whoever moved the parcel; a cron over the same
   query works as well. A `sendState` + `createdAt` query needs a composite index.
2. **Claim before sending** — a transaction that re-reads the document and moves
   it from `pending` to `sending`, so two workers cannot send the same message.
3. **Send** through the existing `SmsController` path: OBITSMS v2
   `GET /bulksms?key_api=…&sender=…&destination={to}&message={message}`, with
   `key_api` and `sender` read from `settings/SMSGateway` **server-side**.
4. **Record the outcome on the same document:**
   - `sendState: "sent"`, `sentAt: <server timestamp>` on code **900**;
   - `sendState: "failed"`, `error: "<code> <message>"` otherwise — **902** (bad
     number) and **903** (bad message) must never be retried, **901** (no
     credit) should be left for a manual retry after a top-up.
   These three fields belong to the sender; the apps never read or write them.
5. **Never delete a document to retry** (see §1) and never re-queue a document
   the apps wrote — write the retry state onto the same document.
6. **Firestore rules** must let a signed-in customer/driver `create` and `get`
   documents in `parcel_sms_outbox`, and must forbid apps from updating or
   deleting them. The `get` is the duplicate check; without it the apps log the
   failure and queue nothing.

---

## 7. Files

| File | What it holds |
|---|---|
| `customer/lib/service/parcel_sms_outbox.dart` | Gating, normalisation, templates, `requestFor()` / `addToBatch()` |
| `customer/lib/service/parcel_shipping_service.dart` | `save()` and `append()` commit the request with the status |
| `customer/test/parcel_sms_number_test.dart` | The normalisation rules of §4 |
| `driver/lib/services/parcel_sms_outbox.dart` | The same, for the driver app |
| `driver/lib/services/parcel_tracking_service.dart` | `_writeStatus()` commits the request with the status |
| `customer/lib/constant/collection_name.dart`, `driver/lib/constant/collection_name.dart` | `parcelSmsOutbox = 'parcel_sms_outbox'` |
| `customer/lib/lang/app_en.dart`, `driver/lib/lang/app_en.dart` | The message templates |

Both apps keep their own copy of the outbox service — they share no package, and
the two copies must stay identical in shape, gating, id derivation and template
text. Change one, change the other.
