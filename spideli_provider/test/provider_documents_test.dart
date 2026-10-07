import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/widgets/osm_map/place_model.dart';

/// Report Doc 36/41: provider documents are uploaded against the admin's
/// document type ids only, and 02#27: a location pick never throws on a
/// result missing a component.
void main() {
  group('DocumentType', () {
    test('uses the Firestore id and the admin flags', () {
      final t = DocumentType.fromJson({'title': 'Registre de commerce (RCCM)', 'frontSide': true, 'backSide': true, 'expireAt': true, 'enable': true, 'type': 'provider'}, docId: 'Ab12Cd34');
      expect(t.id, 'Ab12Cd34');
      expect(t.title, 'Registre de commerce (RCCM)');
      expect(t.frontSide, isTrue);
      expect(t.backSide, isTrue);
      expect(t.hasExpiry, isTrue);
      expect(t.enable, isTrue);
      expect(t.userField, DocumentType.commercialRegisterField);
      expect(t.needsNumber, isTrue);
    });

    test('back side only does not ask for a front image; neither side asks for one image', () {
      expect(DocumentType.fromJson({'title': 'X', 'backSide': true, 'enable': true}, docId: 'a').needsFront, isFalse);
      expect(DocumentType.fromJson({'title': 'X', 'enable': true}, docId: 'a').needsFront, isTrue);
    });

    test('reference number only for commercial register / unique ID types', () {
      expect(DocumentType.userFieldForTitle('Unique identification number'), DocumentType.uniqueIdNumberField);
      expect(DocumentType.userFieldForTitle('Numéro d\'identifiant unique (NIU)'), DocumentType.uniqueIdNumberField);
      expect(DocumentType.userFieldForTitle('Commercial register'), DocumentType.commercialRegisterField);
      expect(DocumentType.userFieldForTitle('ID Card'), isNull);
      expect(DocumentType.fromJson({'title': 'ID Card', 'enable': true}, docId: 'x').needsNumber, isFalse);
    });

    test('enabledFrom keeps enabled types with an id, never invents one', () {
      final list = DocumentType.enabledFrom([
        const MapEntry('b', {'title': 'Unique identification number', 'enable': true}),
        const MapEntry('a', {'title': 'Commercial register', 'enable': true}),
        const MapEntry('c', {'title': 'Disabled', 'enable': false}),
        const MapEntry('d', {'title': 'No flag'}),
      ]);
      expect(list.map((t) => t.id), ['a', 'b']);
      expect(list.map((t) => t.id), isNot(contains('commercialRegister')));
      expect(list.map((t) => t.id), isNot(contains('uniqueIdNumber')));
      expect(DocumentType.enabledFrom(const []), isEmpty);
    });

    test('an empty answer from the cache is a failed load, not "none configured"', () {
      expect(DocumentType.unreadable(isEmpty: true, isFromCache: true), isTrue);
      expect(DocumentType.unreadable(isEmpty: true, isFromCache: false), isFalse);
      expect(DocumentType.unreadable(isEmpty: false, isFromCache: true), isFalse);
      expect(DocumentType.unreadable(isEmpty: false, isFromCache: false), isFalse);
    });
  });

  group('UploadedDocument', () {
    test('writes the documents_verify entry shape', () {
      final json = UploadedDocument(documentId: 'Ab12Cd34', frontImage: 'https://f', status: 'uploaded', number: '567278930').toJson();
      expect(json['documentId'], 'Ab12Cd34');
      expect(json['frontImage'], 'https://f');
      expect(json['backImage'], '');
      expect(json['status'], 'uploaded');
      expect(json['number'], '567278930');
    });
  });

  group('PlaceModel.fromNominatim', () {
    test('reads string coordinates and cleans the address', () {
      final p = PlaceModel.fromNominatim({'lat': '3.87', 'lon': '11.52', 'display_name': 'null, Tsinga, Yaoundé'});
      expect(p, isNotNull);
      expect(p!.coordinates, const LatLng(3.87, 11.52));
      expect(p.address, 'Tsinga, Yaoundé');
    });

    test('a result without a name still gives the point, with an empty address', () {
      final p = PlaceModel.fromNominatim({'lat': 3.87, 'lon': 11.52});
      expect(p?.address, '');
    });

    test('unusable results are skipped, not thrown', () {
      expect(PlaceModel.fromNominatim(null), isNull);
      expect(PlaceModel.fromNominatim('x'), isNull);
      expect(PlaceModel.fromNominatim({'lat': 'abc', 'lon': '11'}), isNull);
      expect(PlaceModel.fromNominatim({'display_name': 'Yaoundé'}), isNull);
      expect(PlaceModel.fromNominatim({'lat': '95', 'lon': '11'}), isNull);
    });
  });
}
