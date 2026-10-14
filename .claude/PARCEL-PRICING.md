# Parcel / Mail pricing in the apps (points 41 + 65)

**Source:** web team, `APP-DEV-BRIEF-12-10-2026-PARCEL-PRICING.md` and
`app-spec-parcel-pricing.md` (12 Oct 2026, field names final).
**Status:** implemented in the customer app (spec sections 4-7) and the driver
app (owner "Carrier settings", brief section 6). Not released.

Nothing is hard-coded any more: no 5,000 fixed charge, no 5000 divisor, no
`settings/ParcelPricing.intercityTax` / `volumetricDivisor` (only its
`commissionAsExtra` is still read). Every amount is in region R's currency
(R = the order's `regionId`, the sender's region) and is **never converted**;
`priceBreakdown.currency` = that region's currency code.

## Customer app

Pure pricing: `customer/lib/utils/parcel_pricing.dart` (unit tested in
`customer/test/parcel_pricing_test.dart`, brief cases A-E included).

| Step | Rule | Code |
|---|---|---|
| Settings | `regions/{R}.parcelPricing` (missing map = all unset), `delivery_carriers/{id}.regionPricing.<R>` (flat fields only without an entry for R; the flat card never carries the five values). Numbers parsed defensively (`"20"`, `null`, `""`) | `RegionParcelPricing`, `ParcelRateCard`, `parcelNumber` |
| 1 scope | The customer still picks Same city / Other city / Other country and the app's existing validation is kept; city names now compare trimmed, lower-case, without accents. `ParcelPricing.scopeFor` is the spec section 5 rule (zone fallback included) | `ParcelPlace.cityMatches`, `scopeFor` |
| 2 weight | divisor = carrier `regionPricing[R].volumetricDivisor` if > 0, else region's if > 0, else none; volumetricKg = L x W x H / divisor (2 decimals, 0 without a divisor or all three sides); chargeableKg = max(real, volumetric), 2 decimals | `resolveVolumetricDivisor`, `weightFor` |
| 3 carriers | `publish` (and not explicitly `isVerified: false`, as before), one of the order's candidate regions in `regionIds` (or none; R_c below), scope in `deliveryScopes` (missing / empty = all), `maxWeight` unset or >= chargeableKg | `DeliveryCarrierModel.servedRegion`, `isEligible`, `ParcelCarrierOption.carrierOffers` |
| 4 base | `rate_card`: base + perKm x km + perKg x chargeableKg, at least minimumCharge. `default` (no carrier, same city only, as before): band with minKg <= chargeableKg <= maxKg (maxKg null = no limit; a gap goes to the next band up) -> distance x `delivery_charge`; bands without minKg / maxKg: the old title matching. `extraKgCharge` 0. Carrier rate tables (`rate_table`) removed; `route_table` never used | `rateCardPrice`, `bandFor`, `carrierQuote`, `defaultQuote` |
| 5 options | pickupCharge = homePickupCharge / pointDropoffCharge by `pickupMethod`; deliveryCharge = homeDeliveryCharge / pointCollectionCharge by `deliveryMethod`; carrier value if set (0 = free), else region, else 0 | `resolveOptionCharges` |
| 6 fixedTax | region `intercityFixedTax` / `intercountryFixedTax`, city 0, not set 0; never the carrier's | `RegionParcelPricing.fixedTaxFor` |
| 7 total | `subTotal` = carrierPrice (+ commission only when `commissionAsExtra`, carrier offers only). The commission's type comes from `sections/{id}.adminCommision.commissionType`: a percentage is taken on carrierPrice ONLY (the delivery company's base price), a fixed one is its amount. Checkout: subTotal - coupon + order taxes + platform fee + its taxes + fixedTax (`parcelScopeTax`) + options + SMS fee = what wallet / gateway / cash charges, written to `priceBreakdown.total`. The order taxes apply to subTotal - coupon - `priceBreakdown.commission` (never below 0): no tax on the commission, in both apps | `ParcelPricing.withExtraCommission`, `ParcelPricing.taxableAmount` (driver `ParcelAmounts.taxableAmount`), `ParcelOrderConfirmationController.calculatePrice` |

**Region R, carriers and currency (fixes of 12 Oct, brief section 9 / web
report 41; candidates since 13 Oct).** The order has CANDIDATE regions,
`ParcelPricing.orderRegionCandidates`, in order of preference:

1. every region of the published zones containing the sender
   (`RegionService.zoneRegionListsAt`) - a zone often serves a country region
   and a city region ("Yaounde": Cameroun + Yaounde-Cameroun) - keeping only
   regions that exist (`regions/{id}`; a zone may still list a deleted one,
   "Worldwide" does); else
2. the published regions of the sender's country (`countryCode`); else
3. the customer's region (`RegionService.customerRegionId`).

Order: the customer's own region first when it is a candidate, then the most
specific - the region served by the fewest published zones (Yaounde-Cameroun,
1 zone, before Cameroun, 2) - ties in zone order.

* **Platform option** (no carrier): R = the first candidate - its band,
  region charges, fixed charge and currency; also the pickup points.
* **A carrier with `regionIds`** is offered when ANY candidate is in its
  `regionIds`, and priced in R_c = the first candidate it serves:
  `regionPricing[R_c]`, else its flat prices; options from that card, else
  `regions[R_c].parcelPricing`; fixed charge from `regions[R_c].parcelPricing`.
  A carrier without `regionIds` uses R. No candidate at all: only carriers
  without `regionIds`.
* The option carries its region (`ParcelCarrierOption.regionId`): the order is
  written with `regionId` = R_c (the platform: R), so its currency,
  `priceBreakdown.currency`, payment methods, SMS fee and receipts follow the
  option. The selection screen shows each option in its own region's currency.

Until 13 Oct R was ONE region, null whenever the sender's zone served several
regions and the customer's own was not among them - which, with the live
zones, was every Yaounde / Douala sender: every carrier with `regionIds` was
then dropped and, same city home to home, the carrier-selection screen was
skipped ("the carrier choice disappeared"). Before 12 Oct an unresolved R
offered every carrier in the default currency (FCFA to an India customer);
that stays fixed: a carrier is never offered outside its regions.
A carrier with no price at all for R_c (no `regionPricing[R_c]` prices and no
flat prices, e.g. IT ADVISORY) gives no quote and is left out, as on the
website. Tested on the live shapes in
`customer/test/parcel_carrier_regions_test.dart`.

**Weight band: moves up, never down** (`ParcelPricing.bandFor` with the
customer's band): the heavier of the band chosen and the band containing the
chargeable weight (the website's `effectiveBand()`). With no kg typed the
chosen band's top weight (`maxKg`, else the number in its title, else `minKg`
for the open top band) stands for the parcel.

**Platform fee:** checkout charges the section's platform fee (and its taxes)
only while `platformFee.enable` is true, and writes `platformFee` /
`platformTax` exactly as charged (`0` / `[]` otherwise). Before, a disabled fee
was still added to the total with no line on screen.
The same rule now applies to every customer checkout
(`customer/lib/utils/platform_fee_charge.dart`, `PlatformFeeCharge`, unit
tested): cab, intercity, rental, on-demand and the food / e-commerce cart add
the fee and its taxes only while the section's `platformFee.enable` is true,
show the "Platform fee" line only then, and record `platformFee` ("0.0") /
`platformTax` (`[]`) as charged. Paying or showing an existing ride, rental or
booking uses what it recorded, never today's setting. Intercity rides now
record their fee (they recorded none while the payment added the current
one). Choosing a section resets `Constant.platformFeeModel` /
`platformTaxList`, so a fee enabled in one section no longer carries over to
a section where it is disabled.

**Wallet payments: never money without the order** (12 Oct,
`customer/lib/utils/wallet_checkout.dart`, unit tested). Checkout used to
debit the wallet first and save the order afterwards, so a failed save lost
the money. Now the balance re-read, the debit, its `wallet` row and the order
(with its "Paid" event; a priced quote: its fields and events) are ONE
Firestore transaction (`FireStoreUtils.payFromWallet`): all or nothing, so
there is no "paid but not saved" or "saved but unpaid" state to undo or
retry. A refusal (balance too low, offline) writes nothing and tells the
customer; the screen stays for a retry. The carrier owner's push, the
customer's region and the booking email run only after the commit. Same for
the cart (stock, cashback, the store's push and email after the commit), cab
/ intercity / rental payments (the paid state in the same transaction), on-
demand bookings and their extra charges, and gift cards. (The on-demand
extra-charge payment also debited the customer's wallet a second time, under
a "provider credited" row, even for a card payment; removed - the provider
app credits the extras when the booking completes.) Customer plans already
debit atomically and retry only the record step.

**Order fields:** `scope`, `pickupMethod`, `deliveryMethod`, `dimensions`,
`weightKg` as before; `dropoffPointId` (sender's point, when pickupMethod is
`pickup_point`) and `pickupPointId` (receiver's point, when deliveryMethod is
`pickup_point`). Before this change `pickupPointId` held the ORIGIN point when
there was one. The app keeps `originPickupPointId` / `destinationPickupPointId`.

**Pickup points:** only `publish == true` and `regionId` = the region: the
sender's region for the drop-off point, the receiver's region (else R) for the
collection point. No fallback to every point any more.

**priceBreakdown** (`ParcelQuote.breakdown`): `source`, `currency`,
`actualKg`, `volumetricKg` (0 without divisor), `chargeableKg`,
`volumetricDivisor` (null when none), `carrierPrice`, `extraKgCharge`,
`options`, `pickupCharge`, `deliveryCharge`, `fixedTax`, `smsCharge`,
`commission`, `total`.

**Shown:** carrier selection and checkout breakdown cards, the checkout and
order-details summaries, the PDF receipt (pickup / delivery charge lines, else
"Options"), and every total (`ParcelAmounts`, order details, cancellation
refund, order-history export) include the options.

## Driver app

* **Totals / cash:** `ParcelAmounts` adds `priceBreakdown.options`
  (`driver/lib/utils/parcel_amounts.dart`), so the total shown and collected
  matches the customer's. In cash the options stay with the courier (not in
  `platformShareOfCash`); paid online they are now credited with the delivery
  charge (`ParcelTrackingService._updateWalletAmount`). Order details show a
  "Pickup and delivery options" line.
* **Carrier settings** (`carrier_settings_screen.dart`,
  `carrier_settings_controller.dart`, `utils/carrier_settings_form.dart`):
  owners only; no `users.carrierId` -> "Your carrier has not been set up yet —
  please contact Spideli." One block per `regionIds` region (currency in the
  title): four prices + five values, blank = `null` with the region default as
  hint, numbers as numbers, never negative; `deliveryScopes` (>= 1);
  `minDeliveryTime`, `maxDeliveryTime`, `deliveryTimeUnit`, `maxWeight`,
  `conditions`. Saved with `update()` field paths
  (`regionPricing.<R>.<key>`) of the changed keys only
  (`DeliveryCarrierModel.updatePaths`). Never written: `isVerified`, `publish`,
  `ownerId`, `code`, `regionIds`, documents, fixed charges.
* **No carrier creation or linking in the app** (see
  `.claude/COMPANY-CARRIER-LINK.md` section 2).

## Answer to brief 7b — how `rate_card` was priced

There is **no currency conversion** anywhere in the app (`Constant.amountShow`
only formats; checkout charges `subTotal` as stored), and no metres or grams:
the formula has always been
`max(minimumCharge, baseCharge + perKmCharge x km + perKgCharge x kg)`,
2 decimals. The differences come from its inputs:

1. **Which prices.** Since 6 Oct (doc point 43) the app prices a carrier with
   `regionPricing[R]`, R = the region of the SENDER's location, and uses the
   flat `baseCharge` / `perKmCharge` / `perKgCharge` / `minimumCharge` only when
   there is no entry for R. The flat fields hold the carrier's FIRST region's
   price. The 15 / 6 / 5 and 20 / 5 / 8 in the brief are the flat fields. Both
   Afrilight orders fit one block exactly: base 1,000, per km 500, per kg 600
   (1,000 + 500 x 527.351 + 600 x 2 = 265,875.51; 1,000 + 500 x 321.218 + 600 x
   1 = 162,209.01). Please check Afrilight's `regionPricing` for those orders'
   region: if that is what it holds, the app charged what the admin entered for
   that region. The single Spideli Express order cannot identify its block on
   its own (e.g. 700 / 250 / 500 also fits).
2. **Which kg.** kg was the chargeable weight: max(entered kg, L x W x H /
   `settings/ParcelPricing.volumetricDivisor`), that divisor defaulting to 5000
   when unset — so dimensions entered on the order raised the per-kg part.
   `priceBreakdown.actualKg` / `volumetricKg` were only written when dimensions
   were given.
3. **Which km.** Other city / Other country: the straight-line distance between
   the two addresses (not by road), converted to km; same city: the road route.

The new code keeps the same formula, with the divisor from the carrier / region
(no default) and the breakdown always recording the weights and divisor.

## Before release (admin / web team)

1. **Save every region's `parcelPricing`.** Until then a region gives a fixed
   charge of 0 (inter-city / inter-country orders lose the 5,000 F) and **no
   divisor** — the old app always applied 5000, so dimensions stop counting too.
2. Save the Parcel Weight screen so every band has `minKg` / `maxKg` (until
   then the old title matching is used).
3. Check each carrier's `regionPricing` (brief 7b above) and the region it is
   keyed by.
4. Pickup points must have `publish: true` and `regionId`; points without them
   are no longer offered.
5. Admin order screen: `pickupPointId` is now the RECEIVER's point;
   `dropoffPointId` the sender's (orders placed before the release: the old
   meaning).
6. Confirm the choice that door / pickup-point charges are the courier's
   revenue (credited to the driver / company on online payments, kept in cash).
