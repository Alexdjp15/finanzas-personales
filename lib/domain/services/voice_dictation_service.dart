import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Lifecycle status of the speech dictation system.
enum VoiceDictationStatus {
  uninitialized,
  ready,
  listening,
  stopped,
  notAvailable,
  permissionDenied,
  error,
}

/// Immutable state snapshot of the voice dictation service.
class VoiceDictationState {
  const VoiceDictationState({
    this.status = VoiceDictationStatus.uninitialized,
    this.isListening = false,
    this.isAvailable = false,
    this.lastWords = '',
    this.errorMessage,
  });

  final VoiceDictationStatus status;
  final bool isListening;
  final bool isAvailable;
  final String lastWords;
  final String? errorMessage;

  VoiceDictationState copyWith({
    VoiceDictationStatus? status,
    bool? isListening,
    bool? isAvailable,
    String? lastWords,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceDictationState(
      status: status ?? this.status,
      isListening: isListening ?? this.isListening,
      isAvailable: isAvailable ?? this.isAvailable,
      lastWords: lastWords ?? this.lastWords,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Abstract contract for Speech-to-Text dictation.
abstract class VoiceDictationService {
  VoiceDictationStatus get status;
  bool get isAvailable;
  bool get isListening;
  String? get lastError;

  Future<bool> initialize({
    void Function(VoiceDictationStatus status)? onStatusChange,
    void Function(String error)? onError,
  });

  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(String error)? onError,
    String localeId = 'es_CO',
    Duration? listenFor,
    Duration? pauseFor,
  });

  Future<void> stopListening();
  Future<void> cancelListening();
  void dispose();
}

/// Production implementation backed by the `speech_to_text` package.
class SpeechToTextVoiceService implements VoiceDictationService {
  SpeechToTextVoiceService({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  VoiceDictationStatus _status = VoiceDictationStatus.uninitialized;
  String? _lastError;
  void Function(VoiceDictationStatus)? _onStatusChange;
  void Function(String)? _onError;

  @override
  VoiceDictationStatus get status => _status;

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  String? get lastError => _lastError;

  @override
  Future<bool> initialize({
    void Function(VoiceDictationStatus status)? onStatusChange,
    void Function(String error)? onError,
  }) async {
    _onStatusChange = onStatusChange;
    _onError = onError;

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'listening') {
            _updateStatus(VoiceDictationStatus.listening);
          } else if (status == 'notListening' || status == 'done') {
            _updateStatus(VoiceDictationStatus.stopped);
          }
        },
        onError: (SpeechRecognitionError errorNotification) {
          final friendly = _translateError(errorNotification.errorMsg);
          _lastError = friendly;
          if (errorNotification.errorMsg.contains('permission') || errorNotification.permanent) {
            _updateStatus(VoiceDictationStatus.permissionDenied);
          } else {
            _updateStatus(VoiceDictationStatus.error);
          }
          _onError?.call(friendly);
        },
      );

      if (available) {
        _updateStatus(VoiceDictationStatus.ready);
        return true;
      } else {
        _updateStatus(VoiceDictationStatus.notAvailable);
        _lastError = 'El navegador o dispositivo no soporta reconocimiento de voz.';
        _onError?.call(_lastError!);
        return false;
      }
    } catch (e) {
      _lastError = 'Fallo al inicializar el micrófono: $e';
      _updateStatus(VoiceDictationStatus.error);
      _onError?.call(_lastError!);
      return false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(String error)? onError,
    String localeId = 'es_CO',
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (onError != null) _onError = onError;

    if (!_speech.isAvailable) {
      final initOk = await initialize(onError: onError);
      if (!initOk) return;
    }

    // Try resolving best Spanish locale
    String targetLocale = localeId;
    try {
      final systemLocales = await _speech.locales();
      final hasEsCo = systemLocales.any((l) => l.localeId == 'es_CO' || l.localeId == 'es-CO');
      if (!hasEsCo) {
        final anySpanish = systemLocales.firstWhere(
          (l) => l.localeId.toLowerCase().startsWith('es'),
          orElse: () => systemLocales.isNotEmpty ? systemLocales.first : stt.LocaleName(localeId, 'Español'),
        );
        targetLocale = anySpanish.localeId;
      }
    } catch (_) {
      targetLocale = localeId;
    }

    try {
      _updateStatus(VoiceDictationStatus.listening);
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            _updateStatus(VoiceDictationStatus.stopped);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
        ),
        // ignore: deprecated_member_use
        localeId: targetLocale,
      );
    } catch (e) {
      _lastError = 'Error al iniciar escucha: $e';
      _updateStatus(VoiceDictationStatus.error);
      _onError?.call(_lastError!);
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _updateStatus(VoiceDictationStatus.stopped);
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
  }

  @override
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
      _updateStatus(VoiceDictationStatus.stopped);
    } catch (e) {
      debugPrint('Error canceling speech: $e');
    }
  }

  @override
  void dispose() {
    _onStatusChange = null;
    _onError = null;
    _speech.stop();
  }

  void _updateStatus(VoiceDictationStatus s) {
    _status = s;
    _onStatusChange?.call(s);
  }

  String _translateError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission')) {
      return 'Permiso de micrófono denegado. Habilita el acceso en tu navegador.';
    }
    if (lower.contains('no_match') || lower.contains('timeout')) {
      return 'No se detectó voz o se detuvo por silencio.';
    }
    if (lower.contains('network')) {
      return 'Error de red en el servicio de voz.';
    }
    return 'Error en el servicio de voz: $raw';
  }
}

/// In-memory fake implementation designed for reliable unit and widget testing.
class FakeVoiceDictationService implements VoiceDictationService {
  FakeVoiceDictationService({
    bool initialAvailable = true,
    this.initialPermissionDenied = false,
  }) : _available = initialAvailable;

  final bool initialPermissionDenied;
  final bool _available;
  bool _isListening = false;
  VoiceDictationStatus _status = VoiceDictationStatus.uninitialized;
  String? _lastError;
  void Function(VoiceDictationStatus)? _onStatusChange;
  void Function(String)? _onError;
  void Function(String words, bool isFinal)? _activeOnResult;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _isListening;

  @override
  VoiceDictationStatus get status => _status;

  @override
  String? get lastError => _lastError;

  @override
  Future<bool> initialize({
    void Function(VoiceDictationStatus status)? onStatusChange,
    void Function(String error)? onError,
  }) async {
    _onStatusChange = onStatusChange;
    _onError = onError;

    if (initialPermissionDenied) {
      _status = VoiceDictationStatus.permissionDenied;
      _lastError = 'Permiso de micrófono denegado. Habilita el acceso en tu navegador.';
      _onStatusChange?.call(_status);
      _onError?.call(_lastError!);
      return false;
    }

    if (!_available) {
      _status = VoiceDictationStatus.notAvailable;
      _lastError = 'El navegador o dispositivo no soporta reconocimiento de voz.';
      _onStatusChange?.call(_status);
      _onError?.call(_lastError!);
      return false;
    }

    _status = VoiceDictationStatus.ready;
    _onStatusChange?.call(_status);
    return true;
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    void Function(String error)? onError,
    String localeId = 'es_CO',
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (onError != null) _onError = onError;
    _activeOnResult = onResult;

    if (!_available) {
      _status = VoiceDictationStatus.notAvailable;
      _lastError = 'El reconocimiento de voz no está disponible.';
      _onStatusChange?.call(_status);
      _onError?.call(_lastError!);
      return;
    }

    _isListening = true;
    _status = VoiceDictationStatus.listening;
    _onStatusChange?.call(_status);
  }

  /// Helper for tests to simulate speech being recognized.
  void emitWords(String words, {bool isFinal = false}) {
    if (!_isListening && !isFinal) return;
    _activeOnResult?.call(words, isFinal);
    if (isFinal) {
      _isListening = false;
      _status = VoiceDictationStatus.stopped;
      _onStatusChange?.call(_status);
    }
  }

  /// Helper for tests to simulate an error.
  void emitError(String error) {
    _lastError = error;
    _isListening = false;
    _status = VoiceDictationStatus.error;
    _onStatusChange?.call(_status);
    _onError?.call(error);
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _status = VoiceDictationStatus.stopped;
    _onStatusChange?.call(_status);
  }

  @override
  Future<void> cancelListening() async {
    _isListening = false;
    _status = VoiceDictationStatus.stopped;
    _onStatusChange?.call(_status);
  }

  @override
  void dispose() {
    _isListening = false;
    _onStatusChange = null;
    _onError = null;
    _activeOnResult = null;
  }
}
