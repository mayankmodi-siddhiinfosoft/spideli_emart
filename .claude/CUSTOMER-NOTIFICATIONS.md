# Customer Notification Center + chat unread badges — contract (2026-10-07)

## 1. Customer notifications — `users/{customerId}/notifications/{notificationId}`

One document per notification shown to the customer (no Cloud Function).

| Field | Type | Notes |
|---|---|---|
| `id` | string | = document id |
| `title` | string | the push title (from the `dynamic_notification` template / chat sender) |
| `body` | string | the push body |
| `type` | string | the template type or push data `type` (`store_accepted`, `driver_accepted`, `restaurant_cancelled`, `delivery_otp`, `provider_order`, `orderChat`, `admin_chat`, …) |
| `category` | string | `order` \| `chat` \| `booking` \| `account` \| `other` — for the icon/filter |
| `orderId` | string | when the push concerns an order/booking (may be empty) |
| `status` | string | the order/booking status after the event, when known (may be empty) |
| `data` | map<string,string> | the push data payload as sent (used to route the tap exactly like a push tap) |
| `read` | bool | `false` on creation; set `true` when the customer views it |
| `createdAt` | Timestamp | server timestamp |
| `source` | string | `store` \| `driver` \| `provider` \| `worker` \| `customer` (recorded on receipt) |

### Who writes it
- **Senders (Store, Driver, Provider, Worker apps):** every push sent to a CUSTOMER (recipient = customer app: order/booking status pushes, delivery/pickup code pushes, chat pushes) also writes this document — same title/body as the push (template text or chat text), best effort (a failed write never blocks the push or the action). The push `data` then carries `notificationId: <id>`.
- **Customer app (fallback):** when a push is received (foreground `onMessage`, background handler, opened from terminated) and its data has **no** `notificationId`, the customer app writes the document itself with id = `msg_<FCM messageId>` (or a stable hash of type+orderId+sentTime when messageId is missing), so it is stored once even if seen by several handlers. This covers admin-panel pushes and older sender builds.
- Ids are unique per notification (sender: Firestore auto id or uuid).

### Customer app UI
- Notification Center screen: newest first (`orderBy createdAt desc`, paginated / limit 100), each row: icon by category, title, body, relative time + date, status chip when `status` is set, unread rows visually distinct (bold + dot/tint). Empty state. Pull to refresh not needed (live stream).
- Unread badge: a bell icon with the unread count (`where read == false`, live) on the main home screens (service list/home) and anywhere the app already shows a notifications entry.
- Tap: mark that notification read, then route with the existing push-tap router (`PushTap.targetOf(data)` / `NotificationService.routeTap`) — order details, chat, booking, etc. Unknown/missing targets: stay on the list, never crash.
- Viewing: opening the Notification Center marks the notifications shown as read (batched write) — rows keep their "new" styling for the current visit.
- Signed-out users: no bell / no center.

## 2. Chat unread badge (all apps with a chat inbox/conversation list)
- Each conversation row in the chat list shows a badge with the number of messages in THAT conversation where `receiverId == me` (or the app's equivalent) and `seen == false`.
- Live (`snapshots`), updates when new messages arrive and when they are marked seen (opening the conversation already marks them seen — verify; fix if not).
- Count capped for display (e.g. `99+`). Zero = no badge.
- Must not load whole threads unnecessarily: a count query (`count()` aggregate) or a limited `where(seen == false, receiverId == me)` listener per visible row; or a per-conversation unread counter kept on the inbox document if the app already has one. Choose per app and document it.

### driver (`driver/`) — implementation notes
- Senders: `driver/lib/constant/send_notification.dart` (`_recordForCustomer`, `notifyCustomer`); pure rules in `driver/lib/services/customer_notification.dart`. Recorded for every customer push (`driver_accepted`, `driver_completed`, `parcel_accepted`, `parcel_completed`, `rental_completed`, `delivery_otp`, chat), also when the customer has no usable token (no push, record only). A failed write drops `notificationId` from the push data (customer fallback stores it); a write slower than 8 s keeps it. No template = no push and no record.
- Chat unread: per inbox row a live `chat/{orderId}/thread where receiverId == me && seen == false limit(100)` listener (`FireStoreUtils.unreadOrderChatCount`, `driver/lib/widget/chat_unread_badge.dart`), equality filters only. Opening the chat marks the messages addressed to the driver seen while it is open (`receiverId == me && seen == false`, the badge's filter; the old `senderId != me` needed a composite index and also touched the customer's messages to the store, which share the thread); the seen listener now stops when the chat closes (`ChatController.onClose`).

### customer (`customer/`) — implementation notes
- Chat unread: per inbox row a live `chat/{orderId}/thread where receiverId == me && senderId == peer && seen == false limit(100)` listener (`ChatUnreadService.orderThread`, `FireStoreUtils.unreadOrderChatQuery`). The store and driver chats of one order (and the provider and worker chats of one booking) share the thread, so the peer filter keeps each row's count to its own conversation; opening a chat marks seen only that peer's messages (`setSeenChatForOrder(orderId, senderId: receivedId)`). Equality filters only.
- Fallback records (`CustomerNotificationService.recordPush`) carry `source: customer` (the sender's role, when given, stays in `data.senderRole`); nothing is written when the existence check fails (offline), so an already-read entry is never reset; `get`/`set` are bounded to 10 s.
- Tapping an `order` or `booking` row the push router has no target for opens its details (`OrderNotificationOpener`: vendor / provider / ride / parcel / rental orders, then `booked_table` for a table booking, own `authorID` only).

### Firestore rules
- `firestore.rules.draft` has `match /users/{userId}/notifications/{notificationId}`: any signed-in sender creates (`id` = doc id, `read == false`); only the owner (or admin) reads, deletes, and updates `read` alone. The live rules need the same before the senders' writes can succeed.

### customer — profile badges
- Profile → Communication: Notifications (`LiveUnreadBadge.notifications()`, unread `users/{uid}/notifications`), Store / Driver / Provider / Worker Inbox (`LiveUnreadBadge.inbox(kind)`, `InboxUnreadService`: the inbox list query `FireStoreUtils.orderInboxQuery(uid, chatType)` + one `ChatUnreadService.orderThread(thread, peer)` per conversation, summed live; newest 50 conversations per inbox), Help & Support (`LiveUnreadBadge.supportChat()`). Every badge follows `authStateChanges`; hidden at 0, "99+" past 99.
