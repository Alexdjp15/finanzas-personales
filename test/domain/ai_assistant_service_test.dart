import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/ai_assistant_service.dart';
import 'package:finanzas_personales/domain/services/nlp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiAssistantService', () {
    test('parseIntentWithAi - parses create_recurring intent', () async {
      final service = AiAssistantService(
        functionInvoker: (action, payload) async {
          expect(action, 'parse_intent');
          return {
            'success': true,
            'intent': {
              'intent_type': 'create_recurring',
              'amount': 35000,
              'source_type': 'card',
              'recurring': {
                'name': 'Netflix',
                'amount': 35000,
                'day_of_month': 15,
                'source_name': 'Nu',
                'is_card': true,
              },
            },
          };
        },
      );

      final result = await service.parseIntentWithAi(
        text: 'crear suscripción netflix 35000 los 15 con nu',
        catalog: NlpCatalog.empty,
      );

      expect(result, isNotNull);
      expect(result!.isAiAnalyzed, isTrue);
      expect(result.intent, isA<CreateRecurringIntent>());
      final rec = result.intent as CreateRecurringIntent;
      expect(rec.name, 'Netflix');
      expect(rec.amount, 35000);
      expect(rec.dayOfMonth, 15);
      expect(rec.isCard, isTrue);
    });

    test('parseIntentWithAi - parses create_card intent', () async {
      final service = AiAssistantService(
        functionInvoker: (action, payload) async {
          return {
            'success': true,
            'intent': {
              'intent_type': 'create_card',
              'amount': 2500000,
              'card': {
                'name': 'Tarjeta Oro',
                'entity': 'Bancolombia',
                'credit_limit': 2500000,
                'cut_off_day': 12,
                'payment_due_day': 2,
                'franchise': 'Mastercard',
                'last_four_digits': '4321',
              },
            },
          };
        },
      );

      final result = await service.parseIntentWithAi(
        text: 'nueva tarjeta de crédito bancolombia cupo 2500000 corte 12 pago 2',
        catalog: NlpCatalog.empty,
      );

      expect(result, isNotNull);
      expect(result!.intent, isA<CreateCardIntent>());
      final card = result.intent as CreateCardIntent;
      expect(card.name, 'Tarjeta Oro');
      expect(card.entity, 'Bancolombia');
      expect(card.creditLimit, 2500000);
      expect(card.cutOffDay, 12);
      expect(card.paymentDueDay, 2);
      expect(card.franchise, 'Mastercard');
      expect(card.lastFourDigits, '4321');
    });

    test('parseIntentWithAi - parses create_pocket and create_account', () async {
      final service = AiAssistantService(
        functionInvoker: (action, payload) async {
          return {
            'success': true,
            'intent': {
              'intent_type': 'create_pocket',
              'amount': 500000,
              'pocket': {
                'name': 'Vacaciones',
                'account_name': 'Bancolombia',
                'initial_balance': 500000,
              },
            },
          };
        },
      );

      final result = await service.parseIntentWithAi(
        text: 'crear bolsillo vacaciones con 500000 en bancolombia',
        catalog: NlpCatalog.empty,
      );

      expect(result, isNotNull);
      expect(result!.intent, isA<CreatePocketIntent>());
      final pck = result.intent as CreatePocketIntent;
      expect(pck.name, 'Vacaciones');
      expect(pck.initialBalance, 500000);
      expect(pck.accountName, 'Bancolombia');
    });

    test('parseIntentWithAi - parses slang expense with "lucas"', () async {
      final service = AiAssistantService(
        functionInvoker: (action, payload) async {
          return {
            'success': true,
            'intent': {
              'intent_type': 'expense',
              'amount': 45000,
              'source_type': 'account',
              'source_id': 'acc-1',
              'description': 'tiendita',
            },
          };
        },
      );

      final result = await service.parseIntentWithAi(
        text: 'me gasté 45 lucas en la tiendita',
        catalog: NlpCatalog.empty,
      );

      expect(result, isNotNull);
      expect(result!.amount, 45000);
      expect(result.sourceType, SourceType.account);
      expect(result.intent, isA<ExpenseIntent>());
      expect((result.intent as ExpenseIntent).description, 'tiendita');
    });

    test('parseIntentWithAi - returns null on failure or error', () async {
      final service = AiAssistantService(
        functionInvoker: (action, payload) async {
          return {'success': false, 'error': 'No response'};
        },
      );

      final result = await service.parseIntentWithAi(
        text: 'algo incomprensible',
        catalog: NlpCatalog.empty,
      );

      expect(result, isNull);
    });

    test('chatCopilot - returns reply from AI studio', () async {
      final service = AiAssistantService(
        functionInvoker: (action, payload) async {
          expect(action, 'chat_copilot');
          expect(payload['message'], '¿Cómo reduzco mis gastos?');
          return {
            'success': true,
            'reply': 'Te recomiendo clasificar tus compras impulsivas y fijar topes mensuales.',
          };
        },
      );

      final reply = await service.chatCopilot(
        message: '¿Cómo reduzco mis gastos?',
        financialContext: {'net_worth': 5000000},
      );

      expect(reply, contains('topes mensuales'));
    });

    test('auditExpenses - parses audit results correctly', () async {
      final service = AiAssistantService(
        functionInvoker: (action, payload) async {
          expect(action, 'audit_expenses');
          return {
            'success': true,
            'audit': {
              'total_analyzed_expenses': 150000,
              'ant_expenses_total': 32000,
              'ant_expenses_count': 3,
              'ant_expenses_items': [
                {'description': 'Café panadería', 'amount': 6000, 'date': '2026-10-01'},
                {'description': 'Snack oficina', 'amount': 12000, 'date': '2026-10-02'},
                {'description': 'Gaseosa', 'amount': 14000, 'date': '2026-10-03'},
              ],
              'potential_duplicates': [
                {
                  'description': 'Domicilio almuerzo',
                  'amount': 28000,
                  'dates': ['2026-10-05', '2026-10-05'],
                  'note': 'Mismo monto el mismo día',
                }
              ],
              'liquidity_leaks': [
                {
                  'category': 'Suscripciones olvidadas',
                  'total_impact': 45000,
                  'recommendation': 'Revisa cargos automáticos en streaming que no utilices',
                }
              ],
              'actionable_tips': [
                'Empaca snacks caseros para recortar gastos hormiga.',
              ],
              'summary_text': 'Identificamos 3 gastos hormiga y 1 posible duplicado.',
            },
          };
        },
      );

      final result = await service.auditExpenses(
        transactions: [],
        pockets: [],
        cards: [],
      );

      expect(result.totalAnalyzedExpenses, 150000);
      expect(result.antExpensesTotal, 32000);
      expect(result.antExpensesCount, 3);
      expect(result.antExpensesItems.length, 3);
      expect(result.antExpensesItems.first.description, 'Café panadería');
      expect(result.potentialDuplicates.length, 1);
      expect(result.potentialDuplicates.first.dates.length, 2);
      expect(result.liquidityLeaks.length, 1);
      expect(result.actionableTips.length, 1);
      expect(result.summaryText, contains('Identificamos 3 gastos hormiga'));
    });
  });

  group('NlpParser Hybrid Engine', () {
    test('isLocalMatch correctly detects slang and creations', () {
      // Local matches (simple numbers, straightforward actions)
      expect(NlpParser.isLocalMatch('almorce 25000 nequi'), isTrue);
      expect(NlpParser.isLocalMatch('ingreso 500000 bancolombia'), isTrue);
      expect(NlpParser.isLocalMatch('pago tc 120000'), isTrue);

      // Slang should delegate to AI
      expect(NlpParser.isLocalMatch('me gaste 30 lucas en el mercado'), isFalse);
      expect(NlpParser.isLocalMatch('pague 50 barras por el servicio'), isFalse);
      expect(NlpParser.isLocalMatch('le meti 2 palos a la tarjeta'), isFalse);
      expect(NlpParser.isLocalMatch('mensualidad gimnasio 80000'), isFalse);

      // Entity creations should delegate to AI
      expect(NlpParser.isLocalMatch('crear suscripcion netflix 35000'), isFalse);
      expect(NlpParser.isLocalMatch('nueva tarjeta nu cupo 3000000'), isFalse);
      expect(NlpParser.isLocalMatch('crear bolsillo ahorro'), isFalse);
      expect(NlpParser.isLocalMatch('nueva cuenta daviplata'), isFalse);
    });

    test('parseHybrid delegates to AI when not local match', () async {
      final mockService = AiAssistantService(
        functionInvoker: (action, payload) async {
          return {
            'success': true,
            'intent': {
              'intent_type': 'expense',
              'amount': 30000,
              'source_type': 'account',
              'source_id': 'acc-1',
              'description': 'mercado',
            },
          };
        },
      );

      final result = await NlpParser.parseHybrid(
        input: 'me gaste 30 lucas en el mercado',
        catalog: const NlpCatalog(accounts: [NlpTarget(id: 'acc-1', aliases: ['nequi'])], cards: [], pockets: []),
        aiService: mockService,
      );

      expect(result.isAiAnalyzed, isTrue);
      expect(result.amount, 30000);
      expect(result.intent, isA<ExpenseIntent>());
    });

    test('parseHybrid resolves locally when local match is confident', () async {
      bool aiInvoked = false;
      final mockService = AiAssistantService(
        functionInvoker: (action, payload) async {
          aiInvoked = true;
          return {'success': false};
        },
      );

      const catalog = NlpCatalog(
        accounts: [NlpTarget(id: 'acc-1', aliases: ['nequi'])],
        cards: [],
        pockets: [NlpPocketTarget(id: 'p-1', accountId: 'acc-1', aliases: ['almuerzo'])],
      );

      final result = await NlpParser.parseHybrid(
        input: 'almorce 25000 nequi almuerzo',
        catalog: catalog,
        aiService: mockService,
      );

      expect(aiInvoked, isFalse);
      expect(result.isAiAnalyzed, isFalse);
      expect(result.amount, 25000);
      expect(result.sourceId, 'acc-1');
      expect(result.pocketId, 'p-1');
    });

    test('parseReceipt invokes Edge function with image_base64 and returns ParsedReceiptResult', () async {
      final mockService = AiAssistantService(
        functionInvoker: (action, payload) async {
          expect(action, 'parse_receipt');
          expect(payload['image_base64'], 'fake_base64_data');
          expect(payload['mime_type'], 'image/png');
          return {
            'success': true,
            'receipt': {
              'operation': 'income',
              'amount': 45000,
              'bank_name': 'Nequi',
              'recipient_or_sender': 'Carlos Vives',
              'date': '2026-10-14',
              'reference_code': 'M12345678',
              'description': 'Plata recibida de Carlos Vives',
            },
          };
        },
      );

      final result = await mockService.parseReceipt(
        imageBase64: 'fake_base64_data',
        mimeType: 'image/png',
      );

      expect(result.operation, 'income');
      expect(result.isIncome, isTrue);
      expect(result.amount, 45000);
      expect(result.bankName, 'Nequi');
      expect(result.recipientOrSender, 'Carlos Vives');
      expect(result.date, '2026-10-14');
      expect(result.referenceCode, 'M12345678');
      expect(result.description, 'Plata recibida de Carlos Vives');
    });

    test('webhookIngest invokes Edge function with rawText, userId, and source', () async {
      final mockService = AiAssistantService(
        functionInvoker: (action, payload) async {
          expect(action, 'webhook_ingest');
          expect(payload['raw_text'], 'Compra por \$25.000 en Éxito');
          expect(payload['user_id'], 'usr-123');
          expect(payload['source'], 'apple_pay');
          return {
            'success': true,
            'status': 'ingested',
            'parsed_intent': {
              'intent_type': 'expense',
              'amount': 25000,
              'description': 'Éxito',
            },
          };
        },
      );

      final result = await mockService.webhookIngest(
        rawText: 'Compra por \$25.000 en Éxito',
        userId: 'usr-123',
        source: 'apple_pay',
      );

      expect(result['success'], isTrue);
      expect(result['status'], 'ingested');
      expect(result['parsed_intent']['amount'], 25000);
    });

    test('parseIntentWithAi sends available_accounts and available_pockets and maps bank_account/pocket/note', () async {
      final mockService = AiAssistantService(
        functionInvoker: (action, payload) async {
          expect(action, 'parse_intent');
          expect(payload['available_accounts'], isA<List>());
          expect(payload['available_pockets'], isA<List>());
          final accs = payload['available_accounts'] as List;
          expect(accs.any((a) => a['id'] == 'acc-nequi'), isTrue);
          final pcks = payload['available_pockets'] as List;
          expect(pcks.any((p) => p['id'] == 'pck-personal'), isTrue);

          return {
            'success': true,
            'intent': {
              'operation': 'expense',
              'amount': 15000,
              'bank_account': 'Nequi',
              'source_id': 'acc-nequi',
              'pocket': 'Personal',
              'pocket_id': 'pck-personal',
              'note': 'Almuerzo',
            },
          };
        },
      );

      final result = await mockService.parseIntentWithAi(
        text: 'me gasté 15 mil en almuerzo desde nequi bolsillo personal',
        catalog: NlpCatalog.empty,
        accounts: const [Account(id: 'acc-nequi', name: 'Nequi')],
        pockets: const [Pocket(id: 'pck-personal', accountId: 'acc-nequi', name: 'Personal', balance: 0)],
      );

      expect(result, isNotNull);
      expect(result!.amount, 15000);
      expect(result.sourceId, 'acc-nequi');
      expect(result.pocketId, 'pck-personal');
      expect(result.intent, isA<ExpenseIntent>());
      expect((result.intent as ExpenseIntent).description, 'Almuerzo');
    });

    test('parseReceipt passes available_accounts and available_pockets with image/jpeg mimeType', () async {
      final mockService = AiAssistantService(
        functionInvoker: (action, payload) async {
          expect(action, 'parse_receipt');
          expect(payload['mime_type'], 'image/jpeg');
          expect(payload['available_accounts'], isNotNull);
          expect(payload['available_pockets'], isNotNull);
          return {
            'success': true,
            'receipt': {
              'operation': 'expense',
              'amount': 15000,
              'bank_name': 'Nequi',
              'description': 'Envío Nequi Almuerzo',
            },
          };
        },
      );

      final result = await mockService.parseReceipt(
        imageBase64: 'fake_jpeg_base64',
        mimeType: 'image/jpeg',
        availableAccounts: const [Account(id: 'acc-1', name: 'Nequi')],
        availablePockets: const [Pocket(id: 'pck-1', accountId: 'acc-1', name: 'Personal', balance: 0)],
      );

      expect(result.amount, 15000);
      expect(result.bankName, 'Nequi');
      expect(result.isIncome, isFalse);
    });
  });
}
