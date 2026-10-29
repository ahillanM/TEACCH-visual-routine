import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// A photo could not be prepared or stored. [message] is safe to show.
class TaskImageException implements Exception {
  final String message;
  const TaskImageException(this.message);
  @override
  String toString() => message;
}

/// What the UI needs for custom activity photos (implemented by
/// `SupabaseSync`; null in the offline demo). Photos are per participant:
/// a shared event has one photo per assigned participant. Only published
/// activities can get a photo. The photo is shown through
/// `VisualRef.photoUrl`, so `ActivityVisual` renders it with the pictogram
/// as fallback.
abstract interface class ActivityPhotos {
  bool hasPhoto(String eventId, String participantId);

  /// Uploads [original] (re-encoded, metadata removed) and attaches it,
  /// replacing and deleting any previous photo. Throws [TaskImageException].
  Future<void> setActivityPhoto({
    required String eventId,
    required String participantId,
    required Uint8List original,
  });

  /// Detaches the photo and deletes it if nothing else uses it.
  Future<void> removeActivityPhoto({
    required String eventId,
    required String participantId,
  });
}

/// Custom activity photos in the PRIVATE Supabase bucket `task-images`.
///
/// Contract (see supabase/README.md, "Task photos"):
/// * Object path `participants/{participantId}/{randomUuid}.jpg`; only this
///   path is stored in `activities.image_path`, never bytes or URLs.
/// * Images are re-encoded before upload: max 1280 px on the long edge,
///   JPEG quality 80, orientation applied, ALL metadata (EXIF/GPS) removed.
/// * Reading uses short-lived signed URLs (cached until shortly before
///   expiry). Signed URLs are bearer links: never log or store them.
/// * Storage RLS decides access: assigned staff upload/read/delete, the
///   participant only reads their own photos. Objects are never overwritten;
///   a photo still used by an activity cannot be deleted.
class TaskImageService {
  final SupabaseClient db;

  static const bucket = 'task-images';
  static const maxEdgePx = 1280;
  static const jpegQuality = 80;
  static const maxUploadBytes = 2 * 1024 * 1024; // = bucket limit
  static const maxInputBytes = 25 * 1024 * 1024; // refuse absurd inputs early
  static const signedUrlTtl = Duration(hours: 2);
  static const _refreshBefore = Duration(minutes: 20);

  final Map<String, ({String url, DateTime expires})> _urls = {};

  TaskImageService(this.db);

  StorageFileApi get _files => db.storage.from(bucket);

  /// Resizes, strips metadata and uploads [original] (any common image
  /// format) for [participantId]. Returns the new object path.
  Future<String> upload({
    required String participantId,
    required Uint8List original,
  }) async {
    if (original.lengthInBytes > maxInputBytes) {
      throw const TaskImageException('This photo is too large.');
    }
    final jpeg = await compute(prepareJpeg, original);
    if (jpeg == null) {
      throw const TaskImageException('This file is not a supported image.');
    }
    if (jpeg.lengthInBytes > maxUploadBytes) {
      throw const TaskImageException('This photo is too large after resizing.');
    }
    final path = 'participants/$participantId/${_uuidV4()}.jpg';
    try {
      await _files.uploadBinary(
        path,
        jpeg,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
      );
    } on StorageException catch (e) {
      throw TaskImageException(e.statusCode == '403'
          ? 'You are not allowed to add photos for this participant.'
          : 'The photo could not be uploaded. Please try again.');
    }
    return path;
  }

  /// Temporary URL for [path], or null if the caller may not read it.
  Future<String?> signedUrl(String path) async =>
      (await signedUrls([path]))[path];

  /// Temporary URLs for several paths in one request (unreadable ones are
  /// left out). Cached URLs are reused until shortly before they expire.
  Future<Map<String, String>> signedUrls(Iterable<String> paths) async {
    final now = DateTime.now();
    final result = <String, String>{};
    final missing = <String>[];
    for (final p in paths.toSet()) {
      final cached = _urls[p];
      if (cached != null && cached.expires.difference(now) > _refreshBefore) {
        result[p] = cached.url;
      } else {
        missing.add(p);
      }
    }
    if (missing.isEmpty) return result;
    try {
      final signed = await _files.createSignedUrlsResult(
          missing, signedUrlTtl.inSeconds);
      final expires = now.add(signedUrlTtl);
      for (final s in signed) {
        if (s is! SignedUrlSuccess) continue; // missing or not readable
        _urls[s.path] = (url: s.signedUrl, expires: expires);
        result[s.path] = s.signedUrl;
      }
    } catch (_) {
      // No access or offline: callers fall back to the pictogram/icon.
    }
    return result;
  }

  /// Deletes [path] if no activity uses it any more. Returns whether it was
  /// deleted (RLS silently refuses photos still in use or not yours).
  Future<bool> deleteIfUnused(String path) async {
    _urls.remove(path);
    try {
      final removed = await _files.remove([path]);
      return removed.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void clearCache() => _urls.clear();

  /// Decode → apply orientation → shrink → JPEG. Re-encoding drops all
  /// metadata (EXIF, GPS, camera data). Null if [bytes] is not an image.
  /// Top-level-safe so it can run in a background isolate via [compute].
  static Uint8List? prepareJpeg(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    var image = img.bakeOrientation(decoded);
    if (image.width > maxEdgePx || image.height > maxEdgePx) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxEdgePx)
          : img.copyResize(image, height: maxEdgePx);
    }
    image.exif = img.ExifData();
    image.iccProfile = null;
    image.textData = null;
    return img.encodeJpg(image, quality: jpegQuality);
  }

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
