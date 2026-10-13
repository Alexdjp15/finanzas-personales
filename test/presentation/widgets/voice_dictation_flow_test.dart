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
  const mockAccounts = [
    Account(id: 'a1', name: 'Bancolombia'),
    Account(id: 'a2', name: 'Nequi'),
  ];
  const mockPockets = [
    Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 500000),
    Pocket(id: 'p2', accountId: 'a2', name: 'Graficolor', balance: 750000),
  ];
  const mockCards = [
    CreditCard(
      id: 'c1',
      entity: 'Bancolombia',
      name: 'Mastercard Black',
      franchise: 'Mastercard',
      lastFourDigits: '9805',
      creditLimit: 10000000,
      availableCredit: 8000000,
      cutOffDay: 15,
      paymentDueDay: 30,
    ),
  ];
  const mockCatalog = NlpCatalog(
    accounts: [
      NlpTarget(id: 'a1', aliases: ['bancolombia']),
      NlpTarget(id: 'a2', aliases: ['nequi']),
    ],
    cards: [
      NlpTarget(id: 'c1', aliases: ['bancolombia', 'mastercard']),
    ],
    pockets: [
      NlpPocketTarget(id: 'p1', accountId: 'a1', aliases: ['personal']),
      NlpPocketTarget(id: 'p2', accountId: 'a2', aliases: ['graficolor']),
    ],
  );

  Widget createNlpDialogWrapper({
    required VoiceDictationService voiceService,
    bool startListeningImmediately = false,
  }) {
    return ProviderScope(
      overrides: [
        voiceDictationServiceProvider.overrideWithValue(voiceService),
        nlpCatalogProvider.overrideWith((ref) => Future.value(mockCatalog)),
        accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
        pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
        creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: NlpEntryDialog(
            startListeningImmediately: startListeningImmediately,
          ),
        ),
      ),
    );
  }

  group('Voice Dictation to NLP Flow Tests', () {
    testWidgets('Tapping microphone button activates listening and shows live feedback banner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeVoice = FakeVoiceDictationService(initialAvailable: true);

      await tester.pumpWidget(createNlpDialogWrapper(voiceService: fakeVoice));
      await tester.pumpAndSettle();

      final micFinder = find.byKey(const Key('voice_dictation_button'));
      expect(micFinder, findsOneWidget);
      expect(fakeVoice.isListening, isFalse);
      expect(find.textContaining('Escuchando en vivo'), findsNothing);

      // Tap microphone button to start listening
      await tester.tap(micFinder);
      await tester.pumpAndSettle();

      expect(fakeVoice.isListening, isTrue);
      expect(find.textContaining('Escuchando en vivo'), findsOneWidget);

      // Tap again to stop
      await tester.tap(micFinder);
      await tester.pumpAndSettle();

      expect(fakeVoice.isListening, isFalse);
      expect(find.textContaining('Escuchando en vivo'), findsNothing);
    });

    testWidgets('Spoken speech updates text field and reactively populates parsed confirmation fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeVoice = FakeVoiceDictationService(initialAvailable: true);

      await tester.pumpWidget(createNlpDialogWrapper(voiceService: fakeVoice));
      await tester.pumpAndSettle();

      // Start listening
      await tester.tap(find.byKey(const Key('voice_dictation_button')));
      await tester.pumpAndSettle();

      // 1. Spoken purchase: "compra almuerzo 35000 tc bancolombia"
      fakeVoice.emitWords('compra almuerzo 35000 tc bancolombia', isFinal: true);
      await tester.pumpAndSettle();

      // Phrase input updated
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, 'compra almuerzo 35000 tc bancolombia');

      // Amount field auto-completed to 35000
      expect(find.text('35000'), findsOneWidget);

      // Operation kind is Gasto
      expect(find.text('Gasto'), findsWidgets);

      // Card is pre-selected and pocket is not mandatory for card charges
      expect(find.textContaining('Tarjeta'), findsWidgets);
    });

    testWidgets('Spoken card payment "pago tc bancolombia 150000" triggers isCardPayment mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeVoice = FakeVoiceDictationService(initialAvailable: true);

      await tester.pumpWidget(createNlpDialogWrapper(voiceService: fakeVoice));
      await tester.pumpAndSettle();

      // Start listening
      await tester.tap(find.byKey(const Key('voice_dictation_button')));
      await tester.pumpAndSettle();

      // Emit card payment phrase
      fakeVoice.emitWords('pago tc bancolombia 150000', isFinal: true);
      await tester.pumpAndSettle();

      // Amount field auto-completed to 150000
      expect(find.text('150000'), findsOneWidget);

      // Mode is Abono a TC
      expect(find.text('Abono a TC'), findsWidgets);
      expect(find.textContaining('Abono / Pago de Tarjeta detectado'), findsOneWidget);
    });

    testWidgets('startListeningImmediately activates listening on dialog open', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeVoice = FakeVoiceDictationService(initialAvailable: true);

      await tester.pumpWidget(
        createNlpDialogWrapper(
          voiceService: fakeVoice,
          startListeningImmediately: true,
        ),
      );
      await tester.pumpAndSettle();

      // Microphone should be active immediately
      expect(fakeVoice.isListening, isTrue);
      expect(find.textContaining('Escuchando en vivo'), findsOneWidget);
    });

    testWidgets('Shows informative error banner when mic permission is denied', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeVoice = FakeVoiceDictationService(
        initialAvailable: true,
        initialPermissionDenied: true,
      );

      await tester.pumpWidget(createNlpDialogWrapper(voiceService: fakeVoice));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('voice_dictation_button')));
      await tester.pumpAndSettle();

      expect(fakeVoice.isListening, isFalse);
      expect(find.textContaining('Permiso de micrófono denegado'), findsWidgets);
    });
  });

  group('Dashboard Command Bar Voice Dictation Integration', () {
    testWidgets('Dashboard button "Dictar por Voz" opens NlpEntryDialog with listening active', (WidgetTester tester) async {
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
            home: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Button exists in the Dashboard Command Bar
      final voiceBtn = find.byKey(const Key('dashboard_voice_dictation_button'));
      expect(voiceBtn, findsOneWidget);
      expect(find.text('Dictar por Voz'), findsOneWidget);

      // Tap button
      await tester.tap(voiceBtn);
      await tester.pumpAndSettle();

      // NlpEntryDialog is opened and listening is automatically triggered
      expect(find.byType(NlpEntryDialog), findsOneWidget);
      expect(fakeVoice.isListening, isTrue);
      expect(find.textContaining('Escuchando en vivo'), findsOneWidget);
    });
  });
}
