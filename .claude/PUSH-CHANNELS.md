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
| customer | `high_importance_channel` (everything else), `chat_messages` (chat) | `high_importance_channel` | `default`; chat `chat_message` (iOS `chat_message.wav`) |
| store (vendor) | `new_order` (new orders and bookings), `new_order_rt_<key>` (the same with the admin's order ringtone, once prepared), `general` (everything else), `chat_messages` (chat) | `new_order` | `order_alert` on `new_order` (iOS `order_alert.caf`), the admin's ringtone on `new_order_rt_<key>` (iOS `order_ringtone_<key>.caf`), `default` on `general`, `chat_message` on `chat_messages` |
| driver | `spideli` (dispatch offers from the Cloud Functions), `driver_jobs` (assigned job, loud), `driver_jobs_rt_<key>` (jobs and offers with the admin's order ringtone, once prepared), `driver_notifications_channel` (everything else), `chat_messages` (chat) | `driver_notifications_channel` | `default`; the admin's ringtone on `driver_jobs_rt_<key>` (iOS `order_ringtone_<key>.caf`); `chat_message` on `chat_messages` |
| provider | `01` "Bookings and messages" (everything else), `chat_messages` (chat) | `01` | `default`; chat `chat_message` |
| worker | `01` "Jobs and messages" (everything else), `chat_messages` (chat) | `01` | `default`; chat `chat_message` |

**Chat, in every direction** (any app to any app): `channel_id: "chat_messages"`,
`sound: "chat_message"`, `apns.payload.aps.sound: "chat_message.wav"` (section
"Chat sound"). **A new order / job** to a store or driver when
`globalSettings.order_ringtone_url` is set: `new_order_rt_<key>` /
`driver_jobs_rt_<key>` and `order_ringtone_<key>.caf` (section "Order
ringtone").

---

## Order ringtone (`globalSettings.order_ringtone_url`)

The admin's order ring sound (an audio URL; the in-app alert of the store and
driver apps already loops it while they are open) is also the sound of
new-order / new-job notifications in the background and with the app closed,
on Android and iOS. Pure naming in `order_ringtone.dart`, identical in
`customer/lib/service/`, `vendor/lib/utils/`, `driver/lib/services/` (tested
with fixed vectors in each app's `test/order_ringtone_test.dart`).

### Names (every app and the server compute the same)

- The URL is used trimmed. "Configured" = it starts with `http://` or
  `https://` (case-insensitive). Anything else (empty, junk) = no ringtone:
  every app behaves exactly as before this section existed.
- `key` = 32-bit FNV-1a over the UTF-8 bytes of the trimmed URL, 8 lowercase
  hex digits. Node.js:

  ```js
  function ringtoneKey(url) {
    const s = (url || '').trim();
    if (!/^https?:\/\//i.test(s)) return '';
    let h = 0x811c9dc5;
    for (const b of Buffer.from(s, 'utf8')) { h ^= b; h = Math.imul(h, 0x01000193) >>> 0; }
    return h.toString(16).padStart(8, '0');
  }
  // 'https://example.com/ring.mp3' -> '955470e2'
  ```
- Store new-order channel `new_order_rt_<key>`; driver job channel
  `driver_jobs_rt_<key>`; iOS sound `order_ringtone_<key>.caf` (both apps).

### What senders put in a NEW order / job push

| Push | Without ringtone | With ringtone |
|---|---|---|
| to a store: `order_placed`, `dinein_placed`, `schedule_order`, `new_order`, `scheduled_order_due` | `new_order` / `order_alert` / `order_alert.caf` | `new_order_rt_<key>` / `order_alert` / `order_ringtone_<key>.caf` |
| to a driver: `new_delivery_order`, `assign_order`, `job_assigned`, `driver_job`, `job_queue` | `driver_jobs` / `default` / `default` | `driver_jobs_rt_<key>` / `default` / `order_ringtone_<key>.caf` |
| dispatch offer (Cloud Functions) | `spideli` / `default` / `default` | `driver_jobs_rt_<key>` / `default` / `order_ringtone_<key>.caf` (server change, below) |

The Android `sound` field (only read by Android 7 and older) keeps today's
value. Senders read the CURRENT URL: the store and driver apps keep a live
listener on `settings/globalSettings` (`OrderRingtoneService.start`); the
customer app re-reads it (4 s bound, falls back to the start-up copy) for
every new-order push to a store (`FireStoreUtils.currentOrderRingtoneUrl`).
Chat and every other push never change.

### Recipient apps (store, driver)

`OrderRingtoneService` (`vendor/lib/service/`, `driver/lib/services/`):

- **When**: on the settings load at start, on every change of the URL (live
  listener while the app runs: download, new channel / new `.caf`, and the
  in-app alert switches to the new URL, restarting a ring in progress; no
  restart of the app), on every return to the foreground, and from the FCM
  background handler (bounded: settings read 8 s, whole catch-up 20 s; at
  most every 10 minutes, always for a `ringtone_changed` push).
- **Decision** (`OrderRingtone.plan`, unit tested): unchanged -> nothing;
  file for the current key already on the device -> adopt (channel + record,
  no download); changed -> download and prepare the new key; no ringtone ->
  clear. The previous key's channel and file are removed only after the new
  one is ready; a failed download keeps everything as it was and is retried
  after 2 minutes / on the next resume.
- **Download**: GET, 200 only, at most 10 MB, 30 s; failure = today's
  behaviour.
- **Android**: the file is stored as
  `files/order_ringtones/order_ringtone_<key>.<ext>` and served by
  `OrderRingtoneProvider` (a FileProvider subclass, authority
  `<applicationId>.order_ringtone`, `res/xml/order_ringtone_paths.xml`, not
  exported). Read access is granted to `com.android.systemui` when the file
  is prepared and again whenever the process starts (the provider's
  `onCreate`, which runs before an FCM push is shown), because URI grants do
  not survive a reboot; the notification service also grants it per posted
  notification. The channel `new_order_rt_<key>` ("New orders", importance
  max, the `new_order` description, vibration, lights, ringtone audio usage)
  / `driver_jobs_rt_<key>` ("New jobs", the `driver_jobs` settings) is created
  with `UriAndroidNotificationSound(content uri)`; older `*_rt_*` channels
  are deleted afterwards. A deleted id is never reused for another sound
  (another URL = another key).
- **iOS**: `AppDelegate` (`OrderRingtoneSounds`) converts the download (MP3,
  M4A/AAC, WAV, CAF, AIFF... anything AVAudioFile reads) to 16-bit Linear
  PCM `.caf`, mono / stereo, cut at 29.5 s, in
  `Library/Sounds/order_ringtone_<key>.caf`. Info.plist and background modes
  are unchanged. On iOS the FCM background handler runs in the app's own
  engine, so the conversion also works from there.
- **Local notifications the apps post** (Android foreground display,
  data-only pushes, the background handler, the driver's assignment watcher)
  use the prepared channel / sound when it is the current URL's, else the
  existing ones (`new_order` / `driver_jobs` / `spideli`).
- **No double sound**: while the in-app alert rings (it loops the same
  sound), a new-order / job notification is shown without a sound of its
  own: Android posts it `silent`; iOS presents a foreground remote push
  without `.sound` (AppDelegate asks Dart `foregroundPushSilent`, answer
  bounded at 3 s). The app waits up to 1.5 s (store) / 2 s (driver) for the
  in-app alert to start, since the order listener and the push arrive
  together. Never a second notification for one push. Not covered: with the
  app in the BACKGROUND but its process alive, Android shows the push itself
  (channel sound) while the in-app loop - if it was already ringing - keeps
  ringing too (behaviour from before this change; the in-app loop is not
  stopped in the background).

### The window after a change (a device that has not caught up yet)

A push that names `new_order_rt_<newkey>` reaching a device without that
channel is shown by Android on the app's manifest default channel: store
`new_order` (today's loud order tone - unchanged by design), driver
`driver_notifications_channel` (heads-up, default tone; `driver_jobs` also
plays the default tone). iOS plays the default tone when
`order_ringtone_<newkey>.caf` is not in `Library/Sounds`. Nothing is lost and
nothing is shown twice. A device catches up as soon as the app runs (start,
resume, the live listener) or any push reaches its background handler
(Android: every message; iOS: data / `content-available` messages when iOS
wakes the app). The handler never re-posts the push it is handling (that
would be a duplicate). Keeping the old key's channel does not help an FCM
push that names the new key, so the old one is only kept until the new one
is ready.

**Admin panel (optional, recommended)**: when `order_ringtone_url` changes,
send a data-only push `{data: {type: "ringtone_changed"}}` to the topics
`vendor` (all store devices) and `driver` (all active drivers):
`android.priority: "high"`, no `notification` block; APNs
`apns-push-type: background`, `apns-priority: 5`,
`aps.content-available: 1`, no alert / sound. The apps show nothing for it
and prepare the new sound in the background (iOS throttles background
pushes; a device that is off catches up at its next start).

---

## Chat sound

Chat messages never use the order ringtone, an order channel, a job channel
or `spideli`. Every app (customer, store, driver, provider, worker) creates
`chat_messages` "Chat messages" (importance high, sound
`res/raw/chat_message.wav`, vibration) at start-up next to its other
channels, and ships the same file as `Runner/chat_message.wav` (in the
Runner target's resources). The tone is an original 0.4 s two-tone ping
(synthesised, 16-bit PCM WAV, no third-party asset); `keep_chat_message.xml`
keeps it if resources are ever shrunk.

- **Every chat push** (`kind: chat`, or a chat `data.type`: `orderChat`,
  `chat`, `*_chat`) from any app: `channel_id: "chat_messages"`,
  `sound: "chat_message"`, `apns.payload.aps.sound: "chat_message.wav"`.
  `data.type` / routing unchanged. Pure rule in `chat_sound.dart`, identical
  in all five apps (`ChatSound`), used by each sender's channel picker
  (`PushChannels.forRecipient` customer/driver, `PushPayload.channelFor`
  store, `pushRouteFor` provider, `pushChannelFor` worker).
- **Receiving**: the foreground / data-only local copy of a chat push goes on
  `chat_messages` (decided before any order / job rule: a chat push is never
  an order alert and never starts or silences the in-app order ring). iOS
  presents remote pushes itself with `chat_message.wav`.
- **Older builds** without `chat_messages` show a chat push on their
  manifest default: customer `high_importance_channel`, driver
  `driver_notifications_channel`, provider / worker `01` - all fine - but an
  OLDER STORE build's default is `new_order`, so until stores update, a chat
  to an old store build rings with the order tone. Ship the store app update
  before (or with) the other apps. iOS plays the default tone where the file
  is missing.

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
| `order_placed` (cart, including a scheduled time that has already passed) | store owner, `users/{vendor.author}.fcmToken` | `new_order` (with a ringtone `new_order_rt_<key>`) | `order_alert` | `order_alert.caf` (with a ringtone `order_ringtone_<key>.caf`) |
| none for a cart order whose scheduled time is still ahead: the order is written with `scheduledNotificationSent: false` and the `scheduledOrderNotifier` Cloud Function pushes the store when it is due (section "Cloud Functions" below) | - | - | - | - |
| `dinein_placed` | store owner, `users/{vendor.author}.fcmToken`, falls back to `vendors/{id}.fcmToken` | `new_order` (with a ringtone `new_order_rt_<key>`) | `order_alert` | `order_alert.caf` (with a ringtone `order_ringtone_<key>.caf`) |
| chat to a store (`chat`) | store (`users/{id}`, read when the chat opens) | `chat_messages` | `chat_message` | `chat_message.wav` |
| chat to a driver (`chat`) | driver (same) | `chat_messages` | `chat_message` | `chat_message.wav` |
| `booking_placed` (booking, payment, cancel) | provider, `users/{provider.author}.fcmToken` | `01` | `default` | `default` |
| chat to a provider (`chat`) | provider (same as chat) | `chat_messages` | `chat_message` | `chat_message.wav` |
| chat to a worker (`chat`) | worker, `providers_workers/{id}.fcmToken` | `chat_messages` | `chat_message` | `chat_message.wav` |

Data (strings only: nulls dropped, maps/lists JSON-encoded, reserved keys
dropped): always `type` (the caller's, else the template type) and the order
id: `{type: "order_placed" | "dinein_placed", orderId}` (the silent
`scheduled_order` data push is gone: `customer/lib/service/push_message.dart`
`ScheduledOrderNotice`), `{type: "provider_order", orderId}` for bookings, `{type: "orderChat", chatType,
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
| chat (`chat`) | customer (`users/{id}`, or `providers_workers/{id}`) | `chat_messages` | `chat_message` | `chat_message.wav` |

Data: `{type: "provider_order", orderId}` for job status; `{type: "orderChat" | "admin",
chatType: "worker", orderId, senderId, senderName}` for chat. Every message also carries
`android.priority: high`, `apns-priority: 10` and `aps.content-available: 1`
(legacy path); the server path sends `kind` plus the same `android.channelId` /
`sound` and `apns.sound` overrides.

---

## driver (`driver/`)

### Receives

- **Channels** (all three created in `main()` before `runApp` by
  `NotificationService.createChannels`, `driver/lib/utils/notification_service.dart`;
  ids in `driver/lib/services/push_message.dart` `PushChannels`):
  - `spideli`, "Spideli Order Notifications": importance max, default sound,
    vibration (`DRIVER_DISPATCH_DOCUMENTATION.md` §5A). The channel the
    dispatch Cloud Functions name for an offer (section "Cloud Functions"
    below). Created alongside the other two, never instead of them.
  - `driver_jobs`, "New jobs": importance max, default sound played on the
    ringtone stream (`AudioAttributesUsage.notificationRingtone`), vibration,
    lights. For an ASSIGNED job (a store's own delivery man, a hand
    assignment; delivery, ride, parcel, rental). Dispatch offers use `spideli`.
    New id, so every device gets it with these settings.
  - `driver_notifications_channel`, "Driver Notifications": importance high,
    default sound, vibration. Everything else (chat, cancellations, updates).
    It is the manifest `com.google.firebase.messaging.default_notification_channel_id`,
    so a push with no channel id, or an id the device does not have (an older
    driver build has no `driver_jobs`), lands on it - still heads-up and audible.
- **Senders to the driver:**
  - a dispatch offer: **only the Cloud Functions** `deliveryDispatch`,
    `parcelDispatch`, `cabDispatch`, `rentalDispatch` (decision D1),
    `android.notification.channelId: "spideli"`, `sound: "default"`,
    `apns.payload.aps.sound: "default"`, data below. No app offers a job to a
    platform driver any more: the customer app's `new_ride` / `new_parcel` /
    `new_rental` pushes and the store app's `order_available` broadcast are
    removed. (The driver app still files those four kinds on `driver_jobs` if
    an older build sends one.)
  - an assigned job (`new_delivery_order` from the store to its own delivery
    man, `assign_order`, or kinds `driver_job`, `job_assigned`, `job_queue`):
    `channel_id: "driver_jobs"`, `sound: "default"`,
    `apns.payload.aps.sound: "default"`. (`driver_notifications_channel` also
    works, less loud.) With an order ringtone configured:
    `driver_jobs_rt_<key>` and `order_ringtone_<key>.caf` (section "Order
    ringtone").
  - chat: `channel_id: "chat_messages"`, `sound: "chat_message"`,
    `aps.sound: "chat_message.wav"` (section "Chat sound").
  - anything else (`customer_cancelled`, `driver_cancelled`, ...):
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
- **The dispatch push** (Cloud Functions, `DRIVER_DISPATCH_DOCUMENTATION.md`
  §3). Data (strings): `click_action: "FLUTTER_NOTIFICATION_CLICK"`,
  `type` = `order` (delivery / e-commerce, `vendor_orders`) | `parcel`
  (`parcel_orders`) | `cab` (`rides`) | `rental` (`rental_orders`), `orderId`
  (and `id`, the same), `status: "Driver Pending"`, `sound: "default"`;
  `android.priority: high` + `notification.channelId: "spideli"`,
  `apns-priority: 10`, `aps.sound: "default"`, `contentAvailable`. The app
  takes a push as an offer when `type` is one of the four, an order id is
  present, and `click_action` is `FLUTTER_NOTIFICATION_CLICK` or `status` is
  `Driver Pending` (`DispatchPush.parse`). Then:
  - foreground (`onMessage`): the order is read from Firestore and, while it
    is still `Driver Pending` for this driver, the global incoming-order dialog
    opens over any screen with Accept / Reject and the
    `settings/DriverNearBy.driverOrderAcceptRejectDuration` countdown (default
    120 s); Android also posts the push on `spideli`;
  - background / terminated: the system shows it on `spideli`; the background
    handler records the offer's start time per order id; a tap (or the launch
    tap, once the dashboard is up) opens the same dialog, or the module's job
    screen when the order is no longer pending for this driver;
  - an offer whose countdown ran out is rejected automatically, once, without
    a reason.
  Offers are also found from Firestore without any push (live listeners), so
  a missed push still shows the dialog. Full contract:
  `.claude/DRIVER-DISPATCH-CONTRACT.md`.
- **Data the driver routes on** (all strings; `NotificationService._routeTap`,
  `handleMessageClick`):
  - `type` = `order` | `parcel` | `cab` | `rental` + `orderId` (or `id`): the
    incoming-order dialog (above), else that module's job screen.
  - `type` = `orderChat` + `orderId` + `senderId` (customer id): opens that chat; without them, the inbox.
  - `type` = `admin_chat`: Help & Support (drawer 7).
  - `type` in the job set above, or `new_order`, `vendor_order`,
    `parcel_order`, `rental_order`, `cab_order`: the home of the driver's module.
  - anything else: opens the app (no crash on missing / non-string keys, or when signed out).
- Foreground: Android posts a local notification on `chat_messages` for a
  chat push (always, whatever channel it names), else on the channel the
  sender named (if it is one of the three above; `driver_jobs_rt_<any key>`
  counts as `driver_jobs`), else `spideli` for a dispatch offer, else
  `driver_jobs` for a job type, else `driver_notifications_channel`
  (`PushChannels.driverChannelFor`); a job / offer then goes on this device's
  prepared `driver_jobs_rt_<key>` when it has one, silently while the in-app
  alert rings (section "Order ringtone"). iOS shows the push itself
  (presentation options alert/badge/sound), no local copy (no duplicate).
  A tap that launched the app is handled after the splash has navigated.
- **A hand assignment found without a push** (the admin panel may assign a
  driver who has no `fcmToken`; `driver_assignment_watcher.dart`): the local
  alert on `driver_jobs` takes its title and body from the
  `dynamic_notification` template `job_assigned`, falling back to
  `new_delivery_order`; with neither there is no system notification, only an
  in-app toast. No notification text lives in the app.
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
| chat (`chat`) | customer (live `users/{id}`) | `chat_messages` | `chat_message` | `chat_message.wav` |

Data: `{type, orderId}` (the caller's `type`, e.g. `parcel_order` /
`rental_order`, else the template type) for order pushes; `{type: "delivery_otp", orderId}`;
`{type: "orderChat", chatType: "driver", orderId, senderId}` for chat. Every push to the customer also
carries `notificationId` (its `users/{customerId}/notifications/{id}` record,
`.claude/CUSTOMER-NOTIFICATIONS.md`) unless that write failed. Values
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
  | new order / booking: `order_placed`, `schedule_order`, `scheduled_order_due`, `new_order`, `dinein_placed` | `new_order` (with a ringtone: `new_order_rt_<key>`, section "Order ringtone") | `order_alert` | `order_alert.caf` (with a ringtone: `order_ringtone_<key>.caf`) |
  | chat (`orderChat`) | `chat_messages` | `chat_message` | `chat_message.wav` |
  | everything else (`driver_accepted`, admin pushes) | `general` | `default` | `default` |

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
  - `type` = `order_placed`, `schedule_order`, `scheduled_order_due`,
    `new_order*`, `driver_*`, `store_*`, `restaurant_*`, `customer_cancelled`:
    the Home (orders) tab (`scheduled_order_due`: its New tab).
  - `type` = `dinein*`: the Dine-in tab (when the user has it).
  - `type` = `orderChat` (or `chat`, `*_chat`): the chat inbox.
  - `type` = `admin_chat`, or `chatType` = `admin`: Help & Support.
  - anything else, or no signed-in user: nothing (no crash on missing keys).
    After a cold start the screen opens once the dashboard is up.
- **Scheduled orders** (`vendor/lib/utils/scheduled_order.dart`): an `Order
  Placed` order sits in the Scheduled tab (no Accept / Reject, no ring) until
  it is due (scheduled time minus the `settings/scheduleOrderNotification`
  lead time), then moves to New (in-app due timer) and rings in-app. No local
  alarms any more (no exact-alarm / boot permissions). The store is notified
  by the `scheduledOrderNotifier` Cloud Function's push `{type:
  "scheduled_order_due", orderId}` on `new_order` (shown by the system in the
  background, by the app's foreground display otherwise). In the foreground
  that push (or the `schedule_order` template type) re-splits the tabs at
  once; `scheduled_order_due` puts the order in New even if the phone's clock
  is behind. A tap opens the orders (New) tab.
- **Foreground:** Android posts a local notification on `chat_messages` for a
  chat push, on `new_order` (or the prepared `new_order_rt_<key>`, silently
  while the in-app alert rings) for order alerts (by `type`, or the push's
  channel id `new_order` / `new_order_rt_*`) and on `general` otherwise; iOS
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
| `restaurant_accepted` (accept, assign, ship), `restaurant_rejected`, `restaurant_cancelled`, `takeaway_completed`, courier order delivered (template `driver_completed`, data `type: store_completed`) | customer, fresh `users/{order.authorID}`, falls back to `order.author.fcmToken` | `high_importance_channel` | `default` | `default` |
| `dinein_accepted`, `dinein_canceled` | customer (same lookup on the booking) | `high_importance_channel` | `default` | `default` |
| `delivery_otp` (POD, `pod_otp_service.dart`) | customer (fresh lookup there) | `high_importance_channel` | `default` | `default` |
| chat (`chat`; data `type: orderChat`, `chatType: vendor`) | customer `users/{receivedId}` (or a driver) | `chat_messages` | `chat_message` | `chat_message.wav` |
| `new_delivery_order` (store assigns its own delivery man) | driver, fresh `users/{order.driverID}` | `driver_jobs`; with a ringtone `driver_jobs_rt_<key>` (a driver without it falls back to `driver_notifications_channel`) | `default` | `default`; with a ringtone `order_ringtone_<key>.caf` |
| `driver_cancelled` (order rejected / cancelled while assigned) | driver `users/{driverID}` | `driver_notifications_channel` | `default` | `default` |

Removed (D1): the store app notifies no platform driver.
`deliveryDispatch` offers the order and pushes the chosen driver on `spideli`
when the store accepts it (`Order Accepted`) and again after a
`Driver Rejected`.

Data: string-only, always `type` (the caller's, or the template type) and
`orderId`; chat adds `chatType`, `senderId`. Every push to a customer also
writes `users/{customerId}/notifications/{id}` (Notification Center,
`.claude/CUSTOMER-NOTIFICATIONS.md`) and carries `notificationId: <id>` in its
data (`SendNotification._recordForCustomer`, best effort, not awaited).
Legacy path: FCM v1 at
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
| chat (`chat`) to a customer | customer | `users/{id}` (re-read when the open-time copy has none) | `chat_messages` | `chat_message` | `chat_message.wav` |
| chat (`chat`) to a worker (record has `providerId`, role not `customer`) | worker | `providers_workers/{id}` | `chat_messages` | `chat_message` | `chat_message.wav` |

Data: `{type: "provider_order", orderId}` for booking status and assignments;
`{type: "orderChat" | "admin", chatType, orderId, senderId, senderName}` for
chat. A push to a customer whose uid is known is first stored at
`users/{customerId}/notifications/{id}` (`source: provider`, category `booking`
or `chat`; .claude/CUSTOMER-NOTIFICATIONS.md) and its data then carries
`notificationId` (left out when that write is refused, so the customer app
stores its own copy). Values are always strings (nulls dropped, maps/lists JSON-encoded, FCM's
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

---

## Cloud Functions (deployed separately; their source is not in this repository)

### Sends

| Push (`data.type`) | Recipient (token) | Android channel | Android sound | APNs sound |
|---|---|---|---|---|
| `scheduled_order_due` (`scheduledOrderNotifier`, every minute: a scheduled order became due) | store owner, current `users/{order.vendor.author}.fcmToken` (no `vendor.author`: `vendors/{vendorID}.author`) | `new_order`; **requested**: with a ringtone `new_order_rt_<key>` | `order_alert` | `order_alert.caf` (`apns-priority: 10`); **requested**: with a ringtone `order_ringtone_<key>.caf` |
| `order` (`deliveryDispatch`: `vendor_orders` became `Order Accepted` or `Driver Rejected`) | the chosen driver, `users/{driverId}.fcmToken` | `spideli`; **requested**: with a ringtone `driver_jobs_rt_<key>` | `default` | `default` (`apns-priority: 10`); **requested**: with a ringtone `order_ringtone_<key>.caf` |
| `parcel` (`parcelDispatch`: `parcel_orders` `Order Placed` / `Driver Rejected`) | the chosen driver | `spideli` | `default` | `default` |
| `cab` (`cabDispatch`: `rides` `Order Placed` / `Driver Rejected`) | the chosen driver | `spideli` | `default` | `default` |
| `rental` (`rentalDispatch`: `rental_orders` `Order Placed` / `Driver Rejected`) | the chosen driver | `spideli` | `default` | `default` |

**Order ringtone (requested from the function owners; the functions are not
in this repository)**: when `settings/globalSettings.order_ringtone_url` is
configured (section "Order ringtone"; read it per run or cache it for at
most a minute), `scheduledOrderNotifier` sends
`android.notification.channelId: "new_order_rt_<key>"` and
`apns.payload.aps.sound: "order_ringtone_<key>.caf"`, and the four dispatch
functions send `channelId: "driver_jobs_rt_<key>"` and
`aps.sound: "order_ringtone_<key>.caf"` (keep `sound: "default"` /
`order_alert` on Android, which only Android 7 reads). Without a ringtone,
exactly today's values (`new_order` / `spideli`). A device that has not
prepared the key yet falls back to its manifest default (store `new_order`,
driver `driver_notifications_channel`) and iOS to the default tone. The
driver app files a dispatch offer by its data (`DispatchPush.parse`), not by
the channel, so its handling is unchanged. Until then a dispatch offer in
the background plays the default tone on `spideli`; the driver app does NOT
re-create `spideli` with the custom sound (a channel's sound is fixed at
creation and `spideli` is created at every start before any download, so it
would never get it - and could never follow a later change).

**Dispatch pushes** (`DRIVER_DISPATCH_DOCUMENTATION.md`): data
`{click_action: "FLUTTER_NOTIFICATION_CLICK", id, orderId, type, status:
"Driver Pending", sound: "default"}`, a `notification` block, high priority on
both platforms. Before the push the function writes the order
`status: "Driver Pending"`, `driverId` = `driverID` = the driver, and
`users/{driver}.orderRequestData` arrayUnion the id. The driver app's answers
(accept / reject / timeout writes per collection) and the requests to the
function owners (`dispatchedAt`, a server-side timeout, exclusions, template
text) are in `.claude/DRIVER-DISPATCH-CONTRACT.md`. They are the only pushes
that offer a job to a platform driver.

Data `{type: "scheduled_order_due", orderId}` (strings). Text: the
`dynamic_notification` template `schedule_order` (`subject` / `message`); when
it has no text the push is data-only (APNs background push, nothing shown).
Once per order: the order's `scheduledNotificationSent` (written `false` by the
customer app for a future scheduled order) is set `true` with
`scheduledNotificationAt` in a transaction before the push; an order that left
`Order Placed` first is marked with `scheduledNotificationSkipped` and never
pushed. Errors are logged without tokens; an `UNREGISTERED` token is only
logged.
