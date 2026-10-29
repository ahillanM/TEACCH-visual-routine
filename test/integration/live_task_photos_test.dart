// LIVE tests for custom task photos (Supabase Storage bucket `task-images`).
// Needs supabase/.demo-credentials.local (gitignored) or --dart-define=DEMO_PASSWORD.
//
//   flutter test test/integration/live_task_photos_test.dart
//
// Uses a fictional day 15 days ahead for Lukas and removes everything again.
// Signed URLs are never printed.
import 'dart:io';
import 'dart:typed_data';

import 'package:bbw_visual_routine/core/data/mock_library.dart';
import 'package:bbw_visual_routine/core/models/schedule_snapshot.dart';
import 'package:bbw_visual_routine/core/state/library_store.dart';
import 'package:bbw_visual_routine/core/state/participant_directory.dart';
import 'package:bbw_visual_routine/core/state/schedule_store.dart';
import 'package:bbw_visual_routine/core/time/time_format.dart';
import 'package:bbw_visual_routine/services/app_config.dart';
import 'package:bbw_visual_routine/services/supabase_auth_service.dart';
import 'package:bbw_visual_routine/services/supabase_sync.dart';
import 'package:bbw_visual_routine/services/task_image_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

const _lukas = 'b0000000-0000-0000-0000-000000000001';
const _mia = 'b0000000-0000-0000-0000-000000000002';

String _password() {
  const d = String.fromEnvironment('DEMO_PASSWORD');
  if (d.isNotEmpty) return d;
  final f = File('supabase/.demo-credentials.local');
  return f.existsSync() ? f.readAsStringSync().trim() : '';
}

SupabaseClient _client() => SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabasePublishableKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );

/// A signed-in app instance with the real sync + photo service.
class _App {
  final SupabaseClient db = _client();
  late final TaskImageService images = TaskImageService(db);
  late final SupabaseSync sync;
  late final ScheduleStore store;

  _App() {
    sync = SupabaseSync(
      db: db,
      participants: ParticipantDirectory(const []),
      support: SupabaseSupportStore(db),
      progress: SupabaseProgressStore(db),
      library: LibraryStore(
          activities: mockLibraryActivities,
          places: mockPlaces,
          contacts: mockContacts),
      images: images,
    );
    store = ScheduleStore(
      repository: sync,
      initial: ScheduleSnapshot(
          version: 1, publishedAt: DateTime.now(), events: const {}),
    );
    sync.attach(store);
  }

  Future<_App> signIn(String email, String pw) async {
    await SupabaseAuthService(
            db: db, onSignedIn: sync.start, onSignedOut: sync.stop)
        .signIn(username: email, password: pw);
    return this;
  }
}

/// A camera-like JPEG with EXIF (make + GPS) and a large size.
Uint8List _cameraJpeg({int w = 3000, int h = 2000}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(90, 140, 200));
  image.exif.imageIfd['Make'] = 'TestCam';
  image.exif.gpsIfd['GPSLatitudeRef'] = 'N';
  return img.encodeJpg(image, quality: 70);
}

Future<int> _httpStatus(String url) async => (await http.get(Uri.parse(url))).statusCode;

void main() {
  group('prepareJpeg (offline)', () {
    test('resizes to 1280 px and strips EXIF/GPS', () {
      final original = _cameraJpeg();
      expect(img.decodeJpg(original)!.exif.imageIfd['Make'], isNotNull,
          reason: 'fixture really has EXIF');
      final out = TaskImageService.prepareJpeg(original)!;
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 1280);
      expect(decoded.height, 853);
      expect(decoded.exif.imageIfd['Make'], isNull);
      expect(decoded.exif.gpsIfd.isEmpty, isTrue);
      expect(out.lengthInBytes, lessThan(TaskImageService.maxUploadBytes));
    });

    test('portrait photos are limited by height; small ones keep their size', () {
      expect(img.decodeJpg(TaskImageService.prepareJpeg(_cameraJpeg(w: 1500, h: 2600))!)!.height, 1280);
      expect(img.decodeJpg(TaskImageService.prepareJpeg(_cameraJpeg(w: 400, h: 300))!)!.width, 400);
    });

    test('non-images are rejected', () {
      expect(TaskImageService.prepareJpeg(Uint8List.fromList('hello'.codeUnits)), isNull);
    });
  });

  final pw = _password();
  group('live Storage + RLS', skip: pw.isEmpty ? 'No demo password' : null, () {
    late _App anna, ben, lukas, mia;
    late String photo; // Lukas's photo uploaded by Anna
    final day = TimeFormat.dateOnly(DateTime.now()).add(const Duration(days: 15));
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final created = <String>[];

    setUpAll(() async {
      anna = await _App().signIn('anna.weber.demo@example.com', pw);
      ben = await _App().signIn('ben.schmidt.demo@example.com', pw);
      lukas = await _App().signIn('lukas.demo@example.com', pw);
      mia = await _App().signIn('mia.demo@example.com', pw);
    });

    tearDownAll(() async {
      await anna.db.rpc('save_schedule', params: {
        'p_participant_id': _lukas,
        'p_schedule_date': date,
        'p_activities': [],
        'p_publish': true,
      });
      for (final p in created) {
        await anna.images.deleteIfUnused(p);
      }
      for (final a in [anna, ben, lukas, mia]) {
        await a.sync.stop();
        await a.db.auth.signOut();
        await a.db.dispose();
      }
    });

    test('assigned staff uploads; path has no names', () async {
      photo = await anna.images.upload(participantId: _lukas, original: _cameraJpeg());
      created.add(photo);
      expect(
          photo,
          matches(RegExp(r'^participants/' + _lukas +
              r'/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.jpg$')));
    });

    test('staff and the participant can read; others cannot', () async {
      final staffUrl = await anna.images.signedUrl(photo);
      expect(staffUrl, isNotNull);
      expect(await _httpStatus(staffUrl!), 200);
      final own = await lukas.images.signedUrl(photo);
      expect(own, isNotNull, reason: 'participant reads own photo');
      expect(await _httpStatus(own!), 200);
      expect(await mia.images.signedUrl(photo), isNull, reason: 'other participant');
      expect(await ben.images.signedUrl(photo), isNull, reason: 'staff not assigned to Lukas');
      final anon = _client();
      await expectLater(anon.storage.from('task-images').download(photo),
          throwsA(isA<StorageException>()));
      await expectLater(anon.storage.from('task-images').createSignedUrl(photo, 60),
          throwsA(isA<StorageException>()));
      await anon.dispose();
    });

    test('unauthorized and malformed uploads are refused', () async {
      await expectLater(ben.images.upload(participantId: _lukas, original: _cameraJpeg(w: 64, h: 64)),
          throwsA(isA<TaskImageException>()), reason: 'staff not assigned');
      await expectLater(lukas.images.upload(participantId: _lukas, original: _cameraJpeg(w: 64, h: 64)),
          throwsA(isA<TaskImageException>()), reason: 'participants cannot upload');
      final files = anna.db.storage.from('task-images');
      final small = TaskImageService.prepareJpeg(_cameraJpeg(w: 64, h: 64))!;
      const opts = FileOptions(contentType: 'image/jpeg');
      await expectLater(files.uploadBinary('participants/$_lukas/lukas-photo.jpg', small, fileOptions: opts),
          throwsA(isA<StorageException>()), reason: 'names / non-uuid file names');
      await expectLater(files.uploadBinary('somewhere/else.jpg', small, fileOptions: opts),
          throwsA(isA<StorageException>()), reason: 'outside participants/');
      await expectLater(
          files.uploadBinary(photo, small, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true)),
          throwsA(isA<StorageException>()), reason: 'no overwriting');
      await expectLater(
          files.uploadBinary('participants/$_lukas/0b6f1c8e-4c1a-4a8e-9d3e-2f6a7b8c9d0e.jpg',
              Uint8List.fromList('not an image'.codeUnits),
              fileOptions: const FileOptions(contentType: 'text/plain')),
          throwsA(isA<StorageException>()), reason: 'bucket allows images only');
    });

    test('saving an activity with a photo; participant loads it', () async {
      await anna.db.rpc('save_schedule', params: {
        'p_participant_id': _lukas,
        'p_schedule_date': date,
        'p_activities': [
          {
            'title': 'Woodworking (photo test)',
            'startTime': '09:00',
            'endTime': '11:00',
            'iconKey': 'carpentry',
            'imagePath': photo,
            'meta': {'eventId': 'evt-photo-test'},
          },
        ],
        'p_publish': true,
      });
      await lukas.sync.refresh();
      final event = lukas.store.published.activeEventsFor(_lukas, day).single;
      expect(event.visual.photoUrl, isNotNull);
      expect(event.visual.symbol, 'carpentry', reason: 'icon fallback kept');
      expect(await _httpStatus(event.visual.photoUrl!), 200);
      // Mia never gets Lukas's activity or photo.
      await mia.sync.refresh();
      expect(mia.store.published.eventsOn(day), isEmpty);
    });

    test('server rejects photos of another participant or missing objects', () async {
      final miaPhoto = await anna.images.upload(participantId: _mia, original: _cameraJpeg(w: 64, h: 64));
      created.add(miaPhoto);
      Future<void> save(String path) => anna.db.rpc('save_schedule', params: {
            'p_participant_id': _lukas,
            'p_schedule_date': date,
            'p_activities': [
              {'title': 'X', 'startTime': '13:00', 'imagePath': path},
            ],
            'p_publish': true,
          });
      await expectLater(save(miaPhoto), throwsA(isA<PostgrestException>()
          .having((e) => e.message, 'message', 'image_wrong_participant')));
      await expectLater(save('participants/$_lukas/0b6f1c8e-4c1a-4a8e-9d3e-2f6a7b8c9d0e.jpg'),
          throwsA(isA<PostgrestException>().having((e) => e.message, 'message', 'image_not_found')));
      await expectLater(save('https://example.com/a.jpg'),
          throwsA(isA<PostgrestException>()), reason: 'URLs are not paths');
      // Participants cannot set photos directly.
      final rows = await lukas.db
          .from('activities')
          .update({'image_path': null})
          .eq('meta->>eventId', 'evt-photo-test')
          .select();
      expect(rows, isEmpty);
    });

    test('a photo in use cannot be deleted; staff edits keep it', () async {
      expect(await anna.images.deleteIfUnused(photo), isFalse);
      expect(await anna.images.signedUrl(photo), isNotNull, reason: 'still there');

      await anna.sync.refresh();
      final e = anna.store.published.activeEventsFor(_lukas, day).single;
      anna.store.publish(
          upserts: [e.copyWith(end: e.end.add(const Duration(minutes: 15)))],
          publishedBy: 'Anna');
      await anna.sync.idle;
      final row = await anna.db
          .from('activities')
          .select('image_path, end_time')
          .eq('meta->>eventId', 'evt-photo-test')
          .single();
      expect(row['end_time'], '11:15:00');
      expect(row['image_path'], photo, reason: 'planner sync never drops the photo');
    });

    test('replace and remove through the sync contract', () async {
      await anna.sync.refresh();
      expect(anna.sync.hasPhoto('evt-photo-test', _lukas), isTrue);
      await anna.sync.setActivityPhoto(
          eventId: 'evt-photo-test', participantId: _lukas, original: _cameraJpeg(w: 800, h: 600));
      final row = await anna.db
          .from('activities')
          .select('image_path')
          .eq('meta->>eventId', 'evt-photo-test')
          .single();
      final newPath = row['image_path'] as String;
      created.add(newPath);
      expect(newPath, isNot(photo));
      expect(await anna.images.signedUrl(photo), isNull, reason: 'old photo deleted');

      await lukas.sync.refresh();
      expect(lukas.store.published.activeEventsFor(_lukas, day).single.visual.photoUrl, isNotNull);

      await anna.sync.removeActivityPhoto(eventId: 'evt-photo-test', participantId: _lukas);
      final after = await anna.db
          .from('activities')
          .select('image_path')
          .eq('meta->>eventId', 'evt-photo-test')
          .single();
      expect(after['image_path'], isNull);
      anna.images.clearCache();
      expect(await anna.images.signedUrl(newPath), isNull, reason: 'deleted');
      await lukas.sync.refresh();
      expect(lukas.store.published.activeEventsFor(_lukas, day).single.visual.photoUrl, isNull,
          reason: 'falls back to the pictogram/icon');
    });
  });
}
