import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/ai_assistant_service.dart';
import 'package:finanzas_personales/domain/services/nlp_parser.dart';
import 'package:finanzas_personales/presentation/providers/ai_assistant_provider.dart';
import 'package:finanzas_personales/presentation/providers/finance_state_providers.dart';
import 'package:finanzas_personales/presentation/screens/dashboard_screen.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/credit_card_crud_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/nlp_entry_dialog.dart';
import 'package:finanzas_personales/presentation/screens/onboarding_screen.dart';

void main() {
  group('Mobile Layout and NLP Subscription Day Tests', () {
    testWidgets('NlpEntryDialog provides editable recurring day field and updates correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockAccounts = [Account(id: 'acc1', name: 'Nequi')];
      const mockPockets = [Pocket(id: 'poc1', accountId: 'acc1', name: 'Personal', balance: 500000)];
      const mockCards = <CreditCard>[];

      const catalog = NlpCatalog(
        accounts: [NlpTarget(id: 'acc1', aliases: ['nequi'])],
        pockets: [NlpPocketTarget(id: 'poc1', accountId: 'acc1', aliases: ['personal'])],
        cards: [],
      );

      final mockAiService = AiAssistantService(
        functionInvoker: (action, payload) async {
          return {
            'success': true,
            'intent': {
              'intent_type': 'create_recurring',
              'amount': 45000,
              'recurring': {
                'name': 'Netflix',
                'amount': 45000,
                'day_of_month': 15,
                'is_card': false,
              },
            },
          };
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAssistantServiceProvider.overrideWithValue(mockAiService),
            nlpCatalogProvider.overrideWith((ref) => Future.value(catalog)),
            accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NlpEntryDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter subscription phrase
      final phraseField = find.byType(TextField).first;
      await tester.enterText(phraseField, 'suscripción netflix 45000 los 15');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Check preview card and editable field
      expect(find.textContaining('Suscripción Detectada'), findsOneWidget);
      expect(find.byKey(const Key('recurring_day_field')), findsOneWidget);

      // Verify initial day is 15
      final dayField = find.byKey(const Key('recurring_day_field'));
      expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);

      // Edit day to 25
      await tester.enterText(dayField, '25');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Confirm summary reflects day 25
      expect(find.textContaining('Cobro mensual: Día 25'), findsOneWidget);
      expect(find.text('Crear Suscripción'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders mobile title "Finanzas" and compact actions on <600px', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.value([])),
            pocketsProvider.overrideWith((ref) => Future.value([])),
            creditCardsProvider.overrideWith((ref) => Future.value([])),
            activeAlertsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title should be "Finanzas" on mobile
      expect(find.text('Finanzas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CreditCardCrudDialog renders on compact mobile screen (360px) without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creditCardsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreditCardCrudDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Registrar Nueva Tarjeta"
      final registerBtn = find.text('Registrar Nueva Tarjeta');
      expect(registerBtn, findsOneWidget);
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      // Form is displayed with non-truncated labels and vertically stacked
      expect(find.text('Cupo Total'), findsOneWidget);
      expect(find.text('Cupo Disponible'), findsOneWidget);
      expect(find.text('Día de corte'), findsOneWidget);
      expect(find.text('Día de pago'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OnboardingScreen renders with added bank accounts on narrow screen without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Añadir Banco"
      final addBankBtn = find.text('Añadir Banco');
      expect(addBankBtn, findsOneWidget);
      await tester.tap(addBankBtn);
      await tester.pumpAndSettle();

      // Verify account item is rendered cleanly without RenderFlex overflow
      expect(find.text('Bolsillo'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
