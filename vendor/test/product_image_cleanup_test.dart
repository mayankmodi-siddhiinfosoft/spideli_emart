import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/utils/product_image_cleanup.dart';

/// Point 58: a confirmed delete removes the product and the images the app
/// uploaded for it - and nothing another product, the store or a profile
/// still shows.
void main() {
  String url(String path, {String token = 't1', String bucket = 'spideli.appspot.com'}) =>
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(path)}?alt=media&token=$token';

  group('storagePathOf', () {
    test('a Firebase Storage download URL gives its object path', () {
      expect(ProductImageCleanup.storagePathOf(url('profileImage/u1/image_picker_1.jpg')), 'profileImage/u1/image_picker_1.jpg');
      expect(ProductImageCleanup.storagePathOf(url('profileImage/u1/a b(1).jpg')), 'profileImage/u1/a b(1).jpg');
    });

    test('a gs:// URL gives its object path', () {
      expect(ProductImageCleanup.storagePathOf('gs://spideli.appspot.com/profileImage/u1/x.png'), 'profileImage/u1/x.png');
    });

    test('anything else is not a Storage object', () {
      for (final Object? value in [null, '', '  ', 'null', 'https://example.com/profileImage/u1/x.png', 'not a url', 42, 'https://firebasestorage.googleapis.com/v0/b/x']) {
        expect(ProductImageCleanup.storagePathOf(value), isNull, reason: '$value');
      }
    });
  });

  group('ownUploads', () {
    test("only the app's own product uploads of the signed-in user or the owner, each once", () {
      final List<String> own = ProductImageCleanup.ownUploads(
        photo: url('profileImage/owner/1.jpg'),
        photos: [
          url('profileImage/owner/1.jpg'),
          url('profileImage/employee/2.jpg'),
          url('profileImage/someoneelse/3.jpg'),
          url('images/variant.png'),
          url('admin/catalogue/4.jpg'),
          'https://example.com/5.jpg',
          null,
          '',
        ],
        uploaderIds: ['owner', 'employee', null, ''],
      );
      expect(own, [url('profileImage/owner/1.jpg'), url('profileImage/employee/2.jpg')]);
    });

    test('no known uploader: nothing is a candidate', () {
      expect(ProductImageCleanup.ownUploads(photo: url('profileImage/u1/1.jpg'), uploaderIds: [null, '', 'null']), isEmpty);
    });

    test('a folder that only starts like the uploader id is not theirs', () {
      expect(ProductImageCleanup.ownUploads(photo: url('profileImage/u10/1.jpg'), uploaderIds: ['u1']), isEmpty);
    });
  });

  group('deletable', () {
    test('an image still used elsewhere is kept, compared by object (any token)', () {
      final String shared = url('profileImage/u1/shared.jpg');
      final String own = url('profileImage/u1/own.jpg');
      final List<String> result = ProductImageCleanup.deletable([shared, own], [url('profileImage/u1/shared.jpg', token: 'other'), null, 'plain text']);
      expect(result, [own]);
    });

    test('two URLs of one object are deleted once', () {
      final String a = url('profileImage/u1/x.jpg', token: 'a');
      final String b = url('profileImage/u1/x.jpg', token: 'b');
      expect(ProductImageCleanup.deletable([a, b], const []), [a]);
    });
  });

  test("storageUrlsIn finds every Storage URL in a document (store photos, variants' images, nested maps)", () {
    final Map<String, dynamic> store = {
      'title': 'Shop',
      'photo': url('profileImage/u1/logo.jpg'),
      'photos': [url('profileImage/u1/front.jpg'), 'https://example.com/x.jpg'],
      'item_attribute': {
        'variants': [
          {'variant_image': url('images/v1.png')},
        ],
      },
      'count': 3,
    };
    expect(ProductImageCleanup.storageUrlsIn(store).toSet(), {url('profileImage/u1/logo.jpg'), url('profileImage/u1/front.jpg'), url('images/v1.png')});
    expect(ProductImageCleanup.storageUrlsIn(null), isEmpty);
  });
}
