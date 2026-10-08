import 'package:customer/service/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// The customer app's new-order / booking pushes to a store, with and
/// without the admin's order sound (globalSettings.order_ringtone_url).
void main() {
  const String url = 'https://example.com/ring.mp3';

  test('without a ringtone: exactly today\'s store channel and sounds', () {
    for (final String? none in [null, '', '   ']) {
      for (final String kind in ['order_placed', 'dinein_placed', 'schedule_order', 'new_order']) {
        expect(PushChannels.forRecipient(PushRecipient.store, kind: kind, orderRingtoneUrl: none),
            const PushChannelSpec(androidChannelId: 'new_order', androidSound: 'order_alert', apnsSound: 'order_alert.caf'));
      }
    }
    expect(PushChannels.forRecipient(PushRecipient.store, kind: 'order_placed'), const PushChannelSpec(androidChannelId: 'new_order', androidSound: 'order_alert', apnsSound: 'order_alert.caf'));
  });

  test('with a ringtone: new orders / bookings name new_order_rt_<key> and order_ringtone_<key>.caf', () {
    for (final String kind in ['order_placed', 'dinein_placed', 'schedule_order', 'new_order']) {
      expect(PushChannels.forRecipient(PushRecipient.store, kind: kind, orderRingtoneUrl: url),
          const PushChannelSpec(androidChannelId: 'new_order_rt_955470e2', androidSound: 'order_alert', apnsSound: 'order_ringtone_955470e2.caf'));
    }
  });

  test('with a ringtone: every other push is unchanged', () {
    for (final PushRecipient? r in [PushRecipient.customer, PushRecipient.driver, PushRecipient.provider, PushRecipient.worker, null]) {
      expect(PushChannels.forRecipient(r, kind: 'order_placed', orderRingtoneUrl: url), PushChannels.forRecipient(r, kind: 'order_placed'), reason: '$r');
    }
    expect(PushChannels.forRecipient(PushRecipient.store, kind: 'store_update', orderRingtoneUrl: url), const PushChannelSpec(androidChannelId: 'general'));
    expect(PushChannels.forRecipient(PushRecipient.store, kind: 'chat', orderRingtoneUrl: url), PushChannels.chat);
  });

  test('the message carries the versioned channel (also as data.channelId) and iOS sound', () {
    final PushChannelSpec spec = PushChannels.forRecipient(PushRecipient.store, kind: 'order_placed', orderRingtoneUrl: url);
    final Map<String, String> data = PushPayload.stringData({'orderId': 'o1'}, type: 'order_placed', spec: spec);
    expect(data, {'orderId': 'o1', 'type': 'order_placed', 'channelId': 'new_order_rt_955470e2'});
    final Map<String, dynamic> message = PushPayload.fcmV1Message(token: 't', title: 'T', body: 'B', data: data, spec: spec);
    expect(message['android'], {
      'priority': 'high',
      'notification': {'channel_id': 'new_order_rt_955470e2', 'sound': 'order_alert'},
    });
    expect(((message['apns'] as Map)['payload'] as Map)['aps'], {'sound': 'order_ringtone_955470e2.caf', 'content-available': 1});
    final Map<String, dynamic> server = PushPayload.serverRequest(token: 't', title: 'T', body: 'B', data: data, spec: spec, kind: 'order_placed');
    expect(server['android'], {'channelId': 'new_order_rt_955470e2', 'sound': 'order_alert'});
    expect(server['apns'], {'sound': 'order_ringtone_955470e2.caf'});
  });

  test('only a new order / booking to a store re-reads the ringtone URL at send time', () {
    expect(PushChannels.isStoreNewOrder(PushRecipient.store, 'order_placed'), isTrue);
    expect(PushChannels.isStoreNewOrder(PushRecipient.store, 'dinein_placed'), isTrue);
    expect(PushChannels.isStoreNewOrder(PushRecipient.store, 'chat'), isFalse);
    expect(PushChannels.isStoreNewOrder(PushRecipient.driver, 'order_placed'), isFalse);
    expect(PushChannels.isStoreNewOrder(null, 'order_placed'), isFalse);
  });
}
