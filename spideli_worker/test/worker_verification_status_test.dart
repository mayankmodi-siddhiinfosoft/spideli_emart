import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/model/worker_verification_status.dart';

/// The ONE worker verification status rule, shared by the Worker and the
/// Provider app (the same file in both; this test is the same in both too).
void main() {
  const n = WorkerDocumentState.notSubmitted;
  const p = WorkerDocumentState.pending;
  const a = WorkerDocumentState.approved;
  const r = WorkerDocumentState.rejected;
  const e = WorkerDocumentState.expired;
  final DateTime now = DateTime(2026, 10, 13, 12);

  WorkerOverallStatus overall(List<WorkerDocumentState> s, {bool? flag, bool? required = true}) =>
      WorkerVerificationStatusRules.overall(s, isDocumentVerify: flag, verificationRequired: required);

  group('documentState', () {
    WorkerDocumentState of({bool exists = true, String? status, bool hasFile = true, DateTime? expireAt}) =>
        WorkerVerificationStatusRules.documentState(exists: exists, status: status, hasFile: hasFile, expireAt: expireAt, now: now);

    test('nothing stored or no file: not submitted', () {
      expect(of(exists: false), n);
      expect(of(status: 'uploaded', hasFile: false), n);
    });
    test('rejected even without a file', () => expect(of(status: 'Rejected', hasFile: false), r));
    test('expired: stored, or past the expiry date whether approved or waiting', () {
      expect(of(status: 'expired'), e);
      expect(of(status: 'approved', expireAt: DateTime(2026, 1, 1)), e);
      expect(of(status: 'uploaded', expireAt: DateTime(2026, 1, 1)), e);
    });
    test('approved / verified; anything else sent is pending', () {
      expect(of(status: 'approved', expireAt: DateTime(2027)), a);
      expect(of(status: 'VERIFIED'), a);
      expect(of(status: 'uploaded'), p);
      expect(of(status: 'pending'), p);
      expect(of(), p);
    });
  });

  group('overall', () {
    test('Not submitted: no required document uploaded', () {
      expect(overall([n, n]), WorkerOverallStatus.notSubmitted);
    });
    test('Pending: some required not uploaded, or uploaded and not reviewed', () {
      expect(overall([a, n]), WorkerOverallStatus.pending);
      expect(overall([p, n]), WorkerOverallStatus.pending);
      expect(overall([a, p]), WorkerOverallStatus.pending);
    });
    test('Action required: any required rejected or expired, never Verified then', () {
      expect(overall([a, r]), WorkerOverallStatus.actionRequired);
      expect(overall([a, e]), WorkerOverallStatus.actionRequired);
      expect(overall([p, r, n]), WorkerOverallStatus.actionRequired);
      expect(overall([a, r], flag: true), WorkerOverallStatus.actionRequired);
      expect(overall([a, e], flag: true, required: false), WorkerOverallStatus.actionRequired);
    });
    test('Verified: every required uploaded AND approved (whatever the flag says)', () {
      expect(overall([a, a]), WorkerOverallStatus.verified);
      expect(overall([a, a], flag: false), WorkerOverallStatus.verified);
    });
    test('flag true + a required document pending / missing: NOT Verified while verification is on or unknown', () {
      expect(overall([a, p], flag: true), WorkerOverallStatus.pending);
      expect(overall([a, n], flag: true), WorkerOverallStatus.pending);
      expect(overall([n, n], flag: true), WorkerOverallStatus.notSubmitted);
      expect(overall([a, p], flag: true, required: null), WorkerOverallStatus.pending);
    });
    test('resubmission: the document is pending again, so the worker is Pending', () {
      expect(overall([a, p], flag: true), WorkerOverallStatus.pending);
    });
    test('verification switched off: the flag counts (unless rejected / expired)', () {
      expect(overall([a, p], flag: true, required: false), WorkerOverallStatus.verified);
      expect(overall([a, p], flag: false, required: false), WorkerOverallStatus.pending);
    });
    test('no required type configured: only the flag', () {
      expect(overall([], flag: true), WorkerOverallStatus.verified);
      expect(overall([]), WorkerOverallStatus.notSubmitted);
    });
  });

  group('jobs gate / assignment filter', () {
    bool gate(WorkerOverallStatus o, {bool? required = true, bool none = false, bool failed = false}) =>
        WorkerVerificationStatusRules.canReceiveJobs(verificationRequired: required, noRequiredTypes: none, typesLoadFailed: failed, overall: o);

    test('only Verified passes while verification is on or unknown', () {
      for (final o in WorkerOverallStatus.values) {
        expect(gate(o), o == WorkerOverallStatus.verified, reason: '$o');
        expect(gate(o, required: null), o == WorkerOverallStatus.verified, reason: '$o');
      }
    });
    test('verification off: always', () {
      for (final o in WorkerOverallStatus.values) {
        expect(gate(o, required: false), isTrue, reason: '$o');
      }
    });
    test('no required type: open when read, closed when the read failed', () {
      expect(gate(WorkerOverallStatus.notSubmitted, none: true), isTrue);
      expect(gate(WorkerOverallStatus.verified, none: true, failed: true), isFalse);
    });
    test('flag true + pending: the gate stays closed', () {
      expect(gate(overall([a, p], flag: true)), isFalse);
      expect(gate(overall([a, r], flag: true)), isFalse);
    });
  });

  group('flag sync', () {
    test('worker submit / resubmit: lowers to false when no longer verified, never raises', () {
      expect(WorkerVerificationStatusRules.flagAfterWorkerSubmit(requiredAfter: [a, p], current: true), isFalse);
      expect(WorkerVerificationStatusRules.flagAfterWorkerSubmit(requiredAfter: [p, n], current: null), isFalse);
      expect(WorkerVerificationStatusRules.flagAfterWorkerSubmit(requiredAfter: [a, p], current: false), isNull);
      expect(WorkerVerificationStatusRules.flagAfterWorkerSubmit(requiredAfter: [a, a], current: false), isNull, reason: 'a worker never raises the flag');
      expect(WorkerVerificationStatusRules.flagAfterWorkerSubmit(requiredAfter: [a, a], current: true), isNull);
      expect(WorkerVerificationStatusRules.flagAfterWorkerSubmit(requiredAfter: const [], current: true), isNull);
    });
    test('review (approve / reject / approve all): recalculated, written only when it changes', () {
      expect(WorkerVerificationStatusRules.flagAfterReview(requiredAfter: [a, a], current: false), isTrue);
      expect(WorkerVerificationStatusRules.flagAfterReview(requiredAfter: [a, a], current: null), isTrue);
      expect(WorkerVerificationStatusRules.flagAfterReview(requiredAfter: [a, a], current: true), isNull);
      expect(WorkerVerificationStatusRules.flagAfterReview(requiredAfter: [a, r], current: true), isFalse);
      expect(WorkerVerificationStatusRules.flagAfterReview(requiredAfter: [a, p], current: true), isFalse);
      expect(WorkerVerificationStatusRules.flagAfterReview(requiredAfter: [a, p], current: false), isNull);
      expect(WorkerVerificationStatusRules.flagAfterReview(requiredAfter: const [], current: true), isNull);
    });
  });

  group('record type separation', () {
    test('worker records (or legacy records without a type) only', () {
      expect(WorkerVerificationStatusRules.isWorkerRecordType('worker'), isTrue);
      expect(WorkerVerificationStatusRules.isWorkerRecordType(' Worker '), isTrue);
      expect(WorkerVerificationStatusRules.isWorkerRecordType(null), isTrue);
      expect(WorkerVerificationStatusRules.isWorkerRecordType(''), isTrue);
      for (final t in WorkerVerificationStatusRules.otherRecordTypes) {
        expect(WorkerVerificationStatusRules.isWorkerRecordType(t), isFalse, reason: t);
      }
    });
    test('required types: enabled worker types only', () {
      expect(WorkerVerificationStatusRules.isRequiredWorkerType({'type': 'worker', 'enable': true}), isTrue);
      expect(WorkerVerificationStatusRules.isRequiredWorkerType({'type': 'worker', 'enable': false}), isFalse);
      expect(WorkerVerificationStatusRules.isRequiredWorkerType({'type': 'driver', 'enable': true}), isFalse);
      expect(WorkerVerificationStatusRules.isRequiredWorkerType({'type': 'provider', 'enable': true}), isFalse);
    });
  });

  group('display labels', () {
    test('four overall statuses', () {
      expect(WorkerOverallStatus.values.map(WorkerVerificationStatusRules.overallLabel), ['Not submitted', 'Pending', 'Action required', 'Verified']);
    });
    test('document statuses', () {
      expect(WorkerDocumentState.values.map(WorkerVerificationStatusRules.documentLabel), ['Not submitted', 'Pending review', 'Approved', 'Rejected', 'Expired']);
    });
    test('document type label', () {
      expect(WorkerVerificationStatusRules.recordTypeLabel('worker'), 'Worker');
      expect(WorkerVerificationStatusRules.recordTypeLabel('driver'), 'Driver');
      expect(WorkerVerificationStatusRules.recordTypeLabel('provider'), 'Provider');
    });
  });

  test('the Worker and Provider apps hold the SAME rule file', () {
    const String path = 'lib/model/worker_verification_status.dart';
    final File mine = File(path);
    final File worker = File('../spideli_worker/$path');
    final File provider = File('../spideli_provider/$path');
    if (!mine.existsSync() || !worker.existsSync() || !provider.existsSync()) {
      markTestSkipped('sibling app not checked out');
      return;
    }
    expect(worker.readAsStringSync(), provider.readAsStringSync());
  });
}
