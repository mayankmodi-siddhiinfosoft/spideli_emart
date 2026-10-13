# Document verification — drivers (driver app ↔ admin panel contract)

What the **driver app** (`driver/`, which also hosts the Company OWNER screens) reads and writes
for a driver's documents, so the admin panel can show exactly the same statuses.
Workers / providers have their own contract (`DOCUMENT-VERIFICATION-WORKER.md`); their records are
never mixed with a driver's.

Code: `driver/lib/services/driver_document_status.dart` (pure rules, unit tested in
`driver/test/driver_document_status_test.dart`), `driver_document_status_service.dart` (Firestore reads / live
streams), `owner_verification_rules.dart` + `owner_verification_service.dart` (owner review),
`FireStoreUtils.uploadDriverDocument` (driver upload).

## 1. Who is who

| Account | `users` fields | Reviews its documents |
|---|---|---|
| Company driver | `ownerId` = company owner uid, `isOwner: false` | its company owner (driver app) — and the admin panel |
| Platform driver | no `ownerId` | the admin panel only |
| Company (owner) | `isOwner: true` | the admin panel only |

## 2. Required documents

`documents` collection, documents with `enable == true` and `type` in:

| Account | Types |
|---|---|
| Driver (platform or company) | `driver`, plus `vehicle` when `serviceTypes` contains `cab-service` or `rental-service` |
| Company owner | `owner` |

`worker`, `provider`, `vendor` documents are never required from a driver. If no enabled document of
these types exists, nothing is required (see 4, last rule).

## 3. The record: `documents_verify/{uid}`

```jsonc
{
  "id": "<uid>",
  "type": "driver",            // holder type: "driver" for every driver, "owner" for a company
  "documents": [
    {
      "documentId": "<documents/{id}>",
      "frontImage": "<Firebase Storage download URL>",   // as stored; "" when the side is not used
      "backImage":  "<Firebase Storage download URL or ''>",
      "status": "uploaded" | "approved" | "rejected",      // see entry status below
      "expireAt": Timestamp,                               // only for documents with expireAt: true
      "rejectReason": "…", "rejectionReason": "…", "reason": "…",  // same text, only while rejected
      "reviewedBy": "<uid of the reviewer>",               // owner uid (app) or admin id (panel)
      "reviewedAt": Timestamp,                             // client time (arrays cannot hold serverTimestamp)
      "…": "any other field is kept untouched by the app"
    }
  ]
}
```

* **Record type separation.** A driver reads / writes only a record whose `type` is `driver` or absent
  (legacy). A record typed `worker`, `provider`, `vendor` or `owner` is never read as a driver's documents,
  never reviewed by an owner and never overwritten (the upload / review is refused). A company reads its
  own record when typed `owner`, `driver` (older builds filed it so) or absent. Every write by the app sets
  `id` and `type`.
* Writes are field-level merges (`set(..., merge: true)` of `id`, `type`, `documents` only) inside a
  Firestore transaction that re-reads the record first; every entry keeps its extra fields.

### Entry status (per document)

Computed by `DriverDocumentStatus.entryStatus` from the entry (in this order):

| Shown | Rule |
|---|---|
| `rejected` | `status == "rejected"` (with or without a file) |
| `not_submitted` | no entry, or no `frontImage` / `backImage` |
| `expired` | `expireAt` is in the past |
| `approved` | `status == "approved"` |
| `pending` (review) | any other status: `uploaded`, `pending`, `resubmitted`, … |

## 4. Overall status (ONE rule, everywhere)

`DriverDocumentStatus.overall(required, docs)` — only the REQUIRED documents count; entries for other
documents are ignored:

1. any required document `rejected` or `expired` → **`action_required`** ("Action required")
2. every required document `approved` → **`verified`**
3. no required document uploaded → **`not_submitted`**
4. otherwise (some missing, or uploaded / re-uploaded and waiting) → **`pending`**

`users.isDocumentVerify` does **not** decide the status: `isDocumentVerify: true` with a required document
rejected, expired or waiting for review is NOT verified (screens and, for company drivers, the jobs gate).
Only when nothing is required at all is the stored flag used (`true` → verified, else not submitted).

Shown on: the driver's documents screen, the owner's driver list (counts per status + filter) and review
screen, the owner's driver cards and assignment sheet. Labels (translated in all 9 languages):
"Not submitted", "Pending", "Action required", "Verified"; per document "Not submitted", "Pending review",
"Approved", "Rejected", "Expired"; document type "Driver" / "Vehicle".

## 5. `users.isDocumentVerify` sync

| Action (who) | Documents write | `isDocumentVerify` (same transaction) |
|---|---|---|
| Driver uploads / re-uploads a document (driver app) | entry → `status: "uploaded"`; `rejectReason`/`rejectionReason`/`reason`, `reviewedBy`/`reviewedAt` (and `approvedAt/By`, `rejectedAt/By`) removed; never approved | **company driver**: set to `false` when it was `true` and the overall status is no longer `verified` (field-level `update`); never set to `true`. Platform driver: not written. |
| Owner approves one (driver app) | entry → `approved`, reason cleared, `reviewedBy` = owner uid, `reviewedAt` | `overall == verified` (true when this completes the set, false otherwise); written only when it changes |
| Owner approves all (driver app) | every uploaded entry waiting for review → `approved` (never a missing, rejected or expired one) | `overall == verified` |
| Owner rejects one (driver app; reason mandatory) | entry → `rejected` + reason, reviewer stamped | `overall == verified` (a rejected required document → `false`) |
| Admin panel (expected) | same entry shape and statuses | should write `overall == verified` with the same rule |

The owner's actions re-check, inside the transaction, that `users/{driverId}.ownerId == owner uid`.
Registration and owner-created drivers start at `isDocumentVerify: false`; profile saves never write it.

## 6. Jobs gate

* **Company drivers** (offers / accepting a job, the owner's assignment `CarrierParcelRules.canTakeAssignment`
  — re-checked in the assignment transaction from the live record —, going online): allowed only when the
  computed overall status is `verified` (and only when verification applies: admin setting on and
  `isAutoVerify == false`; a store's own delivery man is never held back). The async gates compute it fresh
  right before deciding; the synchronous ones use the live value kept for the signed-in driver. Only before
  any status was computed does the flag decide.
  Consequence for the panel: to stop a company driver, reject (or expire) a document, or deactivate the
  account (`active: false`); clearing `isDocumentVerify` alone no longer blocks a driver whose required
  documents are all approved.
* **Platform drivers**: unchanged — `isDocumentVerify` (the admin's verdict) gates jobs, and a rejected /
  expired required document blocks going online.

## 7. Firestore rules needed

* A driver may `update` its own `users/{uid}` with `isDocumentVerify: false` (never `true`):
  `request.resource.data.isDocumentVerify == false || !request.resource.data.diff(resource.data).affectedKeys().hasAny(['isDocumentVerify'])`.
* A driver may write its own `documents_verify/{uid}`, but must not set an entry to `approved` (the panel
  and the owner only) — enforce in rules if possible, or accept that the app never does it.
* A company owner may write `documents_verify/{driverId}` and `users/{driverId}.isDocumentVerify` (true or
  false) only when `get(/users/{driverId}).data.ownerId == request.auth.uid`.
* An owner reads `users` where `ownerId == uid` and `documents_verify/{driverId}` of those drivers (live).
