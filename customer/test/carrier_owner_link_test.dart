import 'package:customer/service/push_message.dart';
import 'package:customer/utils/carrier_owner_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// A carrier parcel goes to the company that manages the carrier
/// (`.claude/COMPANY-CARRIER-LINK.md` section 5), unassigned.
void main() {
  group('the company owner of a carrier', () {
    test('the company account whose users.carrierId is the carrier', () {
      final users = <(String, Map<String, dynamic>)>[
        // A company driver may carry the same carrierId: never the owner.
        ('driver-1', {'role': 'driver', 'carrierId': 'k1', 'ownerId': 'company-1', 'isOwner': false}),
        ('company-1', {'role': 'driver', 'carrierId': 'k1', 'isOwner': true, 'driverType': 'company'}),
      ];
      expect(CarrierOwnerLink.pickOwner('k1', users), 'company-1');
    });

    test('driverType company or the older isCompany count as a company', () {
      expect(CarrierOwnerLink.pickOwner('k1', [('c2', {'carrierId': 'k1', 'driverType': 'company'})]), 'c2');
      expect(CarrierOwnerLink.pickOwner('k1', [('c3', {'carrierId': 'k1', 'isCompany': true})]), 'c3');
    });

    test('the older deliveryCarrierId spelling links too (carrierId wins)', () {
      expect(CarrierOwnerLink.pickOwner('k1', [('c4', {'deliveryCarrierId': 'k1', 'isOwner': true})]), 'c4');
      expect(CarrierOwnerLink.pickOwner('k1', [('c5', {'carrierId': 'k9', 'deliveryCarrierId': 'k1', 'isOwner': true})]), '');
    });

    test('falls back to the owner the carrier document names, else none', () {
      expect(CarrierOwnerLink.pickOwner('k1', const [], carrierDocOwnerId: ' owner-x '), 'owner-x');
      expect(CarrierOwnerLink.pickOwner('k1', [('d', {'carrierId': 'k1', 'isOwner': false})]), '');
      expect(CarrierOwnerLink.pickOwner('', [('c', {'carrierId': '', 'isOwner': true})]), '');
    });
  });

  group('a carrier parcel is written unassigned', () {
    test('carrier parcels are recognised by carrierId or carrierOwnerId', () {
      expect(CarrierOwnerLink.isCarrierOrder(carrierId: 'k1'), isTrue);
      expect(CarrierOwnerLink.isCarrierOrder(carrierOwnerId: 'company-1'), isTrue);
      expect(CarrierOwnerLink.isCarrierOrder(carrierId: ' ', carrierOwnerId: null), isFalse);
      expect(CarrierOwnerLink.isCarrierOrder(), isFalse);
    });

    test('no driver named, never sent to the dispatch', () {
      final Map<String, dynamic> fields = CarrierOwnerLink.unassignedFields();
      expect(fields['sendToDriver'], isFalse);
      expect(fields.containsKey('driverId') && fields['driverId'] == null, isTrue);
      expect(fields.containsKey('driverID') && fields['driverID'] == null, isTrue);
    });
  });

  group('the owner push', () {
    const String url = 'https://example.com/ring.mp3';

    test('goes on the driver app\'s job channel', () {
      expect(PushChannels.forRecipient(PushRecipient.driver, kind: CarrierOwnerLink.orderTemplate), const PushChannelSpec(androidChannelId: 'driver_jobs'));
      expect(PushChannels.isDriverJob(PushRecipient.driver, CarrierOwnerLink.orderTemplate), isTrue);
      expect(PushChannels.isDriverJob(PushRecipient.store, CarrierOwnerLink.orderTemplate), isFalse);
    });

    test('with the admin\'s order ringtone when one is set', () {
      expect(PushChannels.forRecipient(PushRecipient.driver, kind: CarrierOwnerLink.orderTemplate, orderRingtoneUrl: url),
          const PushChannelSpec(androidChannelId: 'driver_jobs_rt_955470e2', apnsSound: 'order_ringtone_955470e2.caf'));
    });

    test('other driver pushes are unchanged', () {
      expect(PushChannels.forRecipient(PushRecipient.driver, kind: 'x', orderRingtoneUrl: url), const PushChannelSpec(androidChannelId: 'driver_notifications_channel'));
    });

    test('its data: the owner push type and the order id', () {
      final PushChannelSpec spec = PushChannels.forRecipient(PushRecipient.driver, kind: CarrierOwnerLink.orderTemplate);
      final Map<String, String> data = PushPayload.stringData({'type': CarrierOwnerLink.ownerPushType, 'orderId': 'p1'}, type: CarrierOwnerLink.orderTemplate, spec: spec);
      expect(data, {'type': 'carrier_parcel_order', 'orderId': 'p1', 'channelId': 'driver_jobs'});
    });
  });
}
