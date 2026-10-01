import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// A chat thread is one document under `chat/`, and `collection.doc()` is
/// unforgiving about what it is given: `doc('')` throws ArgumentError and
/// `doc(null)` quietly invents an auto-id, so a message would be written where
/// nobody reads it.
///
/// [FireStoreUtils.chatThreadId] is the single decision both writers make, and
/// it has to keep picking exactly what the app picked before: the order id for
/// an order chat, the sender for an admin one.
void main() {
  group('chatThreadId', () {
    test('an order chat is keyed by the order', () {
      expect(FireStoreUtils.chatThreadId(orderId: 'order-1', senderId: 'me', isAdmin: false), 'order-1');
    });

    test('an admin chat is keyed by the sender', () {
      expect(FireStoreUtils.chatThreadId(orderId: null, senderId: 'me', isAdmin: true), 'me');
    });

    test('a missing order id falls back to the sender instead of an empty path', () {
      expect(FireStoreUtils.chatThreadId(orderId: null, senderId: 'me', isAdmin: false), 'me');
      expect(FireStoreUtils.chatThreadId(orderId: '', senderId: 'me', isAdmin: false), 'me');
      expect(FireStoreUtils.chatThreadId(orderId: '   ', senderId: 'me', isAdmin: false), 'me');
    });

    test('surrounding whitespace never reaches the path', () {
      expect(FireStoreUtils.chatThreadId(orderId: ' order-1 ', senderId: 'me', isAdmin: false), 'order-1');
    });

    test('nothing usable is null, so the caller refuses the write', () {
      expect(FireStoreUtils.chatThreadId(orderId: null, senderId: null, isAdmin: false), isNull);
      expect(FireStoreUtils.chatThreadId(orderId: '', senderId: '  ', isAdmin: true), isNull);
    });
  });
}

