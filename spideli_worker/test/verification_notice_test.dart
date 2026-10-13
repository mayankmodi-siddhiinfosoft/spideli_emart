import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/model/worker_verification_status.dart';
import 'package:spideliworker/ui/documents/verification_notice_banner.dart';

/// The dashboard's verification notice: when it shows and what its button says.
void main() {
  group('showVerificationNotice', () {
    test('hidden while the state is loading', () {
      for (final s in WorkerOverallStatus.values) {
        expect(showVerificationNotice(loading: true, canReceiveJobs: false, status: s), isFalse);
      }
    });
    test('shown for every not-verified status while jobs are locked', () {
      for (final s in [WorkerOverallStatus.notSubmitted, WorkerOverallStatus.pending, WorkerOverallStatus.actionRequired]) {
        expect(showVerificationNotice(loading: false, canReceiveJobs: false, status: s), isTrue, reason: '$s');
      }
    });
    test('hidden when jobs are open (verified, or verification off)', () {
      for (final s in WorkerOverallStatus.values) {
        expect(showVerificationNotice(loading: false, canReceiveJobs: true, status: s), isFalse, reason: '$s');
      }
    });
    test('hidden when verified', () {
      expect(showVerificationNotice(loading: false, canReceiveJobs: false, status: WorkerOverallStatus.verified), isFalse);
    });
  });

  test('button label follows the status', () {
    expect(verificationNoticeAction(WorkerOverallStatus.notSubmitted), 'Upload documents');
    expect(verificationNoticeAction(WorkerOverallStatus.actionRequired), 'Re-upload documents');
    expect(verificationNoticeAction(WorkerOverallStatus.pending), 'View documents');
  });
}
