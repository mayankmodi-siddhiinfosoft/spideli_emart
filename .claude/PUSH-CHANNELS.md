# Push channels: which Android channel / sound each sender must use

Every app that SENDS a push puts the RECEIVING app's channel in
`android.notification.channel_id`. Android 8+ ignores `android.notification.sound`
and plays the channel's sound, so the channel decides whether a push is loud and
heads-up. If the receiving device has no channel with that id, Android posts the
push on the receiving app's manifest `default_notification_channel_id` (or, when
that channel was never created, on a silent "Miscellaneous" fallback channel).

Each app appends its own section below (re-read the file before writing).
Keep the summary table in sync with the sections.

## Summary: receiving app -> channel to target

| Receiving app | Channel id(s) the app creates at start-up | Manifest default | Sound |
|---|---|---|---|
| customer | `high_importance_channel` (everything) | `high_importance_channel` | `default` |
| store (vendor) | `new_order` (new orders and bookings), `general` (everything else) | `new_order` | `order_alert` on `new_order` (iOS `order_alert.caf`), `default` on `general` |
| driver | `driver_jobs` (new / assigned job, loud) and `driver_notifications_channel` (everything else) | `driver_notifications_channel` | `default` |
| provider | `01` "Bookings and messages" (everything) | `01` | `default` |
| worker | `01` "Jobs and messages" (everything) | `01` | `default` |

---

## customer (`customer/`)

### Receives

- **Channel:** `high_importance_channel`, "Spideli notifications", importance
  max, default sound, vibration. Created in `main()` before `runApp`
  (`customer/lib/utils/notification_service.dart`, `NotificationService.createChannels`),
  so it exists before any background push can arrive. The manifest
  `com.google.firebase.messaging.default_notification_channel_id` is
  `high_importance_channel`, so a push with no channel id, or with an id the
  customer app does not create (for example the old `0`), lands on it too.
- **Senders to the customer** (store, driver, provider, worker) should use
  `channel_id: "high_importance_channel"` and `sound: "default"`, and
  `apns.payload.aps.sound: "default"`.
- **Data the customer routes on** (all values strings; `customer/lib/utils/push_tap.dart`
  `PushTap.targetOf`, `NotificationService.routeTap`):
  - `type` = `delivery_otp` + `orderId`: opens that order's details (code card).
  - `type` = `orderChat` (or `chat`) + `chatType` (`vendor` | `driver` | `provider` | `worker`):
    opens that chat inbox (store, driver, provider or worker), pushed on top of
    the current screen.
  - `type` = `admin_chat`: opens Help & Support.
  - anything else (order / ride / parcel / booking status): opens the app; no
    crash on missing or non-string keys, or when signed out. A tap that
    launched the app is opened once the home (service list) is up.
- **Foreground:** Android posts a local notification on `high_importance_channel`
  for every push with a title/body (before: delivery codes only); iOS shows the
  push itself (presentation options alert/badge/sound), no local copy. A
  data-only push is shown in the Android foreground only if it has `title` /
  `body` data keys, and never in the background: always send a `notification`.
- **Token:** `users/{uid}.fcmToken`, written field-level only
  (`update({'fcmToken'})`; `customer/lib/utils/push_token_sync.dart`), on every
  start when signed in, after login / sign-up / OTP, and on `onTokenRefresh`
  (one subscription). On iOS the app waits up to 10 s for the APNs token first;
  an empty token is never written. `FireStoreUtils.updateUser` no longer
  writes `fcmToken` except when creating the document. Sign-out clears it only
  while it still equals this device's token (transaction). Orders embed the
  customer as `author`, so `author.fcmToken` is a snapshot from order time;
  senders should read `users/{order.authorID}.fcmToken` fresh and fall back to it.
- **Topic:** `customer` (subscribed after the APNs token on iOS).

### Sends (customer -> other apps)

The channel is chosen in `customer/lib/service/push_message.dart`
(`PushChannels.forRecipient`):

| Push (template `type` / kind) | Recipient (token) | Android channel | Android sound | APNs sound |
|---|---|---|---|---|
| `order_placed`, `schedule_order` (cart) | store owner, `users/{vendor.author}.fcmToken` | `new_order` | `order_alert` | `order_alert.caf` |
| `dinein_placed` | store owner, `users/{vendor.author}.fcmToken`, falls back to `vendors/{id}.fcmToken` | `new_order` | `order_alert` | `order_alert.caf` |
| chat to a store (`chat`) | store (`users/{id}`, read when the chat opens) | `general` | `default` | `default` |
| chat to a driver (`chat`) | driver (same) | `driver_notifications_channel` | `default` | `default` |
| `booking_placed` (booking, payment, cancel) | provider, `users/{provider.author}.fcmToken` | `01` | `default` | `default` |
| chat to a provider (`chat`) | provider (same as chat) | `01` | `default` | `default` |
| chat to a worker (`chat`) | worker, `providers_workers/{id}.fcmToken` | `01` | `default` | `default` |

Data (strings only: nulls dropped, maps/lists JSON-encoded, reserved keys
dropped): always `type` (the caller's, else the template type) and the order
id: `{type: "order_placed" | "schedule_order" | "dinein_placed", orderId}`,
`{type: "provider_order", orderId}` for bookings, `{type: "orderChat", chatType,
orderId, senderId, senderName}` for chat. When a channel is named it is also
sent as data `channelId` (the store uses it to pick its foreground channel).
Legacy path: FCM v1 at `projects/{Firebase options projectId}` (settings
`senderId` only as fallback), `android.priority: high` +
`notification.channel_id` / `sound`, `apns-priority: 10`, `aps.sound`,
`aps.content-available: 1`; the OAuth token is cached until 5 minutes before
expiry; a non-2xx returns false and logs the status and FCM error code (never
a token); a push to an empty / `"null"` token is not sent. A dead recipient
token is only logged (the customer app never writes another user's document).
Server path (`serverPushUrl` = https URL): the customer's Firebase ID token,
`kind` (template type, or `chat`) plus the same `android.channelId` / `sound`
and `apns.sound` overrides; the key is never downloaded, no fallback on error.

---

## worker (`spideli_worker/`)

### Receives

- **Channel:** `01`, "Jobs and messages", importance max, default sound,
  vibration. Created in `main()` before `runApp`
  (`spideli_worker/lib/services/notification_service.dart`,
  `NotificationService.prepareBeforeRunApp`; id in
  `spideli_worker/lib/services/push_message.dart` `workerChannelId`). The id
  stays `01` because it is what the app already used, so devices keep it. The
  manifest `com.google.firebase.messaging.default_notification_channel_id` is
  `01` (it had none), so a push with no channel id or an unknown one lands on it.
- **Senders to the worker** (provider: `worker_assigned`; customer: chat) should
  use `channel_id: "01"`, `sound: "default"` and `apns.payload.aps.sound: "default"`.
- **Data the worker routes on** (all values strings; `spideli_worker/lib/services/push_message.dart` `pushRouteFor`):
  - `type` = `provider_order` + `orderId` (or any type with an `orderId`): opens the booking.
  - `type` = `orderChat` (or `chat`) + `orderId` + `senderId` (+ `senderName`): opens that
    chat with the sender as the other side; without `orderId`/`senderId`: the inbox.
  - `type` = `provider_chat` + `orderId` (+ the full chat arguments): the chat (legacy).
  - `type` = `admin` / `admin_chat`, or `chatType` = `admin`: Help & Support.
  - anything else: opens the app (no crash on missing keys).
- **Token:** `providers_workers/{uid}.fcmToken` (NOT `users/`), written
  field-level only by `NotificationService` on every start when signed in,
  after login and on `onTokenRefresh`. On iOS it waits up to 10 s for the APNs
  token; an empty token is never written. Profile saves no longer write the
  token. On logout it is cleared only if it is still this device's token.
  Senders should read it fresh from `providers_workers/{workerId}` at send time.
- Foreground: Android posts a local notification on `01`; iOS shows the push
  itself (presentation options), no local notification (no duplicate).

### Sends (worker -> other apps)

The channel is chosen in `spideli_worker/lib/services/push_message.dart`
(`pushChannelFor`); every push goes through `SendNotification`
(`spideli_worker/lib/services/send_notification.dart`).

| Push (template `type` / kind) | Recipient | Android channel | Android sound | APNs sound |
|---|---|---|---|---|
| `service_intransit` (job started) | customer, fresh `users/{order.authorID}.fcmToken`, falls back to `order.author.fcmToken` | `high_importance_channel` | `default` | `default` |
| `stop_time` (hourly job stopped) | customer (same lookup) | `high_importance_channel` | `default` | `default` |
| `service_completed` | customer (same lookup) | `high_importance_channel` | `default` | `default` |
| `service_charges` (extra charges) | customer (same lookup) | `high_importance_channel` | `default` | `default` |
| chat (`chat`) | customer (`users/{id}`, or `providers_workers/{id}`) | `high_importance_channel` | `default` | `default` |

Data: `{type: "provider_order", orderId}` for job status; `{type: "orderChat" | "admin",
chatType: "worker", orderId, senderId, senderName}` for chat. Every message also carries
`android.priority: high`, `apns-priority: 10` and `aps.content-available: 1`
(legacy path); the server path sends `kind` plus the same `android.channelId` /
`sound` and `apns.sound` overrides.

---

## driver (`driver/`)

### Receives

- **Channels** (both created in `main()` before `runApp` by
  `NotificationService.createChannels`, `driver/lib/utils/notification_service.dart`;
  ids in `driver/lib/services/push_message.dart` `PushChannels`):
  - `driver_jobs`, "New jobs": importance max, default sound played on the
    ringtone stream (`AudioAttributesUsage.notificationRingtone`), vibration,
    lights. For a NEW or ASSIGNED job (delivery, ride, parcel, rental). New id,
    so every device gets it with these settings.
  - `driver_notifications_channel`, "Driver Notifications": importance high,
    default sound, vibration. Everything else (chat, cancellations, updates).
    It is the manifest `com.google.firebase.messaging.default_notification_channel_id`,
    so a push with no channel id, or an id the device does not have (an older
    driver build has no `driver_jobs`), lands on it - still heads-up and audible.
- **Senders to the driver:**
  - a job (`new_delivery_order`, `assign_order`, or kinds `driver_job`,
    `order_available`, `job_assigned`, `job_queue`, `new_ride`, `new_parcel`,
    `new_rental`): `channel_id: "driver_jobs"`, `sound: "default"`,
    `apns.payload.aps.sound: "default"`. (`driver_notifications_channel` also
    works, less loud. The server contract's `driver_job` profile currently uses
    `driver_notifications_channel`; switching it to `driver_jobs` is a
    one-line follow-up in `functions/src/payload.ts`.)
  - anything else (chat, `customer_cancelled`, `driver_cancelled`, ...):
    `channel_id: "driver_notifications_channel"`, `sound: "default"`.
  - Always send a `notification` block (title/body): a data-only push is
    shown only on Android (background handler), never on iOS.
- **Token:** `users/{driverId}.fcmToken`, written field-level only
  (`update({'fcmToken'})`, never a merge set, so a missing document is never
  re-created), on every start when signed in, after login / sign-up / OTP, and
  on `onTokenRefresh` (one subscription for the app run). On iOS the app waits
  up to 10 s for the APNs token before `getToken()`; an empty token is never
  written. `FireStoreUtils.updateUser` no longer writes `fcmToken` except when
  creating the document. Sign-out clears it only if it still equals this
  device's token (transaction). Senders should read `users/{driverId}.fcmToken`
  fresh at send time; an order's embedded `driver.fcmToken` is a snapshot.
- **Topics** (active drivers only, unsubscribed on sign-out): `driver`,
  `driver_<serviceType>`, `section_<id>`, `zone_<id>`, `region_<id>`,
  `company_<ownerId>`, `carrier_<id>`.
- **Data the driver routes on** (all strings; `NotificationService.handleMessageClick`):
  - `type` = `orderChat` + `orderId` + `senderId` (customer id): opens that chat; without them, the inbox.
  - `type` = `admin_chat`: Help & Support (drawer 7).
  - `type` in the job set above, or `order`, `new_order`, `vendor_order`,
    `parcel_order`, `rental_order`, `cab_order`: the home of the driver's module.
  - anything else: opens the app (no crash on missing / non-string keys, or when signed out).
- Foreground: Android posts a local notification on the channel the sender
  named (if it is one of the two above), else `driver_jobs` for a job type,
  else `driver_notifications_channel`. iOS shows the push itself
  (presentation options alert/badge/sound), no local copy (no duplicate).
  A tap that launched the app is handled after the splash has navigated.
- iOS: `AppDelegate` sets `UNUserNotificationCenter.current().delegate = self`
  (so flutter_local_notifications gets its foreground presentation and taps
  alongside firebase_messaging) and calls `registerForRemoteNotifications()`.
  Background mode `remote-notification` and `aps-environment` are set in all
  three build configurations.

### Sends (driver -> other apps)

Every push goes through `driver/lib/constant/send_notification.dart`
(`SendNotification`); the message is built by `PushMessage` in
`driver/lib/services/push_message.dart`.

| Push (template `type` / kind) | Recipient (token lookup) | Android channel | Android sound | APNs sound |
|---|---|---|---|---|
| `driver_accepted` (delivery accept) | customer: fresh `users/{order.authorID}.fcmToken`, falls back to `order.author.fcmToken` | `high_importance_channel` | `default` | `default` |
| `driver_accepted` (delivery accept) | store: `users/{vendor.author}.fcmToken`, then `vendors/{vendorID}.fcmToken`, then `order.vendor.fcmToken` | `general` | `default` | `default` |
| `driver_accepted` (ride accept) | customer (same lookup) | `high_importance_channel` | `default` | `default` |
| `driver_completed` | customer (same lookup) | `high_importance_channel` | `default` | `default` |
| `parcel_accepted`, `parcel_completed` | customer (same lookup) | `high_importance_channel` | `default` | `default` |
| `rental_completed` | customer (same lookup) | `high_importance_channel` | `default` | `default` |
| delivery code (`delivery_otp`, own text) | customer, fresh `users/{authorID}` | `high_importance_channel` | `default` | `default` |
| chat (`chat`) | customer (live `users/{id}`) | `high_importance_channel` | `default` | `default` |

Data: `{type, orderId}` (the caller's `type`, e.g. `parcel_order` /
`rental_order`, else the template type) for order pushes; `{type: "delivery_otp", orderId}`;
`{type: "orderChat", chatType: "driver", orderId, senderId}` for chat. Values
are strings only (nulls dropped, maps/lists JSON-encoded). Legacy path: project
id from `Firebase.app().options.projectId` (falls back to settings `senderId`),
`android.priority: high`, `apns-priority: 10`, `aps.content-available: 1`, the
HTTP status is checked (non-2xx = failure, logged with the FCM error code,
never the token), the OAuth token is cached until 5 minutes before expiry. A
push to an empty / `"null"` token is not sent (logged). An `UNREGISTERED`
token is only logged: the driver app never writes another user's document; the
owner's app replaces its token on its next start. Server path
(`serverPushUrl` = https URL): the same fields as `kind` + `android.channelId` /
`sound` + `apns.sound`, the driver's Firebase ID token, never the key.

---

## store (`vendor/`)

### Receives

- **Channels**, created in `main()` before `runApp`, again in
  `NotificationService.initInfo` and in the background handler
  (`vendor/lib/utils/notification_service.dart`, `NotificationService.createChannels`;
  ids in `vendor/lib/utils/push_payload.dart`):
  - `new_order` "New orders": importance max, sound `res/raw/order_alert.wav`
    (kept in release builds by `res/raw/keep.xml`), vibration, lights,
    ringtone audio usage. The manifest
    `com.google.firebase.messaging.default_notification_channel_id` is
    `new_order`, so a push with no channel id, or one the store does not
    create, rings on the loud channel (older customer builds send none).
  - `general` "Store updates": importance high, default sound.
- **iOS:** `vendor/ios/Runner/order_alert.caf` (the same tone) is in the Runner
  target's resources, so `aps.sound: "order_alert.caf"` plays the store tone.
  Any other sound name plays the default tone.
- **Senders to the store** should use:

  | Push to the store | Android channel | Android sound | APNs sound |
  |---|---|---|---|
  | new order / booking: `order_placed`, `schedule_order`, `new_order`, `dinein_placed` | `new_order` | `order_alert` | `order_alert.caf` |
  | everything else (chat `orderChat`, `driver_accepted`, admin pushes) | `general` | `default` | `default` |

- **Token:** `users/{uid}.fcmToken` (owner and employee), written field-level
  only (`FireStoreUtils.saveDeviceFcmToken`) on every start when signed in,
  after login / sign-up / OTP, after creating a store, and on `onTokenRefresh`.
  For an owner the same token is also written on every store they own
  (`vendors/{id}.fcmToken` where `author == uid`), which customers (dine-in,
  chat) and drivers (`driver_accepted`, via the order's `vendor` copy) still
  read. On iOS the app waits up to ~10 s for the APNs token; an empty token is
  never written. `updateUser` / `updateVendor` no longer write the token from
  their in-memory copies. On sign-out it is cleared only where it is still this
  device's token. Senders should read the owner's token fresh from
  `users/{vendor.author}.fcmToken`. Employees receive no pushes: senders
  target the owner.
- **Data the store routes on** (all values strings;
  `NotificationRouting.targetFor`):
  - `type` = `order_placed`, `schedule_order`, `new_order*`, `driver_*`,
    `store_*`, `restaurant_*`, `customer_cancelled`: the Home (orders) tab.
  - `type` = `dinein*`: the Dine-in tab (when the user has it).
  - `type` = `orderChat` (or `chat`, `*_chat`): the chat inbox.
  - `type` = `admin_chat`, or `chatType` = `admin`: Help & Support.
  - anything else, or no signed-in user: nothing (no crash on missing keys).
    After a cold start the screen opens once the dashboard is up.
- **Foreground:** Android posts a local notification on `new_order` for order
  alerts (by `type`, or the push's channel id) and on `general` otherwise; iOS
  shows the push itself (presentation options), no local notification (no
  duplicate). A data-only message with a `title` / `body` is shown locally, in
  the foreground and from the background handler.

### Sends (store -> other apps)

The channel is chosen in `vendor/lib/utils/push_payload.dart`
(`PushPayload.channelFor`); every push goes through `SendNotification`
(`vendor/lib/constant/send_notification.dart`), which reads the recipient's
current token from `users/{recipientId}.fcmToken` and falls back to the copy
on the order.

| Push (template `type` / kind) | Recipient | Android channel | Android sound | APNs sound |
|---|---|---|---|---|
| `restaurant_accepted` (accept, assign, ship), `restaurant_rejected`, `restaurant_cancelled`, `takeaway_completed`, "Order Delivered" (no template, `type: store_completed`) | customer, fresh `users/{order.authorID}`, falls back to `order.author.fcmToken` | `high_importance_channel` | `default` | `default` |
| `dinein_accepted`, `dinein_canceled` | customer (same lookup on the booking) | `high_importance_channel` | `default` | `default` |
| `delivery_otp` (POD, `pod_otp_service.dart`) | customer (fresh lookup there) | `high_importance_channel` | `default` | `default` |
| chat (`chat`; data `type: orderChat`, `chatType: vendor`) | customer `users/{receivedId}` (a driver recipient gets the driver channel) | `high_importance_channel` | `default` | `default` |
| `new_delivery_order` (store assigns its own delivery man) | driver, fresh `users/{order.driverID}` | `driver_jobs` (older driver builds fall back to `driver_notifications_channel`) | `default` | `default` |
| `driver_cancelled` (order rejected / cancelled while assigned) | driver `users/{driverID}` | `driver_notifications_channel` | `default` | `default` |

Data: string-only, always `type` (the caller's, or the template type) and
`orderId`; chat adds `chatType`, `senderId`. Legacy path: FCM v1 at
`projects/{Firebase options projectId}` (`spideli-870b0`; settings `senderId` is
only the fallback), `android.priority: high` + `notification.channel_id` /
`sound`, `apns-priority: 10`, `aps.sound`, `aps.content-available: 1`; the
access token is cached until 5 minutes before expiry. Server path (when
`serverPushUrl` is an https URL): `kind` plus the same `android.channelId` /
`sound` and `apns.sound` overrides; the key is never downloaded. A non-2xx is
logged (status and FCM error code, never a token) and returns false. On
`UNREGISTERED` / token `INVALID_ARGUMENT` (legacy) or `unregistered` /
`invalid_token` (server) the store clears `users/{recipientId}.fcmToken` in a
transaction, only while it still equals the dead token (under
`firestore.rules.draft` that cross-user write is refused and only logged).

---

## provider (`spideli_provider/`)

### Receives

- **Channel:** `01`, "Bookings and messages", importance max, default sound,
  vibration. Created in `main()` before `runApp`
  (`spideli_provider/lib/services/notification_service.dart`,
  `NotificationService.createAndroidChannels`; id in
  `spideli_provider/lib/services/push_message.dart` `PushChannels.provider`).
  The id stays `01` because earlier builds already created it on devices (an
  existing channel's importance and sound cannot be changed). The manifest
  `com.google.firebase.messaging.default_notification_channel_id` is `01` (it
  had none), so a push with no channel id (the customer sends `booking_placed`
  that way) or an unknown one lands on it.
- **Senders to the provider** (customer: `booking_placed` and chat; worker:
  chat) should use `channel_id: "01"`, `sound: "default"` and
  `apns.payload.aps.sound: "default"`. Leaving the channel out also works (the
  manifest default is `01`).
- **Data the provider routes on** (all values strings; `NotificationService._route`):
  - `type` = `provider_order` (or `booking_placed`) + `orderId`: opens that booking.
  - `type` = `orderChat` + `orderId` + `senderId` (+ `senderName`, `chatType`):
    opens that chat with the sender as the other side.
  - `type` = `provider_chat` + `orderId` (+ the full chat arguments): the chat (legacy).
  - `type` = `admin_chat` / `admin`: Help & Support.
  - missing ids or anything else: nothing is opened, nothing crashes. A tap
    that arrives before the dashboard is up (cold start, signed out) is kept
    and opened once the dashboard shows.
- **Token:** `users/{uid}.fcmToken`, written field-level (`update({fcmToken})`)
  only onto an existing record whose `role` is `provider` (a customer account
  signed in to this app never gets its token replaced), on every start when
  signed in, on every sign-in (auth listener), when the dashboard opens, and on
  `onTokenRefresh`. On iOS the app waits up to 10 s for the APNs token first; ''
  is never written over a token. Full writes of the provider record
  (`FireStoreUtils.updateCurrentUser`) carry this device's current token or
  leave the field alone. On logout (and when a disabled account is turned
  away) the token is cleared only if it is still this device's (transaction).
- **Foreground:** Android posts a local notification on `01`; iOS shows the
  push itself (presentation options), no local copy (no duplicate). Data-only
  pushes with a `title`/`body` in `data` are shown locally on both, in the
  foreground and in the background handler.

### Sends (provider -> other apps)

The channel is chosen in `spideli_provider/lib/services/push_message.dart`
(`recipientForKind`, `pushRouteFor`); every push goes through `SendNotification`
(`spideli_provider/lib/services/send_notification.dart`).

| Push (template `type` / kind) | Recipient | Token read at send time | Android channel | Android sound | APNs sound |
|---|---|---|---|---|---|
| `provider_accepted` | customer | `users/{order.authorID}.fcmToken`, falls back to `order.author.fcmToken` | `high_importance_channel` | `default` | `default` |
| `provider_rejected` | customer | same | `high_importance_channel` | `default` | `default` |
| `service_intransit` | customer | same | `high_importance_channel` | `default` | `default` |
| `stop_time` | customer | same | `high_importance_channel` | `default` | `default` |
| `service_completed` | customer | same | `high_importance_channel` | `default` | `default` |
| `service_charges` | customer | same | `high_importance_channel` | `default` | `default` |
| `worker_assigned` | worker | `providers_workers/{workerId}.fcmToken`, falls back to the list copy | `01` | `default` | `default` |
| chat (`chat`) to a customer | customer | `users/{id}` (re-read when the open-time copy has none) | `high_importance_channel` | `default` | `default` |
| chat (`chat`) to a worker (record has `providerId`, role not `customer`) | worker | `providers_workers/{id}` | `01` | `default` | `default` |

Data: `{type: "provider_order", orderId}` for booking status and assignments;
`{type: "orderChat" | "admin", chatType, orderId, senderId, senderName}` for
chat. Values are always strings (nulls dropped, maps/lists JSON-encoded, FCM's
reserved keys dropped) and `type` is always present. Title and body are cut to
200 / 1000 characters. The legacy message also carries `android.priority: high`,
`apns-priority: 10` and `aps.content-available: 1`; the server path sends
`kind` plus the same `android.channelId` / `sound` and `apns.sound` overrides.
A send returns false on any non-2xx answer and logs the status and FCM error
code with an 8-character token fingerprint (never the token, the OAuth token
or the ID token). A dead recipient token (`UNREGISTERED`, or `INVALID_ARGUMENT`
about the token) is only logged: the record belongs to another user's app,
which replaces it on its next start. The project in the FCM path is
`Firebase.app().options.projectId` (`spideli-870b0`), then the service
account's `project_id`, then `settings/notification_setting.senderId`.
