import 'dart:typed_data';

import 'package:bbw_visual_routine/app/app_scope.dart';
import 'package:bbw_visual_routine/app/app_services.dart';
import 'package:bbw_visual_routine/core/state/in_memory_photos.dart';
import 'package:bbw_visual_routine/core/time/clock.dart';
import 'package:bbw_visual_routine/screens_staff/photos/activity_photo_dialog.dart';
import 'package:bbw_visual_routine/services/task_image_service.dart';
import 'package:bbw_visual_routine/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'test_fixtures.dart';

Uint8List _png({int width = 40, int height = 30}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

/// Photos that always fail, to check the failure path.
class _FailingPhotos implements ActivityPhotos {
  @override
  bool hasPhoto(String eventId, String participantId) => false;

  @override
  Future<void> setActivityPhoto({
    required String eventId,
    required String participantId,
    required Uint8List original,
  }) async =>
      throw const TaskImageException('The photo could not be uploaded.');

  @override
  Future<void> removeActivityPhoto({
    required String eventId,
    required String participantId,
  }) async => throw const TaskImageException('The photo could not be removed.');
}

void main() {
  group('InMemoryActivityPhotos', () {
    test(
      'adds, replaces and removes a photo without touching other data',
      () async {
        final store = freshStore();
        final photos = InMemoryActivityPhotos(store, latency: Duration.zero);
        final before = store.published[workshopId()]!;
        expect(photos.hasPhoto(workshopId(), lena), isFalse);

        await photos.setActivityPhoto(
          eventId: workshopId(),
          participantId: lena,
          original: _png(),
        );
        final withPhoto = store.published[workshopId()]!;
        expect(photos.hasPhoto(workshopId(), lena), isTrue);
        expect(withPhoto.visual.photoBytes, isNotNull);
        expect(withPhoto.title, before.title);
        expect(withPhoto.start, before.start);
        expect(withPhoto.visual.symbol, before.visual.symbol);
        expect(withPhoto.visual.pictogramUrl, before.visual.pictogramUrl);

        await photos.setActivityPhoto(
          eventId: workshopId(),
          participantId: lena,
          original: _png(width: 20),
        );
        expect(
          store.published[workshopId()]!.visual.photoBytes,
          isNot(same(withPhoto.visual.photoBytes)),
        );

        await photos.removeActivityPhoto(
          eventId: workshopId(),
          participantId: lena,
        );
        expect(photos.hasPhoto(workshopId(), lena), isFalse);
        expect(
          store.published[workshopId()]!.visual.pictogramUrl,
          before.visual.pictogramUrl,
        );
      },
    );

    test('a photo is not a schedule change for participants', () async {
      final store = freshStore();
      final photos = InMemoryActivityPhotos(store, latency: Duration.zero);
      await photos.setActivityPhoto(
        eventId: workshopId(),
        participantId: lena,
        original: _png(),
      );
      expect(store.pendingChangesFor(lena), isEmpty);
      expect(store.changes, isEmpty);
    });

    test('removes metadata and shrinks large images before storing', () async {
      final store = freshStore();
      final photos = InMemoryActivityPhotos(store, latency: Duration.zero);
      await photos.setActivityPhoto(
        eventId: workshopId(),
        participantId: lena,
        original: _png(width: 3000, height: 1500),
      );
      final stored = img.decodeJpg(
        store.published[workshopId()]!.visual.photoBytes!,
      )!;
      expect(stored.width, TaskImageService.maxEdgePx);
      expect(stored.height, 640);
    });

    test(
      'rejects a file that is not an image and keeps the activity',
      () async {
        final store = freshStore();
        final photos = InMemoryActivityPhotos(store, latency: Duration.zero);
        await expectLater(
          photos.setActivityPhoto(
            eventId: workshopId(),
            participantId: lena,
            original: Uint8List.fromList([1, 2, 3, 4]),
          ),
          throwsA(isA<TaskImageException>()),
        );
        expect(photos.hasPhoto(workshopId(), lena), isFalse);
        expect(store.published[workshopId()], isNotNull);
      },
    );

    test('an activity that is not published cannot get a photo', () async {
      final store = freshStore();
      final photos = InMemoryActivityPhotos(store, latency: Duration.zero);
      await expectLater(
        photos.setActivityPhoto(
          eventId: 'does-not-exist',
          participantId: lena,
          original: _png(),
        ),
        throwsA(isA<TaskImageException>()),
      );
    });
  });

  group('ActivityPhotoDialog', () {
    late AppServices services;

    setUp(() {
      services = AppServices.demo(
        clock: DemoClock(startHour: 9, startMinute: 40, ticking: false),
      );
    });
    tearDown(() => services.dispose());

    Future<void> open(WidgetTester tester, {ActivityPhotos? photos}) async {
      final scoped = photos == null
          ? services
          : AppServices(
              clock: services.clock,
              auth: services.auth,
              schedule: services.schedule,
              participants: services.participants,
              support: services.support,
              library: services.library,
              routines: services.routines,
              aiDrafts: services.aiDrafts,
              photos: photos,
            );
      final event = services.schedule.published[workshopId()]!;
      final participant = services.participants['p-lena']!;
      await tester.pumpWidget(
        AppScope(
          services: scoped,
          child: MaterialApp(
            theme: buildPlannerTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => showActivityPhotoDialog(
                      context,
                      event: event,
                      participant: participant,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers camera, gallery and shows the activity title', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Add Photo'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Use Pictogram Instead'), findsNothing);
      expect(find.textContaining('Woodwork Workshop'), findsOneWidget);
    });

    testWidgets('gallery → preview → confirm saves the photo', (tester) async {
      final photos = InMemoryActivityPhotos(
        services.schedule,
        latency: Duration.zero,
      );
      final scoped = AppServices(
        clock: services.clock,
        auth: services.auth,
        schedule: services.schedule,
        participants: services.participants,
        support: services.support,
        library: services.library,
        routines: services.routines,
        aiDrafts: services.aiDrafts,
        photos: photos,
      );
      await tester.pumpWidget(
        AppScope(
          services: scoped,
          child: MaterialApp(
            theme: buildPlannerTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ActivityPhotoDialog(
                      event: services.schedule.published[workshopId()]!,
                      participant: services.participants['p-lena']!,
                      pickImage: (ImageSource _) async => _png(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Use This Photo?'), findsOneWidget);
      expect(photos.hasPhoto(workshopId(), 'p-lena'), isFalse);

      await tester.tap(find.text('Use This Photo'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();

      expect(photos.hasPhoto(workshopId(), 'p-lena'), isTrue);
      expect(find.text('Photo saved for Lena.'), findsOneWidget);
      expect(find.text('Use This Photo?'), findsNothing);
    });

    testWidgets('a failed upload shows the error and keeps the preview', (
      tester,
    ) async {
      final failing = _FailingPhotos();
      await tester.pumpWidget(
        AppScope(
          services: AppServices(
            clock: services.clock,
            auth: services.auth,
            schedule: services.schedule,
            participants: services.participants,
            support: services.support,
            library: services.library,
            routines: services.routines,
            aiDrafts: services.aiDrafts,
            photos: failing,
          ),
          child: MaterialApp(
            theme: buildPlannerTheme(),
            home: Scaffold(
              body: ActivityPhotoDialog(
                event: services.schedule.published[workshopId()]!,
                participant: services.participants['p-lena']!,
                pickImage: (ImageSource _) async => _png(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();
      expect(find.text('Use This Photo?'), findsOneWidget);

      await tester.tap(find.text('Use This Photo'));
      await tester.pumpAndSettle();

      expect(find.text('The photo could not be uploaded.'), findsOneWidget);
      expect(find.text('The activity was not changed.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(
        services.schedule.published[workshopId()]!.title,
        'Woodwork Workshop',
      );
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      await tester.pumpWidget(
        AppScope(
          services: services,
          child: MaterialApp(
            theme: buildPlannerTheme(),
            home: Scaffold(
              body: ActivityPhotoDialog(
                event: services.schedule.published[workshopId()]!,
                participant: services.participants['p-lena']!,
                pickImage: (ImageSource _) async => null,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Add Photo'), findsOneWidget);
      expect(find.text('Use This Photo?'), findsNothing);
    });

    testWidgets('a camera that cannot open shows a helpful message', (
      tester,
    ) async {
      await tester.pumpWidget(
        AppScope(
          services: services,
          child: MaterialApp(
            theme: buildPlannerTheme(),
            home: Scaffold(
              body: ActivityPhotoDialog(
                event: services.schedule.published[workshopId()]!,
                participant: services.participants['p-lena']!,
                pickImage: (ImageSource _) async => throw Exception('denied'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('camera could not be opened'), findsOneWidget);
    });
  });
}
