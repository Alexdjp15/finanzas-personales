import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/voice_dictation_service.dart';

/// Provides the active instance of [VoiceDictationService].
/// Can be overridden in widget or unit tests with [FakeVoiceDictationService].
final voiceDictationServiceProvider = Provider<VoiceDictationService>((ref) {
  final service = SpeechToTextVoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});

class VoiceDictationNotifier extends Notifier<VoiceDictationState> {
  VoiceDictationService get _service => ref.read(voiceDictationServiceProvider);

  @override
  VoiceDictationState build() {
    return const VoiceDictationState();
  }

  Future<bool> initialize() async {
    final ok = await _service.initialize(
      onStatusChange: (status) {
        state = state.copyWith(
          status: status,
          isListening: status == VoiceDictationStatus.listening,
          isAvailable: _service.isAvailable,
        );
      },
      onError: (err) {
        state = state.copyWith(
          errorMessage: err,
          isListening: false,
          status: _service.status,
        );
      },
    );
    state = state.copyWith(
      isAvailable: ok,
      status: _service.status,
    );
    return ok;
  }

  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    String localeId = 'es_CO',
  }) async {
    state = state.copyWith(
      clearError: true,
      lastWords: '',
    );
    await _service.startListening(
      localeId: localeId,
      onResult: (words, isFinal) {
        state = state.copyWith(
          lastWords: words,
          isListening: !isFinal,
        );
        onResult(words, isFinal);
      },
      onError: (err) {
        state = state.copyWith(
          errorMessage: err,
          isListening: false,
          status: _service.status,
        );
      },
    );
    state = state.copyWith(
      isListening: _service.isListening,
      status: _service.status,
    );
  }

  Future<void> stopListening() async {
    await _service.stopListening();
    state = state.copyWith(
      isListening: false,
      status: VoiceDictationStatus.stopped,
    );
  }

  Future<void> cancelListening() async {
    await _service.cancelListening();
    state = state.copyWith(
      isListening: false,
      status: VoiceDictationStatus.stopped,
    );
  }
}

final voiceDictationProvider =
    NotifierProvider<VoiceDictationNotifier, VoiceDictationState>(
  VoiceDictationNotifier.new,
);
