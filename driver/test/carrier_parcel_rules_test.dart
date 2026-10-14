import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/services/carrier_parcel_rules.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrier parcels (`.claude/COMPANY-CARRIER-LINK.md` section 5): the company
/// owner assigns them; no driver sees, is offered or takes one otherwise; a
/// reject / timeout goes back to the owner.
void main() {
  const String owner = 'company-1';
  const String carrier = 'carrier-1';
  const String me = 'driver-me';
  const String other = 'driver-other';

  Map<String, dynamic> parcel(
    String status, {
    String? driverId,
    String? assignedBy,
    String? carrierId = carrier,
    String? carrierOwnerId = owner,
    List<String>? rejected,
  }) =>
      {
        'id': 'p1',
        'status': status,
        'driverId': ?driverId,
        'driverID': ?driverId,
        'assignedBy': ?assignedBy,
        'carrierId': ?carrierId,
        'carrierOwnerId': ?carrierOwnerId,
        'rejectedByDrivers': ?rejected,
      };

  group('which parcels are carrier-bound', () {
    test('carrierId or carrierOwnerId (or companyOwnerId) marks one', () {
      expect(CarrierParcelRules.isCarrierBound(parcel('Order Placed')), isTrue);
      expect(CarrierParcelRules.isCarrierBound(parcel('Order Placed', carrierOwnerId: null)), isTrue);
      expect(CarrierParcelRules.isCarrierBound(parcel('Order Placed', carrierId: null)), isTrue);
      expect(CarrierParcelRules.isCarrierBound({'status': 'Order Placed', 'companyOwnerId': owner}), isTrue);
      expect(CarrierParcelRules.isCarrierBound(parcel('Order Placed', carrierId: null, carrierOwnerId: null)), isFalse);
      expect(CarrierParcelRules.isCarrierBound({'status': 'Order Placed', 'carrierId': '  '}), isFalse);
      expect(CarrierParcelRules.isCarrierBound(null), isFalse);
    });

    test('the company it belongs to: carrierOwnerId, else the owner\'s linked carrier', () {
      expect(CarrierParcelRules.belongsToCompany(parcel('Order Placed'), ownerUid: owner), isTrue);
      expect(CarrierParcelRules.belongsToCompany(parcel('Order Placed'), ownerUid: 'company-2', ownerCarrierId: carrier), isFalse,
          reason: 'a named owner wins over a shared carrier id');
      expect(CarrierParcelRules.belongsToCompany(parcel('Order Placed', carrierOwnerId: null), ownerUid: owner, ownerCarrierId: carrier), isTrue);
      expect(CarrierParcelRules.belongsToCompany(parcel('Order Placed', carrierOwnerId: null), ownerUid: owner, ownerCarrierId: 'carrier-2'), isFalse);
      expect(CarrierParcelRules.belongsToCompany(parcel('Order Placed', carrierOwnerId: null), ownerUid: owner), isFalse);
      expect(CarrierParcelRules.belongsToCompany(parcel('Order Placed'), ownerUid: ''), isFalse);
    });
  });

  group('visibility to drivers', () {
    test('a parcel without a carrier is visible as before', () {
      expect(CarrierParcelRules.visibleToDriver(parcel('Order Placed', carrierId: null, carrierOwnerId: null), me), isTrue);
    });

    test('an unassigned carrier parcel is visible to nobody (company drivers included)', () {
      expect(CarrierParcelRules.visibleToDriver(parcel('Order Placed'), me), isFalse);
      expect(CarrierParcelRules.visibleToDriver(parcel('Driver Rejected'), me), isFalse);
    });

    test('visible only to the driver the owner assigned it to', () {
      final Map<String, dynamic> assigned = parcel('Driver Pending', driverId: me, assignedBy: owner);
      expect(CarrierParcelRules.visibleToDriver(assigned, me), isTrue);
      expect(CarrierParcelRules.visibleToDriver(assigned, other), isFalse);
      expect(CarrierParcelRules.ownerAssignedTo(assigned, me), isTrue);
    });

    test('a dispatch nobody owner-assigned is foreign: hidden and handed back', () {
      final Map<String, dynamic> dispatched = parcel('Driver Pending', driverId: me);
      expect(CarrierParcelRules.visibleToDriver(dispatched, me), isFalse);
      expect(CarrierParcelRules.isForeignOffer(dispatched, me), isTrue);
      // assignedBy that is not the order's company does not count.
      final Map<String, dynamic> wrongOwner = parcel('Driver Pending', driverId: me, assignedBy: 'someone-else');
      expect(CarrierParcelRules.ownerAssignedTo(wrongOwner, me), isFalse);
      expect(CarrierParcelRules.isForeignOffer(wrongOwner, me), isTrue);
      // The owner's own assignment is not foreign; nor is another driver's offer.
      expect(CarrierParcelRules.isForeignOffer(parcel('Driver Pending', driverId: me, assignedBy: owner), me), isFalse);
      expect(CarrierParcelRules.isForeignOffer(dispatched, other), isFalse);
      expect(CarrierParcelRules.isForeignOffer(parcel('Driver Pending', driverId: me, carrierId: null, carrierOwnerId: null), me), isFalse);
    });

    test('a job the driver is already working stays visible to them', () {
      expect(CarrierParcelRules.visibleToDriver(parcel('Driver Accepted', driverId: me), me), isTrue);
      expect(CarrierParcelRules.visibleToDriver(parcel('In Transit', driverId: me), me), isTrue);
      expect(CarrierParcelRules.visibleToDriver(parcel('In Transit', driverId: me), other), isFalse);
    });

    test('an order without carrierOwnerId: any owner assignment counts', () {
      expect(CarrierParcelRules.ownerAssignedTo(parcel('Driver Pending', driverId: me, assignedBy: owner, carrierOwnerId: null), me), isTrue);
    });
  });

  group('accept (DispatchOrderRules.acceptCheck)', () {
    test('never from the open search, even for a company driver', () {
      expect(DispatchOrderRules.acceptCheck(DispatchKind.parcel, parcel('Order Placed'), me, fromOpenSearch: true), AcceptCheck.gone);
      // The same open parcel without a carrier is still taken from the search.
      expect(DispatchOrderRules.acceptCheck(DispatchKind.parcel, parcel('Order Placed', carrierId: null, carrierOwnerId: null), me, fromOpenSearch: true),
          AcceptCheck.ok);
    });

    test('never a legacy request or an offer the owner did not make', () {
      expect(DispatchOrderRules.acceptCheck(DispatchKind.parcel, parcel('Driver Pending'), me, heldAsRequest: true), AcceptCheck.gone);
      expect(DispatchOrderRules.acceptCheck(DispatchKind.parcel, parcel('Driver Pending', driverId: me), me), AcceptCheck.gone);
    });

    test('the owner\'s assignment is accepted with the normal flow', () {
      expect(DispatchOrderRules.acceptCheck(DispatchKind.parcel, parcel('Driver Pending', driverId: me, assignedBy: owner), me), AcceptCheck.ok);
      expect(DispatchOrderRules.acceptCheck(DispatchKind.parcel, parcel('Driver Pending', driverId: me, assignedBy: owner), other), AcceptCheck.gone);
      expect(DispatchOrderRules.acceptCheck(DispatchKind.parcel, parcel('Driver Accepted', driverId: me, assignedBy: owner), me), AcceptCheck.held);
    });

    test('the owner\'s assignment has no countdown: accepted whenever the driver chooses', () {
      final Map<String, dynamic> assigned = parcel('Driver Pending', driverId: me, assignedBy: owner);
      expect(CarrierParcelRules.isOwnerAssignment(assigned, me), isTrue);
      // Even in orderRequestData and announced by a push: never timed out.
      expect(DispatchOrderRules.isTimedOffer(assigned, uid: me, orderId: 'p1', requests: const ['p1'], pushSeen: true), isFalse);
      // Still pending for this driver, so it stays on the parcel home's cards.
      expect(DispatchOrderRules.isPendingFor(assigned, me), isTrue);
    });

    test('a platform parcel offer keeps its countdown', () {
      final Map<String, dynamic> platform = parcel('Driver Pending', driverId: me, carrierId: null, carrierOwnerId: null);
      expect(CarrierParcelRules.isOwnerAssignment(platform, me), isFalse);
      expect(DispatchOrderRules.isTimedOffer(platform, uid: me, orderId: 'p1', requests: const ['p1']), isTrue);
    });

    test('a carrier parcel the owner did not assign is not an owner assignment', () {
      expect(CarrierParcelRules.isOwnerAssignment(parcel('Driver Pending', driverId: me), me), isFalse);
      expect(CarrierParcelRules.isOwnerAssignment(parcel('Driver Pending', driverId: me, assignedBy: 'someone-else'), me), isFalse);
      expect(CarrierParcelRules.isOwnerAssignment(parcel('Driver Pending', driverId: other, assignedBy: owner), me), isFalse);
    });
  });

  group('the owner assigns', () {
    test('allowed while placed, handed back, or offered and not answered', () {
      for (final String s in ['Order Placed', 'Driver Rejected']) {
        expect(CarrierParcelRules.assignCheck(parcel(s), ownerUid: owner, driverId: me), CarrierAssignCheck.ok, reason: s);
      }
      expect(CarrierParcelRules.assignCheck(parcel('Driver Pending', driverId: other, assignedBy: owner), ownerUid: owner, driverId: me), CarrierAssignCheck.ok);
      expect(CarrierParcelRules.assignCheck(parcel('Driver Pending', driverId: me, assignedBy: owner), ownerUid: owner, driverId: me), CarrierAssignCheck.sameDriver);
    });

    test('refused once accepted, ended, unpaid, gone or another company\'s', () {
      expect(CarrierParcelRules.assignCheck(parcel('Driver Accepted', driverId: other), ownerUid: owner, driverId: me), CarrierAssignCheck.accepted);
      expect(CarrierParcelRules.assignCheck(parcel('In Transit', driverId: other), ownerUid: owner, driverId: me), CarrierAssignCheck.accepted);
      for (final String s in ['Order Completed', 'Order Cancelled', 'Order Rejected']) {
        expect(CarrierParcelRules.assignCheck(parcel(s), ownerUid: owner, driverId: me), CarrierAssignCheck.ended, reason: s);
      }
      expect(CarrierParcelRules.assignCheck(parcel('Quote Requested'), ownerUid: owner, driverId: me), CarrierAssignCheck.notPaid);
      expect(CarrierParcelRules.assignCheck(null, ownerUid: owner, driverId: me), CarrierAssignCheck.gone);
      expect(CarrierParcelRules.assignCheck(parcel('Order Placed'), ownerUid: 'company-2', driverId: me), CarrierAssignCheck.notMine);
    });

    test('the assignment is an offer in the D3 shape, by the owner', () {
      const Object at = 'NOW';
      final Map<String, dynamic> fields = CarrierParcelRules.assignFields(driverId: me, ownerUid: owner, now: at);
      expect(fields['status'], 'Driver Pending');
      expect(fields['driverId'], me);
      expect(fields['driverID'], me);
      expect(fields['assignedBy'], owner);
      expect(fields['assignedAt'], at);
      expect(fields['dispatchedAt'], at, reason: 'the countdown starts at the assignment');
      expect(fields['sendToDriver'], isFalse);
      expect(fields['rejectedByDrivers'], FieldValue.arrayRemove([me]), reason: 'the owner chose this driver again');
      expect(fields['driver'], FieldValue.delete(), reason: 'the snapshot is written by the accept only');
      expect(fields.containsKey('status') && !fields.containsKey('driverRejections'), isTrue);
      // The result reads as the owner's assignment to that driver.
      final Map<String, dynamic> after = {...parcel('Order Placed'), 'status': fields['status'], 'driverId': me, 'driverID': me, 'assignedBy': owner};
      expect(CarrierParcelRules.ownerAssignedTo(after, me), isTrue);
      expect(DispatchOrderRules.isPendingFor(after, me), isTrue);
    });

    test('server timestamp by default', () {
      expect(CarrierParcelRules.assignFields(driverId: me, ownerUid: owner)['assignedAt'], FieldValue.serverTimestamp());
    });

    test('a reassignment names the driver it replaces', () {
      expect(CarrierParcelRules.replacedDriver(parcel('Driver Pending', driverId: other, assignedBy: owner), me), other);
      expect(CarrierParcelRules.replacedDriver(parcel('Driver Pending', driverId: me, assignedBy: owner), me), isNull);
      expect(CarrierParcelRules.replacedDriver(parcel('Order Placed'), me), isNull);
    });

    test('the owner\'s list: waiting for the owner vs. waiting for the driver', () {
      expect(CarrierParcelRules.awaitsOwner(status: 'Order Placed'), isTrue);
      expect(CarrierParcelRules.awaitsOwner(status: 'Driver Rejected', driverId: ''), isTrue);
      expect(CarrierParcelRules.awaitsOwner(status: 'Quote Requested'), isFalse);
      expect(CarrierParcelRules.awaitsOwner(status: 'Driver Pending', driverId: me), isFalse);
      expect(CarrierParcelRules.awaitsDriver(status: 'Driver Pending', driverId: me), isTrue);
      expect(CarrierParcelRules.awaitsDriver(status: 'Driver Accepted', driverId: me), isFalse);
      expect(CarrierParcelRules.canAssignStatus('Order Placed'), isTrue);
      expect(CarrierParcelRules.canAssignStatus('Driver Accepted'), isFalse);
    });

    test('assignable drivers: this company\'s driver accounts, not disabled', () {
      expect(CarrierParcelRules.isAssignableDriver(ownerId: owner, companyId: owner, role: 'driver'), isTrue);
      expect(CarrierParcelRules.isAssignableDriver(ownerId: owner, companyId: owner), isTrue);
      expect(CarrierParcelRules.isAssignableDriver(ownerId: 'company-2', companyId: owner, role: 'driver'), isFalse);
      expect(CarrierParcelRules.isAssignableDriver(ownerId: owner, companyId: owner, role: 'driver', isOwner: true), isFalse);
      expect(CarrierParcelRules.isAssignableDriver(ownerId: owner, companyId: owner, role: 'customer'), isFalse);
      expect(CarrierParcelRules.isAssignableDriver(ownerId: owner, companyId: owner, role: 'driver', active: false), isFalse);
      expect(CarrierParcelRules.isAssignableDriver(ownerId: '', companyId: ''), isFalse);
    });
  });

  group('reject / timeout goes back to the owner', () {
    test('back to Order Placed, nobody named, not for the dispatch', () {
      final Map<String, dynamic> fields = CarrierParcelRules.returnToOwnerFields(me);
      expect(fields['status'], 'Order Placed');
      expect(fields['sendToDriver'], isFalse);
      expect(fields.containsKey('driverId') && fields['driverId'] == null, isTrue);
      expect(fields.containsKey('driverID') && fields['driverID'] == null, isTrue);
      expect(fields['rejectedByDrivers'], FieldValue.arrayUnion([me]));
      expect(fields.containsKey('driverRejections'), isFalse, reason: 'a timeout records no reason');
    });

    test('a manual reject keeps its reason', () {
      final Map<String, dynamic> reason = {'driverRejections': FieldValue.arrayUnion([{'driverId': me, 'reason': 'Too far'}])};
      final Map<String, dynamic> fields = CarrierParcelRules.returnToOwnerFields(me, reasonFields: reason);
      expect(fields['driverRejections'], reason['driverRejections']);
      expect(fields['status'], 'Order Placed');
    });

    test('the result waits for the owner again and is hidden from drivers', () {
      final Map<String, dynamic> after = {...parcel('Order Placed'), 'driverId': null, 'driverID': null, 'rejectedByDrivers': [me]};
      expect(CarrierParcelRules.awaitsOwner(status: after['status'], driverId: after['driverId'], driverID: after['driverID']), isTrue);
      expect(CarrierParcelRules.visibleToDriver(after, me), isFalse);
      expect(DispatchOrderRules.requestVerdict(after, me), RequestVerdict.stale, reason: 'the offer leaves the driver\'s orderRequestData');
    });

    test('the driver may still reject / time out an owner offer naming them', () {
      final Map<String, dynamic> assigned = parcel('Driver Pending', driverId: me, assignedBy: owner);
      expect(DispatchOrderRules.canReject(DispatchKind.parcel, assigned, me), isTrue);
      expect(DispatchOrderRules.canReject(DispatchKind.parcel, assigned, me, timeout: true), isTrue);
      expect(DispatchOrderRules.canReject(DispatchKind.parcel, assigned, other), isFalse);
    });
  });

  group('pushes', () {
    test('the owner push type opens the owner\'s Orders list and rings on the job channel', () {
      expect(CarrierParcelRules.ownerPushTypes, containsAll(<String>['carrier_parcel_order', 'carrier_parcel_returned']));
      expect(PushChannels.driverChannelFor(type: CarrierParcelRules.ownerPushType), PushChannels.driverJob);
    });

    test('the assigned driver\'s push is read as a parcel offer', () {
      final DispatchPush? push = DispatchPush.parse({
        'type': DispatchKind.parcel.pushType,
        'orderId': 'p1',
        'click_action': DispatchPush.clickAction,
        'status': 'Driver Pending',
      });
      expect(push?.kind, DispatchKind.parcel);
      expect(push?.orderId, 'p1');
      expect(PushChannels.driverChannelFor(type: 'parcel', requestedChannelId: 'driver_jobs'), PushChannels.driverJob);
    });
  });
}
