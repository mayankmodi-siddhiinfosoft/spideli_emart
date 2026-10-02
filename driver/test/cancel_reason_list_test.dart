import 'package:driver/utils/cancel_reason_list.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// `settings/cancellationReasons` read the way the web panels and the other
/// apps read it (BUG-REPORT-01 §3, CANCEL-REASON-CONTRACT): `driver`, then
/// `reasons`, then `list`; strings or `{code, label}`; "Other" once, last.
void main() {
  const List<String> defaults = FireStoreUtils.defaultDriverCancellationReasons;
  List<CancelReasonOption> parse(Map<String, dynamic>? data) => parseCancelReasonList(data, roleKeys: const ['driver'], defaults: defaults);
  List<String> labels(List<CancelReasonOption> o) => o.map((e) => e.label).toList();
  List<String> codes(List<CancelReasonOption> o) => o.map((e) => e.code).toList();

  test('no document: the built-in driver defaults, Other last with code other', () {
    final o = parse(null);
    expect(labels(o), defaults);
    expect(o.last.code, 'other');
    expect(o.where((e) => e.isOther).length, 1);
    // A plain string's code is its own text (the existing behaviour).
    expect(o.first.code, defaults.first);
  });

  test('the driver key wins over reasons / list', () {
    final o = parse({
      'driver': ['Flat tyre'],
      'customer': ['Not mine'],
      'reasons': ['From reasons'],
      'list': ['From list'],
    });
    expect(labels(o), ['Flat tyre', 'Other']);
  });

  test('falls back to reasons, then list', () {
    expect(
        labels(parse({
          'reasons': ['A'],
        })),
        ['A', 'Other']);
    expect(
        labels(parse({
          'driver': [],
          'reasons': '',
          'list': ['B'],
        })),
        ['B', 'Other']);
  });

  test('map entries: label shown, the map code written; alternative keys read', () {
    final o = parse({
      'list': [
        {'code': 'vehicle', 'label': 'Vehicle problem'},
        {'id': 'unsafe', 'text': 'Unsafe pickup'},
        {'value': 'late', 'reason': 'Running late'},
        {'name': 'Customer unreachable'},
        {'code': 'no_label'},
        {'title': 'Titled', 'code': 'titled'},
      ],
    });
    expect(labels(o), ['Vehicle problem', 'Unsafe pickup', 'Running late', 'Customer unreachable', 'Titled', 'Other']);
    expect(codes(o), ['vehicle', 'unsafe', 'late', 'Customer unreachable', 'titled', 'other']);
    expect(o.any((e) => e.label.contains('{')), isFalse);
  });

  test('Other exactly once and last; a stored other keeps its label', () {
    final o = parse({
      'driver': [
        'other',
        {'code': 'other', 'label': 'Something else'},
        'Late',
        'Late',
        'Other',
      ],
    });
    expect(labels(o), ['Late', 'Something else']);
    expect(codes(o), ['Late', 'other']);
    expect(o.where((e) => e.isOther).length, 1);
    expect(
        labels(parse({
          'driver': ['Late', 'other'],
        })),
        ['Late', 'Other']);
    final o2 = parse({
      'driver': [
        {'code': 'other', 'label': 'Something else'},
        'Late',
      ],
    });
    expect(labels(o2), ['Late', 'Something else']);
    expect(o2.last.isOther, isTrue);
  });

  test('a list holding only Other, blanks or "null" falls back to the defaults', () {
    expect(
        labels(parse({
          'driver': ['Other', ' ', null, 'null', 'undefined'],
        })),
        defaults);
    expect(
        labels(parse({
          'driver': 'not a list',
          'reasons': [
            {'code': 'other'},
          ],
        })),
        defaults);
  });

  group('CancelReasonResult.fromOption (what is written)', () {
    test('a map entry writes its code and its label', () {
      final r = CancelReasonResult.fromOption(const CancelReasonOption(label: 'Vehicle problem', code: 'vehicle'));
      expect(r.code, 'vehicle');
      expect(r.reason, 'Vehicle problem');
    });

    test('a string entry writes its text as both, as before', () {
      final r = CancelReasonResult.fromOption(parseCancelReasonEntry('Vehicle problem')!);
      expect(r.code, 'Vehicle problem');
      expect(r.reason, 'Vehicle problem');
    });

    test('Other writes code other and the typed text, whatever its label', () {
      final r = CancelReasonResult.fromOption(const CancelReasonOption(label: 'Something else', code: 'other'), otherText: '  Road closed  ');
      expect(r.code, 'other');
      expect(r.reason, 'Road closed');
    });
  });
}
