// Emulator tests for /firestore.rules.draft.
//
//   cd functions/rules-test && npm install && npm test
//
// `npm test` starts the Firestore emulator under the demo-spideli project id
// (a "demo-" project never reaches a real Firebase project), loads the draft
// rules (or RULES_FILE) into it, and runs these cases. Each case mirrors a
// write one of the five apps really makes (file names in the comments), or an
// attack the draft is meant to stop. After merging the draft with the live
// rules, add a case for every rule the merge brought in and run this again,
// with RULES_FILE pointing at the merged file, before publishing.
const { before, after, beforeEach, describe, test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  writeBatch,
  runTransaction,
  increment,
  arrayUnion,
  Timestamp,
  setLogLevel,
} = require("firebase/firestore");

// Every refused write is expected by some case; keep the SDK from logging each one.
setLogLevel("silent");

// RULES_FILE=/path/to/merged.rules npm test  - test the file you are about to publish.
const RULES_PATH = process.env.RULES_FILE ? path.resolve(process.env.RULES_FILE) : path.join(__dirname, "..", "..", "..", "firestore.rules.draft");
const DAY = 86_400_000;

let env;

function as(uid, claims) {
  return env.authenticatedContext(uid, claims).firestore();
}
function anon() {
  return env.unauthenticatedContext().firestore();
}
/** setKnownFields() in the apps: a merge set of exactly these top-level keys. */
function setKnown(ref, data) {
  return setDoc(ref, data, { mergeFields: Object.keys(data) });
}

const PLAN_CUSTOMER = { isEnable: true, planFor: "customer", expiryDay: "30", features: { orderHistory: true }, name: "Monthly" };

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const put = (p, d) => setDoc(doc(db, p), d);
    await Promise.all([
      put("settings/DriverNearBy", { auto_approve_driver: false }),
      put("settings/vendor", { auto_approve_vendor: false }),
      put("settings/provider", { auto_approve_provider: true }),
      put("settings/document_verification_settings", { isDriverVerification: true, isOwnerVerification: true, isStoreVerification: false }),
      put("settings/notification_setting", { senderId: "248496578266", serviceJson: "", serverPushUrl: "" }),

      put("subscription_plans/cust_monthly", PLAN_CUSTOMER),
      put("subscription_plans/cust_disabled", { ...PLAN_CUSTOMER, isEnable: false }),
      put("subscription_plans/vendor_basic", { isEnable: true, expiryDay: "30", orderLimit: "10", name: "Basic" }),

      put("users/admin1", { id: "admin1", role: "admin" }),
      put("users/cust1", { id: "cust1", role: "customer", active: true, wallet_amount: 10, fcmToken: "tok-cust1", email: "c1@x.test" }),
      put("users/cust2", { id: "cust2", role: "customer", active: true, wallet_amount: 0 }),
      put("users/drv1", { id: "drv1", role: "driver", active: true, isActive: false, isDocumentVerify: false, isOwner: false, vendorID: "", fcmToken: "tok-drv1", wallet_amount: 0, reviewsCount: "0" }),
      put("users/drvOff", { id: "drvOff", role: "driver", active: false, isDocumentVerify: false }),
      put("users/owner1", { id: "owner1", role: "driver", isOwner: true, active: true, isDocumentVerify: true }),
      put("users/fleetDrv", { id: "fleetDrv", role: "driver", ownerId: "owner1", active: true, isDocumentVerify: true }),
      put("users/vend1", { id: "vend1", role: "vendor", vendorID: "store1", active: true }),
      put("users/vend2", { id: "vend2", role: "vendor", vendorID: "store2", active: true }),
      put("users/emp1", { id: "emp1", role: "employee", vendorID: "store1", employeePermissionId: "r1" }),
      put("users/storeDrv", { id: "storeDrv", role: "driver", vendorID: "store1", active: true, phoneNumber: "100" }),
      put("users/prov1", { id: "prov1", role: "provider", active: true, wallet_amount: 0 }),
      put("users/prov2", { id: "prov2", role: "provider", active: true }),

      put("vendors/store1", { id: "store1", author: "vend1" }),
      put("vendors/store2", { id: "store2", author: "vend2" }),
      put("vendors/store3", { id: "store3", author: "vend1" }),

      put("providers_workers/wrk1", { id: "wrk1", providerId: "prov1", role: "", active: true, isActive: true, salary: 500, wallet_amount: 0, online: false, fcmToken: "tok-wrk1", reviewsCount: 0 }),
      put("providers_workers/wrkOff", { id: "wrkOff", providerId: "prov1", active: false, isActive: false }),
      put("providers_workers/wrkLegacy", { id: "wrkLegacy", providerId: "prov1", isActive: true }),

      put("vendor_orders/ord1", { id: "ord1", authorID: "cust1", driverID: "drv1", vendorID: "store1", status: "In Transit" }),
      put("order_pod/ord1", { orderId: "ord1", customerId: "cust1", driverId: "drv1", vendorId: "store1", status: "pending", code: "1234" }),

      put("wallet/w1", { id: "w1", user_id: "cust1", order_id: "ord1", amount: 5 }),
      put("wallet/w2", { id: "w2", user_id: "cust2", amount: 7 }),

      put("parcel_sms_outbox/p1", { id: "p1", sendState: "sent" }),
      put("push_rate_limits/cust1", { hits: [], dayKey: "2026-10-03", dayCount: 1 }),
    ]);
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-spideli",
    firestore: { rules: fs.readFileSync(RULES_PATH, "utf8") },
  });
});
after(async () => {
  if (env) await env.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
  await seed();
});

// ---------------------------------------------------------------------------
describe("users: sign-up", () => {
  test("customer: {wallet_amount: 0} stub, then the profile (customer updateUser)", async () => {
    const db = as("newCust");
    const ref = doc(db, "users/newCust");
    await assertSucceeds(setDoc(ref, { wallet_amount: 0 }, { merge: true }));
    await assertSucceeds(setKnown(ref, { id: "newCust", role: "customer", active: true, isActive: false, isDocumentVerify: false, fcmToken: "t", sectionIds: [] }));
  });

  test("nobody signs up as admin, employee, or with money", async () => {
    await assertFails(setDoc(doc(as("x1"), "users/x1"), { role: "admin" }));
    await assertFails(setDoc(doc(as("x2"), "users/x2"), { role: "employee", vendorID: "store1" }));
    await assertFails(setDoc(doc(as("x3"), "users/x3"), { role: "customer", wallet_amount: 100 }));
  });

  test("the stub cannot be turned into an admin either", async () => {
    const db = as("x4");
    await assertSucceeds(setDoc(doc(db, "users/x4"), { wallet_amount: 0 }));
    await assertFails(setKnown(doc(db, "users/x4"), { role: "admin" }));
  });

  test("driver: active / verified only when the settings say so (driver signup_controller)", async () => {
    // auto_approve_driver is false and isDriverVerification is true in the seed.
    await assertFails(setDoc(doc(as("d1"), "users/d1"), { role: "driver", active: true }));
    await assertFails(setDoc(doc(as("d2"), "users/d2"), { role: "driver", active: false, isDocumentVerify: true }));
    await assertSucceeds(setDoc(doc(as("d3"), "users/d3"), { role: "driver", active: false, isDocumentVerify: false, isAutoVerify: false, isOwner: false, isActive: false }));
    // Company sign-up may set isOwner, never an ownerId.
    await assertSucceeds(setDoc(doc(as("d4"), "users/d4"), { role: "driver", active: false, isOwner: true }));
    await assertFails(setDoc(doc(as("d5"), "users/d5"), { role: "driver", active: false, ownerId: "owner1" }));
  });

  test("provider: auto-approve on means it may start active (provider signup_controller)", async () => {
    await assertSucceeds(setKnown(doc(as("p9"), "users/p9"), { id: "p9", role: "provider", active: true, wallet_amount: 0, subscriptionPlanId: null, subscription_plan: null, subscriptionExpiryDate: null }));
  });

  test("vendor: isAutoVerify allowed because store verification is off; vendorID must be its own store", async () => {
    await assertSucceeds(setDoc(doc(as("v9"), "users/v9"), { role: "vendor", active: false, isDocumentVerify: true, isAutoVerify: true, vendorID: "" }));
    await assertFails(setDoc(doc(as("v8"), "users/v8"), { role: "vendor", active: false, vendorID: "store1" }));
  });
});

// ---------------------------------------------------------------------------
describe("users: the account editing itself", () => {
  test("ordinary fields stay writable: fcmToken, profile, location, online switch", async () => {
    await assertSucceeds(updateDoc(doc(as("cust1"), "users/cust1"), { fcmToken: "new", firstName: "A", shippingAddress: [] }));
    // driver fire_store_utils.updateUserLocation / notification_service / online toggle
    await assertSucceeds(updateDoc(doc(as("drv1"), "users/drv1"), { location: { latitude: 1, longitude: 2 }, rotation: 90 }));
    await assertSucceeds(setDoc(doc(as("drv1"), "users/drv1"), { fcmToken: "" }, { merge: true }));
    await assertSucceeds(updateDoc(doc(as("drv1"), "users/drv1"), { isActive: true }));
  });

  test("role, verification, ownership, activation cannot be raised by the account", async () => {
    const db = as("drv1");
    await assertFails(updateDoc(doc(db, "users/drv1"), { role: "admin" }));
    await assertFails(updateDoc(doc(db, "users/drv1"), { isDocumentVerify: true }));
    await assertFails(updateDoc(doc(db, "users/drv1"), { isAutoVerify: true }));
    await assertFails(updateDoc(doc(db, "users/drv1"), { isOwner: true }));
    await assertFails(updateDoc(doc(db, "users/drv1"), { ownerId: "owner1" }));
    await assertFails(updateDoc(doc(db, "users/drv1"), { carrierId: "c1" }));
    await assertFails(updateDoc(doc(as("drvOff"), "users/drvOff"), { active: true }));
  });

  test("a whole-profile write-back that changes nothing privileged passes (driver updateUser)", async () => {
    await assertSucceeds(
      setDoc(doc(as("drv1"), "users/drv1"), { id: "drv1", role: "driver", active: true, isActive: true, isDocumentVerify: false, isOwner: false, vendorID: "", firstName: "D" }, { merge: true }),
    );
  });

  test("business account: pending request yes, approval no (customer business_account.dart)", async () => {
    const db = as("cust1");
    const pending = { companyName: "Co", registrationNumber: "R1", documentUrl: "https://x", status: "pending", submittedAt: Timestamp.now() };
    await assertSucceeds(updateDoc(doc(db, "users/cust1"), { accountType: "business", businessProfile: pending }));
    await assertFails(updateDoc(doc(db, "users/cust1"), { businessProfile: { ...pending, status: "approved" } }));
    await assertFails(updateDoc(doc(db, "users/cust1"), { businessProfile: { ...pending, reviewedBy: "me" } }));
  });

  test("customer plan purchase: real plan, one period, snapshot of that plan (customer_plan_service.recordPurchase)", async () => {
    const db = as("cust1");
    const snapshot = { ...PLAN_CUSTOMER, id: "cust_monthly", planFor: "customer" };
    const write = (planId, snap, days) => {
      const b = writeBatch(db);
      b.update(doc(db, "users/cust1"), { subscriptionPlanId: planId, subscription_plan: snap, subscriptionExpiryDate: Timestamp.fromMillis(Date.now() + days * DAY) });
      b.set(doc(db, "subscription_history/h1"), { id: "h1", user_id: "cust1", subscription_plan: snap });
      return b.commit();
    };
    await assertFails(write("cust_monthly", snapshot, 400));
    await assertFails(write("cust_disabled", { ...snapshot, id: "cust_disabled" }, 30));
    await assertFails(write("vendor_basic", { id: "vendor_basic", planFor: "customer" }, 30));
    await assertFails(write("cust_monthly", { ...snapshot, features: { orderHistory: true, everything: true } }, 30));
    await assertSucceeds(write("cust_monthly", snapshot, 30));
  });

  test("vendor plan before the first store (vendor updateUser with vendorID '')", async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), "users/vend2"), { vendorID: "" }));
    const db = as("vend2");
    await assertSucceeds(updateDoc(doc(db, "users/vend2"), { subscriptionPlanId: "vendor_basic", subscriptionExpiryDate: Timestamp.fromMillis(Date.now() + 30 * DAY) }));
    await assertFails(updateDoc(doc(db, "users/vend2"), { subscriptionPlanId: "cust_monthly", subscriptionExpiryDate: Timestamp.fromMillis(Date.now() + 30 * DAY) }));
  });

  test("vendorID: an owned store yes, someone else's store no (StoreService.selectStore)", async () => {
    await assertSucceeds(updateDoc(doc(as("vend1"), "users/vend1"), { vendorID: "store3" }));
    await assertFails(updateDoc(doc(as("vend1"), "users/vend1"), { vendorID: "store2" }));
    await assertFails(updateDoc(doc(as("emp1"), "users/emp1"), { vendorID: "store3" }));
    await assertFails(updateDoc(doc(as("emp1"), "users/emp1"), { employeePermissionId: "owner-role" }));
  });

  test("wallet_amount on the account itself: KNOWN GAP, a number is accepted", async () => {
    await assertSucceeds(updateDoc(doc(as("cust1"), "users/cust1"), { wallet_amount: 5 }));
    await assertFails(updateDoc(doc(as("cust1"), "users/cust1"), { wallet_amount: "lots" }));
  });

  test("account deletion: own document only", async () => {
    await assertFails(deleteDoc(doc(as("cust1"), "users/cust2")));
    await assertSucceeds(deleteDoc(doc(as("cust1"), "users/cust1")));
  });
});

// ---------------------------------------------------------------------------
describe("users: someone else's document", () => {
  test("customer rating a driver: counters yes; token, wallet, verification no", async () => {
    const db = as("cust1");
    await assertSucceeds(updateDoc(doc(db, "users/drv1"), { reviewsCount: "1", reviewsSum: "5" }));
    await assertFails(updateDoc(doc(db, "users/drv1"), { fcmToken: "attacker" }));
    await assertFails(updateDoc(doc(db, "users/drv1"), { wallet_amount: 1000 }));
    await assertFails(updateDoc(doc(db, "users/drv1"), { isDocumentVerify: true }));
    await assertFails(updateDoc(doc(db, "users/cust2"), { wallet_amount: increment(50) }));
  });

  test("paying apps move other users' balances (driver/store/provider/worker updateUserWallet)", async () => {
    const db = as("drv1");
    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const ref = doc(db, "users/cust1");
        const snap = await tx.get(ref);
        tx.update(ref, { wallet_amount: snap.data().wallet_amount + 3 });
      }),
    );
    await assertSucceeds(updateDoc(doc(as("wrk1"), "users/prov1"), { wallet_amount: increment(-2) }));
  });

  test("store assigns / releases orders on any driver (vendor addDriverOrder)", async () => {
    await assertSucceeds(setDoc(doc(as("vend1"), "users/drv1"), { inProgressOrderID: arrayUnion("ord1") }, { merge: true }));
  });

  test("store manages its own delivery men and employees only", async () => {
    await assertSucceeds(setDoc(doc(as("vend1"), "users/storeDrv"), { active: false }, { merge: true }));
    await assertSucceeds(updateDoc(doc(as("vend1"), "users/storeDrv"), { phoneNumber: "200", firstName: "N" }));
    await assertSucceeds(updateDoc(doc(as("vend1"), "users/emp1"), { employeePermissionId: "r2" }));
    // (storeDrv is inactive now, so this would be a real change.)
    await assertFails(setDoc(doc(as("vend2"), "users/storeDrv"), { active: true }, { merge: true }));
    await assertFails(updateDoc(doc(as("vend1"), "users/storeDrv"), { vendorID: "store3" }));
    await assertFails(updateDoc(doc(as("vend1"), "users/emp1"), { role: "vendor" }));
  });

  test("store creates a delivery man / employee for its store (vendor add_driver / add_employee)", async () => {
    const db = as("vend1");
    await assertSucceeds(setKnown(doc(db, "users/newDrv"), { id: "newDrv", role: "driver", vendorID: "store1", active: true, isDocumentVerify: true, fcmToken: "" }));
    await assertSucceeds(setKnown(doc(db, "users/newEmp"), { id: "newEmp", role: "employee", vendorID: "store1", employeePermissionId: "r1" }));
    await assertFails(setKnown(doc(db, "users/badDrv"), { id: "badDrv", role: "driver", vendorID: "store2" }));
    await assertFails(setKnown(doc(db, "users/badVend"), { id: "badVend", role: "vendor", vendorID: "store1" }));
  });

  test("fleet owner creates and edits its drivers (driver_create_controller)", async () => {
    const db = as("owner1");
    await assertSucceeds(setDoc(doc(db, "users/newFleet"), { id: "newFleet", role: "driver", ownerId: "owner1", active: true, isDocumentVerify: true, isOwner: false }, { merge: true }));
    await assertFails(setDoc(doc(db, "users/badFleet"), { id: "badFleet", role: "driver", ownerId: "owner1", isOwner: true }, { merge: true }));
    await assertFails(setDoc(doc(as("drv1"), "users/notMine"), { id: "notMine", role: "driver", ownerId: "drv1", active: true }));
    await assertSucceeds(setDoc(doc(db, "users/fleetDrv"), { phoneNumber: "9", active: false, isActive: false }, { merge: true }));
    await assertSucceeds(deleteDoc(doc(db, "users/fleetDrv")));
  });

  test("admin: custom claim or users.role == 'admin'", async () => {
    await assertSucceeds(updateDoc(doc(as("panel", { admin: true }), "users/drv1"), { isDocumentVerify: true }));
    await assertSucceeds(updateDoc(doc(as("admin1"), "users/drv1"), { role: "driver", active: false }));
  });
});

// ---------------------------------------------------------------------------
describe("providers_workers", () => {
  test("worker saves its profile and online switch (worker updateCurrentUser)", async () => {
    const db = as("wrk1");
    await assertSucceeds(
      setKnown(doc(db, "providers_workers/wrk1"), { id: "wrk1", providerId: "prov1", role: "", active: true, isActive: true, salary: 500, wallet_amount: 0, online: true, fcmToken: "new", firstName: "W" }),
    );
    await assertSucceeds(updateDoc(doc(db, "providers_workers/wrk1"), { fcmToken: "" }));
  });

  test("worker cannot re-point, re-activate, verify or pay itself a salary", async () => {
    const db = as("wrk1");
    await assertFails(updateDoc(doc(db, "providers_workers/wrk1"), { salary: 5000 }));
    await assertFails(updateDoc(doc(db, "providers_workers/wrk1"), { providerId: "prov2" }));
    await assertFails(updateDoc(doc(db, "providers_workers/wrk1"), { isDocumentVerify: true }));
    await assertFails(updateDoc(doc(as("wrkOff"), "providers_workers/wrkOff"), { active: true, isActive: true }));
  });

  test("legacy worker with only isActive: the app's active = isActive write-back passes", async () => {
    await assertSucceeds(setKnown(doc(as("wrkLegacy"), "providers_workers/wrkLegacy"), { active: true, isActive: true, online: true }));
  });

  test("provider creates, edits and removes its own workers only (add_worker_controller)", async () => {
    const db = as("prov1");
    await assertSucceeds(setDoc(doc(db, "providers_workers/newW"), { id: "newW", providerId: "prov1", role: "", active: true, salary: 300, wallet_amount: 0 }));
    await assertFails(setDoc(doc(db, "providers_workers/badW"), { id: "badW", providerId: "prov2", active: true }));
    await assertFails(setDoc(doc(db, "providers_workers/badW2"), { id: "badW2", providerId: "prov1", isDocumentVerify: true }));
    await assertFails(setDoc(doc(as("cust1"), "providers_workers/badW3"), { id: "badW3", providerId: "cust1" }));
    await assertSucceeds(setKnown(doc(db, "providers_workers/wrk1"), { salary: 600, active: false }));
    await assertFails(setKnown(doc(as("prov2"), "providers_workers/wrk1"), { salary: 1 }));
    await assertFails(setKnown(doc(db, "providers_workers/wrk1"), { providerId: "prov2" }));
    await assertSucceeds(deleteDoc(doc(db, "providers_workers/wrkOff")));
    await assertFails(deleteDoc(doc(as("prov2"), "providers_workers/wrk1")));
  });

  test("customer rating a worker writes back its WorkerModel (on_demand_review_controller)", async () => {
    const db = as("cust1");
    await assertSucceeds(
      setKnown(doc(db, "providers_workers/wrk1"), { id: "wrk1", providerId: "prov1", active: true, salary: 500, online: false, fcmToken: "tok-wrk1", email: "", phoneNumber: "", reviewsCount: 1, reviewsSum: 5 }),
    );
    await assertFails(updateDoc(doc(db, "providers_workers/wrk1"), { salary: 1 }));
    await assertFails(updateDoc(doc(db, "providers_workers/wrk1"), { fcmToken: "attacker" }));
  });
});

// ---------------------------------------------------------------------------
describe("settings and server-only data", () => {
  test("settings: public read, admin-only write", async () => {
    await assertSucceeds(getDoc(doc(anon(), "settings/notification_setting")));
    await assertFails(updateDoc(doc(as("cust1"), "settings/notification_setting"), { serverPushUrl: "https://evil.test" }));
    await assertFails(setDoc(doc(as("vend1"), "settings/new"), { x: 1 }));
    await assertSucceeds(updateDoc(doc(as("panel", { admin: true }), "settings/notification_setting"), { serverPushUrl: "https://us-central1-spideli-870b0.cloudfunctions.net/sendPush" }));
  });

  test("push_rate_limits: no client access at all", async () => {
    await assertFails(getDoc(doc(as("cust1"), "push_rate_limits/cust1")));
    await assertFails(setDoc(doc(as("cust1"), "push_rate_limits/cust1"), { hits: [], dayCount: 0 }));
  });

  test("subscription plans read-only for clients", async () => {
    await assertSucceeds(getDoc(doc(anon(), "subscription_plans/cust_monthly")));
    await assertFails(setDoc(doc(as("prov1"), "subscription_plans/cust_monthly"), { expiryDay: "-1" }, { merge: true }));
  });

  test("subscription_history: the buyer's own row", async () => {
    await assertSucceeds(setDoc(doc(as("prov1"), "subscription_history/h2"), { id: "h2", user_id: "prov1" }));
    await assertFails(setDoc(doc(as("prov1"), "subscription_history/h3"), { id: "h3", user_id: "prov2" }));
  });

  test("an unlisted collection is admin only", async () => {
    await assertFails(setDoc(doc(as("cust1"), "secret_stuff/a"), { x: 1 }));
    await assertSucceeds(setDoc(doc(as("panel", { admin: true }), "secret_stuff/a"), { x: 1 }));
  });
});

// ---------------------------------------------------------------------------
describe("order_pod and vendor_orders.pod", () => {
  test("code readable by the order's customer, driver and store; not by others", async () => {
    await assertSucceeds(getDoc(doc(as("cust1"), "order_pod/ord1")));
    await assertSucceeds(getDoc(doc(as("drv1"), "order_pod/ord1")));
    await assertSucceeds(getDoc(doc(as("vend1"), "order_pod/ord1")));
    await assertSucceeds(getDoc(doc(as("emp1"), "order_pod/ord1")));
    await assertFails(getDoc(doc(as("cust2"), "order_pod/ord1")));
    await assertFails(getDoc(doc(as("vend2"), "order_pod/ord1")));
    await assertFails(getDocs(collection(as("cust1"), "order_pod")));
  });

  test("a code that does not exist yet reads as missing", async () => {
    await assertSucceeds(getDoc(doc(as("cust2"), "order_pod/nope")));
  });

  test("only the order's driver / store generate a code", async () => {
    await assertFails(setDoc(doc(as("cust1"), "order_pod/ord1"), { orderId: "ord1", status: "verified" }));
    await assertFails(setDoc(doc(as("drv1"), "order_pod/ord1"), { orderId: "other" }));
  });

  test("vendor_orders.pod becomes verified only with order_pod verified in the same write", async () => {
    const db = as("drv1");
    await assertFails(updateDoc(doc(db, "vendor_orders/ord1"), { pod: { status: "verified" } }));
    const b = writeBatch(db);
    b.update(doc(db, "order_pod/ord1"), { status: "verified", verifiedAt: Timestamp.now() });
    b.update(doc(db, "vendor_orders/ord1"), { pod: { status: "verified" }, status: "Order Completed" });
    await assertSucceeds(b.commit());
  });
});

// ---------------------------------------------------------------------------
describe("wallet ledger and parcel SMS outbox", () => {
  test("customer lists its own rows only (customer getWalletTransaction)", async () => {
    await assertSucceeds(getDocs(query(collection(as("cust1"), "wallet"), where("user_id", "==", "cust1"))));
    await assertFails(getDocs(collection(as("cust1"), "wallet")));
    await assertFails(getDoc(doc(as("cust1"), "wallet/w2")));
    await assertSucceeds(getDocs(query(collection(as("drv1"), "wallet"), where("order_id", "==", "ord1"))));
  });

  test("rows are created with their own id and never edited by a customer", async () => {
    await assertSucceeds(setDoc(doc(as("cust1"), "wallet/w3"), { id: "w3", user_id: "cust1", amount: -2 }));
    await assertFails(setDoc(doc(as("cust1"), "wallet/w4"), { id: "other", user_id: "cust1" }));
    await assertFails(updateDoc(doc(as("cust1"), "wallet/w1"), { amount: 500 }));
    await assertFails(deleteDoc(doc(as("vend1"), "wallet/w1")));
  });

  test("parcel_sms_outbox: create pending; an existing request is not readable", async () => {
    await assertSucceeds(getDoc(doc(as("cust1"), "parcel_sms_outbox/p2")));
    await assertSucceeds(setDoc(doc(as("cust1"), "parcel_sms_outbox/p2"), { id: "p2", sendState: "pending", to: "+221" }));
    await assertFails(getDoc(doc(as("cust1"), "parcel_sms_outbox/p1")));
    await assertFails(setDoc(doc(as("cust1"), "parcel_sms_outbox/p3"), { id: "p3", sendState: "sent" }));
  });
});
