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

    test('NlpParser recognizes reminders without amount (variable amount)', () {
      const catalog = NlpCatalog.empty;

      final res1 = NlpParser.parse('recuérdame pagar la energía los 10', catalog);
      expect(res1.intent, isA<CreateRecurringIntent>());
      final intent1 = res1.intent as CreateRecurringIntent;
      expect(intent1.name.toLowerCase(), contains('energia'));
      expect(intent1.amount, equals(0));
      expect(intent1.dayOfMonth, equals(10));
      expect(res1.issues, isEmpty);

      final res2 = NlpParser.parse('recordar recibo del agua cada 15', catalog);
      expect(res2.intent, isA<CreateRecurringIntent>());
      final intent2 = res2.intent as CreateRecurringIntent;
      expect(intent2.name.toLowerCase(), contains('agua'));
      expect(intent2.amount, equals(0));
      expect(intent2.dayOfMonth, equals(15));
      expect(res2.issues, isEmpty);
    });

    testWidgets('NlpEntryDialog displays multiline field, clear button and variable amount badge (\$0 COP)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAiService = AiAssistantService(
        functionInvoker: (action, payload) async {
          return {
            'success': true,
            'intent': {
              'intent_type': 'create_recurring',
              'amount': 0,
              'recurring': {
                'name': 'energía',
                'amount': 0,
                'day_of_month': 10,
                'is_card': false,
              },
            },
          };
        },
      );

      const catalog = NlpCatalog.empty;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAssistantServiceProvider.overrideWithValue(mockAiService),
            nlpCatalogProvider.overrideWith((ref) => Future.value(catalog)),
            accountsProvider.overrideWith((ref) => Future.value([])),
            pocketsProvider.overrideWith((ref) => Future.value([])),
            creditCardsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NlpEntryDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final phraseField = find.byType(TextField).first;
      final textFieldWidget = tester.widget<TextField>(phraseField);
      expect(textFieldWidget.minLines, equals(2));
      expect(textFieldWidget.maxLines, equals(4));
      expect(textFieldWidget.keyboardType, equals(TextInputType.multiline));

      // Enter reminder phrase without amount
      await tester.enterText(phraseField, 'recuérdame pagar la energía los 10');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Clear button is visible
      final clearBtn = find.byKey(const Key('nlp_clear_text_button'));
      expect(clearBtn, findsOneWidget);

      // Variable amount badge is displayed
      expect(find.text('Monto Variable / Por Definir (\$0 COP)'), findsOneWidget);
      expect(find.text('Guardar Recordatorio'), findsOneWidget);

      // Tapping clear button clears text
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nlp_clear_text_button')), findsNothing);
    });

    testWidgets('DashboardScreen renders "⚡ Acciones Rápidas" on mobile and opens bottom sheet with 6 actions', (WidgetTester tester) async {
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

      // Quick actions prominent button is visible
      final quickActionsBtn = find.byKey(const Key('dashboard_quick_actions_button'));
      expect(quickActionsBtn, findsOneWidget);
      expect(find.text('⚡ Acciones Rápidas'), findsOneWidget);

      // Ensure visible and tap to open bottom sheet
      await tester.ensureVisible(quickActionsBtn);
      await tester.tap(quickActionsBtn);
      await tester.pumpAndSettle();

      // Verify all 6 options in bottom sheet
      expect(find.text('Transferir entre Bolsillos'), findsOneWidget);
      expect(find.text('Abonar a Tarjeta (Pagar TC)'), findsOneWidget);
      expect(find.text('Gestionar Cuentas Banco y Bolsillos'), findsOneWidget);
      expect(find.text('Gestionar Tarjetas de Crédito'), findsOneWidget);
      expect(find.text('Suscripciones y Recurrentes'), findsOneWidget);
      expect(find.text('Auditar Gastos Hormiga (IA)'), findsOneWidget);
    });

    testWidgets('DashboardScreen toggles accounts and cards collapsible panels showing compact summaries', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockAccounts = [Account(id: 'a1', name: 'Bancolombia')];
      const mockPockets = [Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 500000)];
      const mockCards = [
        CreditCard(
          id: 'c1',
          entity: 'Nu',
          name: 'Moradita',
          franchise: 'Mastercard',
          lastFourDigits: '1234',
          creditLimit: 2000000,
          availableCredit: 1950000,
          cutOffDay: 15,
          paymentDueDay: 30,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
            activeAlertsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Accounts is expanded by default, showing accounts title and pocket
      expect(find.text('Cuentas Banco y Bolsillos'), findsOneWidget);
      expect(find.text('  • Personal'), findsOneWidget);

      // Cards is collapsed by default, showing compact summary with debt (50,000 COP)
      expect(find.textContaining('Tarjetas (1) · Deuda'), findsOneWidget);
      expect(find.text('Utilización: 3%'), findsNothing); // Inner details hidden

      // Ensure visible and tap accounts toggle to collapse
      final accountsToggle = find.byKey(const Key('dashboard_accounts_toggle_header'));
      await tester.ensureVisible(accountsToggle);
      await tester.tap(accountsToggle);
      await tester.pumpAndSettle();

      // Now accounts shows compact summary
      expect(find.textContaining('Cuentas Banco (1) · 500.000'), findsOneWidget);
      expect(find.text('  • Personal'), findsNothing);

      // Ensure visible and tap cards toggle to expand
      final cardsToggle = find.byKey(const Key('dashboard_cards_toggle_header'));
      await tester.ensureVisible(cardsToggle);
      await tester.tap(cardsToggle);
      await tester.pumpAndSettle();

      // Now cards is expanded and shows "Tarjetas de Crédito" and utilization
      expect(find.text('Tarjetas de Crédito'), findsOneWidget);
      expect(find.text('Utilización: 3%'), findsOneWidget);
    });

    testWidgets('NlpEntryDialog displays clean title, vertical operation/amount on mobile (<480px) and simplified labels', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const mockAccounts = [Account(id: 'a1', name: 'Bancolombia')];
      const mockPockets = [Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 500000)];
      const mockCards = [
        CreditCard(
          id: 'c1',
          entity: 'Nu',
          name: 'Moradita',
          franchise: 'Mastercard',
          lastFourDigits: '1234',
          creditLimit: 2000000,
          availableCredit: 1950000,
          cutOffDay: 15,
          paymentDueDay: 30,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
            nlpCatalogProvider.overrideWith((ref) => Future.value(const NlpCatalog(
              accounts: [NlpTarget(id: 'a1', aliases: ['bancolombia'])],
              cards: [],
              pockets: [NlpPocketTarget(id: 'p1', accountId: 'a1', aliases: ['personal'])],
            ))),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NlpEntryDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Clean Title without truncation
      expect(find.text('Ingreso Rápido'), findsOneWidget);

      // 2. Multiline TextField with hint text and hintMaxLines == 2
      final phraseField = find.byType(TextField).first;
      final textFieldWidget = tester.widget<TextField>(phraseField);
      expect(textFieldWidget.minLines, equals(2));
      expect(textFieldWidget.maxLines, equals(4));
      expect(textFieldWidget.decoration?.hintText, equals('Escribe o dicta tu movimiento...'));
      expect(textFieldWidget.decoration?.hintMaxLines, equals(2));

      // 3. Vertical layout for Operación and Monto COP on mobile
      final opFinder = find.byKey(const Key('dropdown_nlp_op_mode_expense'));
      final amountFinder = find.widgetWithText(TextField, 'Monto COP');
      expect(opFinder, findsOneWidget);
      expect(amountFinder, findsOneWidget);

      final opOffset = tester.getTopLeft(opFinder);
      final amountOffset = tester.getTopLeft(amountFinder);
      // Stacked vertically: amount is below operation
      expect(amountOffset.dy, greaterThan(opOffset.dy + 30));

      // 4. Simplified options in dropdown
      expect(find.text('Gasto'), findsOneWidget);

      // 5. Simplified labels for origin and pocket
      expect(find.text('Cuenta o Tarjeta'), findsOneWidget);
      expect(find.text('Bolsillo'), findsOneWidget);

      // 6. Dialog inset padding on mobile
      final dialogWidget = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialogWidget.insetPadding, equals(const EdgeInsets.symmetric(horizontal: 14, vertical: 20)));

      // 7. No RenderFlex overflows
      expect(tester.takeException(), isNull);
    });
  });
}
