import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ledger_transaction.dart';
import '../models/models.dart';
import 'nlp_parser.dart';

class AntExpenseItem {
  const AntExpenseItem({
    required this.description,
    required this.amount,
    required this.date,
  });

  factory AntExpenseItem.fromJson(Map<String, dynamic> json) {
    return AntExpenseItem(
      description: json['description']?.toString() ?? 'Gasto sin descripción',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      date: json['date']?.toString() ?? '',
    );
  }

  final String description;
  final int amount;
  final String date;
}

class DuplicateExpenseItem {
  const DuplicateExpenseItem({
    required this.description,
    required this.amount,
    required this.dates,
    required this.note,
  });

  factory DuplicateExpenseItem.fromJson(Map<String, dynamic> json) {
    final rawDates = json['dates'];
    final dates = rawDates is List ? rawDates.map((e) => e.toString()).toList() : <String>[];
    return DuplicateExpenseItem(
      description: json['description']?.toString() ?? 'Transacción duplicada',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      dates: dates,
      note: json['note']?.toString() ?? '',
    );
  }

  final String description;
  final int amount;
  final List<String> dates;
  final String note;
}

class LiquidityLeakItem {
  const LiquidityLeakItem({
    required this.category,
    required this.totalImpact,
    required this.recommendation,
  });

  factory LiquidityLeakItem.fromJson(Map<String, dynamic> json) {
    return LiquidityLeakItem(
      category: json['category']?.toString() ?? 'General',
      totalImpact: (json['total_impact'] as num?)?.toInt() ?? 0,
      recommendation: json['recommendation']?.toString() ?? '',
    );
  }

  final String category;
  final int totalImpact;
  final String recommendation;
}

class ExpenseAuditResult {
  const ExpenseAuditResult({
    required this.totalAnalyzedExpenses,
    required this.antExpensesTotal,
    required this.antExpensesCount,
    required this.antExpensesItems,
    required this.potentialDuplicates,
    required this.liquidityLeaks,
    required this.actionableTips,
    required this.summaryText,
  });

  factory ExpenseAuditResult.fromJson(Map<String, dynamic> json) {
    final rawAnts = json['ant_expenses_items'];
    final antItems = rawAnts is List
        ? rawAnts.whereType<Map<String, dynamic>>().map(AntExpenseItem.fromJson).toList()
        : <AntExpenseItem>[];

    final rawDupes = json['potential_duplicates'];
    final dupeItems = rawDupes is List
        ? rawDupes.whereType<Map<String, dynamic>>().map(DuplicateExpenseItem.fromJson).toList()
        : <DuplicateExpenseItem>[];

    final rawLeaks = json['liquidity_leaks'];
    final leakItems = rawLeaks is List
        ? rawLeaks.whereType<Map<String, dynamic>>().map(LiquidityLeakItem.fromJson).toList()
        : <LiquidityLeakItem>[];

    final rawTips = json['actionable_tips'];
    final tips = rawTips is List ? rawTips.map((e) => e.toString()).toList() : <String>[];

    return ExpenseAuditResult(
      totalAnalyzedExpenses: (json['total_analyzed_expenses'] as num?)?.toInt() ?? 0,
      antExpensesTotal: (json['ant_expenses_total'] as num?)?.toInt() ?? 0,
      antExpensesCount: (json['ant_expenses_count'] as num?)?.toInt() ?? antItems.length,
      antExpensesItems: antItems,
      potentialDuplicates: dupeItems,
      liquidityLeaks: leakItems,
      actionableTips: tips,
      summaryText: json['summary_text']?.toString() ?? '',
    );
  }

  final int totalAnalyzedExpenses;
  final int antExpensesTotal;
  final int antExpensesCount;
  final List<AntExpenseItem> antExpensesItems;
  final List<DuplicateExpenseItem> potentialDuplicates;
  final List<LiquidityLeakItem> liquidityLeaks;
  final List<String> actionableTips;
  final String summaryText;
}

class ParsedReceiptResult {
  const ParsedReceiptResult({
    required this.operation,
    required this.amount,
    required this.bankName,
    this.recipientOrSender,
    this.date,
    this.referenceCode,
    required this.description,
  });

  factory ParsedReceiptResult.fromJson(Map<String, dynamic> json) {
    return ParsedReceiptResult(
      operation: json['operation']?.toString().toLowerCase() == 'income' ? 'income' : 'expense',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      bankName: json['bank_name']?.toString() ?? '',
      recipientOrSender: json['recipient_or_sender']?.toString(),
      date: json['date']?.toString(),
      referenceCode: json['reference_code']?.toString(),
      description: json['description']?.toString() ?? 'Comprobante bancario',
    );
  }

  final String operation; // 'expense' | 'income'
  final int amount;
  final String bankName;
  final String? recipientOrSender;
  final String? date;
  final String? referenceCode;
  final String description;

  bool get isIncome => operation == 'income';
}

/// Service bridging the Flutter client with Google AI Studio (Gemini Flash)
/// via the Supabase Edge Function `finance_ai`.
class AiAssistantService {
  AiAssistantService({
    this.client,
    this.functionInvoker,
  });

  final SupabaseClient? client;
  final Future<Map<String, dynamic>> Function(String action, Map<String, dynamic> payload)? functionInvoker;

  Future<Map<String, dynamic>> _invoke(String action, Map<String, dynamic> payload) async {
    if (functionInvoker != null) {
      return await functionInvoker!(action, payload);
    }

    if (client == null) {
      throw StateError('SupabaseClient o functionInvoker requerido para AiAssistantService');
    }

    final res = await client!.functions.invoke(
      'finance_ai',
      body: {
        'action': action,
        ...payload,
      },
    );

    if (res.status != 200) {
      final err = res.data is Map ? (res.data['error'] ?? 'Error desconocido') : res.data?.toString();
      throw Exception('Edge function error ($action): $err');
    }

    final data = res.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// Parses text via Google AI Studio / Gemini Flash.
  Future<ParsedTransaction?> parseIntentWithAi({
    required String text,
    required NlpCatalog catalog,
    List<Account>? accounts,
    List<CreditCard>? cards,
    List<Pocket>? pockets,
  }) async {
    try {
      final catalogPayload = {
        'accounts': (accounts ?? []).map((a) => {'id': a.id, 'name': a.name}).toList(),
        'cards': (cards ?? [])
            .map((c) => {'id': c.id, 'name': c.name, 'entity': c.entity, 'last_four_digits': c.lastFourDigits})
            .toList(),
        'pockets': (pockets ?? [])
            .map((p) => {'id': p.id, 'name': p.name, 'account_id': p.accountId, 'balance': p.balance})
            .toList(),
      };

      final data = await _invoke('parse_intent', {
        'text': text,
        'catalog': catalogPayload,
      });

      if (data['success'] != true || data['intent'] == null) {
        return null;
      }

      final intentMap = data['intent'] as Map<String, dynamic>;
      final intentType = intentMap['intent_type']?.toString().toLowerCase();

      final amount = (intentMap['amount'] as num?)?.toInt();
      final sourceTypeStr = intentMap['source_type']?.toString().toLowerCase();
      final sourceId = intentMap['source_id']?.toString();
      final pocketId = intentMap['pocket_id']?.toString();
      final description = intentMap['description']?.toString() ?? '';

      final SourceType? sourceType = sourceTypeStr == 'card'
          ? SourceType.card
          : (sourceTypeStr == 'account' ? SourceType.account : null);

      NlpIntent intent;
      TransactionKind kind = TransactionKind.expense;
      bool isCardPayment = false;

      switch (intentType) {
        case 'income':
          kind = TransactionKind.income;
          intent = IncomeIntent(
            amount: amount,
            sourceId: sourceId,
            pocketId: pocketId,
            description: description,
          );
          break;

        case 'transfer':
          intent = TransferIntent(
            amount: amount,
            fromPocketId: pocketId,
            toPocketId: intentMap['to_pocket_id']?.toString(),
            fromPocketName: intentMap['pocket_name']?.toString() ?? '',
            toPocketName: intentMap['to_pocket_name']?.toString() ?? '',
            description: description,
          );
          break;

        case 'card_payment':
          isCardPayment = true;
          intent = CardPaymentIntent(
            amount: amount,
            cardId: intentMap['target_card_id']?.toString() ?? sourceId,
            fromPocketId: pocketId,
          );
          break;

        case 'create_recurring':
          final rec = intentMap['recurring'] as Map<String, dynamic>? ?? {};
          intent = CreateRecurringIntent(
            name: rec['name']?.toString() ?? 'Suscripción',
            amount: (rec['amount'] as num?)?.toInt() ?? amount,
            dayOfMonth: (rec['day_of_month'] as num?)?.toInt() ?? 1,
            sourceName: rec['source_name']?.toString() ?? '',
            sourceId: rec['source_id']?.toString() ?? sourceId,
            pocketId: pocketId,
            isCard: rec['is_card'] == true || sourceType == SourceType.card,
          );
          break;

        case 'create_card':
          final crd = intentMap['card'] as Map<String, dynamic>? ?? {};
          intent = CreateCardIntent(
            name: crd['name']?.toString() ?? 'Tarjeta',
            entity: crd['entity']?.toString() ?? 'Banco',
            creditLimit: (crd['credit_limit'] as num?)?.toInt() ?? amount,
            cutOffDay: (crd['cut_off_day'] as num?)?.toInt() ?? 15,
            paymentDueDay: (crd['payment_due_day'] as num?)?.toInt() ?? 30,
            franchise: crd['franchise']?.toString() ?? 'Visa',
            lastFourDigits: crd['last_four_digits']?.toString() ?? '',
          );
          break;

        case 'create_pocket':
          final pck = intentMap['pocket'] as Map<String, dynamic>? ?? {};
          intent = CreatePocketIntent(
            name: pck['name']?.toString() ?? 'Nuevo Bolsillo',
            accountId: pck['account_id']?.toString() ?? sourceId,
            accountName: pck['account_name']?.toString() ?? '',
            initialBalance: (pck['initial_balance'] as num?)?.toInt() ?? amount,
          );
          break;

        case 'create_account':
          final acc = intentMap['account'] as Map<String, dynamic>? ?? {};
          intent = CreateAccountIntent(
            name: acc['name']?.toString() ?? 'Nueva Cuenta',
            accountNumber: acc['account_number']?.toString() ?? '',
            initialBalance: (acc['initial_balance'] as num?)?.toInt() ?? amount,
          );
          break;

        case 'expense':
        default:
          kind = TransactionKind.expense;
          intent = ExpenseIntent(
            amount: amount,
            sourceType: sourceType,
            sourceId: sourceId,
            pocketId: pocketId,
            description: description,
          );
          break;
      }

      final issues = <ParseIssue>[];
      if (amount == null && intentType != 'create_pocket' && intentType != 'create_account') {
        issues.add(ParseIssue.missingAmount);
      }

      return ParsedTransaction(
        amount: amount,
        kind: kind,
        sourceType: sourceType,
        sourceId: sourceId,
        pocketId: pocketId,
        issues: issues,
        isCardPayment: isCardPayment,
        intent: intent,
        isAiAnalyzed: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Interactive conversational copilot with personal finance context.
  Future<String> chatCopilot({
    required String message,
    List<Map<String, String>>? history,
    required Map<String, dynamic> financialContext,
  }) async {
    final data = await _invoke('chat_copilot', {
      'message': message,
      'history': history ?? [],
      'financial_context': financialContext,
    });

    if (data['success'] == true && data['reply'] != null) {
      return data['reply'] as String;
    }
    throw Exception(data['error'] ?? 'No se pudo obtener respuesta del Copiloto IA');
  }

  /// Audits user's expenses (gastos hormiga, duplicate charges, liquidity leaks).
  Future<ExpenseAuditResult> auditExpenses({
    required List<LedgerTransaction> transactions,
    required List<Pocket> pockets,
    required List<CreditCard> cards,
  }) async {
    final txList = transactions.map((t) {
      return {
        'description': t.description,
        'amount': t.amount,
        'type': t.type.name,
        'date': t.date.toIso8601String(),
      };
    }).toList();

    final pocketList = pockets.map((p) {
      return {
        'name': p.name,
        'balance': p.balance,
      };
    }).toList();

    final cardList = cards.map((c) {
      return {
        'name': c.name,
        'debt': c.debt,
        'limit': c.creditLimit,
      };
    }).toList();

    final data = await _invoke('audit_expenses', {
      'transactions': txList,
      'pockets': pocketList,
      'cards': cardList,
    });

    if (data['success'] == true && data['audit'] != null) {
      return ExpenseAuditResult.fromJson(data['audit'] as Map<String, dynamic>);
    }
    throw Exception(data['error'] ?? 'No se pudo completar la auditoría con IA');
  }

  /// Analyzes an image of a bank receipt or transfer slip (Nequi, Bancolombia, etc.)
  /// without persisting the image anywhere (ephemeral in-memory processing).
  Future<ParsedReceiptResult> parseReceipt({
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    final data = await _invoke('parse_receipt', {
      'image_base64': imageBase64,
      'mime_type': mimeType,
    });

    if (data['success'] == true && data['receipt'] != null) {
      return ParsedReceiptResult.fromJson(data['receipt'] as Map<String, dynamic>);
    }
    throw Exception(data['error'] ?? 'No se pudo procesar el comprobante bancario');
  }

  /// Ingests automated raw text from Apple Pay Shortcuts, Android SMS or Push webhooks.
  Future<Map<String, dynamic>> webhookIngest({
    required String rawText,
    String? userId,
    String? source,
  }) async {
    final payload = <String, dynamic>{
      'raw_text': rawText,
    };
    if (userId != null) payload['user_id'] = userId;
    if (source != null) payload['source'] = source;

    return await _invoke('webhook_ingest', payload);
  }
}
