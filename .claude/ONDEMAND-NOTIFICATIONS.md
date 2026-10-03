# On-demand booking notifications — one contract for Customer, Provider, Worker

Client requirement (3 Oct 2026): every on-demand booking action notifies the
other party, immediately, exactly once, with consistent data, and tapping the
notification opens that booking.

Booking record: `provider_orders/{orderId}` (`OnProviderOrderModel`). Statuses
(already used by all three apps — do not add new ones): `Order Placed`,
`Order Accepted`, `Order Assigned`, `Order Ongoing`, `Order Completed`,
`Order Rejected`, `Order Cancelled`.

## Data payload (every on-demand push, all values strings)

| key | value |
|---|---|
| `type` | `provider_order` (the routing key all three apps already use) |
| `event` | the event code below |
| `orderId` | the booking id (`provider_orders` doc id) |
| `status` | the booking status after the action |
| `serviceId` / `serviceName` | the booked service (`order.provider.id` / title), when known |
| `customerId` / `providerId` / `workerId` | the parties, when known |
| `senderRole` | `customer` \| `provider` \| `worker` |

Never send nulls (drop the key). Each app's existing payload builder already
stringifies values.

## Recipient and token

Always pass the recipient's id so the sender reads the CURRENT token:
customer and provider from `users/{id}.fcmToken`, worker from
`providers_workers/{id}.fcmToken`; the token copied on the booking is only a
fallback. Channel by recipient app: customer `high_importance_channel`,
provider `01`, worker `01` (see `.claude/PUSH-CHANNELS.md`).

## Title / body

Use the existing Firestore template (`dynamic_notification`, via
`sendFcmMessage(templateType, ...)`) where one exists for the event; templates
that exist: `booking_placed`, `provider_accepted`, `provider_rejected`,
`service_intransit`, `stop_time`, `service_completed`, `service_cancelled`,
`service_charges`, `worker_assigned`. For an event with no template, send an
app-defined, translated title/body (`sendOneNotification`) — do NOT write to
Firestore templates.

## Events

| # | Who acts | Action | event | Notify | Template |
|---|---|---|---|---|---|
| 1 | Customer | books (every booking path, incl. after payment) | `booking_placed` | Provider | `booking_placed` |
| 2 | Customer | cancels the booking | `booking_cancelled_by_customer` | Provider (and Worker if one is assigned) | `service_cancelled` |
| 3 | Provider | accepts | `provider_accepted` | Customer | `provider_accepted` |
| 4 | Provider | rejects / cancels | `provider_rejected` | Customer (and Worker if one was assigned) | `provider_rejected` |
| 5 | Provider | assigns a worker | `worker_assigned` | Worker | `worker_assigned` |
| 6 | Provider | assigns / changes the worker | `worker_assigned_customer` | Customer | none: "A worker has been assigned to your booking" / "Your booking's worker has changed" |
| 7 | Provider | removes a worker from the booking (reassign) | `worker_unassigned` | the previous Worker | none: "This booking is no longer assigned to you" |
| 8 | Provider or Worker | starts the service | `service_intransit` | Customer | `service_intransit` |
| 9 | Provider or Worker | stops the time (hourly) | `stop_time` | Customer | `stop_time` |
| 10 | Provider or Worker | adds extra charges | `service_charges` | Customer | `service_charges` |
| 11 | Provider or Worker | completes | `service_completed` | Customer | `service_completed` |
| 12 | Worker | accepts the assigned job (the Worker app has NO such action today) | `worker_accepted` | Customer and Provider | none |
| 13 | Worker | rejects / declines the assigned job (no such action today) | `worker_rejected` | Customer and Provider | none |
| 14a | Provider | "Assign to myself" (Accepted → Assigned, no worker) | `provider_self_assigned` | Customer | none |
| 14b | Customer | pays an hourly booking ("Pay Now", booking already exists) | `booking_paid` | Provider (and Worker if assigned) | none |
| 14c | Customer | pays extra charges | `extra_charges_paid` | Provider (and Worker if assigned) | none |
| 14 | any | any other status change found in the code | an event code named after it | the other parties | template if one fits |

Rules: one push per recipient per action (a screen and a list that both offer
the action must not both send); a failed push never blocks or undoes the
action; the action's Firestore write happens first, the push after.

## Tap behaviour

| App | Opens |
|---|---|
| Customer | the on-demand booking details screen for `orderId` |
| Provider | the booking details screen for `orderId` |
| Worker | the job details screen for `orderId` (or the job list if it was unassigned) |

Works from foreground (local notification tap), background
(`onMessageOpenedApp`) and terminated (`getInitialMessage`, opened after the
app's start-up navigation); a missing/invalid `orderId` opens the bookings
list and never crashes.

## Notes (3 Oct 2026, implementation)

- Provider declining a booking also tells an assigned worker with app text
  "Booking cancelled" (the `provider_rejected` template is worded for the
  customer). Reassignment pushes also carry `previousWorkerId`.
- Provider sends go through `spideli_provider/lib/services/booking_notifier.dart`
  (one call per action, 30 s de-duplication); customer through
  `customer/lib/service/on_demand_notifier.dart`; worker through
  `spideli_worker/lib/ui/booking_list/job_actions.dart` `JobActions.notifyCustomer`.
- Fixed: the customer's cancel flow used to send the `booking_placed`
  template ("New Booking Received") to the provider.
