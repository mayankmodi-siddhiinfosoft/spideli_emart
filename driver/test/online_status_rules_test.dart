import 'dart:async';

import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_online_status.dart';
import 'package:driver/services/online_status_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client report (8 Oct): "the driver goes Offline automatically". Only the
/// driver's switch changes `users/{uid}.isActive`; these cover the rules
/// that decide what the switch shows and does in every service.
void main() {
  group('isActive as stored', () {
    test('only an explicit true is online (what the dispatch reads)', () {
      expect(OnlineStatusRules.isOnline(true), isTrue);
      expect(OnlineStatusRules.isOnline(false), isFalse);
      expect(OnlineStatusRules.isOnline(null), isFalse);
      expect(OnlineStatusRules.isOnline('true'), isTrue);
      expect(OnlineStatusRules.isOnline(' TRUE '), isTrue);
      expect(OnlineStatusRules.isOnline('1'), isTrue);
      expect(OnlineStatusRules.isOnline(1), isTrue);
      expect(OnlineStatusRules.isOnline(0), isFalse);
      expect(OnlineStatusRules.isOnline('false'), isFalse);
      expect(OnlineStatusRules.isOnline('yes'), isFalse);
      expect(OnlineStatusRules.isOnline(<String, dynamic>{}), isFalse);
    });

    test('reads every value the way UserModel.fromJson does', () {
      for (final dynamic stored in <dynamic>[true, false, null, 'true', 'false', '1', '0', 1, 0, 2.5, 'x']) {
        final bool viaModel = UserModel.fromJson({'isActive': stored}).isActive == true;
        expect(OnlineStatusRules.isOnline(stored), viaModel, reason: 'isActive: $stored');
      }
    });
  });

  group('the value shown before the live record arrives', () {
    test('the session copy of the same driver (app restart while online)', () {
      expect(OnlineStatusRules.initial(uid: 'd1', copyId: 'd1', copyIsActive: true), isTrue);
    });

    test('a driver who went offline is shown offline after a restart', () {
      expect(OnlineStatusRules.initial(uid: 'd1', copyId: 'd1', copyIsActive: false), isFalse);
      expect(OnlineStatusRules.initial(uid: 'd1', copyId: 'd1', copyIsActive: null), isFalse);
    });

    test('no copy, or another account\'s copy: unknown, never a made-up "Offline"', () {
      expect(OnlineStatusRules.initial(uid: 'd1', copyId: null, copyIsActive: null), isNull);
      expect(OnlineStatusRules.initial(uid: 'd1', copyId: 'd2', copyIsActive: true), isNull);
      expect(OnlineStatusRules.initial(uid: '', copyId: '', copyIsActive: true), isNull);
    });

    test('the shared status falls back to a dashboard copy only while unknown', () {
      expect(DriverOnlineStatus.value, isNull);
      expect(DriverOnlineStatus.isKnown, isFalse);
      expect(DriverOnlineStatus.isOnline, isFalse);
      expect(DriverOnlineStatus.isOnlineOr(true), isTrue);
      expect(DriverOnlineStatus.isOnlineOr(false), isFalse);
      expect(DriverOnlineStatus.isOnlineOr(null), isFalse);
    });
  });

  group('a tap on the online switch', () {
    test('going offline is never refused', () {
      for (final bool checks in [true, false]) {
        for (final bool pending in [true, false]) {
          expect(
            OnlineStatusRules.switchRequest(goingOnline: false, checksDocuments: checks, verificationPending: pending),
            OnlineSwitchStep.write,
            reason: 'checks: $checks, pending: $pending',
          );
        }
      }
    });

    test('going online without document checks writes at once', () {
      expect(OnlineStatusRules.switchRequest(goingOnline: true, checksDocuments: false, verificationPending: false), OnlineSwitchStep.write);
    });

    test('going online while verification is pending is refused', () {
      expect(OnlineStatusRules.switchRequest(goingOnline: true, checksDocuments: true, verificationPending: true), OnlineSwitchStep.verificationPending);
    });

    test('going online with verified documents checks expired / rejected ones first', () {
      expect(OnlineStatusRules.switchRequest(goingOnline: true, checksDocuments: true, verificationPending: false), OnlineSwitchStep.checkDocuments);
    });
  });

  group('dashboards', () {
    test('one layout per service set', () {
      expect(OnlineStatusRules.dashboardLayout(isOwner: true, modules: const ['cab-service']), 'owner');
      expect(OnlineStatusRules.dashboardLayout(isOwner: false, modules: const []), 'delivery-service');
      expect(OnlineStatusRules.dashboardLayout(isOwner: false, modules: const ['cab-service']), 'cab-service');
      expect(
        OnlineStatusRules.dashboardLayout(isOwner: false, modules: const ['delivery-service', 'cab-service', 'delivery-service']),
        'delivery-service|cab-service',
      );
      expect(OnlineStatusRules.dashboardLayout(isOwner: false, modules: const ['cab-service', 'delivery-service']), isNot('delivery-service|cab-service'));
    });

    test('nothing running: opened (sign-in, app start)', () {
      expect(OnlineStatusRules.dashboardRoute(running: false, openLayout: null, wanted: 'cab-service'), DashboardRoute.open);
      expect(OnlineStatusRules.dashboardRoute(running: false, openLayout: 'cab-service', wanted: 'cab-service', rebuild: true), DashboardRoute.open);
    });

    test('the same dashboards running: reused, never adopted by a second copy (a job push tapped)', () {
      expect(OnlineStatusRules.dashboardRoute(running: true, openLayout: 'delivery-service|cab-service', wanted: 'delivery-service|cab-service'), DashboardRoute.reuse);
    });

    test('another service set, an unknown one, or a section change: rebuilt from scratch', () {
      expect(OnlineStatusRules.dashboardRoute(running: true, openLayout: 'delivery-service', wanted: 'delivery-service|cab-service'), DashboardRoute.rebuild);
      expect(OnlineStatusRules.dashboardRoute(running: true, openLayout: null, wanted: 'delivery-service'), DashboardRoute.rebuild);
      expect(OnlineStatusRules.dashboardRoute(running: true, openLayout: 'delivery-service', wanted: 'delivery-service', rebuild: true), DashboardRoute.rebuild);
    });
  });

  group('SingleFlight (the location plugin keeps one pending result)', () {
    test('concurrent callers share one call and its result', () async {
      final SingleFlight<int> flight = SingleFlight<int>();
      final Completer<int> platform = Completer<int>();
      int calls = 0;
      Future<int> task() {
        calls++;
        return platform.future;
      }

      final List<Future<int>> callers = [for (var i = 0; i < 4; i++) flight.run(task)];
      expect(calls, 1);
      expect(flight.isRunning, isTrue);
      platform.complete(7);
      expect(await Future.wait(callers), [7, 7, 7, 7]);
      await Future<void>.delayed(Duration.zero);
      expect(flight.isRunning, isFalse);
    });

    test('a finished call lets the next one through', () async {
      final SingleFlight<int> flight = SingleFlight<int>();
      int calls = 0;
      expect(await flight.run(() async => ++calls), 1);
      await Future<void>.delayed(Duration.zero);
      expect(await flight.run(() async => ++calls), 2);
    });

    test('an error reaches every caller and clears the slot', () async {
      final SingleFlight<int> flight = SingleFlight<int>();
      final Completer<int> platform = Completer<int>();
      final Future<int> a = flight.run(() => platform.future);
      final Future<int> b = flight.run(() => platform.future);
      platform.completeError(StateError('denied'));
      await expectLater(a, throwsStateError);
      await expectLater(b, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(flight.isRunning, isFalse);
      expect(await flight.run(() async => 3), 3);
    });

    test('a task that throws synchronously is reported, not thrown', () async {
      final SingleFlight<int> flight = SingleFlight<int>();
      await expectLater(flight.run(() => throw ArgumentError('sync')), throwsArgumentError);
      await Future<void>.delayed(Duration.zero);
      expect(flight.isRunning, isFalse);
    });
  });

  group('boundedOrDefault', () {
    test('the value when it comes in time', () async {
      expect(await boundedOrDefault<int>(Future<int>.value(5), const Duration(seconds: 1), 0), 5);
    });

    test('the fallback when it never comes (a dialog that never answers)', () async {
      expect(await boundedOrDefault<bool>(Completer<bool>().future, const Duration(milliseconds: 10), false), isFalse);
    });

    test('the fallback on an error', () async {
      expect(await boundedOrDefault<bool>(Future<bool>.error(StateError('x')), const Duration(seconds: 1), false), isFalse);
    });
  });
}
