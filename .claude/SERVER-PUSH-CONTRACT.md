# Server push: one contract for all five apps

**Status (3 Oct 2026):** written and tested locally, **not deployed**. Nothing
changes for the apps until `settings/notification_setting.serverPushUrl` is set
(section 7).

**Why.** All five apps read `settings/notification_setting.serviceJson` (a
Firebase Storage URL of a Firebase Admin SDK service-account key), download the
private key, and mint OAuth tokens on the phone to call FCM HTTP v1. Anyone who
opens an APK, or reads that settings document, gets the key and full admin
access to project `spideli-870b0`.

**Fix.** One HTTPS Cloud Function, `sendPush` (source in `functions/`), holds the
FCM credentials. An app sends its signed-in user's **Firebase ID token** and the
message. The function checks who is calling, applies limits, builds the same
FCM message the apps build today, and sends it with `admin.messaging().send()`.

Files:

| File | What |
|---|---|
| `functions/src/index.ts` | the HTTP handler |
| `functions/src/payload.ts` | request validation / normalisation and the FCM message builder |
| `functions/src/errors.ts` | FCM and Auth errors to HTTP responses |
| `functions/src/tokens.ts` | dead-token clean-up |
| `functions/src/rateLimit.ts`, `config.ts`, `redact.ts` | per-account limit, settings, token fingerprint for logs |
| `functions/test/payload.test.js` | unit tests (`npm test`, 25 cases) |
| `functions/e2e/sendPush.e2e.test.js` | HTTP end-to-end test on the Auth/Firestore/Functions emulators (`npm run test:e2e`, 5 cases) |
| `firebase.json`, `.firebaserc` | deploys **only** the `push` functions codebase; no `firestore` section, so no deploy from this repo can replace the live rules |
| `.claude/PUSH-CHANNELS.md` | the Android channel / sound each receiving app creates (written by the app owners; section 3 below follows it) |

---

## 1. The switch (all apps)

| `settings/notification_setting.serverPushUrl` | What the app does |
|---|---|
| a non-empty `https://` URL with a host | **Server path.** POST to that URL. **Never** download `serviceJson` and never mint an OAuth token. If the server call fails, **do not fall back** to the legacy path. |
| absent, empty, or not `https` | **Legacy path** (direct FCM v1 with the downloaded key), unchanged. |

- Read `serverPushUrl` where each app already reads `serviceJson`: customer,
  driver and store keep a snapshot listener on `settings/notification_setting`
  (a change applies live); provider and worker read it once at start.
- Always assign it, defaulting to `''`, so clearing the field in Firestore
  switches a running app back to the legacy path. That is the rollback.
- A URL is valid when `Uri.tryParse(url.trim())` has `scheme == 'https'` and a
  non-empty `host` (`PushPayload.isServerPushUrl` in the apps).

---

## 2. Endpoint

```
POST https://us-central1-spideli-870b0.cloudfunctions.net/sendPush
Authorization: Bearer <Firebase ID token of the signed-in user>
Content-Type: application/json
```

- The deploy also prints a Cloud Run URL (`https://sendpush-<hash>-uc.a.run.app`).
  Both reach the same function. Put whichever one you use in `serverPushUrl`;
  the apps never hard-code it.
- The ID token comes from `FirebaseAuth.instance.currentUser!.getIdToken()`.
  No signed-in user: do not call the function.
- The caller must be a real account (not anonymous sign-in) with a profile
  document: `users/{uid}` (customer, driver, store owner / employee, provider)
  or `providers_workers/{uid}` (worker).

### Request body (a JSON object)

| Field | Type | Rules |
|---|---|---|
| `token` | string | Recipient FCM registration token. Send **exactly one** of `token` / `topic`. Trimmed; 32-4096 chars of `[A-Za-z0-9_\-:.]`; `''`, `'null'`, `'undefined'` are refused (400). |
| `topic` | string | FCM topic (`/topics/` prefix optional), `[a-zA-Z0-9-_.~%]{1,900}`. **Only callers whose `users/{uid}.role` is `admin`** (setting `PUSH_TOPIC_ROLES`). The apps never send to topics. |
| `title` | string | Notification title. Longer than **200** characters (code points): clipped, reported in `truncated`. `""` is sent as-is. |
| `body` | string | Notification body. Longer than **1000** characters: clipped, reported. |
| `data` | object | FCM data. Converted exactly like the apps' `PushPayload.stringData`: strings as-is, objects / arrays JSON-encoded, numbers and booleans with their string form (`5` -> `"5"`, `true` -> `"true"`), `null` drops the key. Keys are trimmed; empty keys and FCM-reserved keys (`from`, `notification`, `message_type`, `collapse_key`, anything starting with `google` or `gcm`) are dropped. Converted / dropped keys are reported. Keys plus values over **4096** UTF-8 bytes: refused with **413**. (A Dart `1.0` arrives in JSON as `1` and becomes `"1"`; send it as a string to keep the `.0`.) |
| `kind` | string | Optional. `[A-Za-z0-9_.:-]{1,64}`, else ignored. The notification template type for `sendFcmMessage` (`order_placed`, `restaurant_accepted`, `new_delivery_order`, `service_intransit`, ...), `chat` for chat, `delivery_otp` for the POD code. Used for logs and for the fallback channel (section 3). |
| `android` | `{ channelId?, sound? }` | The **receiving** app's channel and sound, chosen by the sender from `.claude/PUSH-CHANNELS.md`. `channel_id` is accepted as a spelling of `channelId`. Each `[A-Za-z0-9_.-]{1,64}`; a malformed value is ignored (reported) and the fallback applies. |
| `apns` | `{ sound? }` | iOS sound, `[A-Za-z0-9_. -]{1,64}`; malformed is ignored. |

- At least one of `title`, `body` or non-empty `data` is required (400).
- `null` for any optional field means absent. Unknown fields are **ignored**
  and listed in `ignored` (a refused push is a push nobody sees, and the apps
  do not retry).
- What is refused (400): body not an object, missing / malformed / both
  token and topic, `title` or `body` not a string, `data` not an object,
  nothing to send. 413: data too large, or the whole request over 16 KB.

This is what the apps send (`PushPayload.serverRequest` and twins):

```json
{ "token": "...", "title": "...", "body": "...",
  "data": { "type": "order_placed", "orderId": "..." },
  "kind": "order_placed",
  "android": { "channelId": "new_order", "sound": "order_alert" },
  "apns": { "sound": "order_alert.caf" } }
```

### What the function sends to FCM

Exactly the message the apps send on the legacy path
(`PushPayload.fcmV1Message`; the unit test "on the wire it is byte-for-byte..."
compares the two after firebase-admin's own conversion):

```json
{ "token": "...",
  "notification": { "title": "...", "body": "..." },
  "data": { "...": "strings only" },
  "android": { "priority": "high",
               "notification": { "channel_id": "<receiving app channel>", "sound": "<sound>" } },
  "apns": { "headers": { "apns-priority": "10" },
            "payload": { "aps": { "sound": "<sound>", "content-available": 1 } } } }
```

- `channel_id` is left out when neither the caller nor a fallback names one:
  the receiving app's manifest default channel shows it.
- `sound` defaults to `"default"` on both platforms. Without `aps.sound` an
  iPhone shows the alert silently.
- A data-only request (no title, no body) gets `android.priority: "high"` with
  no `android.notification`, and APNs `apns-priority: 5`,
  `apns-push-type: background`, `aps.content-available: 1` with no sound (what
  Apple requires for a silent push). iOS never displays a data-only push: the
  apps always send a title / body.

---

## 3. Channels and sounds (receiving app decides; from `.claude/PUSH-CHANNELS.md`)

The sender passes the receiving app's values in `android` / `apns`:

| Receiving app | Push | `android.channelId` | `android.sound` | `apns.sound` |
|---|---|---|---|---|
| customer | everything | `high_importance_channel` | `default` | `default` |
| store (vendor) | new order / booking: `order_placed`, `schedule_order`, `new_order`, `dinein_placed` | `new_order` | `order_alert` | `order_alert.caf` (in the store's Runner bundle) |
| store (vendor) | everything else (chat, `driver_accepted`, ...) | `general` | `default` | `default` |
| driver | new / assigned job: `new_delivery_order`, `assign_order`, and kinds `driver_job`, `order_available`, `job_assigned`, `job_queue`, `new_ride`, `new_parcel`, `new_rental` | `driver_jobs` | `default` | `default` |
| driver | everything else (chat, `customer_cancelled`, `driver_cancelled`, ...) | `driver_notifications_channel` | `default` | `default` |
| provider | everything | `01` | `default` | `default` |
| worker | everything | `01` | `default` | `default` |

**Fallback when the caller sends no channel** (an older build), by `kind`
(case-insensitive), reported as `profile` in the response:

| `profile` | Selected when | Channel / sounds |
|---|---|---|
| `order_alert` | `kind` is a store order kind above, **or** `data.type` is one (only if `kind` matched nothing) | `new_order`, `order_alert`, `order_alert.caf` |
| `driver_job` | `kind` is a driver job kind above (`kind` only: `data.type` values such as `parcel_order` also go to customers) | `driver_jobs`, `default`, `default` |
| `default` | everything else | no channel (manifest default), `default`, `default` |

- The caller's `android.channelId` / `sound` and `apns.sound` always win over
  the fallback.
- A channel the device does not have (e.g. `driver_jobs` on an older driver
  build) falls back to that app's manifest default channel, and a missing raw
  sound plays the default tone, so a "wrong" channel still shows the push.

---

## 4. Responses

All responses are JSON with `Cache-Control: no-store`.

**200**

```json
{ "ok": true, "messageId": "projects/spideli-870b0/messages/0:1696...",
  "profile": "order_alert", "channelId": "new_order",
  "convertedDataKeys": ["amount"], "droppedDataKeys": ["from"],
  "truncated": ["body"], "ignored": ["android.priority"] }
```

The last four lists appear only when non-empty.

**Errors** have the shape `{ "ok": false, "error": "<code>", "message": "<text>", ... }`.
A failed FCM send also carries:

- `fcmErrorCode`: FCM's own code (`UNREGISTERED`, `INVALID_ARGUMENT`,
  `SENDER_ID_MISMATCH`, `QUOTA_EXCEEDED`, `UNAVAILABLE`, `INTERNAL`,
  `THIRD_PARTY_AUTH_ERROR`, `PERMISSION_DENIED`, `UNAUTHENTICATED`), or `""`
  when the send never reached FCM. The same names the apps' legacy error
  parsers (`FcmSendError`) read.
- `deadToken`: `true` when the recipient token can never receive again
  (`UNREGISTERED`, `SENDER_ID_MISMATCH`, or a malformed token).
- `tokensCleared`: how many profiles the function blanked for that dead token
  (section 6). The app must **not** retry, and does **not** need to write the
  recipient's document itself.

| Status | `error` | Meaning / app action |
|---|---|---|
| 400 | `invalid_argument` | Bad request (`field` says which), or FCM rejected the payload. Client bug: do not retry. A 400 **without** a JSON body is malformed JSON (rejected by the framework). |
| 400 | `invalid_token` | FCM rejected the recipient token as malformed. `deadToken: true`. |
| 401 | `unauthenticated` | No `Authorization: Bearer` header. |
| 401 | `invalid_id_token` | The ID token is not valid. |
| 401 | `id_token_expired` | Call `getIdToken(true)` and retry **once** (the apps retry once on any 401). |
| 403 | `anonymous_not_allowed` | An anonymous Firebase sign-in. No app uses one. |
| 403 | `user_not_found` | The caller has no `users/{uid}` or `providers_workers/{uid}` document. |
| 403 | `user_disabled` | The account was disabled or revoked. |
| 403 | `topic_forbidden` | A topic send from a non-admin account. |
| 403 | `sender_mismatch` | The token belongs to another Firebase project (`deadToken: true` when FCM said `SENDER_ID_MISMATCH`). |
| 404 | `unregistered` | The recipient token is dead (app uninstalled or token rotated). `deadToken: true`. Do not retry. |
| 405 | `method_not_allowed` | Not a POST (`Allow: POST`). |
| 413 | `payload_too_large` | Request over 16 KB, data over 4096 bytes (`field: "data"`), or the FCM message over 4 KB. |
| 415 | `unsupported_media_type` | `Content-Type` is not `application/json`. |
| 429 | `rate_limited` | The per-account limit. Also `limit: "minute" \| "day"`, `retryAfterSeconds`, and a `Retry-After` header. Do not retry automatically. |
| 429 | `fcm_rate_limited` | FCM is throttling this target (`QUOTA_EXCEEDED`, `Retry-After: 60`). |
| 500 | `server_misconfigured` | The function's service account may not send with FCM (`PERMISSION_DENIED` / `UNAUTHENTICATED` without an FCM detail). Section 7 step 6. |
| 500 | `internal` | Anything else on the server. Check the function logs. |
| 502 | `apns_auth_error` | `THIRD_PARTY_AUTH_ERROR`: APNs refused the project's credentials. **Every iPhone push fails until the APNs key is fixed** (section 7 step 1). |
| 502 | `fcm_error` | FCM internal error. |
| 503 | `unavailable` / `fcm_unavailable` | Transient. `Retry-After` is set. One retry is acceptable, more is not. |

**Limits per signed-in account:** 60 sends in any rolling 60 seconds and 3000
per UTC day; refused attempts do not count. Change them in `functions/.env`
(`PUSH_LIMIT_PER_MINUTE`, `PUSH_LIMIT_PER_DAY`) and redeploy.

**Logging:** uid, `kind`, profile, channel, target type, a 12-character SHA-256
fingerprint of the FCM token, title / body **lengths**, data **keys**, the
adjustment lists (key names only) and the FCM error code. Never a token, a
title, a body or a data value. Apps must not log the ID token or the FCM token
either.

---

## 5. App-side reference

All five apps carry this path (uncommitted work in their own
`push_message.dart` / `push_payload.dart`, `send_notification.dart` and the
settings readers in `fire_store_utils.dart` / `main.dart`). Summary:

- `useServerPush` = `serverPushUrl` is an https URL. Checked **first** in every
  send method, before anything touches `serviceJson`. While it is true, the
  legacy key download / token minting must refuse to run.
- Build the string-only `data` map, pick the receiving app's channel / sounds
  (section 3), then POST `serverRequest(...)` with
  `Authorization: Bearer <getIdToken()>`; on 401 retry once with
  `getIdToken(true)`. 15 s timeout.
- Success is HTTP 200 only. Log anything else with the status, `error` and
  `fcmErrorCode` (never a token) and return false.
- On `deadToken: true` do nothing more: the function already cleared the token.
  (On the legacy path an app may clear `fcmToken` on a document it is allowed
  to write; under `firestore.rules.draft` that excludes other users' documents.)

| Legacy method | Server call |
|---|---|
| `sendFcmMessage(type, token, payload)` | Look up the template as today (`getNotificationContent(type)`), keep each app's behaviour for a missing template, then send with `kind: type`. |
| `sendOneNotification(token:, title:, body:, payload:)` | Send with the caller's text; `kind` when the caller has one (`delivery_otp`). |
| `sendChatFcmMessage(title, message, token, payload)` | Send with `kind: 'chat'`. |

---

## 6. Firestore

- `settings/notification_setting.serverPushUrl`: string, written by an admin
  only. The switch in section 1.
- `push_rate_limits/{uid}` (server only):
  `{ hits: number[], dayKey: 'YYYY-MM-DD', dayCount, updatedAt, expireAt }`.
  Clients must have no access:
  ```
  match /push_rate_limits/{uid} { allow read, write: if false; }
  ```
  If the live rules contain a broad allow such as
  `match /{document=**} { allow read, write: if request.auth != null; }`, that
  allow still wins (rules are OR-ed) and a client could reset its own counter
  until the broad rule is removed (`.claude/FIRESTORE-RULES-DRAFT.md`).
- **Dead-token clean-up** (`functions/src/tokens.ts`): after `deadToken`, the
  function sets `fcmToken: ""` on up to 10 documents each in `users`,
  `providers_workers` and `vendors` whose `fcmToken` equals the dead token.
  Each update is conditional on the document's update time, so a token the app
  wrote meanwhile is never overwritten. It uses the automatic single-field
  index on `fcmToken`. Turn it off with `PUSH_CLEAR_DEAD_TOKENS=false`.
  Tokens copied into orders (`author.fcmToken`, `vendor.fcmToken`) are
  snapshots and are not touched; the apps read the profile first.
- Optional clean-up of old limiter documents: a TTL policy on `expireAt` for the
  `push_rate_limits` collection group (Firebase console > Firestore > TTL, or
  `gcloud firestore fields ttls update expireAt --collection-group=push_rate_limits --enable-ttl --project=spideli-870b0`).

---

## 7. Deploy runbook (in this order; nothing has been deployed)

**Before you start: iOS.** The apps can only receive on iPhone when the Firebase
project has an **APNs authentication key** for each iOS app: Firebase console >
Project settings > Cloud Messaging > Apple app configuration > upload the `.p8`
key (Key ID, Team ID) for every one of the five iOS bundle ids. Without it FCM
answers `THIRD_PARTY_AUTH_ERROR` and no iPhone gets anything, on the legacy path
as well as this one. Also: App Store / TestFlight builds need the
`aps-environment` entitlement to resolve to `production` (Xcode does this on
export when the Push Notifications capability is on).

1. **Sign in with the right account.** The Firebase CLI on this Mac is signed in
   as an account **without** access to `spideli-870b0`. Use one that is Owner
   or Editor of the project:
   ```
   firebase login:add            # opens the browser; pick the project owner account
   firebase login:use <that-email>
   firebase projects:list        # spideli-870b0 must be listed
   ```
   (or `firebase logout` then `firebase login`). The project must be on the
   Blaze plan; it already runs `deleteUser`, so it is.
2. `firebase functions:list --project spideli-870b0`: check that no function
   named `sendPush` exists. This repo deploys under the **`push` codebase**, so
   functions deployed from elsewhere (`deleteUser` and others in the `default`
   codebase) are never touched or offered for deletion.
3. Tests, from the repo root:
   ```
   cd functions && npm ci && npm test        # 25 unit tests
   npm run test:e2e                          # 5 HTTP tests on the emulators (needs Java)
   ```
4. Deploy, from the repo root:
   ```
   firebase deploy --only functions:push:sendPush --project spideli-870b0
   ```
   (same as `npm --prefix functions run deploy`). The predeploy hook builds
   `lib/` locally and only `lib/`, `package.json` and `package-lock.json` are
   uploaded (`src`, `test`, `e2e`, `rules-test` are in the `ignore` list);
   `"gcp-build": ""` stops Cloud Build from trying to compile the absent
   TypeScript sources. Accept enabling the APIs it asks for (Cloud Functions, Cloud Build,
   Artifact Registry, Cloud Run, Eventarc). Container image retention: 1 day is
   fine. Runtime: **Node.js 22**. Note the printed function URL.
5. Smoke test without sending anything:
   ```
   curl -i -X POST https://us-central1-spideli-870b0.cloudfunctions.net/sendPush \
        -H 'Content-Type: application/json' -d '{}'
   ```
   must return `401 {"ok":false,"error":"unauthenticated",...}`. An HTML 403
   means an organisation policy blocked public invocation (`allUsers`) on the
   Cloud Run service: allow it for this service; the function authenticates
   every call itself.
6. Runtime permissions: the function runs as the default compute service
   account (`248496578266-compute@developer.gserviceaccount.com`). If a test
   send returns `500 server_misconfigured`, grant that account **Firebase Cloud
   Messaging API Admin** (`roles/firebasecloudmessaging.admin`) and **Cloud
   Datastore User** (`roles/datastore.user`) in Google Cloud > IAM.
7. Add the `push_rate_limits` rule (section 6) to the live Firestore rules.
   Optionally the TTL policy.
8. Ship the five app builds that contain the server path. While
   `serverPushUrl` is unset they keep using the legacy path, so shipping
   changes nothing yet.
9. Set `settings/notification_setting.serverPushUrl` to the function URL
   (Firebase console > Firestore > `settings` > `notification_setting`, field
   type string). Customer, driver and store switch live; provider and worker on
   their next start. If the apps enforce a minimum version (`settings/Version`),
   raise it now.
10. **Verify each app, Android and iPhone, app in foreground, background and
    killed.** Watch `firebase functions:log --only sendPush --project spideli-870b0`
    (or Logs Explorer) for `sendPush: sent` with the expected `channelId`, and
    for `FCM refused` lines:
    - customer: `order_placed` and `schedule_order` to the store (**loud
      `new_order`**), `dinein_placed`, `booking_placed` to the provider, chat
      to store / driver / provider / worker.
    - store: `restaurant_accepted` / `restaurant_rejected` /
      `restaurant_cancelled` / `takeaway_completed` / `dinein_accepted` to the
      customer, `new_delivery_order` to its own driver (`driver_jobs`),
      `driver_cancelled` (`driver_notifications_channel`), `delivery_otp`, chat.
    - driver: `driver_accepted` to the customer and the store (`general`),
      `driver_completed`, `parcel_accepted` / `parcel_completed`,
      `rental_completed`, `delivery_otp`, chat.
    - provider: `provider_accepted` / `provider_rejected` / `service_intransit`
      / `service_charges` / completion to the customer, `worker_assigned` to the
      worker (`01`), chat.
    - worker: `service_intransit` / `stop_time` / `service_completed` /
      `service_charges` to the customer, chat.
    - `apns_auth_error` on any iPhone send: fix the APNs key (top of this
      section) before going further.
11. **Only when every app sends through the function, retire the key:**
    1. Find **every other user** of this key first. The Laravel admin panel
       (`spideli-emart-admin`) may send pushes with the same JSON. Give it a
       **new** key that stays on its server only (never in Storage or
       Firestore), or route its pushes through this function from an admin
       account.
    2. Google Cloud console > IAM & Admin > Service Accounts: open the account
       in the JSON's `client_email` (normally
       `firebase-adminsdk-…@spideli-870b0.iam.gserviceaccount.com`). Under
       Keys, **delete the key whose ID equals the JSON's `private_key_id`**.
       Do not delete the service account itself. (Whoever opens the JSON to
       read `private_key_id` should delete that local copy afterwards and
       never paste the file anywhere; the Keys list also shows each key's
       creation date.)
    3. Delete the Storage object `serviceJson` pointed to. Its download-token
       URL stops working once the object is gone.
    4. Set `serviceJson` to `""` (an empty string). **Do not delete the field**:
       older driver and store builds assign `event.data()?["serviceJson"]` to a
       non-nullable `String`, and provider / worker builds call `.toString()`
       on it.
    5. Review Cloud Audit Logs (Logs Explorer,
       `protoPayload.authenticationInfo.principalEmail` = that service account)
       for use from unexpected places while the key was public.
12. Old app builds without the server path lose push after step 11.

**Rollback:** clear `serverPushUrl`. This works only until step 11; after that,
fix forward.

---

## 8. Hardening follow-ups for the function (not blockers)

- **Recipient check:** any signed-in account can push to any token (limited by
  the rate limits). Next step: send `orderId` / `chatId` and let the server
  look up the recipient's token itself, so apps never handle other users' FCM
  tokens.
- **Server-side templates:** read `dynamic_notification` on the server so
  clients cannot choose the text of "official" notifications.
- **Firebase App Check** on the request (`X-Firebase-AppCheck`) once the apps
  integrate App Check.
- `verifyIdToken(token, true)` (revocation check) if disabling an account must
  stop pushes immediately; it costs one Auth API call per push.

---

## 9. Other secrets the apps hold today (follow-ups)

These are readable by any client, because the apps read them from Firestore.
Each one needs to move to a server and be **rotated**:

- **SMTP:** `settings/emailSetting` (host, port, user, **password**) is read by
  customer, driver, store and provider (`models/mail_setting.dart`). Email is
  sent from the phone with the `mailer` package (e.g. `customer/lib/constant/constant.dart`
  `smtpServer`). Anyone can send mail as the platform. Move sending to a
  function or the Trigger Email extension, and change the SMTP password.
- **Payment gateway secrets** in `settings/*`, parsed by `models/payment_model/*`
  in customer, driver, store and provider: `stripeSettings.stripeSecret`,
  `razorpaySettings.razorpaySecret`, `paypalSettings.paypalSecret`,
  `flutterWave.secretKey`, `payStack.secretKey`, `MercadoPago.AccessToken`,
  `midtrans_settings.serverKey`, `orange_money_settings.clientSecret` and
  `merchantKey`, `xendit_settings.apiKey`, `PaytmSettings.PAYTM_MERCHANT_KEY`,
  `payFastSettings.merchant_key`. Secret keys allow refunds, payouts and reading
  customer payment data. Payment intents and orders should be created
  server-side with only publishable keys on the device. Rotate every secret
  key once moved.
- **SMS gateway:** `settings/SMSGateway` API key (OBITSMS). The customer app
  reads the whole document (`customer/lib/service/parcel_sms_outbox.dart`), so
  clients can read the key. Keep it in a document clients cannot read; Laravel
  reads it server-side.
- **OpenAI:** `settings/openai_settings`. The store app reads only `status`,
  but if the document also holds an API key, clients can read it. Move the key.
- **Google Maps keys** (`settings/googleMapKey`, the AndroidManifests, and
  `GOOGLE_API_KEY` in provider / worker `constants.dart`) are client keys by
  design. Restrict them to the apps' package names and SHA-1s / bundle ids, and
  to the Maps APIs they use.
