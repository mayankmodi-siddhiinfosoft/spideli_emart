# A delivery company and its carrier: what the driver app expects

**For:** the admin panel team. **Date:** 7 Oct 2026.
**Answers:** BUG-REPORT-01-APP §3, 02#19 "Still yours: managing carrier
settings from the app", which says: *"If you need a company tied to a carrier
record, tell us what the app expects and we will build that side to match,
rather than guessing a second time."* Also client doc 36 (the app half of
02#19) and doc 43 (per-region pricing, several zones). Decision D6: the app
keeps its current lookup; the panel half is specified here, not guessed in code.

**Short version:** the admin sets **`users/{companyId}.carrierId` =
the id of a `delivery_carriers` document**. That is the only link the panel
needs to write. The company then edits that carrier's commercial settings and
per-region prices from the driver app. `delivery_carriers` keeps its original
shape; no `ownerId` / `carrierId` field is needed on it.

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
used by the company's **Carrier settings** screen
(`driver/lib/app/owner_screen/carrier_settings_screen.dart`, reached from the
owner dashboard), in this order:

1. **`users/{companyId}.carrierId`** (the app also reads the older spelling
   `deliveryCarrierId`): `delivery_carriers/{that id}` if it exists. **This is
   the link to build.**
2. Tolerant fallbacks, kept for records written before this contract: the first
   `delivery_carriers` document whose `ownerId`, `userId`, `ownerUserId`,
   `companyId` or `driverId` equals the signed-in account, its own id, or its
   `ownerId`.

When nothing is found the screen says no carrier is linked yet and writes
nothing. **The app never creates a `delivery_carriers` document** and never
writes `users.carrierId` (only the admin does; the rules forbid the account
itself).

> Please write `carrierId`, not `deliveryCarrierId`. A company document with
> only `deliveryCarrierId` is read as linked, but its next profile save writes
> `carrierId` with the same value, which the rules draft refuses as a
> self-change of the link.

---

## 3. What the company edits from the app

Only these `delivery_carriers` fields, under the panel's own keys, and only the
fields it actually changed (a known-fields merge; every other field stays as
the panel stored it):

| Field | Type |
|---|---|
| `name`, `phone`, `conditions` | string |
| `countryCode` | string, e.g. `"+237"` (picker) |
| `baseCharge`, `perKmCharge`, `perKgCharge`, `minimumCharge` | number >= 0, or `null` when emptied |
| `maxWeight`, `minDeliveryTime`, `maxDeliveryTime` | number, or `null` |
| `deliveryTimeUnit` | `"hours"` / `"days"` (a different stored value is kept) |
| `regionPricing.<regionId>.<charge>` | number or `null`, for `<charge>` in `baseCharge`, `perKmCharge`, `perKgCharge`, `minimumCharge`, and only for a `<regionId>` in the carrier's `regionIds` |

**Per-region pricing (doc 43).** A carrier with `regionIds` shows one input per
region and charge, prefilled from `regionPricing`, the flat charge as a
fallback. The app writes each changed price by its field path
(`regionPricing.r1.baseCharge`), never the whole map, and mirrors the **first**
region's values to the flat `baseCharge` / `perKmCharge` / `perKgCharge` /
`minimumCharge`, exactly as the panel does. A carrier with no `regionIds` keeps
one "everywhere" price in the flat fields.

**Shown, never written** (the admin's): `isVerified`, `code`, `regionIds`,
`operatingLicence`, `commercialRegister`, `uniqueIdNumber`,
`operatingLicenceFile`, `commercialRegisterFile`, `uniqueIdNumberFile`.

Older builds wrote `rates`, `deliveryTimes`, `contactName`, `email`; they are
read only to prefill an empty field and never written back.

---

## 4. What the panel must provide

1. **A way for the admin to link a company to a carrier:** on the Owners
   screen (or Carrier Management), pick a carrier for a company and write
   `users/{companyId}.carrierId = <carrierId>`; unlinking writes `''` (or
   deletes the field). One carrier per company. Show the link on both screens.
2. **Leave `delivery_carriers` as it is.** No owner field is needed there.
   `regionIds` and `regionPricing` keep the shape of doc 43.
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

## 5. Carrier-bound parcels and the company's drivers

Today the driver app's parcel search hides an order with a `carrierId` only
when the data says who that carrier's drivers are
(`CarrierDispatchService.driverServesCarrier`): the driver's own
`users.carrierId`, or driver / owner ids named on the carrier document. With
only `users/{companyId}.carrierId` set, nothing names the drivers, so the order
stays visible to every parcel driver, as before. The app is not changed further
(D6). The dispatch of carrier parcels belongs to `parcelDispatch`; the
suggested rule for its owners is: offer a parcel with `carrierId` only to
drivers whose `ownerId` is a company with `users/{ownerId}.carrierId ==
order.carrierId` (`.claude/DRIVER-DISPATCH-CONTRACT.md` section 8).

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
