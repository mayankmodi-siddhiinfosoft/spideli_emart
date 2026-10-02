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
