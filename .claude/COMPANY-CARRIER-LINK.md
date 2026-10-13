# A delivery company and its carrier: what the driver app expects

**For:** the admin panel team. **Date:** 7 Oct 2026.
**Answers:** BUG-REPORT-01-APP §3, 02#19 "Still yours: managing carrier
settings from the app", which says: *"If you need a company tied to a carrier
record, tell us what the app expects and we will build that side to match,
rather than guessing a second time."* Also client doc 36 (the app half of
02#19) and doc 43 (per-region pricing, several zones). Decision D6: the app
keeps its current lookup; the panel half is specified here, not guessed in code.

**Short version:** the admin sets **`users/{companyId}.carrierId` =
the id of a `delivery_carriers` document** (and, since the binding of 9 Oct,
`delivery_carriers/{id}.ownerId`). The company then edits that carrier's
commercial settings and per-region prices from the driver app. **Since 13 Oct
2026 an owner with no carrier can also create its own** from the app
("Set up your carrier", section 2a); it stays unverified and unpublished until
the admin verifies and publishes it.

---

## 1. Terms

| | Where | Panel screen |
|---|---|---|
| **Company** (fleet owner) | `users/{companyId}`: `role: "driver"`, `isOwner: true`, `driverType: "company"` (older: `isCompany: true`) | Owners |
| **Its drivers** | `users` with `role: "driver"` and `ownerId == companyId` | Owners > drivers |
| **Carrier** | `delivery_carriers/{carrierId}` (admin spec §11) | Carrier Management |

A company and a carrier are different records (confirmed by the client). The
link below says "this company manages that carrier".

---

## 2. How the driver app finds the company's carrier

`CarrierDispatchService.myCarrier()` (`driver/lib/services/carrier_dispatch_service.dart`),
used by the owner's **Carrier settings** screen
(`driver/lib/app/owner_screen/carrier_settings_screen.dart`, reached from the
owner dashboard, shown only to an account with `isOwner == true`):

1. **`users/{ownerId}.carrierId`** (the app also reads the older spelling
   `deliveryCarrierId`): `delivery_carriers/{that id}`. **This is the only
   lookup** (since 12 Oct 2026 the fallbacks by `ownerId` / `userId` /
   `companyId` / `driverId` are gone: the binding of 9 Oct is 1-to-1).

When the owner has no `carrierId` the screen (and the owner's home) only says
*"Your carrier has not been set up yet — please contact Spideli."* (translated)
and writes nothing.

**Superseded on 13 Oct 2026** (the 12 Oct rule "the app never creates a carrier
and never links one" no longer holds): see 2a. The app still never re-binds an
owner who already has a carrier, never writes `ownerId` of an existing
carrier, and never changes `isVerified` / `publish` / `code`.

### 2a. "Set up your carrier" (13 Oct 2026)

An owner (`isOwner == true`) **registered with the Parcel service**
(`serviceTypes` holds `parcel_delivery` / `parcel-service`) and with no
`carrierId` (`CarrierSetupForm.needsSetup`) is taken to **Set up your carrier**
automatically when the owner dashboard opens (right after sign-up, or at the
first login once approved; once per app launch, so closing it leaves the owner
on the dashboard). The owner home then shows *"You have not set up your carrier
yet."* with a **Set up your carrier** button; Carrier settings offers the same
button to any owner without a carrier. The registration numbers given at
sign-up are pre-filled.

**An owner NOT registered with the Parcel service has no carrier screens at
all** (`CarrierSetupForm.offersCarrier`): no "Carrier settings" in the drawer,
no reminder on the owner home, no automatic set-up, and Carrier settings
(if reached) only says *"Carrier settings are for parcel delivery companies
only."* The form (`driver/lib/app/owner_screen/carrier_setup_screen.dart`,
pure rules `driver/lib/utils/carrier_setup_form.dart`) asks for:

| Field | Required | Stored as |
|---|---|---|
| Carrier name (pre-filled from `companyName`) | yes | `name` |
| Phone + dial code | yes | `phone`, `countryCode` |
| Email | no (valid if given) | `email` |
| Logo photo | no | `photo` |
| Regions served (published `regions`) | at least one | `regionIds` |
| Delivery scopes | at least one | `deliveryScopes` |
| Max weight, min / max delivery time, unit, conditions | no | `maxWeight`, `minDeliveryTime`, `maxDeliveryTime`, `deliveryTimeUnit`, `conditions` |
| Prices of each selected region: base, per km, per kg, minimum | **yes: no carrier is created without them** | `regionPricing.<regionId>.<field>`; the first region's four also flat |
| The five door / pickup-point values of each region | no (blank = region default) | `regionPricing.<regionId>.<field>` |
| Operating licence, commercial register, unique ID (+ a photo each) | no | `operatingLicence`, `commercialRegister`, `uniqueIdNumber`, `...File` |

`CarrierDispatchService.createOwnCarrier` writes, in ONE batch, the new
`delivery_carriers/{id}` with `ownerId` = the owner, **`isVerified: false`,
`publish: false`**, `createdFrom: "driver_app"`, `createdAt` / `updatedAt`,
and `users/{ownerId}.carrierId = id`. A carrier already carrying
`ownerId` == the owner (a set-up whose binding did not land) is bound
instead of creating a second one. Photos go to Storage
`carrierDocuments/{ownerId}/`.

The customer app offers only carriers with `publish == true` and
`isVerified != false`, so a new carrier is invisible to customers until the
admin verifies and publishes it. The prices can be changed later in Carrier
settings. **Admin panel:** list carriers with
`createdFrom == "driver_app"` and `isVerified == false` for review, set
`code`, verify and publish.

Rules draft: `ownCarrierCreateOk` (create: owner without a carrier, `ownerId`
== self, `isVerified` / `publish` explicitly false, no `code` / fixed taxes,
at least one region and `regionPricing` for exactly its `regionIds`) and `ownCarrierLinkOk` (the owner's `carrierId` may go from
empty to a carrier whose `ownerId` is the owner, checked with `getAfter` in the
same batch).

> Please write `carrierId`, not `deliveryCarrierId`. A company document with
> only `deliveryCarrierId` is read as linked, but its next profile save writes
> `carrierId` with the same value, which the rules draft refuses as a
> self-change of the link.

---

## 3. What the owner edits from the app (brief of 12 Oct 2026, section 6)

Only these `delivery_carriers` fields, under the panel's own keys, and only the
fields it actually changed, through a Firestore **`update()` with field paths**
(`DeliveryCarrierModel.updatePaths`); never a `set()` of the document:

| Field | Type |
|---|---|
| `name`, `phone`, `email`, `conditions` | string |
| `countryCode` | string, e.g. `"+237"` (picker) |
| `maxWeight`, `minDeliveryTime`, `maxDeliveryTime` | number >= 0, or `null` when emptied |
| `deliveryTimeUnit` | `"hours"` / `"days"` (a different stored value is kept) |
| `deliveryScopes` | list of `city` / `intercity` / `intercountry`, at least one (missing on the carrier = all three, and is only written when the owner changes it) |
| `regionPricing.<regionId>.<key>` | number >= 0 or `null` (blank = "use the region default"; `0` = free), for `<key>` in `baseCharge`, `perKmCharge`, `perKgCharge`, `minimumCharge`, `volumetricDivisor`, `homePickupCharge`, `pointDropoffCharge`, `homeDeliveryCharge`, `pointCollectionCharge`, and only for a `<regionId>` in the carrier's `regionIds` |
| `baseCharge`, `perKmCharge`, `perKgCharge`, `minimumCharge` (flat) | the first region's four prices mirrored, as the panel does; or, on a carrier with no `regionIds`, its one "everywhere" price |

**One block per region** in `regionIds`, labelled with the region's currency,
prefilled from `regionPricing.<regionId>` as stored (an unset value stays empty).
Each empty door / pickup-point value shows the region default from
`regions/{regionId}.parcelPricing` as its hint. Strings stored by older carriers
(`"20"`) are left untouched unless the owner changes that value.

**Shown, never written** (the admin's): `isVerified`, `publish`, `ownerId`,
`code`, `regionIds`, `operatingLicence`, `commercialRegister`,
`uniqueIdNumber`, `operatingLicenceFile`, `commercialRegisterFile`,
`uniqueIdNumberFile`, and the region fixed charges (`intercityFixedTax`,
`intercountryFixedTax`, which live on the region, never on the carrier).

Older builds wrote `rates`, `deliveryTimes`, `contactName`; they are read only
to prefill an empty field and never written back.

---

## 4. What the panel must provide

1. **A way for the admin to link a company to a carrier:** on the Owners
   screen (or Carrier Management), pick a carrier for a company and write
   `users/{companyId}.carrierId = <carrierId>`; unlinking writes `''` (or
   deletes the field). One carrier per company. Show the link on both screens.
2. **`delivery_carriers`** keeps the shape of doc 43 plus the binding of 9 Oct
   (`ownerId`) and the parcel pricing keys of 12 Oct (`deliveryScopes`, the
   five values in each `regionPricing.<regionId>`; see `.claude/PARCEL-PRICING.md`).
3. **Read the company's own fields** written by the driver app (Owners >
   Company details):
   - `companyName`, `companyAddress` (asked for and saved since 7 Oct; absent on
     the six older companies), `commercialRegister`, `operatingLicence`,
     `uniqueIdNumber`, and the files `commercialRegisterFile`,
     `operatingLicenceFile`, `uniqueIdNumberFile` (Storage URLs, do not
     `encodeURI` them);
   - **`zoneIds`** (doc 43): the zones the company serves, a list, written at
     company sign-up and on its profile screen, with the legacy single
     `zoneId` = the first. A driver the company creates is given one zone out
     of `zoneIds`. Please show and edit `zoneIds` on the owner screens; a
     screen that reads only `zoneId` sees just the first zone.

---

## 5. Carrier-bound parcels: the company owner assigns (12 Oct 2026)

**Decision (client, 12 Oct):** a parcel booked with a delivery company is
**never** dispatched or offered directly to a driver — not even to the
company's own drivers. The **company owner** receives it and assigns it to one
of its drivers; only then does that driver get it. (Before: a carrier parcel
stayed visible in every parcel driver's search unless the data named the
carrier's drivers.)

### 5.1 Customer app: placing the order

Every carrier path — normal, scheduled, quote request, quote payment (the
carrier picked on the carrier-selection list of `BookParcelController`) —
goes through `ParcelOrderConfirmationController.placeOrder` and
`ParcelShippingService.save`, which write the order **unassigned**:

| Field | Value |
|---|---|
| `carrierId` | the `delivery_carriers` id the customer picked |
| `carrierOwnerId` (+ `companyOwnerId`, same value) | the company account: `users` where `carrierId` (else `deliveryCarrierId`) == the carrier **and** a company account (`isOwner: true` / `driverType: "company"` / `isCompany: true`); fallback: the owner named on the carrier document (`ownerId`, `userId`, ...); resolved again on every save (`ParcelShippingService.carrierOwnerId`, pure part `customer/lib/utils/carrier_owner_link.dart`) |
| `sendToDriver` | `false` |
| `driverId`, `driverID` | `null`; no `driver` snapshot |
| `status` | `Order Placed` (`Quote Requested` for a quote request) |

Non-carrier parcels are unchanged. When the order is an order (not a quote
request: on placing, or when a priced quote is paid) the customer app sends
the owner the templated push **`carrier_parcel_order`** (text only from
`dynamic_notification`; a missing template follows the customer app's usual
template behaviour) to the live `users/{carrierOwnerId}.fcmToken`, data
`{type: "carrier_parcel_order", orderId}`, on the driver app's job channel
`driver_jobs` (`driver_jobs_rt_<key>` with the order ringtone). No
notification record is written for the owner: the driver app has no
notification centre for driver / owner accounts; the owner's Orders list is
the record.

### 5.2 Driver app: the owner's Orders list

Owner dashboard > Orders (`OwnerOrderListScreen`, parcel section): the
company's parcels are `parcel_orders` where `carrierOwnerId` (or
`companyOwnerId`) == the owner, or `carrierId` == the owner's
`users.carrierId`, plus those its drivers carry. Tabs: **Pending** (waiting
for assignment: `Order Placed` / `Driver Rejected`, nobody named),
**Assigned** (`Driver Pending`, offered to a company driver), In Transit,
Delivered, Cancelled, All. A tap on the owner push opens this page.

**Assign driver / Reassign** (`CarrierParcelService.assign`, rules in
`driver/lib/services/carrier_parcel_rules.dart`): the owner picks one of its
drivers (`users` with `ownerId` == owner, not a company account, `role`
driver, `active` not false; online first, online / offline shown; a driver who
rejected the order before is marked). One transaction re-reads the order and
writes only if it is still the company's and **not accepted**: `Order
Placed`, `Driver Rejected`, or `Driver Pending` (a reassign before the driver
answered). Refused: `Quote Requested` (not paid), `Driver Accepted` /
`Order Shipped` / `In Transit`, ended orders.

| Write | Fields |
|---|---|
| `parcel_orders/{id}` | `status: "Driver Pending"`, `driverId` = `driverID` = the driver, `assignedBy` = owner uid, `assignedAt` = `dispatchedAt` = server time, `sendToDriver: false`, `rejectedByDrivers` arrayRemove the driver, `driver` deleted |
| `users/{driver}` | `orderRequestData` arrayUnion the order id (same transaction) |
| `users/{replaced driver}` | `orderRequestData` arrayRemove (after, best effort) |
| push to the driver | template **`carrier_parcel_assigned`**, channel `driver_jobs`, data `{type: "parcel", orderId, id, click_action: "FLUTTER_NOTIFICATION_CLICK", status: "Driver Pending"}` (the parcel-offer data: the incoming-order dialog with its countdown) |

The driver then answers with the normal offer flow (D2 / D3 of
`DRIVER-DISPATCH-CONTRACT.md`): accept writes `Driver Accepted` as for any
parcel and the customer gets `parcel_accepted`.

### 5.3 The driver rejects or the offer times out: back to the owner

`DispatchOfferService` (reject and timeout) writes, for a parcel with
`carrierId` / `carrierOwnerId`, **instead of** `Driver Rejected`:
`status: "Order Placed"`, `sendToDriver: false`, `driverId: null`,
`driverID: null`, `rejectedByDrivers` arrayUnion the driver (a manual reject
also its `driverRejections` reason), and the driver's `orderRequestData`
loses the id. The owner gets the templated push **`carrier_parcel_returned`**
(data `{type: "carrier_parcel_order", orderId}`, job channel) and assigns
again. `Order Placed` was chosen over `Driver Rejected` so the order looks
"new, waiting" to the customer and the owner; the dispatch function must skip
it anyway (5.5).

### 5.4 Nobody else sees a carrier parcel

- Parcel search (`ParcelSearchController`, `ParcelDispatchService.isOfferable`,
  `CarrierDispatchService.driverServesCarrier`): a carrier parcel is never
  listed, for independent **and** company drivers.
- Accept (`DispatchOrderRules.acceptCheck`): a carrier parcel is accepted
  only when it names the driver **and** carries the owner's `assignedBy`
  (`assignedBy` == `carrierOwnerId` when the order names one); never from the
  open search or a legacy request.
- Offers (`IncomingOfferService`): a `Driver Pending` carrier parcel naming
  the driver without the owner's `assignedBy` (e.g. a dispatch function that
  does not skip carrier parcels yet) is never shown (no dialog, no card) and
  is handed back to the owner at once (the timeout write of 5.3).

### 5.5 Still needed outside the apps

1. **Cloud Function `parcelDispatch` must SKIP every parcel with a non-empty
   `carrierId` or `carrierOwnerId`** (on `Order Placed` and on
   `Driver Rejected`). The apps cannot stop the function; until it skips
   them, a function offer of a carrier parcel is bounced back to the owner by
   the driver app (5.4), which costs a round trip and may notify the owner.
2. **Admin: three `dynamic_notification` templates** (same shape and
   `service_type` as the existing parcel templates, e.g. `parcel_accepted`;
   the apps send no text of their own):

   | `type` | To | Suggested subject | Suggested message |
   |---|---|---|---|
   | `carrier_parcel_order` | company owner | New parcel order | A customer booked a parcel with your company. Open Orders to assign a driver. |
   | `carrier_parcel_assigned` | company driver | New parcel assigned | Your company assigned you a parcel. Accept or reject it. |
   | `carrier_parcel_returned` | company owner | Parcel not taken | Your driver did not take the parcel. Open Orders to assign another driver. |
   | `carrier_parcel_picked_up` | company owner | Parcel picked up | Your driver picked up a parcel. |
   | `carrier_parcel_delivered` | company owner | Parcel delivered | Your driver delivered a parcel. |
   | `parcel_picked_up` / `parcel_in_transit` / `parcel_arrived_destination` | customer | Parcel picked up / on its way / arrived | (customer app, en + fr/ar as the admin writes them) |

   Without a template the app sends nothing for that step (no fixed text).

3. **Rules** (`firestore.rules.draft`, not deployed): the owner's assignment
   writes `Driver Pending`, names a driver and shrinks `rejectedByDrivers`,
   which the draft reserves for the admin / functions; and it adds to another
   user's `orderRequestData`. Add a fleet-owner branch: the caller is the
   order's `carrierOwnerId` (or its `carrierId` is the caller's
   `users.carrierId`), the old status is `Order Placed` / `Driver Rejected` /
   `Driver Pending`, the new one `Driver Pending` naming a driver whose
   `users.ownerId` is the caller, `assignedBy` == caller; and on
   `users/{driver}` let the fleet owner (`fleetOwnerOf`) change only
   `orderRequestData`. The driver's hand-back to `Order Placed` already
   passes the draft's guards (it names nobody and adds only its own uid).

---

## 6. Rules (`firestore.rules.draft`, not deployed)

- `users/{uid}.carrierId`: never changed by the account itself, never by a
  store or a fleet owner on its staff, empty on every sign-up and staff
  creation; **only the admin** sets it.
- `users/{companyId}` own writes of `companyAddress`, `zoneIds`, `zoneId`,
  `companyName` and the company numbers / files: allowed (not guarded).
- `delivery_carriers/{id}`: read by signed-in accounts; create / delete admin
  only; update by the admin, or by the linked company (`users/{me}.carrierId ==
  id`, or the fallback owner fields of section 2) limited to the fields of
  section 3 plus `regionPricing`, where only entries of regions in the
  carrier's `regionIds` may change.

The panel writes the link as the admin (custom claim `admin: true` or
`users/{uid}.role == "admin"`, `.claude/FIRESTORE-RULES-DRAFT.md` section 5).
