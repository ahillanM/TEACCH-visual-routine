import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Languages offered for dictation.
enum SpeechLanguage {
  german('DE', 'de_DE'),
  english('EN', 'en_US');

  final String label;
  final String defaultLocaleId;
  const SpeechLanguage(this.label, this.defaultLocaleId);

  /// German if the phone is set to German, otherwise English.
  static SpeechLanguage forLocale(Locale locale) =>
      locale.languageCode == 'de' ? german : english;
}

/// Why dictation could not start.
enum SpeechUnavailable { permissionDenied, notSupported }

/// Callbacks for one dictation session.
class SpeechCallbacks {
  /// Live (partial) and final recognised text of this session.
  final void Function(String text, bool isFinal) onResult;

  /// A user-facing message; the session has ended.
  final void Function(String message) onError;

  /// The session ended (stopped, pause/time limit reached, or error).
  final VoidCallback onDone;

  const SpeechCallbacks({
    required this.onResult,
    required this.onError,
    required this.onDone,
  });
}

/// Speech → text for the "Build with AI" text field.
///
/// Uses the platform's speech recognition (Android SpeechRecognizer, Web
/// Speech API in Chrome). Audio is handled by the device's speech provider
/// and is never sent to our backend; only the recognised text is used.
abstract class SpeechInput {
  /// Asks for microphone permission on first use. Null when ready.
  Future<SpeechUnavailable?> initialize();

  bool get isListening;

  Future<void> start(SpeechLanguage language, SpeechCallbacks callbacks);

  /// Ends the session and delivers the final text.
  Future<void> stop();

  /// Ends the session without a final result (e.g. dialog closed).
  Future<void> cancel();
}

/// [SpeechInput] backed by the `speech_to_text` plugin.
class DeviceSpeechInput implements SpeechInput {
  final SpeechToText _stt;

  DeviceSpeechInput([SpeechToText? stt]) : _stt = stt ?? SpeechToText();

  static const _listenFor = Duration(seconds: 60);
  static const _pauseFor = Duration(seconds: 5);

  SpeechCallbacks? _session;
  SpeechLanguage? _language;
  bool _onDevice = false;
  bool _gotWords = false;
  bool _retried = false;
  List<LocaleName> _locales = const [];

  @override
  bool get isListening => _session != null;

  @override
  Future<SpeechUnavailable?> initialize() async {
    if (_stt.isAvailable) return null;
    bool ok;
    try {
      ok = await _stt.initialize(onError: _onError, onStatus: _onStatus);
    } catch (_) {
      ok = false; // e.g. platform without a speech recognizer
    }
    if (!ok) {
      final permitted = await _stt.hasPermission.catchError((_) => false);
      return permitted
          ? SpeechUnavailable.notSupported
          : SpeechUnavailable.permissionDenied;
    }
    try {
      _locales = await _stt.locales();
    } catch (_) {
      _locales = const [];
    }
    return null;
  }

  @override
  Future<void> start(SpeechLanguage language, SpeechCallbacks callbacks) async {
    if (_session != null) return; // never two sessions at once
    _session = callbacks;
    _language = language;
    _gotWords = false;
    _retried = false;
    // Prefer local recognition (Android 12+ when the device supports it).
    _onDevice = !kIsWeb;
    await _listen();
  }

  Future<void> _listen() async {
    try {
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _localeIdFor(_language!),
          partialResults: true,
          onDevice: _onDevice,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          listenFor: _listenFor,
          pauseFor: _pauseFor,
        ),
      );
    } catch (_) {
      _fail('Voice input could not start. Please try again or type instead.');
    }
  }

  /// Matches the device's locale id format ("de_DE" on Android, "de-DE" on
  /// the web); falls back to the default id.
  String _localeIdFor(SpeechLanguage language) {
    final wanted = _norm(language.defaultLocaleId);
    final prefix = wanted.substring(0, 2);
    final exact = _locales.where((l) => _norm(l.localeId) == wanted);
    final any = _locales.where((l) => _norm(l.localeId).startsWith(prefix));
    return (exact.firstOrNull ?? any.firstOrNull)?.localeId ??
        language.defaultLocaleId;
  }

  static String _norm(String id) => id.replaceAll('-', '_').toLowerCase();

  void _onResult(SpeechRecognitionResult r) {
    final s = _session;
    if (s == null) return;
    if (r.recognizedWords.isNotEmpty) _gotWords = true;
    s.onResult(r.recognizedWords, r.finalResult);
    if (r.finalResult) _end();
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus && _session != null) _end();
  }

  void _onError(SpeechRecognitionError e) {
    if (_session == null) return;
    // The on-device recognizer may lack this language pack: retry once with
    // the phone's regular speech service before giving up.
    if (_onDevice && !_retried && !_gotWords && e.errorMsg.startsWith('error_language')) {
      _retried = true;
      _onDevice = false;
      unawaited(_listen());
      return;
    }
    _fail(describe(e.errorMsg));
  }

  /// User-facing text for the platform error codes.
  static String describe(String code) => switch (code) {
        'error_no_match' || 'error_speech_timeout' =>
          "I didn't catch anything. Tap the microphone and speak again.",
        'error_permission' || 'error_insufficient_permissions' =>
          'Microphone access is blocked. Allow it in the phone settings.',
        'error_network' || 'error_network_timeout' || 'error_server' ||
        'error_server_disconnected' =>
          'The speech service is not reachable. Check the connection or type instead.',
        'error_language_not_supported' || 'error_language_unavailable' =>
          'This language is not available for voice input on this device.',
        'error_busy' || 'error_too_many_requests' =>
          'Voice input is busy. Please wait a moment and try again.',
        _ => 'Voice input stopped unexpectedly. Please try again or type instead.',
      };

  void _fail(String message) {
    final s = _session;
    _session = null;
    s?.onError(message);
    s?.onDone();
  }

  void _end() {
    final s = _session;
    _session = null;
    s?.onDone();
  }

  @override
  Future<void> stop() async {
    final session = _session;
    if (session == null) return;
    try {
      await _stt.stop(); // delivers the final result, then "done"
    } catch (_) {
      _end();
    }
    // Some recognizers never report "done" after a manual stop.
    Timer(const Duration(seconds: 3), () {
      if (identical(_session, session)) _end();
    });
  }

  @override
  Future<void> cancel() async {
    _session = null;
    try {
      await _stt.cancel();
    } catch (_) {}
  }
}
