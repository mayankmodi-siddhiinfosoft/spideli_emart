# Mandatory cancellation / rejection reasons — one contract for all five apps

Client requirement (2 Oct 2026): for any order or service cancellation or
rejection, the Customer, Restaurant (store), Driver, Provider and Worker must
give a reason before the action completes. The reason is stored with the order,
shown on the Order Details screen to every relevant user, and the screen says
WHO cancelled or rejected it.

## The rule
- No cancel / reject / decline action may change anything until a reason is
  chosen or typed. Backing out of the reason sheet changes NOTHING — no status,
  no refund, no wallet reversal, no notification.
- Reasons come from `settings/cancellationReasons.<role>` (an array of strings)
  when present, else the app's built-in defaults for that role. The list always
  ends with "Other", which requires free text (trimmed, at least 3 characters).
- Reuse each app's existing cancel-reason sheet (customer `CancelReasonSheet`,
  driver `CancelReasonSheet`, store `cancel_reason_sheet.dart`); build the
  provider/worker one the same way with the design system.

## What is written on the ORDER / BOOKING / RIDE / PARCEL document
A FINAL cancellation or rejection (the order stops):

| Field | Value |
|---|---|
| `cancelReason` | the text shown to people (the chosen reason, or the typed "Other" text) |
| `cancelReasonCode` | the stable code: the chosen list entry, or `other` |
| `cancelledBy` | `customer` \| `vendor` \| `driver` \| `provider` \| `worker` \| `admin` |
| `cancelledByName` | the display name of whoever acted (optional, for the details screen) |
| `cancelledAt` | server timestamp |
| `cancelAction` | `cancelled` \| `rejected` — which of the two it was |

Written as a known-fields merge alongside the status change, in the same write.
Read tolerantly: older store records wrote `cancelledBy: "vendor"`; treat
`store`/`restaurant` as the same party. Never clear these fields on a later save.

A driver PASSING on an offer is not a final rejection — the order goes back to
dispatch. That keeps the existing shape:
`driverRejections: [{ driverId, reason, code, at, afterAccept }]` (arrayUnion)
plus `rejectedByDrivers`. The reason is still mandatory.

### Driver passes vs. final cancellations (dispatch, 7 Oct 2026)

The Cloud Functions dispatch every order (`.claude/DRIVER-DISPATCH-CONTRACT.md`).
A driver never ends an order; everything a driver does to an offer is a
**pass**, and a pass **never writes the final fields** above (`cancelReason`,
`cancelReasonCode`, `cancelledBy`, `cancelledByName`, `cancelledAt`,
`cancelAction`).

| Driver action | Order write | Reason |
|---|---|---|
| **Reject** an offer (dialog or module card) | `status: "Driver Rejected"`, `rejectedByDrivers` arrayUnion own uid, `driverId: null`, `driverID: null` | **mandatory**: `driverRejections` arrayUnion `{driverId, reason, code, at, afterAccept: false}`. Backing out of the sheet writes nothing |
| **Timeout** (the countdown ran out, or the app opened after it did) | the same status / `rejectedByDrivers` / null driver fields | **none**: no `driverRejections` entry, the reason sheet never opens |
| Automatic decline of a ride outside the driver's region | the same | none |
| **Pass** on an open parcel / rental in the search list (`Order Placed`, nobody named) | `rejectedByDrivers` arrayUnion own uid only; status unchanged | mandatory, `driverRejections` |
| **Hand back** an accepted ride or rental before pickup | `Driver Rejected`, `rejectedByDrivers` arrayUnion own uid, both driver fields null, `driver` deleted | mandatory, `driverRejections` with `afterAccept: true` |

`rejectedByDrivers` is the functions' exclusion list: a driver in it is never
offered that order again. Only its own uid is ever added by a driver (rules
draft); the customer and the store never write it, nor `driverRejections`.

### Customer cancels

Customer cancels are **transaction field updates** on the live order (never a
whole model): `status`, the final fields above, and nothing else except:
parcels also `parcelStatus` / `trackingEvents` (`Cancelled` event); and, from a
status where no driver has accepted yet, `driverId: null` and `driverID: null`
(the driver the dispatch was only offering it to comes off the order).

| Service | Customer may cancel at | Status written |
|---|---|---|
| Ride | `Order Placed`, `Driver Pending`, `Driver Rejected`, `Order Accepted` with no driver | `Order Rejected` |
| Rental | `Order Placed`, `Driver Pending`, `Driver Rejected`, `Driver Accepted` | `Order Cancelled` |
| Parcel | `Order Placed`, `Quote Requested`, `Driver Pending`, `Driver Rejected`, while the parcel is still with the sender (`parcelStatus` empty, `Created`, `Paid`, `Waiting drop-off`) | `Order Cancelled` |

The **parcel refund** (paid online only) is the full charged total, **minus
`smsCharge` once the server has sent a receiver SMS** (`smsSent` holds a sent
event); while nothing was sent, the SMS fee is refunded too
(`.claude/PARCEL-SMS-CONTRACT.md` section 2).

A booking the dispatch auto-cancels (no driver accepted in time) is ended by
the Cloud Function. The functions are asked to write the final fields too
(`cancelledBy: "admin"` or `"system"`); the customer app reads any value and
shows "Your ride was cancelled" with the reason when there is one.

### Store app

The store's reject and cancel write the reason fields **in the same
transaction as the status**, and only if the order's status (and its delivery
man) is unchanged since the reason sheet opened; otherwise nothing is written
and the store is told the order was updated meanwhile. The store never writes
`rejectedByDrivers`, `driverRejections` or `pod`, and writes `driverId` /
`driverID` only to name its own delivery man (self delivery).

## What the Order Details screen shows
Every order/booking/ride/parcel details screen, in every app, for a cancelled or
rejected record shows one clear block:

  **Cancelled by Restaurant** (or Rejected by Driver, Cancelled by Customer…)
  Reason: <cancelReason>
  <date and time>

Labels by `cancelledBy`: customer → Customer, vendor/store/restaurant → the
section's own word (Restaurant / Store), driver → Driver, provider → Service
provider, worker → Worker, admin → Admin. A record with no reason (cancelled
before this rule existed) shows "No reason recorded" — never a blank or "null".
Where the store or admin can see them, list `driverRejections` underneath as
"Passed by drivers".

The list card (not only the details screen) shows a one-line version:
"Cancelled by Customer · Changed my plans".
