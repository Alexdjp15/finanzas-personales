import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/domain/services/voice_dictation_service.dart';

void main() {
  group('VoiceDictationService & FakeVoiceDictationService Unit Tests', () {
    test('initializes successfully when available', () async {
      final fake = FakeVoiceDictationService(initialAvailable: true);
      VoiceDictationStatus? latestStatus;

      final ok = await fake.initialize(
        onStatusChange: (status) => latestStatus = status,
      );

      expect(ok, isTrue);
      expect(fake.isAvailable, isTrue);
      expect(fake.status, VoiceDictationStatus.ready);
      expect(latestStatus, VoiceDictationStatus.ready);
      expect(fake.lastError, isNull);
    });

    test('initializes with permissionDenied when mic permissions are blocked', () async {
      final fake = FakeVoiceDictationService(initialPermissionDenied: true);
      String? errorMessage;

      final ok = await fake.initialize(
        onError: (err) => errorMessage = err,
      );

      expect(ok, isFalse);
      expect(fake.status, VoiceDictationStatus.permissionDenied);
      expect(errorMessage, contains('Permiso de micrófono denegado'));
    });

    test('reports notAvailable when hardware or browser speech API is missing', () async {
      final fake = FakeVoiceDictationService(initialAvailable: false);
      String? errorMessage;

      final ok = await fake.initialize(
        onError: (err) => errorMessage = err,
      );

      expect(ok, isFalse);
      expect(fake.status, VoiceDictationStatus.notAvailable);
      expect(errorMessage, contains('no soporta'));
    });

    test('starts listening and emits partial and final words', () async {
      final fake = FakeVoiceDictationService(initialAvailable: true);
      await fake.initialize();

      final emittedWords = <String>[];
      final finalFlags = <bool>[];

      await fake.startListening(
        onResult: (words, isFinal) {
          emittedWords.add(words);
          finalFlags.add(isFinal);
        },
      );

      expect(fake.isListening, isTrue);
      expect(fake.status, VoiceDictationStatus.listening);

      // 1. Partial result
      fake.emitWords('compra almuerzo', isFinal: false);
      expect(emittedWords.last, 'compra almuerzo');
      expect(finalFlags.last, isFalse);
      expect(fake.isListening, isTrue);

      // 2. Final result
      fake.emitWords('compra almuerzo 25000', isFinal: true);
      expect(emittedWords.last, 'compra almuerzo 25000');
      expect(finalFlags.last, isTrue);
      expect(fake.isListening, isFalse);
      expect(fake.status, VoiceDictationStatus.stopped);
    });

    test('stopListening and cancelListening halt active listening cleanly', () async {
      final fake = FakeVoiceDictationService(initialAvailable: true);
      await fake.initialize();

      await fake.startListening(onResult: (_, _) {});
      expect(fake.isListening, isTrue);

      await fake.stopListening();
      expect(fake.isListening, isFalse);
      expect(fake.status, VoiceDictationStatus.stopped);

      await fake.startListening(onResult: (_, _) {});
      expect(fake.isListening, isTrue);

      await fake.cancelListening();
      expect(fake.isListening, isFalse);
      expect(fake.status, VoiceDictationStatus.stopped);
    });

    test('emits error and transitions to error status', () async {
      final fake = FakeVoiceDictationService(initialAvailable: true);
      await fake.initialize();

      String? capturedError;
      await fake.startListening(
        onResult: (_, _) {},
        onError: (err) => capturedError = err,
      );

      fake.emitError('Fallo en conexión');
      expect(fake.status, VoiceDictationStatus.error);
      expect(fake.isListening, isFalse);
      expect(capturedError, 'Fallo en conexión');
    });
  });
}
