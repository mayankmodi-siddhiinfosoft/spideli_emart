# Client bug report — 1 October 2026

Reported by the client against the live apps and panels. Items marked PANEL are
not ours (admin / store web panel) and are listed only so nobody re-triages them.

| # | Report | Where |
|---|---|---|
| 1 | Error when completing an order | PANEL (admin + store web) |
| 2 | Creating a store: show the selected store location clearly | STORE app |
| 3 | Real-time chat notifications (push) | ALL apps (send on message) |
| 4 | Customer order tracking: map does not display | CUSTOMER app |
| 5 | Self delivery: "Mark as Completed" does not respond for certain orders | STORE app |
| 6 | Driver app chat opens a blank white screen | DRIVER app |
| 7 | Creating a driver of type "Company" fails, nothing happens on submit; none appear in the admin list | DRIVER app (+ panel listing) |
| 8 | The schedule-time calendar does not display anywhere (customer, store...) | CUSTOMER + STORE apps |
| 9 | Orders cannot be assigned from the dashboard without opening the order; doing so says "No driver found" | STORE app |
| 10 | Independent drivers cannot act on an order assigned to them | DRIVER app |
| 11 | Audible order alert on the store app when it is closed or in the background | STORE app |
| 12 | How does a vendor pay for a store advertisement inside the app? | STORE app |
| 13 | Customer chat: the keyboard covers the text field | CUSTOMER app |
| 14 | A vendor must give a reason when cancelling an order | STORE app |
| 15 | Multivendor home: move the search box into the same block as map view / QR scan | CUSTOMER app |
| 16 | Store and driver registration: choosing a region must filter the zone list to that region's zones | STORE + DRIVER apps |
| 17 | Addresses render raw "null" (e.g. "123 Yaounde St, null, Tsinga") | ALL apps |
| 18 | A driver registering as "Company" must appear in admin carrier management, and manage those settings from the app | DRIVER app + PANEL |
| 19 | Drivers receive no push notification when an order is available, in any module | DRIVER app + SERVER |
| 20 | The receipt code must be mandatory as proof of delivery | DRIVER app |
| 21 | Let customers type a quantity instead of tapping +/- (e.g. 80 units) | CUSTOMER app |
| 22-24 | Admin document screens: DataTables error; no screen to validate provider documents | PANEL |
| 25 | How do drivers upload licence, ID and vehicle documents after registering? | DRIVER app |
| 26 | Worker account creation crashes when setting the location | PROVIDER app |
| 27 | On-demand: "Booking Date & Slot" is unresponsive in the app; order cannot be placed on web | CUSTOMER app (+ panel) |
| 28 | A button links to a wrong URL (should start with spideli.com) | PANEL |
| 29 | Multivendor / e-commerce: how is proof of delivery captured when a driver completes? | DRIVER app |

## How to work these

- **Reproduce before changing anything.** Several of these are "nothing happens",
  which is usually a guard failing silently, an exception swallowed in a handler,
  or a widget that never gets a tap target — find the cause, do not paper over it.
- Fix the **app** side only. Where the fix needs a panel or a server change, say
  exactly what it needs and leave the app's half working.
- Keep every existing action, condition, navigation target and `.tr` string; no
  redesign beyond what the fix needs; design system for any new UI.
- GetX: an `Obx`/`GetX` builder must read an observable synchronously; use
  `DsObserve` for lazily-built children.
- Verify `flutter analyze --no-pub` → 0 errors, 0 warnings in the apps you touch.
