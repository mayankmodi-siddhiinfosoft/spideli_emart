import 'package:driver/widget/osm_map/map_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report 02#27 / 02#18: picking a place never throws on a result without
/// usable coordinates, and never keeps "null" (or an absent name) as the
/// address text.
void main() {
  test('a result is picked with its cleaned address', () {
    final OSMMapController c = OSMMapController();
    final picked = c.selectSearchResult({'lat': '3.8480', 'lon': '11.5021', 'display_name': '18, null, Yaoundé, Région du Centre, null, Cameroun'});
    expect(picked, isNotNull);
    expect(picked!.coordinates.latitude, closeTo(3.848, 1e-9));
    expect(picked.coordinates.longitude, closeTo(11.5021, 1e-9));
    expect(picked.address, '18, Yaoundé, Région du Centre, Cameroun');
    expect(c.pickedPlace.value, same(picked));
  });

  test('no display name: an empty address, not the word null', () {
    final OSMMapController c = OSMMapController();
    expect(c.selectSearchResult({'lat': '3.8', 'lon': '11.5'})!.address, '');
    expect(c.selectSearchResult({'lat': 3.8, 'lon': 11.5, 'display_name': null})!.address, '');
  });

  test('no usable coordinates, or not a map: nothing is picked, nothing throws', () {
    final OSMMapController c = OSMMapController();
    expect(c.selectSearchResult({'lat': '', 'lon': '11.5', 'display_name': 'Somewhere'}), isNull);
    expect(c.selectSearchResult({'display_name': 'Somewhere'}), isNull);
    expect(c.selectSearchResult('not a place'), isNull);
    expect(c.pickedPlace.value, isNull);
  });
}
