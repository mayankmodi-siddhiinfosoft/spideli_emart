# Worker document verification: contract (Worker app, Provider app, admin panel)

What the Worker app (`spideli_worker/`) and the Provider app (`spideli_provider/`)
read and write for a worker's documents, and what the admin panel must do to stay
consistent with them.

The status rule lives in ONE pure file, identical in both apps (a unit test in each
app compares the two copies):

- `spideli_worker/lib/model/worker_verification_status.dart`
- `spideli_provider/lib/model/worker_verification_status.dart`

## 1. Collections

| Path | Holds | Written by |
|---|---|---|
| `documents/{typeId}` | the document types the admin configured | admin panel only |
| `settings/document_verification_settings.isWorkerVerification` | `true` = workers must be verified to get jobs | admin panel only |
| `documents_verify/{workerUid}` | the worker's uploaded documents (one record per worker) | Worker app (submit), Provider app (review), admin panel (review) |
| `providers_workers/{workerUid}.isDocumentVerify` | the synced "verified" flag | Provider app / admin panel (true or false), Worker app (false only) |
| Storage `workerDocument/{workerUid}/{millis}_{name}` | the image files | Worker app |

### 1.1 Required document types

A document is REQUIRED for workers when its `documents/{typeId}` row has
`type == "worker"` AND `enable == true`. Both apps query exactly that and check both
fields again on every row (a `driver`, `owner`, `vendor` or `provider` type never
becomes a worker document). An upload is matched to its type by
`documents_verify.documents[].documentId == documents/{typeId}` (the Firestore
document id). A type disabled later stops counting: its upload is kept but ignored.

Type fields read: `title`, `frontSide`, `backSide`, `expireAt` (bool: the document
has an expiry date), `enable`, `type`.

### 1.2 Record shape: `documents_verify/{workerUid}`

```json
{
  "id": "<workerUid>",
  "type": "worker",
  "documents": [
    {
      "documentId": "<documents/{typeId}>",
      "frontImage": "<Storage download URL, stored as returned>",
      "backImage": "<Storage download URL or ''>",
      "status": "uploaded | approved | rejected | expired",
      "expireAt": "<Timestamp, only when the type has expireAt == true>",
      "submittedAt": "<Timestamp of the (re)submission>",
      "rejectReason": "<text, only when status == rejected>",
      "reviewedAt": "<Timestamp>",
      "reviewedBy": "<uid of the reviewer>",
      "reviewedByRole": "provider | admin"
    }
  ]
}
```

- `type` is ALWAYS `"worker"`. The same `documents_verify` collection holds driver,
  owner, vendor and provider records; they are never mixed:
  - a record whose `type` is anything other than `"worker"` (or empty, for legacy
    records written before the type was stored) is never read as a worker's
    uploads, never counted for the jobs gate or the assignment filter, and never
    written by either app (the Worker app refuses the upload, the Provider app
    refuses the review);
  - both apps write `type: "worker"` with every write.
- One entry per `documentId` (the first entry of an id wins when reading; a submission
  replaces the entry in place and drops duplicates).
- Unknown keys in an entry (`number`, panel fields) are preserved by both apps.
- Reason keys read (first non-empty wins): `rejectReason`, `rejectionReason`,
  `rejectedReason`, `rejected_reason`, `reason`. The apps write `rejectReason`.
- Older keys still read: `expiryDate` (= `expireAt`), `uploadedAt` (= `submittedAt`).
- Image URLs are displayed exactly as stored (already percent-encoded; never
  re-encoded).

## 2. Statuses

### 2.1 One document

From its entry (`WorkerVerificationStatusRules.documentState`), in this order:

1. `status == "rejected"` → **Rejected** (even without a file)
2. no `frontImage` and no `backImage` (or no entry) → **Not submitted**
3. `status == "expired"`, or `expireAt` in the past (approved or not) → **Expired**
4. `status == "approved"` or `"verified"` → **Approved**
5. anything else sent (`uploaded`, `pending`, none) → **Pending review**

### 2.2 Overall status of a worker

Computed ONLY from the current statuses of ALL REQUIRED documents
(`WorkerVerificationStatusRules.overall`); used by every screen, the Worker app's jobs
gate and the Provider app's assignment filter:

| Overall | Rule |
|---|---|
| **Action required** (shown as "Action required") | any required document Rejected or Expired. Never Verified then, whatever `isDocumentVerify` says. |
| **Verified** | every required document uploaded AND Approved |
| **Not submitted** | no required document uploaded |
| **Pending** | otherwise: some required documents not uploaded yet, or uploaded / resubmitted and not reviewed yet |

`providers_workers.isDocumentVerify` is NOT enough to be Verified: flag `true` with a
required document Pending, Not submitted, Rejected or Expired is NOT Verified (UI and
jobs gate). The flag counts only:

- when the platform switched verification off
  (`isWorkerVerification != true` and the setting was read): flag `true` and nothing
  Rejected / Expired → Verified (display only; the gate is open anyway);
- when the admin configured no required worker type at all: flag `true` → Verified,
  otherwise Not submitted.

### 2.3 Jobs gate (Worker app) and assignment filter (Provider app)

`WorkerVerificationStatusRules.canReceiveJobs`:

- verification off → always;
- the setting not read yet → treated as ON;
- required types read and there are none → open (nothing can be uploaded);
- required types could not be read → closed;
- otherwise → only when the overall status is **Verified**.

The Worker app hides active jobs, blocks starting a job and going online.

Provider app, "Assign worker" (the ONLY path that writes `provider_orders.workerId`;
used for the first assignment and for reassignment, from the booking list and from
booking details; there is no auto-assign; "Assign to Myself" assigns the provider,
not a worker):

- the list shows every online worker of the provider; a worker who is not eligible is
  greyed out with the reason ("Documents missing", "Pending review", "Documents
  rejected", "Documents not checked") and cannot be selected;
- pressing Assign re-validates AT THAT MOMENT, in one Firestore transaction
  (`WorkerVerificationService.assignWorker`): it re-reads
  `providers_workers/{workerId}` (must be the provider's own worker),
  `settings/document_verification_settings` and the worker's LIVE
  `documents_verify/{workerId}` record, checks them against the required types read
  from the server just before (not a cached list), and writes the order
  (`workerId`, `status: "Order Assigned"`) in the same transaction only when the
  overall status is Verified (or verification is off / no required type). Otherwise
  nothing is written and the provider sees why (missing / pending review /
  rejected or expired / not checked). `isDocumentVerify` alone never allows it.
- The admin panel, if it assigns workers to bookings, must apply the same check.

## 3. Flag sync: `providers_workers/{workerUid}.isDocumentVerify`

Recalculated on every change, in the same Firestore transaction as the change:

| Change | Who | Documents write | Flag write |
|---|---|---|---|
| Worker submits a document for the first time | Worker app | entry added, `status: "uploaded"`, `submittedAt` | `false` when the worker is not Verified afterwards and the flag is not already `false` |
| Worker resubmits (after rejection / expiry, or any re-upload) | Worker app | entry replaced in place: `status: "uploaded"` (never auto-approved), `submittedAt` new, `rejectReason` and every other reason key, `reviewedAt`, `reviewedBy`, `reviewedByRole` and the old `expireAt` removed | as above: lowered to `false` (the worker may LOWER, never RAISE, their own flag) |
| Provider approves one document | Provider app | entry `status: "approved"`, reasons removed, `reviewedAt/By/ByRole` | recalculated: `true` exactly when every required document is then approved, else `false`; written only when it changes |
| Provider rejects one document (reason mandatory) | Provider app | entry `status: "rejected"`, `rejectReason`, `reviewedAt/By/ByRole` | recalculated (a rejected required document → `false`) |
| Provider "Approve all uploaded" | Provider app | every REQUIRED entry that is Pending review → approved (rejected / expired / missing ones untouched) | recalculated (`true` only when nothing is missing) |
| Admin approves / rejects | admin panel | same entry fields (`reviewedByRole: "admin"`) | **must** recalculate the same way |

Provider guard: the review transaction re-reads `providers_workers/{workerUid}` and
refuses unless its `providerId` is the signed-in provider (only its own workers), and
refuses a `documents_verify` record of another type.

## 4. What the admin panel must do

1. Read worker records with `type == "worker"` only; write `type: "worker"`.
2. Approve: `status: "approved"`, remove every reason key, set `reviewedAt`,
   `reviewedBy`, `reviewedByRole: "admin"`.
3. Reject: `status: "rejected"`, `rejectReason` (mandatory), same review fields.
4. After every approve / reject, in the same transaction or batch, set
   `providers_workers/{workerUid}.isDocumentVerify` to the recalculated value (true
   exactly when every required, enabled `worker` type has an approved, unexpired,
   uploaded entry). Never set it `true` on its own: the apps ignore a `true` flag
   while a required document is not approved (when verification is on).
5. Show the overall status with the four values above (same rule, section 2.2).
6. When a document type is enabled / disabled, the overall status of every worker
   changes immediately in the apps (they listen live). The panel should recalculate
   the flag of the affected workers (or accept that the flag lags until the next
   review: the apps do not depend on it while verification is on).

## 5. Firestore rules needed

- `providers_workers/{uid}.isDocumentVerify`
  - the worker (self) may only lower it (`notRaised`): already in
    `firestore.rules.draft` (`workerSelfOk`);
  - the worker's provider (`worksForMe`) must be allowed to set it `true` as well as
    `false`. `workerProviderEditOk` in `firestore.rules.draft` currently says
    `notRaised('isDocumentVerify')`, which would refuse the provider's approval
    transaction; relax it for the worker's own provider, ideally only when the
    worker's required documents are approved (or move the flag write server-side).
- `documents_verify/{uid}` (still `signedIn()` read/write in the draft, TODO):
  - the worker (`uid == id`) may write `id`, `type` (must be `"worker"`) and
    `documents`; must not set an entry's `status` to `approved` (rules cannot inspect
    list items: the real fix is a status map keyed by document id, or approval in a
    Cloud Function);
  - the worker's provider may write `id`, `type: "worker"` and `documents` of its own
    workers' records only (`get(providers_workers/{id}).data.providerId == uid()`);
  - nobody but the holder may write a record whose stored `type` differs.
- Storage `workerDocument/{uid}/**`: write by `uid` only; read by the worker, the
  worker's provider and admins.

## 6. Pushes (unchanged)

`worker_document_submitted` (to the provider), `worker_document_approved`,
`worker_documents_verified`, `worker_document_rejected` (to the worker): see
`.claude/PUSH-CHANNELS.md`.
