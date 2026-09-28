import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/utils/order_history_limit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The free order-history limit of WEB spec §6 as the client re-decided it on
/// 28 September: the allowance is worked out ONCE, across the WHOLE history,
/// before any tab is built. A tab then only narrows to its own statuses within
/// what the allowance permits — so a tab may legitimately come back empty while
/// orders of that kind exist, and the notice appears only when the allowance
/// actually hid something.
///
/// §9's period picker is applied in the SAME funnel, after the allowance, so
/// the two can never disagree about which orders the customer may see.
void main() {
  // The number is a setting (`settings/OrderHistory.freeOrderLimit`), never a
  // constant — the tests pass it in exactly as the controller reads it. The
  // client's data currently holds 8.
  const int freeOrderLimit = 8;

  /// Day N of September 2026; a bigger N is a newer order.
  Timestamp day(int n) => Timestamp.fromDate(DateTime(2026, 9, n));

  /// The funnel of `OrderController.renderOrders`, to the letter: one
  /// allowance, then the period, then each tab's own statuses.
  _Render render(List<_Order> orders, {int? limit, HistoryPeriod period = const HistoryPeriod.all()}) {
    final FreeOrderAllowance<_Order> allowance = OrderHistoryLimit.applyFreeOrderAllowance(
      orders,
      limit,
      (_Order o) => o.createdAt,
      keepAlways: (_Order o) => _activeStatuses.contains(o.status),
    );
    final FreeOrderAllowance<_Order> visible = allowance.inPeriod(period);
    return _Render(
      hiddenCount: allowance.hiddenCount,
      all: visible.visible,
      delivered: OrderHistoryLimit.limitOrderHistory(visible, (_Order o) => o.status == Constant.orderCompleted),
      cancelled: OrderHistoryLimit.limitOrderHistory(visible, (_Order o) => o.status == Constant.orderCancelled),
      rejected: OrderHistoryLimit.limitOrderHistory(visible, (_Order o) => o.status == Constant.orderRejected),
    );
  }

  group('the allowance is one decision across the whole history', () {
    test('the eight newest of any kind survive, whichever tab they belong to', () {
      // Twelve orders, days 1..12, statuses cycled so the newest eight are a
      // mix of completed, cancelled and rejected.
      const List<String> cycle = [Constant.orderCompleted, Constant.orderCancelled, Constant.orderRejected];
      final List<_Order> orders = [for (int n = 12; n >= 1; n--) _Order('o$n', cycle[n % 3], day(n))];

      final _Render r = render(orders, limit: freeOrderLimit);

      expect(r.all.length, freeOrderLimit);
      // Days 12..5 — the newest eight across the whole history, not eight per
      // tab (which would have returned all twelve).
      expect(r.all.map((o) => o.id), ['o12', 'o11', 'o10', 'o9', 'o8', 'o7', 'o6', 'o5']);
      // The tabs together are exactly the allowance, never more.
      expect(r.delivered.length + r.cancelled.length + r.rejected.length, freeOrderLimit);
      expect(r.hiddenCount, 4);
    });

    test('the tabs are subsets of the one allowance, so no tab reaches past it', () {
      final List<_Order> orders = [
        for (int n = 10; n >= 1; n--) _Order('c$n', Constant.orderCompleted, day(n)),
        for (int n = 10; n >= 1; n--) _Order('x$n', Constant.orderCancelled, day(n)),
      ];

      final _Render r = render(orders, limit: freeOrderLimit);

      expect(r.all.length, freeOrderLimit);
      for (final _Order o in [...r.delivered, ...r.cancelled, ...r.rejected]) {
        expect(r.all, contains(o));
      }
      expect(r.hiddenCount, 12);
    });

    test('an entitled customer (no limit) keeps every order', () {
      final List<_Order> orders = [for (int n = 20; n >= 1; n--) _Order('o$n', Constant.orderCompleted, day(n))];

      final _Render r = render(orders, limit: null);

      expect(r.all.length, 20);
      expect(r.hiddenCount, 0);
    });
  });

  group('the notice appears only when the allowance actually hid something', () {
    List<_Order> historyOf(int count) => [for (int n = count; n >= 1; n--) _Order('o$n', Constant.orderCompleted, day(n))];

    test('eight orders under an allowance of eight hide nothing', () {
      final _Render r = render(historyOf(8), limit: freeOrderLimit);

      expect(r.all.length, 8);
      expect(r.hiddenCount, 0, reason: 'having eight is not the same as hiding one');
    });

    test('the ninth order is what triggers the notice', () {
      final _Render r = render(historyOf(9), limit: freeOrderLimit);

      expect(r.all.length, 8);
      expect(r.hiddenCount, 1);
      // The oldest is the one that went.
      expect(r.all.map((o) => o.id), isNot(contains('o1')));
    });

    test('hidSomething mirrors the count the notice is drawn from', () {
      expect(OrderHistoryLimit.applyFreeOrderAllowance(historyOf(8), freeOrderLimit, (_Order o) => o.createdAt).hidSomething, isFalse);
      expect(OrderHistoryLimit.applyFreeOrderAllowance(historyOf(9), freeOrderLimit, (_Order o) => o.createdAt).hidSomething, isTrue);
    });
  });

  group('a tab may legitimately be empty', () {
    test('cancelled orders exist but are all older than the allowance reaches', () {
      final List<_Order> orders = [
        // The newest eight are all completed…
        for (int n = 20; n >= 13; n--) _Order('c$n', Constant.orderCompleted, day(n)),
        // …and every cancelled order is older than them.
        for (int n = 5; n >= 1; n--) _Order('x$n', Constant.orderCancelled, day(n)),
      ];

      final _Render r = render(orders, limit: freeOrderLimit);

      expect(r.delivered.length, 8);
      expect(r.cancelled, isEmpty, reason: 'the client chose this: newer orders used the allowance up');
      expect(r.hiddenCount, 5, reason: 'the one notice above the tabs explains the empty tab');
    });
  });

  group('the period picker is applied after the allowance, in the same funnel', () {
    final List<_Order> orders = [
      // Ten orders in September 2026…
      for (int n = 10; n >= 1; n--) _Order('sep$n', Constant.orderCompleted, day(n)),
      // …and two the allowance can never reach, in an earlier month.
      _Order('aug2', Constant.orderCompleted, Timestamp.fromDate(DateTime(2026, 8, 2))),
      _Order('aug1', Constant.orderCompleted, Timestamp.fromDate(DateTime(2026, 8, 1))),
    ];

    test('a period cannot recover an order the allowance already hid', () {
      final _Render r = render(orders, limit: freeOrderLimit, period: HistoryPeriod.month(DateTime(2026, 8)));

      expect(r.all, isEmpty, reason: 'August is entirely outside the allowance, so the period finds nothing');
      // Were the period applied FIRST, the customer would step through the
      // whole history eight orders at a time — which defeats §6 entirely.
    });

    test('the notice keeps reporting what the allowance hid, not what the period left out', () {
      final _Render r = render(orders, limit: freeOrderLimit, period: HistoryPeriod.month(DateTime(2026, 9)));

      expect(r.all.length, 8, reason: 'the September orders the allowance permits');
      expect(r.hiddenCount, 4);
    });

    test('a period narrows an unlimited history without inventing a hidden count', () {
      final _Render r = render(orders, limit: null, period: HistoryPeriod.month(DateTime(2026, 8)));

      expect(r.all.map((o) => o.id), ['aug2', 'aug1']);
      expect(r.hiddenCount, 0);
    });

    test('an order with no usable createdAt is kept by the period, not dropped', () {
      const _Order undated = _Order('undated', Constant.orderCompleted, null);

      expect(HistoryPeriod.month(DateTime(2026, 9)).contains(undated.createdAt), isTrue);
      expect(HistoryPeriod.range(from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 2)).contains(undated.createdAt), isTrue);
    });

    test('only months the customer may actually see are offered', () {
      final FreeOrderAllowance<_Order> allowance = OrderHistoryLimit.applyFreeOrderAllowance(orders, freeOrderLimit, (_Order o) => o.createdAt);

      expect(OrderHistoryLimit.monthsOf(allowance.visible, (_Order o) => o.createdAt), [DateTime(2026, 9)]);
    });
  });

  group('safeguard: an order still in progress is never hidden', () {
    // DEVIATION from WEB spec §6, kept deliberately and flagged to the panel
    // team: a customer tracking a live delivery must not lose sight of it.
    test('an old in-progress order survives an allowance that reaches past it', () {
      final List<_Order> orders = [
        for (int n = 20; n >= 13; n--) _Order('c$n', Constant.orderCompleted, day(n)),
        _Order('live', Constant.orderInTransit, day(2)),
        _Order('old', Constant.orderCompleted, day(1)),
      ];

      final _Render r = render(orders, limit: freeOrderLimit);

      expect(r.all.map((o) => o.id), contains('live'));
      expect(r.all.map((o) => o.id), isNot(contains('old')));
      // It still COUNTS against the allowance — the deviation is only that it
      // is shown rather than hidden — so 'old' is the one order hidden.
      expect(r.hiddenCount, 1);
    });

    test('an in-progress order inside the allowance changes nothing', () {
      final List<_Order> orders = [
        _Order('live', Constant.orderShipped, day(9)),
        for (int n = 8; n >= 1; n--) _Order('c$n', Constant.orderCompleted, day(n)),
      ];

      final _Render r = render(orders, limit: freeOrderLimit);

      expect(r.all.length, 8);
      expect(r.hiddenCount, 1);
    });
  });

  group('ordering', () {
    test('the allowance comes back newest first, whatever order it was given', () {
      final List<_Order> orders = [
        _Order('mid', Constant.orderCompleted, day(5)),
        _Order('old', Constant.orderCompleted, day(1)),
        _Order('new', Constant.orderCompleted, day(9)),
      ];

      final _Render r = render(orders, limit: freeOrderLimit);

      expect(r.all.map((o) => o.id), ['new', 'mid', 'old']);
    });
  });
}

/// The statuses `OrderController.activeStatuses` protects.
const Set<String> _activeStatuses = {
  Constant.orderPlaced,
  Constant.orderAccepted,
  Constant.driverPending,
  Constant.driverAccepted,
  Constant.driverRejected,
  Constant.orderShipped,
  Constant.orderInTransit,
};

/// Just the two fields the funnel reads off an order.
class _Order {
  final String id;
  final String status;
  final Timestamp? createdAt;

  const _Order(this.id, this.status, this.createdAt);

  @override
  String toString() => id;
}

/// What one render of the order screen produced.
class _Render {
  final int hiddenCount;
  final List<_Order> all;
  final List<_Order> delivered;
  final List<_Order> cancelled;
  final List<_Order> rejected;

  const _Render({required this.hiddenCount, required this.all, required this.delivered, required this.cancelled, required this.rejected});
}
