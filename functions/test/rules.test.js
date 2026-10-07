// Unit tests of the pure rules (compiled to lib/ by `npm test`).
const { test } = require("node:test");
const assert = require("node:assert/strict");

const {
  leadTimeMs,
  dartIntTryParse,
  dueAtMs,
  decide,
  buildDueMessage,
  templateText,
  usableToken,
  isDeadTokenError,
} = require("../lib/rules");

const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;
const ts = (ms) => ({ toMillis: () => ms }); // a Firestore Timestamp stand-in
const NOW = Date.UTC(2026, 9, 7, 12, 0, 0);

test("lead time: minute / hour / day from a number or a string (as ScheduledOrderRule.leadTime)", () => {
  assert.equal(leadTimeMs("15", "minute"), 15 * MIN);
  assert.equal(leadTimeMs(2, "hour"), 2 * HOUR);
  assert.equal(leadTimeMs("1", "day"), DAY);
  assert.equal(leadTimeMs(" 10 ", " minute "), 10 * MIN);
});

test("lead time defaults: unreadable 0, unknown or missing unit ONE minute, never negative", () => {
  assert.equal(leadTimeMs("0", "minute"), 0);
  assert.equal(leadTimeMs(null, "minute"), 0);
  assert.equal(leadTimeMs("abc", "hour"), 0);
  assert.equal(leadTimeMs("1.5", "hour"), 0);
  assert.equal(leadTimeMs("5", "week"), MIN);
  assert.equal(leadTimeMs("5", undefined), MIN);
  assert.equal(leadTimeMs("-3", "hour"), 0);
});

test("Dart int.tryParse: sign, decimal, 0x hex; nothing else", () => {
  assert.equal(dartIntTryParse("+5"), 5);
  assert.equal(dartIntTryParse("-0x1F"), -31);
  assert.equal(dartIntTryParse(""), null);
  assert.equal(dartIntTryParse("5m"), null);
});

test("due time is scheduleTime minus the lead", () => {
  assert.equal(dueAtMs(ts(NOW + HOUR), 10 * MIN), NOW + 50 * MIN);
  assert.equal(dueAtMs(new Date(NOW), 0), NOW);
  assert.equal(dueAtMs(undefined, 0), null);
});

test("decide: a placed order waits until due, then is notified (due == now counts)", () => {
  const order = { status: "Order Placed", scheduledNotificationSent: false, scheduleTime: ts(NOW + 20 * MIN) };
  assert.deepEqual(decide(order, NOW, 10 * MIN), { kind: "wait", dueAtMs: NOW + 10 * MIN });
  assert.deepEqual(decide(order, NOW + 10 * MIN, 10 * MIN), { kind: "notify", dueAtMs: NOW + 10 * MIN });
  assert.deepEqual(decide(order, NOW, 20 * MIN), { kind: "notify", dueAtMs: NOW });
  assert.equal(decide(order, NOW + DAY, 0).kind, "notify");
});

test("decide: never twice, never for an order that left Order Placed", () => {
  assert.deepEqual(decide({ status: "Order Placed", scheduledNotificationSent: true, scheduleTime: ts(NOW) }, NOW, 0), { kind: "done" });
  assert.deepEqual(decide(undefined, NOW, 0), { kind: "done" });
  for (const status of ["Order Accepted", "Order Rejected", "Order Cancelled", "Order Completed"]) {
    assert.deepEqual(decide({ status, scheduledNotificationSent: false, scheduleTime: ts(NOW - HOUR) }, NOW, 0), { kind: "skip", status });
  }
});

test("decide: no readable scheduleTime is due at once (the store lists it under New too)", () => {
  assert.equal(decide({ status: "Order Placed", scheduledNotificationSent: false }, NOW, 0).kind, "notify");
});

test("push with template text: new_order channel, order tone, string data", () => {
  const m = buildDueMessage(" tok ", "o-1", { title: "T", body: "B" });
  assert.equal(m.token, "tok");
  assert.deepEqual(m.notification, { title: "T", body: "B" });
  assert.deepEqual(m.data, { type: "scheduled_order_due", orderId: "o-1" });
  assert.deepEqual(m.android, { priority: "high", notification: { channelId: "new_order", sound: "order_alert" } });
  assert.deepEqual(m.apns, { headers: { "apns-priority": "10" }, payload: { aps: { sound: "order_alert.caf" } } });
  for (const v of Object.values(m.data)) assert.equal(typeof v, "string");
});

test("push without template text: data-only, nothing shown, never an empty notification", () => {
  const m = buildDueMessage("tok", "o-1", null);
  assert.equal(m.notification, undefined);
  assert.deepEqual(m.data, { type: "scheduled_order_due", orderId: "o-1" });
  assert.deepEqual(m.android, { priority: "high" });
  assert.deepEqual(m.apns.headers, { "apns-priority": "5", "apns-push-type": "background" });
  assert.deepEqual(m.apns.payload, { aps: { "content-available": 1 } });
});

test("template text, tokens, dead-token errors", () => {
  assert.deepEqual(templateText({ subject: " New order ", message: "Prepare it" }), { title: "New order", body: "Prepare it" });
  assert.equal(templateText({ subject: "", message: "" }), null);
  assert.equal(templateText(undefined), null);
  assert.equal(usableToken("abc"), true);
  assert.equal(usableToken(""), false);
  assert.equal(usableToken("null"), false);
  assert.equal(usableToken(undefined), false);
  assert.equal(isDeadTokenError("messaging/registration-token-not-registered"), true);
  assert.equal(isDeadTokenError("messaging/internal-error"), false);
});
