import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/nlp_parser.dart';
import 'package:finanzas_personales/domain/services/voice_dictation_service.dart';
import 'package:finanzas_personales/presentation/providers/finance_state_providers.dart';
import 'package:finanzas_personales/presentation/providers/voice_dictation_provider.dart';
import 'package:finanzas_personales/presentation/screens/dashboard_screen.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/nlp_entry_dialog.dart';
import 'package:finanzas_personales/presentation/utils/app_theme.dart';

void main() {
  group('Dashboard URL Query Action Parsing Unit Tests', () {
    test('extracts direct query parameter action=nlp', () {
      final uri = Uri.parse('https://alexdjp15.github.io/finanzas-personales/?action=nlp');
      expect(DashboardScreen.parseActionFromUri(uri), equals('nlp'));
    });

    test('extracts direct query parameter action=voice', () {
      final uri = Uri.parse('https://alexdjp15.github.io/finanzas-personales/?action=voice');
      expect(DashboardScreen.parseActionFromUri(uri), equals('voice'));
    });

    test('extracts hash fragment query parameter action=voice', () {
      final uri = Uri.parse('https://alexdjp15.github.io/finanzas-personales/#/?action=voice');
      expect(DashboardScreen.parseActionFromUri(uri), equals('voice'));
    });

    test('extracts hash fragment query parameter with multiple arguments', () {
      final uri = Uri.parse('https://alexdjp15.github.io/finanzas-personales/#/dashboard?theme=dark&action=nlp');
      expect(DashboardScreen.parseActionFromUri(uri), equals('nlp'));
    });

    test('returns null when action parameter is missing or empty', () {
      expect(DashboardScreen.parseActionFromUri(Uri.parse('https://alexdjp15.github.io/finanzas-personales/')), isNull);
      expect(DashboardScreen.parseActionFromUri(Uri.parse('https://alexdjp15.github.io/finanzas-personales/?action=')), isNull);
      expect(DashboardScreen.parseActionFromUri(Uri.parse('https://alexdjp15.github.io/finanzas-personales/?other=123')), isNull);
    });
  });

  group('Dashboard URL Action Auto-Opening Widget Tests', () {
    const mockAccounts = [Account(id: 'a1', name: 'Bancolombia')];
    const mockPockets = [Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 500000)];
    const mockCards = <CreditCard>[];
    const mockCatalog = NlpCatalog(
      accounts: [NlpTarget(id: 'a1', aliases: ['bancolombia'])],
      cards: [],
      pockets: [NlpPocketTarget(id: 'p1', accountId: 'a1', aliases: ['personal'])],
    );

    testWidgets('Automatically opens NlpEntryDialog when action is "nlp"', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nlpCatalogProvider.overrideWith((ref) => Future.value(mockCatalog)),
            accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
            activeAlertsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.dark),
            home: const DashboardScreen(initialAction: 'nlp'),
          ),
        ),
      );

      // Settle post frame callback to open dialog
      await tester.pumpAndSettle();

      // NlpEntryDialog is automatically opened
      expect(find.byType(NlpEntryDialog), findsOneWidget);
      expect(find.text('Ingreso Rápido'), findsOneWidget);
    });

    testWidgets('Automatically opens NlpEntryDialog with live dictation when action is "voice"', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeVoice = FakeVoiceDictationService(initialAvailable: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceDictationServiceProvider.overrideWithValue(fakeVoice),
            nlpCatalogProvider.overrideWith((ref) => Future.value(mockCatalog)),
            accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
            activeAlertsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.dark),
            home: const DashboardScreen(initialAction: 'voice'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // NlpEntryDialog is opened and voice dictation is triggered immediately
      expect(find.byType(NlpEntryDialog), findsOneWidget);
      expect(fakeVoice.isListening, isTrue);
      expect(find.textContaining('Escuchando en vivo'), findsOneWidget);
    });

    testWidgets('Does not open dialog when initialAction is null or unrecognized', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nlpCatalogProvider.overrideWith((ref) => Future.value(mockCatalog)),
            accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
            activeAlertsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.dark),
            home: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No dialog is displayed
      expect(find.byType(NlpEntryDialog), findsNothing);
    });
  });
}
