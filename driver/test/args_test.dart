import 'package:driver/utils/args.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client point 6: the blank chat screen came from assigning a missing or
/// non-String argument into a non-nullable `Rx`. These are the exact shapes the
/// callers hand over.
void main() {
  group('argString', () {
    test('reads a present string', () {
      expect(argString({'orderId': 'ORD-1'}, 'orderId'), 'ORD-1');
    });

    test('a missing key is empty, not a crash', () {
      expect(argString({'senderId': 'abc'}, 'orderId'), '');
    });

    test('an explicit null is empty', () {
      // A customer with no `fcmToken` on their user document.
      expect(argString({'token': null}, 'token'), '');
    });

    test('non-string values are coerced instead of throwing', () {
      expect(argString({'orderId': 42}, 'orderId'), '42');
    });

    test('values that merely print as missing are treated as absent', () {
      for (final text in ['null', 'NULL', 'nil', 'undefined']) {
        expect(argString({'orderId': text}, 'orderId'), '', reason: text);
      }
    });

    test('whitespace-only is empty and real values are trimmed', () {
      expect(argString({'orderId': '   '}, 'orderId'), '');
      expect(argString({'orderId': '  ORD-2 '}, 'orderId'), 'ORD-2');
    });

    test('non-map arguments do not throw', () {
      // Several screens are opened with a bare model object.
      expect(argString(Object(), 'orderId'), '');
      expect(argString(null, 'orderId'), '');
      expect(argString('ORD-3', 'orderId'), '');
    });
  });

  group('argOf', () {
    test('reads a value of the requested type', () {
      expect(argOf<String>({'a': 'x'}, 'a'), 'x');
      expect(argOf<int>({'a': 7}, 'a'), 7);
    });

    test('returns null rather than assigning the wrong type', () {
      expect(argOf<String>({'a': 7}, 'a'), isNull);
      expect(argOf<String>({'a': null}, 'a'), isNull);
      expect(argOf<String>({}, 'a'), isNull);
    });

    test('non-map arguments return null', () {
      expect(argOf<String>(null, 'a'), isNull);
      expect(argOf<String>(Object(), 'a'), isNull);
    });
  });
}
