import 'package:customer/models/service_group_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group names saved HTML-escaped by the panel are shown as typed', () {
    expect(ServiceGroupModel.fromJson({'name': 'Online Shopping &amp; Restaurant'}, docId: 'shopping').name, 'Online Shopping & Restaurant');
    expect(ServiceGroupModel.fromJson({'name': 'Transport &amp; Delivery'}, docId: 'transport').name, 'Transport & Delivery');
    expect(ServiceGroupModel.decodeHtmlEntities('Rock &#39;n&#x27; Roll &lt;3'), "Rock 'n' Roll <3");
    expect(ServiceGroupModel.decodeHtmlEntities('Fish & Chips'), 'Fish & Chips');
    expect(ServiceGroupModel.decodeHtmlEntities('&unknown; stays'), '&unknown; stays');
  });
}
