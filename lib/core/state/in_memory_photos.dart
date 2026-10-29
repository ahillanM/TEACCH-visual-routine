import 'package:flutter/foundation.dart';

import '../../services/task_image_service.dart';
import 'schedule_store.dart';

/// OFFLINE DEMO implementation of [ActivityPhotos]: photos live in memory
/// and vanish on restart. It uses the same image preparation as production
/// (resize, orientation, metadata removal) so staff see realistic results.
///
/// Demo simplification: a shared event has ONE photo for everyone, while the
/// Supabase implementation stores one photo per participant.
class InMemoryActivityPhotos implements ActivityPhotos {
  final ScheduleStore schedule;

  /// Artificial delay so the progress state is visible in demos and tests.
  final Duration latency;

  InMemoryActivityPhotos(
    this.schedule, {
    this.latency = const Duration(milliseconds: 600),
  });

  @override
  bool hasPhoto(String eventId, String participantId) =>
      schedule.published[eventId]?.visual.photoBytes != null;

  @override
  Future<void> setActivityPhoto({
    required String eventId,
    required String participantId,
    required Uint8List original,
  }) async {
    final event = schedule.published[eventId];
    if (event == null) {
      throw const TaskImageException(
        'Publish the activity first, then add a photo.',
      );
    }
    if (original.lengthInBytes > TaskImageService.maxInputBytes) {
      throw const TaskImageException('This photo is too large.');
    }
    final jpeg = await compute(TaskImageService.prepareJpeg, original);
    if (jpeg == null) {
      throw const TaskImageException('This file is not a supported image.');
    }
    await Future<void>.delayed(latency);
    schedule.setPublishedVisual(eventId, event.visual.withPhotoBytes(jpeg));
  }

  @override
  Future<void> removeActivityPhoto({
    required String eventId,
    required String participantId,
  }) async {
    final event = schedule.published[eventId];
    if (event == null || event.visual.photoBytes == null) return;
    await Future<void>.delayed(latency);
    schedule.setPublishedVisual(eventId, event.visual.withPhotoBytes(null));
  }
}
