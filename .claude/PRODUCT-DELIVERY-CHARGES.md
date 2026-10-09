# Product-level delivery charges (Doc 60) and tax country names (Doc 61) — Customer app

Source: `APP-SPEC-PRODUCT-DELIVERY-CHARGES.md` §2 / §4 and `BUG-REPORT-01-APP.md` §5 items 17 and 18.
This note covers the CUSTOMER app (`customer/`). The Store app's tier editor is a separate piece of work.

## 1. When it applies

- `sections/{sectionId}.is_delivery_charge_customization == true` (boolean `true`, or the text `"true"`), read when the cart loads and read again by `validateCartBeforePayment` before any payment. The section is the cart store's `section_id`, or the open service's id if the store has none.
- The admin sets the flag only for `ecommerce-service` / `multivendor-delivery-service`, and the app treats the flag itself as the switch.
- **Exception (client decision, 9 Oct 2026):** a store that delivers its orders itself (`vendors.isSelfDelivery == true` with the self-delivery feature on) is always **free delivery**, even when the flag is on; its product tiers are not applied.
- **Admin catalogue import (confirmed by the client, 9 Oct 2026):** a product imported from `admin_products` copies that template's `delivery_charges`.
- If the flag is false, missing, malformed or unreadable, the delivery charge is calculated exactly as before: `settings/DeliveryCharge` for the store's region, the flat e-commerce `sections.delivery_charge`, the vendor-level `deliveryCharge` and self-delivery.
- TakeAway orders still have a delivery charge of 0.

## 2. Where the numbers come from

- `vendor_products/{id}.delivery_charges`: an array of up to 5 tiers `{delivery_charges_per_km, minimum_delivery_charges, minimum_delivery_charges_within_km}`. Each value may be a number or a numeric string.
- Missing, unreadable or negative values count as 0. Array entries that are not maps, or that hold none of the three fields, are dropped.
- Tiers are read from `vendor_products` (`FireStoreUtils.getProductById`), never from the cart line cached on the phone. They are read when a product first appears in the cart, and again for every line at checkout.
- `ProductModel.deliveryChargeTiers` is read-only. `toJson` does not write it, so the stock update at order time (`setKnownFields`) leaves the field as it is.
- Distance is the Haversine great-circle distance in km (Earth radius 6371 km) from the selected delivery address to the store position (`VendorModel.latitude/longitude`, from its tolerant parser). It is always km, whatever `distanceType` is set to.
- A store without a position still cannot take a Delivery order: `validateCartBeforePayment` blocks it as before. In that case the distance counts as 0 until the customer switches to TakeAway.

## 3. The rule (`customer/lib/utils/product_delivery_charge.dart`)

Per item, at distance `d` km:

1. No tiers: the item's charge is **0**.
2. Sort the tiers by `minimum_delivery_charges_within_km` ascending.
3. The **first tier whose withinKm >= d** applies, and the item's charge is that tier's `minimum_delivery_charges`. The boundary is inclusive.
4. If `d` is beyond every tier's withinKm, the tier with the **largest withinKm** applies: `minimum_delivery_charges + (d - withinKm) * delivery_charges_per_km`.
5. A negative or non-finite `d` counts as 0 km. The result is rounded to 2 decimals.

With a single tier this is exactly the spec formula: `d <= withinKm ? min : min + (d - withinKm) * perKm`.

**Order charge = the MAXIMUM item charge in the cart, not the sum.** If it comes to 0, the cart shows "Free Delivery".

Example tiers: `[{150, 1500, 5}, {180, 2200, 10}, {200, 3000, 15}]` (perKm, min, withinKm):

| d (km) | charge |
|---|---|
| 2 | 1500 |
| 5 | 1500 |
| 7 | 2200 |
| 12 | 3000 |
| 20 | 3000 + 5 × 200 = 4000 |

## 4. Cart, checkout and order

- `CartController.calculatePrice`: in product mode, `deliveryCharges` is the order charge above. No `settings/DeliveryCharge`, no flat e-commerce charge and no vendor charge is used, and `_loadDeliveryCharge` does not read the setting.
- Everything after the delivery charge in `calculatePrice` works on this amount unchanged: the coupon and special discount on the subtotal, delivery tax (`driverDeliveryTaxList`, applied to the delivery charge as before, still not for self-delivering stores), tips, packaging, platform fee, total and cashback.
- `validateCartBeforePayment`:
  - re-reads the section flag and every product's tiers, then recalculates;
  - if the Delivery charge now differs from the one on screen, it stops with "The delivery charge has been updated. Please check the new total before paying." so the customer is charged exactly what they were shown.
  - If the flag was switched off since the cart opened, it loads `settings/DeliveryCharge` again.
- The order is `vendor_orders` (this app's collection; the spec says `restaurant_orders`). The charge is written to the existing **`deliveryCharge`** field with the existing type (a string of the number). No new order field is added.
- Display:
  - The cart's "Delivery Fee" row shows the amount, or "Free Delivery" when the product charge is 0.
  - Order details shows "Free Delivery" whenever the charged `deliveryCharge` is 0, otherwise the amount. For self-delivery stores this is the same as before. A self-delivering e-commerce store with a flat fee now shows its real fee.
  - The receipt PDF shows the order's `deliveryCharge` as before.

## 5. Tax country names (Doc 61)

- **Problem:** the device reverse-geocodes the country in its own language ("Cameroun", `isoCountryCode` "CM"), but the admin saves taxes with the English name from `countriesdata.json` ("Cameroon"). So `tax where country == "Cameroun"` returned nothing.
- **Fix:** the customer app's only tax query is `FireStoreUtils.getTaxList`, called from `ServiceListController._navigate` for every service (food, e-commerce, cab, intercity, rental, parcel, on-demand, dine-in). It now queries `country whereIn TaxCountry.queryNames(...)` and keeps each tax once, by doc id. The values it asks for are:
  - the name the device reported;
  - the English name for the ISO code;
  - that name's English aliases (for example GB gives "United Kingdom", "UK" and "Great Britain");
  - at most 30 values in all.
- **When the geocoder gives no ISO code:** a few local names are recognised, such as "Cameroun" → CM and "Tchad" → TD.
- **Where the names come from:** the ISO → English table is in `customer/lib/utils/tax_country.dart`. It was generated from the English list of the bundled `country_code_picker` package, with formal names given their common form first.
- `settings/globalSettings.taxScope` is applied as before (`product` / `order`). Only the country match changed.
- **Other apps:** the Store app (`vendor/lib/utils/fire_store_utils.dart` `getTaxList`) still queries `country isEqualTo <geocoded name>` and has the same problem. The Driver app's `getTaxList` was removed earlier. Provider and Worker do not query `tax`.

## 6. Tests

- `customer/test/product_delivery_charge_test.dart`: parsing, the section flag, a single tier, several tiers, the max rule, empty tiers and distance edge cases.
- `customer/test/tax_country_test.dart`: ISO and local-name normalisation and the query values.
