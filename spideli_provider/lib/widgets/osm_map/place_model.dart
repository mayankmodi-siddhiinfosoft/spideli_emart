import 'package:latlong2/latlong.dart';
import 'package:spideliprovider/utils/address_format.dart';

class PlaceModel {
  final LatLng coordinates;
  final String address;

  PlaceModel({required this.coordinates, required this.address});

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(coordinates: LatLng(json['lat'], json['lng']), address: json['address']);
  }

  /// One Nominatim search / reverse result, or null when it carries no usable
  /// coordinates (report 02#27: the old code did `double.parse(place['lat'])`
  /// and passed `display_name` straight into a non-null String, so a result
  /// missing either threw inside the tap handler and closed the worker /
  /// service screen). The address is cleaned with the panels' rule (02#18).
  static PlaceModel? fromNominatim(Object? raw) {
    if (raw is! Map) return null;
    final double? lat = _coordinate(raw['lat']);
    final double? lon = _coordinate(raw['lon']);
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) return null;
    return PlaceModel(coordinates: LatLng(lat, lon), address: formatAddressText(raw['display_name']));
  }

  static double? _coordinate(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  Map<String, dynamic> toJson() {
    return {'lat': coordinates.latitude, 'lng': coordinates.longitude, 'address': address};
  }

  @override
  String toString() {
    return 'Place(lat: ${coordinates.latitude}, lng: ${coordinates.longitude}, address: $address)';
  }
}
