import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/ai_assistant_service.dart';
import 'package:finanzas_personales/domain/services/nlp_parser.dart';
import 'package:finanzas_personales/presentation/providers/ai_assistant_provider.dart';
import 'package:finanzas_personales/presentation/providers/finance_state_providers.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/ai_copilot_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/expense_audit_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/nlp_entry_dialog.dart';
import 'package:finanzas_personales/presentation/utils/image_picker_helper.dart';

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

  group('AiCopilotDialog Widget Tests', () {
    testWidgets('renders initial greeting and quick prompts', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AiCopilotDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sof.IA'), findsOneWidget);
      expect(find.textContaining('¡Hola! Soy Sof.IA, tu asistente financiera personal'), findsOneWidget);
      expect(find.text('¿Cómo está mi patrimonio neto actual?'), findsOneWidget);
    });

    testWidgets('sends message and displays AI reply', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAiService = AiAssistantService(
        functionInvoker: (action, payload) async {
          if (action == 'chat_copilot') {
            return {
              'success': true,
              'reply': 'Tienes un patrimonio sólido de más de 1 millón en activos.',
            };
          }
          return {'success': false};
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAssistantServiceProvider.overrideWithValue(mockAiService),
            accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AiCopilotDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap quick prompt pill
      await tester.tap(find.text('¿Cómo está mi patrimonio neto actual?'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tienes un patrimonio sólido'), findsOneWidget);
    });
  });

  group('ExpenseAuditDialog Widget Tests', () {
    testWidgets('renders audit dialog and displays results', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAiService = AiAssistantService(
        functionInvoker: (action, payload) async {
          if (action == 'audit_expenses') {
            return {
              'success': true,
              'audit': {
                'total_analyzed_expenses': 85000,
                'ant_expenses_total': 18000,
                'ant_expenses_count': 2,
                'ant_expenses_items': [
                  {'description': 'Café panadería', 'amount': 8000, 'date': '2026-10-01'},
                  {'description': 'Snack', 'amount': 10000, 'date': '2026-10-02'},
                ],
                'potential_duplicates': [],
                'liquidity_leaks': [],
                'actionable_tips': [
                  'Pon un límite a los cafés para ahorrar hasta \$50.000 al mes.',
                ],
                'summary_text': 'Se encontraron 2 gastos hormiga.',
              },
            };
          }
          return {'success': false};
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAssistantServiceProvider.overrideWithValue(mockAiService),
            recentTransactionsProvider.overrideWith((ref) => Future.value([])),
            pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
            creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseAuditDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Auditoría de Gastos Hormiga y Fugas'), findsOneWidget);
      expect(find.textContaining('Gastos Hormiga'), findsWidgets);
      expect(find.text('Café panadería'), findsOneWidget);
      expect(find.textContaining('Pon un límite a los cafés'), findsOneWidget);
    });
  });

  group('NlpEntryDialog Creation Intents & AI Badge', () {
    testWidgets('renders CreateRecurringIntent preview card', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockAiService = AiAssistantService(
        functionInvoker: (action, payload) async {
          if (action == 'parse_intent') {
            return {
              'success': true,
              'intent': {
                'intent_type': 'create_recurring',
                'amount': 38000,
                'source_type': 'card',
                'recurring': {
                  'name': 'Spotify Premium',
                  'amount': 38000,
                  'day_of_month': 10,
                  'is_card': true,
                },
              },
            };
          }
          return {'success': false};
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAssistantServiceProvider.overrideWithValue(mockAiService),
            nlpCatalogProvider.overrideWith((ref) => Future.value(mockCatalog)),
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

      final inputFinder = find.byType(TextField).first;
      await tester.enterText(inputFinder, 'crear suscripcion spotify 38000 los 10 con tarjeta');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('✨ Analizado con IA'), findsOneWidget);
      expect(find.textContaining('Suscripción Detectada'), findsOneWidget);
      expect(find.textContaining('Spotify Premium'), findsOneWidget);
      expect(find.textContaining('Cobro mensual: Día 10'), findsOneWidget);
    });

    testWidgets('renders scan receipt button and preloads receipt data without auto-saving', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ImagePickerHelper.customClipboardReader = () async => null;
      addTearDown(() {
        ImagePickerHelper.customClipboardReader = null;
        ImagePickerHelper.customPicker = null;
      });

      final mockAiService = AiAssistantService(
        functionInvoker: (action, payload) async {
          if (action == 'parse_receipt') {
            return {
              'success': true,
              'receipt': {
                'operation': 'income',
                'amount': 25000,
                'bank_name': 'Bancolombia',
                'recipient_or_sender': 'Carlos Vives',
                'description': 'Transferencia recibida de Carlos Vives',
              },
            };
          }
          return {'success': false};
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAssistantServiceProvider.overrideWithValue(mockAiService),
            nlpCatalogProvider.overrideWith((ref) => Future.value(mockCatalog)),
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

      // 1. Check scan receipt button is rendered
      final scanBtn = find.byKey(const Key('nlp_scan_receipt_button'));
      expect(scanBtn, findsOneWidget);

      // 2. Tap scan button -> Opens paste dialog in test environment
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pegar Comprobante / Base64'), findsOneWidget);

      // 3. Enter fake base64 data and tap Analizar
      final pasteInput = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(pasteInput, 'data:image/jpeg;base64,fakeData');
      await tester.tap(find.text('Analizar'));
      await tester.pumpAndSettle();

      // 4. Verify fields preloaded: amount 25000, description, and NOT auto-saved (action button is Confirmar Ingreso)
      expect(find.text('25000'), findsOneWidget);
      expect(find.text('Transferencia recibida de Carlos Vives'), findsOneWidget);
      expect(find.text('Confirmar Ingreso'), findsOneWidget);
    });
  });
}
