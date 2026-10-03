import 'package:customer/models/section_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sections sort by numeric order even when the panel stores it as text', () {
    SectionModel s(String name, dynamic order) => SectionModel.fromJson({'name': name, if (order != null) 'order': order, 'isActive': true});
    final List<SectionModel> list = [s('Tontine', '10'), s('Home/On Demand Service', '9'), s('Restaurants', '2'), s('No order', null), s('Fashion', 4), s('Cab Service', '6')];
    list.sort(SectionModel.compareByOrder);
    expect(list.map((e) => e.name), ['Restaurants', 'Fashion', 'Cab Service', 'Home/On Demand Service', 'Tontine', 'No order']);
  });
}
