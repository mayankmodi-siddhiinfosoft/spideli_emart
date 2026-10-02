import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/utils/cancel_reasons.dart';

const List<String> _defaults = ['Item out of stock', 'Too busy', 'Other'];

List<String> _labels(List<CancelReasonOption> list) => list.map((o) => o.label).toList();
List<String> _codes(List<CancelReasonOption> list) => list.map((o) => o.code).toList();

void main() {
  group('parseCancelReasons', () {
    test('no document falls back to the defaults, Other last with code "other"', () {
      final list = parseCancelReasons(null, defaults: _defaults);
      expect(_labels(list), ['Item out of stock', 'Too busy', 'Other']);
      expect(_codes(list), ['Item out of stock', 'Too busy', 'other']);
      expect(list.last.isOther, isTrue);
    });

    test('vendor list of strings wins; Other re-added when missing', () {
      final list = parseCancelReasons({
        'vendor': ['Closed', ' Rush '],
        'reasons': ['Ignored'],
      }, defaults: _defaults);
      expect(_labels(list), ['Closed', 'Rush', 'Other']);
      expect(_codes(list), ['Closed', 'Rush', 'other']);
    });

    test('store is read when vendor is absent or empty', () {
      final list = parseCancelReasons({'vendor': [], 'store': ['Closed']}, defaults: _defaults);
      expect(_labels(list), ['Closed', 'Other']);
    });

    test('panel shape: top-level reasons as {code, label} maps', () {
      final list = parseCancelReasons({
        'reasons': [
          {'code': 'out_of_stock', 'label': 'Item out of stock'},
          {'code': 'other', 'label': 'Something else'},
          {'code': 'closed', 'label': 'Store closed'},
        ],
      }, defaults: _defaults);
      expect(_labels(list), ['Item out of stock', 'Store closed', 'Something else']);
      expect(_codes(list), ['out_of_stock', 'closed', 'other']);
      expect(list.where((o) => o.isOther).length, 1);
    });

    test('list key, mixed strings and maps, text/reason label fallbacks', () {
      final list = parseCancelReasons({
        'list': [
          'Too busy',
          {'code': 'addr', 'text': 'Wrong address'},
          {'reason': 'No rider'},
          {'code': 'no_label'},
          null,
          'null',
          '',
          {'label': null},
        ],
      }, defaults: _defaults);
      expect(_labels(list), ['Too busy', 'Wrong address', 'No rider', 'no_label', 'Other']);
      expect(_codes(list), ['Too busy', 'addr', 'No rider', 'no_label', 'other']);
    });

    test('a map is never shown as "{code: ...}"', () {
      final list = parseCancelReasons({
        'reasons': [
          {'code': 'x', 'label': 'Label X'},
        ],
      }, defaults: _defaults);
      expect(list.any((o) => o.label.contains('{')), isFalse);
    });

    test('a stored list holding only Other falls back to the defaults', () {
      final list = parseCancelReasons({
        'reasons': ['Other'],
      }, defaults: _defaults);
      expect(_labels(list), ['Item out of stock', 'Too busy', 'Other']);
    });

    test('duplicates and a mid-list Other collapse; Other once, last', () {
      final list = parseCancelReasons({
        'vendor': ['Other', 'Closed', 'closed', 'OTHER', 'Busy'],
      }, defaults: _defaults);
      expect(_labels(list), ['Closed', 'Busy', 'Other']);
    });

    test('a non-list value is ignored', () {
      final list = parseCancelReasons({'vendor': 'Closed', 'reasons': {'a': 1}}, defaults: _defaults);
      expect(_labels(list), _defaults);
    });
  });
}
