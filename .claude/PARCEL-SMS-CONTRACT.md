# Parcel SMS to the receiver: what the apps write, what the server owns

**Date:** 7 Oct 2026. **Sources:** `app-spec-parcel-sms.md` (the SMS spec,
including the region fee of 7 Oct), client Point 54 (BUG-REPORT-01-APP §4 /
§5 item 15), decision D5. **Replaces** `.claude/PARCEL-SMS-OUTBOX.md` (retired).

**In one line:** the customer app records the sender's choice and the
receiver's number on `parcel_orders`; a **server-side trigger** on
`parcel_orders` composes and sends every SMS. No app composes SMS wording, sends
an SMS, writes `smsSent`, or writes `parcel_sms_outbox`.

> Parcel itself is still paused by the client (`app-spec-parcel-sms.md`). The
> app half below is built so the trigger can be added without an app release.

---

## 1. Fields the customer app writes on `parcel_orders`

At **creation** (`ParcelOrderConfirmationController`,
`ParcelShippingService.save(isNew: true)`, one known-fields write), next to the
existing `receiver` map (`name`, `phone` as `(+237) 677123456`, `address`, ...):

| Field | Type | Value |
|---|---|---|
| `receiverName` | string | the receiver's name, trimmed; omitted when empty |
| `receiverPhone` | string | the **national number, digits only, no country code**: `"677123456"`. A leading trunk `0` is dropped (`0677...` -> `677...`) except for countries whose numbers keep it after the code (+39, +378, +379, +225, +229, +241, +242) |
| `receiverCountryCode` | string | the dialling code from the phone field's country picker, `"+237"`: `+` and 1 to 3 digits, or a 4-digit North American code such as `"+1876"` |
| `sendReceiverSms` | bool | the sender ticked "Notify receiver via SMS"; `false` otherwise (always written) |
| `smsCharge` | number | the fee charged for it when ticked (section 2), **`0` when not ticked** (or free) |
| `smsOptOut` | bool | `false`, at creation only |
| `priceBreakdown.smsCharge` | number | the same fee, inside `priceBreakdown.total` |

`priceBreakdown.total` is the payable total **including** `smsCharge`. There is
no `total_pay` field in the apps (that name is the website's); readers should
use `priceBreakdown.total`.

**Validation** (`customer/lib/service/parcel_receiver_sms.dart`): the
receiver's mobile is required on every parcel booking; the country code is
required; the national number has at least 6 digits; code plus number at most
15 digits (E.164). An invalid number blocks the booking with a translated
message.

**When the option is offered:** `settings/SMSGateway.isEnabled == true` (read
fresh at checkout; an unreadable document = off, nothing offered or charged),
the order is not an unpriced quote request, and the order has both
`receiverPhone` and `receiverCountryCode`.

**Quote orders.** A quote request is created with `sendReceiverSms: false`,
`smsCharge: 0`. When the sender later **pays the priced quote**, the option is
offered again, and `sendReceiverSms`, `smsCharge` and `priceBreakdown.smsCharge`
are written on the **existing** order (status `Quote Requested` ->
`Order Placed`). So the trigger must react to **updates**, not only to creation
(section 4).

Checkbox text: "Notify receiver via SMS that a parcel has been sent (+50 FCFA)",
or "(Free)" when the fee is 0. The details screen and the receipt show a
"Receiver SMS" line (or "Free") whenever `sendReceiverSms` is true. The app
promises no message content.

---

## 2. The fee

`smsCharge` = `regions/{regionId}.parcelSmsFee`, where `regionId` is the
parcel's own `regionId`, else the region the sender's location resolves to.

| `parcelSmsFee` | Fee |
|---|---|
| a number, or numeric text (`"50"`, `"50,5"`) >= 0 | that amount; **0 = free** |
| missing, unreadable, negative, or the region unknown / not readable | **50** |

**There is no fallback to `settings/SMSGateway.parcelSmsFee`.** The newest bug
report (§4, Point 54) says the website and the admin panel keep the fee in
`settings/SMSGateway.parcelSmsFee`; the SMS spec of 7 Oct and decision D5 put
it per region. The apps follow the region. **Ask of the web / admin team:**
make the website checkout and the admin settings use
`regions/{regionId}.parcelSmsFee` too (Settings > Regions > Edit Region), so the
website and the app charge the same amount.

`settings/SMSGateway.isEnabled` only shows or hides the option; it is not the
fee and not a gate the trigger can skip.

**Where the fee goes.** It is outside VAT, coupons, commission and the
driver's credit, like the fixed intercity / intercountry tax:

```
total = subTotal - discount + order taxes
      + platformFee + platform-fee taxes (only when platformFee > 0)
      + parcelScopeTax + smsCharge (when sendReceiverSms)
```

The driver app shows and collects exactly this total
(`driver/lib/utils/parcel_amounts.dart`, the same formula as the customer's
`ParcelAmounts`). On completion of a **cash** parcel, besides the admin
commission, the driver's (or its company's) wallet is debited: "Parcel fixed
tax deducted" (`parcelScopeTax`), "Parcel receiver SMS fee deducted"
(`smsCharge`) and "Parcel platform fee deducted" (`platformFee` + its taxes),
once per order, after the completion is claimed. The platform-fee debit is new
and needs the client's confirmation.

**Refund on a customer cancel** (`customer/lib/service/parcel_cancellation.dart`,
both cancel paths): an order paid online is refunded to the wallet
`ParcelAmounts.total`, **minus `smsCharge` once the server has marked an SMS
sent** (`smsSent` holds an event set to `true` or a timestamp); while nothing
was sent the fee is refunded with the rest. Unpaid quotes and cash orders
refund nothing. (Client decision pending, section 6.)

---

## 3. What the apps never do

- compose SMS text, choose events, or read `settings/SMSGateway.templates` /
  `eventsEnabled` / the API key;
- write `smsSent` (any app, ever) or `smsOptOut` after creation;
- write `parcel_sms_outbox` or `sms_log`;
- write a whole `parcel_orders` model back. Every later write is field-level
  (`update()` or a known-fields merge), so `smsSent`, `smsOptOut` and the flat
  receiver fields survive: the customer's cancel writes only `status`, the
  reason fields, `parcelStatus`, `trackingEvents` (and clears the offered
  driver); the driver app writes only `status`, `driverId`, `driverID`,
  `driver`, `rejectedByDrivers`, `driverRejections`, `receiverPickupDateTime`,
  `regionId`, `parcelStatus`, `trackingEvents`, `deliveryProof`,
  `driverCredited`.

**The driver app** reads `receiverName`, `receiverPhone`,
`receiverCountryCode`, `sendReceiverSms` and `smsCharge` read-only (flat fields
first, the `receiver` map as fallback): the accepted parcel's home card shows
the receiver's name and phone with a call button; the details, list, scan
result, company list and incoming-offer dialog show the same; the details
"Order Total" lists Platform fee, its taxes, Fixed tax and Receiver SMS (or
"Free"). It never writes any of those fields
(`driver/test/parcel_sms_charge_test.dart`).

---

## 4. What the server trigger owns

Whoever builds it (a Cloud Function on `parcel_orders` writes, per
`app-spec-parcel-sms.md`) owns:

- **the wording**: `settings/SMSGateway.templates.<event>`, admin-editable;
- **the events**: `settings/SMSGateway.eventsEnabled` (array of event keys);
- **send-once**: `parcel_orders.smsSent.<event>`, checked and set in a
  transaction before calling OBITSMS, so a retry or a double write never pays
  twice;
- **the log**: one `sms_log` document per attempt (`parcelOrderId`, `event`,
  `destination`, `message`, `responseCode`, `success`, `regionId`, `createdAt`);
- **the opt-out**: `smsOptOut` (the app writes `false` once; afterwards only the
  server / admin);
- **the key and the sender id**, read server-side only.

**Inputs from the order:**

| Template placeholder | Field |
|---|---|
| `{receiver}` | `receiverName`, else `receiver.name` |
| `{sender}` | `sender.name` (Point 54 also asks for the sender's phone: `sender.phone`) |
| `{code}` | `trackingNumber` (`SPD-yyMMdd-XXXXXX`) |
| `{point}` | the destination pickup point: `destinationPickupPointId` -> `pickup_points/{id}` (name / address) |
| destination | `receiverCountryCode` digits + `receiverPhone`, e.g. `237677123456` (OBITSMS wants plain digits, country code first) |

An older order (before 7 Oct) may have only the `receiver.phone` text
`(+237) 677123456`; the trigger may parse it or skip the order.

**Event mapping** (the strings the apps write):

| Event key | When |
|---|---|
| `placed` | `sendReceiverSms == true` and `status` is not `Quote Requested`: on creation, **or on the update** that pays a priced quote and turns `sendReceiverSms` true |
| `atPickupPoint` | `parcelStatus` becomes `At destination pickup point` |
| `delivered` | `parcelStatus` becomes `Delivered` (eMart `status` `Order Completed`) |

The other `parcelStatus` values the apps write are `Created`, `Paid`,
`Waiting drop-off`, `Collected`, `At origin pickup point`, `In transit`,
`Arrived destination`, `Out for delivery`, `Returned`, `Cancelled`; every
change also appends to `trackingEvents` (`{status, at, by, role,
pickupPointId?, note?}`).

The apps assume **`sendReceiverSms` gates every receiver SMS of the order**
(the sender paid once for "notify the receiver"), and that nothing is sent
while `smsOptOut` is true.

---

## 5. Rules (`firestore.rules.draft`, not deployed)

- `parcel_orders` create: `smsSent` absent, `smsOptOut` absent or `false`,
  `sendReceiverSms` a bool, `smsCharge` a number >= 0.
- `parcel_orders` update: nobody but the admin (and the server) changes
  `smsSent` or `smsOptOut`; `sendReceiverSms`, `smsCharge` and the flat receiver
  fields change only by the order's author while the order is
  `Quote Requested` (the quote payment).
- `parcel_sms_outbox`, `sms_log`: no client access.
- `regions` stays public read, admin write (the fee is read before checkout).

If the website writes `smsSent` itself at creation (the report's example shows
`smsSent: {placed: true}` on an order), these rules refuse that create: the
website must leave `smsSent` to the trigger.

---

## 6. Open questions

**For the client** (from `app-spec-parcel-sms.md`, ask all at once):

- [ ] Which events text the receiver? Each event is one paid SMS per parcel.
      The recommendation is `placed` and `atPickupPoint`.
- [ ] The exact wording of each message, and the language (French in
      Cameroon; accented letters cut a message from 160 to 70 characters).
- [ ] Is the pickup-point notification an SMS to the receiver, a push to the
      sender, or both?
- [ ] Is the SMS fee kept when an order is cancelled after a text went out
      (what the app does), or always refunded, or never refunded?
- [ ] Does the sender also need a text? (The sender has the app; push reaches
      them.)
- [ ] The cash platform-fee debit from the driver's wallet (section 2).

**For the server / web team:**

- [ ] Who builds and owns the trigger (and the SMS bill)?
- [ ] React to updates as well as creates (quote payment, `parcelStatus`).
- [ ] Use `regions/{regionId}.parcelSmsFee` on the website and in the admin,
      not `settings/SMSGateway.parcelSmsFee`.
- [ ] Move the OBITSMS key out of the client-readable `settings/SMSGateway`.

**Answered by the app:** the receiver's number **is required** to place a
parcel order (validated, with its country code); the app does not own the
trigger.

---

## 7. Files

| File | What |
|---|---|
| `customer/lib/service/parcel_receiver_sms.dart` | gateway check, region fee, number normalisation and validation |
| `customer/lib/controllers/parcel_order_confirmation_controller.dart` | the checkbox, the total, the fields written at checkout / quote payment |
| `customer/lib/service/parcel_shipping_service.dart` | `save()` (creation writes `smsOptOut: false`), `append()` |
| `customer/lib/service/parcel_cancellation.dart` | the customer's cancel and its refund |
| `customer/lib/models/parcel_order_model.dart` | the fields, read and written (never `smsSent` / `smsOptOut` after creation) |
| `customer/test/parcel_receiver_sms_test.dart` | fee and number rules |
| `driver/lib/models/parcel_order_model.dart`, `driver/lib/utils/parcel_amounts.dart` | read-only receiver fields, the total |
| `driver/lib/services/parcel_tracking_service.dart` | field-level status writes, the cash wallet debits |
