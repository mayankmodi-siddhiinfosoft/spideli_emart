import 'dart:io';

import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/live_tracking_controller.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as location;

/// Bug #4 — "customer order tracking: map does not display".
///
/// The screen was never empty because of the map plugin: markers and the camera
/// were only ever touched from the **driver** snapshot, and the Google camera
/// only from the route step. With no driver assigned and no route there was
/// nothing to draw and nothing to look at but lat/lng 0,0.
///
/// So the thing worth pinning down is that the **order alone** is enough: the
/// store and the delivery address produce markers and a camera target before
/// any driver exists, and a route that cannot be fetched does not take them
/// away again.
void main() {
  const double storeLat = 3.8480;
  const double storeLng = 11.5021;
  const double homeLat = 3.8667;
  const double homeLng = 11.5167;

  OrderModel order({String? driverId, String status = Constant.orderPlaced}) => OrderModel(
    id: 'order-1',
    status: status,
    driverID: driverId,
    vendor: VendorModel(latitude: storeLat, longitude: storeLng),
    address: ShippingAddress(location: UserLocation(latitude: homeLat, longitude: homeLng)),
  );

  /// `applyOrder` hands off to an async `updateLiveTracking`; the markers are
  /// built before its first suspension, this just lets the rest run.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() => Constant.selectedMapType = 'osm');

  group('with no driver assigned', () {
    test('the store and the delivery address are both marked', () async {
      final c = LiveTrackingController();
      c.orderModel.value = order();

      c.applyOrder();
      await settle();

      expect(c.osmMarkers.length, 2);
      expect(c.osmMarkers.map((m) => m.point), containsAll(<location.LatLng>[location.LatLng(storeLat, storeLng), location.LatLng(homeLat, homeLng)]));
    });

    test('the camera opens on the store, not on 0,0', () {
      final c = LiveTrackingController();
      c.orderModel.value = order();

      c.applyOrder();

      expect(c.trackedPoints, [location.LatLng(storeLat, storeLng), location.LatLng(homeLat, homeLng)]);
      expect(c.initialTarget, location.LatLng(storeLat, storeLng));
    });

    test('a route that cannot be fetched leaves the markers alone', () async {
      final c = LiveTrackingController();
      c.orderModel.value = order();

      c.applyOrder();
      await settle();

      // The route used to be fetched FIRST and unguarded, so a Directions/OSRM
      // call that could not be made threw and the markers after it were never
      // drawn. Offline, loadRoute must come back quietly with the markers
      // still standing.
      await HttpOverrides.runZoned<Future<void>>(
        () => c.loadRoute(location.LatLng(storeLat, storeLng), location.LatLng(homeLat, homeLng)),
        createHttpClient: (_) => throw const SocketException('offline'),
      );

      expect(c.osmMarkers.length, 2);
      expect(c.routePoints, isEmpty);
    });

    test('a leg with an unset end is not even asked for', () async {
      final c = LiveTrackingController();
      c.orderModel.value = order();

      c.applyOrder();
      await settle();
      await c.loadRoute(const location.LatLng(0, 0), location.LatLng(homeLat, homeLng));

      expect(c.osmMarkers.length, 2);
      expect(c.routePoints, isEmpty);
    });
  });

  group('once a driver is assigned', () {
    test('the driver is marked too, and is what the map opens on', () async {
      final c = LiveTrackingController();
      c.orderModel.value = order(driverId: 'driver-1');
      c.driverUserModel.value = UserModel(location: UserLocation(latitude: 3.8600, longitude: 11.5100));

      c.applyOrder();
      await settle();

      expect(c.osmMarkers.length, 3);
      expect(c.trackedPoints.first, location.LatLng(3.8600, 11.5100));
      expect(c.initialTarget, location.LatLng(3.8600, 11.5100));
    });

    test('a driver whose location has not arrived yet is not marked at 0,0', () async {
      final c = LiveTrackingController();
      c.orderModel.value = order(driverId: 'driver-1');
      c.driverUserModel.value = UserModel();

      c.applyOrder();
      await settle();

      expect(c.osmMarkers.length, 2);
      expect(LiveTrackingController.hasPoint(c.driverCurrent.value), isFalse);
    });
  });

  group('the Google branch draws the same thing', () {
    setUp(() => Constant.selectedMapType = 'google');

    test('markers exist with no driver and no icon bitmaps decoded', () async {
      final c = LiveTrackingController();
      c.orderModel.value = order();

      c.applyOrder();
      await settle();

      expect(c.markers.keys.map((k) => k.value), containsAll(<String>['Pickup', 'Drop']));
      expect(c.markers.length, 2);
      // An icon that never decoded must not cost the marker.
      expect(c.pickupIcon, isNull);
      expect(c.markers.values.every((m) => m.icon == BitmapDescriptor.defaultMarker), isTrue);
    });

    test('the driver marker is added once a location arrives', () async {
      final c = LiveTrackingController();
      c.orderModel.value = order(driverId: 'driver-1');
      c.driverUserModel.value = UserModel(location: UserLocation(latitude: 3.8600, longitude: 11.5100));

      c.applyOrder();
      await settle();

      expect(c.markers.length, 3);
      expect(c.markers[const MarkerId('Driver')]?.position, const LatLng(3.8600, 11.5100));
    });
  });

  group('boundsOf', () {
    test('covers every tracked point', () {
      final bounds = LiveTrackingController.boundsOf([
        location.LatLng(3.80, 11.60),
        location.LatLng(3.90, 11.50),
        location.LatLng(3.85, 11.55),
      ]);
      expect(bounds.southwest.latitude, 3.80);
      expect(bounds.southwest.longitude, 11.50);
      expect(bounds.northeast.latitude, 3.90);
      expect(bounds.northeast.longitude, 11.60);
    });

    test('a single point still makes a usable (degenerate) box', () {
      final bounds = LiveTrackingController.boundsOf([location.LatLng(3.85, 11.55)]);
      expect(bounds.southwest, bounds.northeast);
    });
  });
}
