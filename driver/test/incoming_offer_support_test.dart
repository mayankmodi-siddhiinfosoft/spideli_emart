import 'dart:convert';

import 'package:driver/constant/constant.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/incoming_offer_service.dart';
import 'package:driver/utils/rental_proposal_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pieces around the incoming-order dialog (D3) that hold no Firestore
/// call: hand-assignment marks, the dialog's hold on the alert, the
/// dialog's route name, and the counter-offer's driver.
void main() {
  group('hand-assignment marks (DriverAssignmentWatcher)', () {
    test('read as {id: epoch ms}; the older plain list reads as marked at an unknown time', () {
      expect(DriverAssignmentWatcher.decodeHandAssigned(jsonEncode({'o1': 1700, 'o2': 'x'})), {'o1': 1700, 'o2': 0});
      expect(DriverAssignmentWatcher.decodeHandAssigned(jsonEncode(['o1', '', null, 'o3'])), {'o1': 0, 'o3': 0});
      expect(DriverAssignmentWatcher.decodeHandAssigned('not json'), isEmpty);
      expect(DriverAssignmentWatcher.decodeHandAssigned(null), isEmpty);
    });

    test('a hand assignment the server no longer shows pending (ended while the app was closed) is dropped', () {
      final Map<String, int> marks = {'still': 1, 'ended': 2};
      expect(DriverAssignmentWatcher.pruneHandAssigned(marks, {'still', 'offer'}), {'still': 1});
      expect(DriverAssignmentWatcher.pruneHandAssigned(marks, const {}), isEmpty);
    });

    test('a pending order nobody marked is not a hand assignment', () {
      expect(DriverAssignmentWatcher.isHandAssigned('never-marked'), isFalse);
    });
  });

  group('the incoming-order dialog holds the shared alert', () {
    test('a screen stopping its own alert does not silence the dialog; the dialog\'s release does', () async {
      expect(AudioPlayerService.held, isFalse);
      await AudioPlayerService.hold();
      expect(AudioPlayerService.held, isTrue);
      await AudioPlayerService.playSound(false); // a module screen's sync
      expect(AudioPlayerService.held, isTrue);
      await AudioPlayerService.release();
      expect(AudioPlayerService.held, isFalse);
      await AudioPlayerService.release(); // never below zero
      expect(AudioPlayerService.held, isFalse);
    });
  });

  test('the dialog route is told apart from the screens a controller closes', () {
    Route<void> named(String? name) => MaterialPageRoute<void>(settings: RouteSettings(name: name), builder: (_) => const SizedBox());
    expect(IncomingOfferService.isDialogRoute(named('${IncomingOfferService.dialogRoutePrefix}o1')), isTrue);
    expect(IncomingOfferService.isDialogRoute(named('/ParcelSearchScreen')), isFalse);
    expect(IncomingOfferService.isDialogRoute(named(null)), isFalse);
    expect(IncomingOfferService.isDialogRoute(null), isFalse);
  });

  group('a counter-offer names the driver it was made for (customer canAcceptCounter)', () {
    test('the driver the booking is offered to, else the signed-in driver', () {
      expect(RentalProposalService.counteredByFor({'driverId': 'd1', 'status': Constant.driverPending}, 'company'), 'd1');
      expect(RentalProposalService.counteredByFor({'driverID': 'd2'}, 'me'), 'd2');
      expect(RentalProposalService.counteredByFor({'driverId': null, 'driverID': '  '}, 'me'), 'me');
      expect(RentalProposalService.counteredByFor(const {}, 'me'), 'me');
    });

    test('so this driver\'s offer waits for the customer instead of timing out', () {
      final Map<String, dynamic> booking = {'status': Constant.driverPending, 'driverId': 'me', 'driverID': 'me'};
      booking['priceProposal'] = {'status': 'countered', 'counteredBy': RentalProposalService.counteredByFor(booking, 'me')};
      expect(DispatchOrderRules.awaitsCustomer(booking, 'me'), isTrue);
    });
  });
}
