import 'package:spideliprovider/utils/cancel_reason_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// `settings/cancellationReasons` read the way the web panels read it
/// (BUG-REPORT-01 §3): role key, then `reasons`, then `list`; strings or
/// `{code, label}`; "Other" always offered once, last.
void main() {
  const defaults = ['Changed my plans', 'Booked by mistake', 'Other'];
  List<String> labels(List<CancelReasonOption> o) => o.map((e) => e.label).toList();
  List<String> codes(List<CancelReasonOption> o) => o.map((e) => e.code).toList();

  test('no document: defaults, Other last with code other', () {
    final o = parseCancelReasonList(null, roleKeys: const ['provider'], defaults: defaults);
    expect(labels(o), ['Changed my plans', 'Booked by mistake', 'Other']);
    expect(codes(o), ['Changed my plans', 'Booked by mistake', 'other']);
    expect(o.last.isOther, isTrue);
  });

  test('role key wins over reasons / list', () {
    final o = parseCancelReasonList(
      {
        'provider': ['Too slow'],
        'reasons': ['From reasons'],
        'list': ['From list'],
      },
      roleKeys: const ['provider'],
      defaults: defaults,
    );
    expect(labels(o), ['Too slow', 'Other']);
  });

  test('falls back to reasons, then list', () {
    expect(
      labels(
        parseCancelReasonList(
          {
            'reasons': ['A'],
          },
          roleKeys: const ['provider'],
          defaults: defaults,
        ),
      ),
      ['A', 'Other'],
    );
    expect(
      labels(
        parseCancelReasonList(
          {
            'provider': [],
            'reasons': '',
            'list': ['B'],
          },
          roleKeys: const ['provider'],
          defaults: defaults,
        ),
      ),
      ['B', 'Other'],
    );
  });

  test('map entries: label shown, code written; never "{code: ..}"', () {
    final o = parseCancelReasonList(
      {
        'list': [
          {'code': 'too_slow', 'label': 'Taking too long'},
          {'code': 'price', 'text': 'Price too high'},
          {'reason': 'No code given'},
          {'code': 'empty'},
        ],
      },
      roleKeys: const ['provider'],
      defaults: defaults,
    );
    expect(labels(o), ['Taking too long', 'Price too high', 'No code given', 'Other']);
    expect(codes(o), ['too_slow', 'price', 'No code given', 'other']);
    expect(o.any((e) => e.label.contains('{')), isFalse);
  });

  test('Other is not duplicated and keeps a stored label', () {
    final o = parseCancelReasonList(
      {
        'reasons': [
          'other',
          {'code': 'other', 'label': 'Something else'},
          'Late',
          'Late',
        ],
      },
      roleKeys: const ['provider'],
      defaults: defaults,
    );
    expect(labels(o), ['Late', 'Something else']);
    expect(codes(o), ['Late', 'other']);
    expect(o.where((e) => e.isOther).length, 1);
  });

  test('a list holding only Other, blanks or "null" is not usable', () {
    final o = parseCancelReasonList(
      {
        'provider': ['Other', ' ', null, 'null'],
      },
      roleKeys: const ['provider'],
      defaults: defaults,
    );
    expect(labels(o), ['Changed my plans', 'Booked by mistake', 'Other']);
  });
}
