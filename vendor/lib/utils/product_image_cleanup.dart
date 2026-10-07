/// Which images of a deleted product the Store app removes from Firebase
/// Storage (client point 58: "If confirmed, the product and its images are
/// permanently deleted", as the store and admin panels do).
///
/// Only what the app uploaded for products itself is ever a candidate: a
/// Firebase Storage object under `profileImage/{uploader uid}/`, the folder
/// [AddProductController] uploads product photos to, for the signed-in user
/// or the store's owner. An image imported from the admin catalogue lives
/// elsewhere and is never touched. The same folder also holds the store's own
/// photos and profile pictures, and a photo can be shared by several products
/// (the same file picked twice lands on the same object), so a candidate is
/// deleted only when nothing else still points at its object - compared by
/// object path, since two download URLs with different tokens can reach the
/// same object.
abstract final class ProductImageCleanup {
  /// The Store app's upload folder for product photos.
  static const String uploadFolder = 'profileImage';

  /// The object path of a Firebase Storage URL - a download URL
  /// (`https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?...`) or
  /// a `gs://{bucket}/{path}` - or null for anything else.
  static String? storagePathOf(Object? url) {
    if (url is! String) return null;
    final String text = url.trim();
    if (text.isEmpty) return null;
    final Uri? uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.scheme == 'gs') {
      final String path = uri.pathSegments.where((p) => p.isNotEmpty).join('/');
      return uri.host.isEmpty || path.isEmpty ? null : path;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (uri.host != 'firebasestorage.googleapis.com') return null;
    // v0 / b / {bucket} / o / {path, its slashes encoded as %2F}
    final List<String> segments = uri.pathSegments;
    if (segments.length < 5 || segments[0] != 'v0' || segments[1] != 'b' || segments[3] != 'o') return null;
    final String path = segments.sublist(4).join('/');
    return path.trim().isEmpty ? null : path;
  }

  /// [photo] and [photos] of a product that the app uploaded itself, under
  /// the folder of one of [uploaderIds] - each URL once.
  static List<String> ownUploads({Object? photo, Iterable<Object?>? photos, required Iterable<String?> uploaderIds}) {
    final List<String> prefixes = uploaderIds
        .where((id) => id != null && id.trim().isNotEmpty && id.trim().toLowerCase() != 'null')
        .map((id) => '$uploadFolder/${id!.trim()}/')
        .toSet()
        .toList();
    if (prefixes.isEmpty) return const [];
    final List<String> result = [];
    for (final Object? url in [photo, ...?photos]) {
      final String? path = storagePathOf(url);
      if (path == null || !prefixes.any(path.startsWith)) continue;
      final String text = (url as String).trim();
      if (!result.contains(text)) result.add(text);
    }
    return result;
  }

  /// Of [candidates], those no URL in [stillUsed] points at (by object path).
  /// Two candidates on the same object are one deletion.
  static List<String> deletable(List<String> candidates, Iterable<Object?> stillUsed) {
    final Set<String> used = {for (final Object? url in stillUsed) ?storagePathOf(url)};
    final Set<String> seen = {};
    final List<String> result = [];
    for (final String url in candidates) {
      final String? path = storagePathOf(url);
      if (path == null || used.contains(path) || !seen.add(path)) continue;
      result.add(url);
    }
    return result;
  }

  /// Every Firebase Storage URL anywhere in [value]: a document's data, its
  /// nested maps and lists.
  static List<String> storageUrlsIn(Object? value) {
    final List<String> found = [];
    void walk(Object? v) {
      if (v is String) {
        if (storagePathOf(v) != null) found.add(v.trim());
      } else if (v is Map) {
        v.values.forEach(walk);
      } else if (v is Iterable) {
        v.forEach(walk);
      }
    }

    walk(value);
    return found;
  }
}
