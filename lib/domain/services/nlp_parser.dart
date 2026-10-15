import '../models/models.dart';
import 'ai_assistant_service.dart';

enum TransactionKind { income, expense }

enum SourceType { account, card }

enum ParseIssue { missingAmount, unknownSource, ambiguousSource, ambiguousPocket, incomeToCard }

class NlpTarget {
  const NlpTarget({required this.id, required this.aliases});

  final String id;
  final List<String> aliases;
}

class NlpPocketTarget extends NlpTarget {
  const NlpPocketTarget({required super.id, required this.accountId, required super.aliases});

  final String accountId;
}

class NlpCatalog {
  const NlpCatalog({required this.accounts, required this.cards, required this.pockets});

  static const empty = NlpCatalog(accounts: [], cards: [], pockets: []);

  final List<NlpTarget> accounts;
  final List<NlpTarget> cards;
  final List<NlpPocketTarget> pockets;
}

// --- Typed Intent Hierarchy ---
sealed class NlpIntent {
  const NlpIntent();
}

class ExpenseIntent extends NlpIntent {
  const ExpenseIntent({
    this.amount,
    this.sourceType,
    this.sourceId,
    this.pocketId,
    this.description = '',
  });

  final int? amount;
  final SourceType? sourceType;
  final String? sourceId;
  final String? pocketId;
  final String description;
}

class IncomeIntent extends NlpIntent {
  const IncomeIntent({
    this.amount,
    this.sourceId,
    this.pocketId,
    this.description = '',
  });

  final int? amount;
  final String? sourceId;
  final String? pocketId;
  final String description;
}

class TransferIntent extends NlpIntent {
  const TransferIntent({
    this.amount,
    this.fromPocketId,
    this.toPocketId,
    this.fromPocketName = '',
    this.toPocketName = '',
    this.description = '',
  });

  final int? amount;
  final String? fromPocketId;
  final String? toPocketId;
  final String fromPocketName;
  final String toPocketName;
  final String description;
}

class CardPaymentIntent extends NlpIntent {
  const CardPaymentIntent({
    this.amount,
    this.cardId,
    this.fromPocketId,
  });

  final int? amount;
  final String? cardId;
  final String? fromPocketId;
}

class CreatePocketIntent extends NlpIntent {
  const CreatePocketIntent({
    required this.name,
    this.accountId,
    this.accountName = '',
    this.initialBalance,
  });

  final String name;
  final String? accountId;
  final String accountName;
  final int? initialBalance;
}

class CreateAccountIntent extends NlpIntent {
  const CreateAccountIntent({
    required this.name,
    this.accountNumber = '',
    this.initialBalance,
  });

  final String name;
  final String accountNumber;
  final int? initialBalance;
}

class CreateCardIntent extends NlpIntent {
  const CreateCardIntent({
    required this.name,
    this.entity = '',
    this.creditLimit,
    this.cutOffDay,
    this.paymentDueDay,
    this.franchise = 'Visa',
    this.lastFourDigits = '',
  });

  final String name;
  final String entity;
  final int? creditLimit;
  final int? cutOffDay;
  final int? paymentDueDay;
  final String franchise;
  final String lastFourDigits;
}

class CreateRecurringIntent extends NlpIntent {
  const CreateRecurringIntent({
    required this.name,
    this.amount,
    this.dayOfMonth,
    this.sourceName = '',
    this.sourceId,
    this.pocketId,
    this.isCard = false,
  });

  final String name;
  final int? amount;
  final int? dayOfMonth;
  final String sourceName;
  final String? sourceId;
  final String? pocketId;
  final bool isCard;
}

class ParsedTransaction {
  const ParsedTransaction({
    required this.amount,
    required this.kind,
    required this.sourceType,
    required this.sourceId,
    required this.pocketId,
    required this.issues,
    this.isCardPayment = false,
    this.intent,
    this.isAiAnalyzed = false,
  });

  final int? amount;
  final TransactionKind kind;
  final SourceType? sourceType;
  final String? sourceId;
  final String? pocketId;
  final bool isCardPayment;

  /// Anything listed here must be fixed by the user in the confirmation screen.
  final List<ParseIssue> issues;

  final NlpIntent? intent;
  final bool isAiAnalyzed;

  ParsedTransaction copyWith({
    int? amount,
    TransactionKind? kind,
    SourceType? sourceType,
    String? sourceId,
    String? pocketId,
    bool? isCardPayment,
    List<ParseIssue>? issues,
    NlpIntent? intent,
    bool? isAiAnalyzed,
  }) {
    return ParsedTransaction(
      amount: amount ?? this.amount,
      kind: kind ?? this.kind,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      pocketId: pocketId ?? this.pocketId,
      issues: issues ?? this.issues,
      isCardPayment: isCardPayment ?? this.isCardPayment,
      intent: intent ?? this.intent,
      isAiAnalyzed: isAiAnalyzed ?? this.isAiAnalyzed,
    );
  }
}

/// Deterministic, RegEx based parser (no external NLP dependency).
class NlpParser {
  const NlpParser._();

  static final _amountPattern = RegExp(r'(?<![\d.,])(\d{1,3}(?:[.,]\d{3})+|\d+)(?![\d])');
  static final _incomePattern = RegExp(
    r'(?<![a-z])(ingresaron|ingreso|ingrese|recibi|recibido|me\s+pagaron|consignaron|me\s+consignaron|me\s+cayo|quincena|prima|me\s+entro|abono\s+de|me\s+transfirieron|te\s+transfirieron|recibiste|te\s+llego|te\s+llegó|te\s+enviaron|me\s+enviaron|abono\s+a\s+tu\s+cuenta|recepcion\s+de\s+transferencia|recepción\s+de\s+transferencia|consignacion\s+recibida|consignación\s+recibida)(?![a-z])',
  );
  static final _incomePriorityPattern = RegExp(
    r'\b(?:me\s+transfirieron|te\s+transfirieron|recibiste|recibi|recibí|recibido|te\s+llego|te\s+llegó|te\s+enviaron|me\s+enviaron|abono\s+a\s+tu\s+cuenta|recepcion\s+de\s+transferencia|recepción\s+de\s+transferencia|consignacion\s+recibida|consignación\s+recibida|me\s+consignaron|consignaron|me\s+pagaron|me\s+cayo|me\s+cayó|quincena|prima|me\s+entro|me\s+entró|ingresaron|ingreso|ingrese|ingresé)\b',
    caseSensitive: false,
  );
  static final _cardPaymentActionPattern = RegExp(
    r'(?<![a-z])(pago\s+tc|pagar\s+tc|abono\s+tc|abonar\s+tc|pago\s+tarjeta|pagar\s+tarjeta|abono\s+tarjeta|abonar\s+tarjeta|pago\s+de\s+tc|abono\s+de\s+tc|abone\s+a\s+la\s+tarjeta|le\s+meti\s+a\s+la\s+tarjeta|pague\s+la\s+tarjeta|abone\s+tc|pague\s+tc|le\s+meti\s+.*tarjeta|abone\s+.*tarjeta|pague\s+.*tarjeta)(?![a-z])',
  );
  static final _cardPaymentWordPattern = RegExp(r'(?<![a-z])(pago|pagar|abono|abonar)(?![a-z])');
  static final _cardHintPattern = RegExp(r'(?<![a-z])(tarjeta\s+de\s+credito|tarjeta|tc|credito)(?![a-z])');
  static final _accountHintPattern = RegExp(
    r'(?<![a-z])(cuenta|cuenta\s+de\s+ahorros|cuenta\s+corriente|ahorros|cta)(?![a-z])',
  );

  static final _createPocketPattern = RegExp(r'\b(?:crear|crea|nuevo|nueva)\s+bolsillo\b', caseSensitive: false);
  static final _createAccountPattern = RegExp(r'\b(?:crear|crea|nueva|nuevo)\s+cuenta\b', caseSensitive: false);
  static final _createCardPattern = RegExp(r'\b(?:crear|crea|nueva|nuevo)\s+(?:tarjeta(?:\s+de\s+credito)?|tc)\b', caseSensitive: false);
  static final _createRecurringPattern = RegExp(
    r'\b(?:crear|crea|nueva|nuevo|agrega|agregar|anade|añadir)?\s*(?:suscripcion|suscripción|recurrente|pago\s+recurrente)\b|\b(?:recuerdame|recuérdame|recordar)\s+(?:a\s+)?(?:pagar\s+)?(?:el\s+|la\s+|los\s+|mi\s+)?(?:recibo|factura|servicio|pago|arriendo|energia|energía|agua|luz|gas|internet)\b|\b(?:recuerdame|recuérdame|recordar)\s+pagar\b|\b(?:factura|recibo)\s+(?:de|del)\b',
    caseSensitive: false,
  );
  static final _transferPattern = RegExp(r'\b(?:transferi|transferir|pase|pasar|movi|mover|traslade|trasladar)\b', caseSensitive: false);
  static final _slangOrComplexPattern = RegExp(
    r'\b(?:lucas?|barras?|palos?|mensualidad|cobro\s+fijo|los\s+\d{1,2}\s+de\s+cada\s+mes|cada\s+\d{1,2})\b',
    caseSensitive: false,
  );

  /// Checks if the input phrase can be handled purely and unambiguously by local Dart logic.
  /// If it contains Colombian slang ("lucas", "palos", "cobro fijo") or entity creation intents,
  /// returns false so the hybrid engine prioritizes the Gemini Flash AI Edge function.
  static bool isLocalMatch(String input) {
    final text = _normalize(input);
    if (_slangOrComplexPattern.hasMatch(text)) {
      return false;
    }
    if (_createPocketPattern.hasMatch(text) ||
        _createAccountPattern.hasMatch(text) ||
        _createCardPattern.hasMatch(text) ||
        _createRecurringPattern.hasMatch(text)) {
      return false;
    }
    return RegExp(r'\d+').hasMatch(text);
  }

  /// Hybrid parsing: if local match is confident and without missing data, returns local result.
  /// Otherwise, delegates to Google AI Studio / Gemini Flash via [AiAssistantService].
  static Future<ParsedTransaction> parseHybrid({
    required String input,
    required NlpCatalog catalog,
    required AiAssistantService aiService,
    List<Account>? accounts,
    List<CreditCard>? cards,
    List<Pocket>? pockets,
  }) async {
    final localResult = parse(input, catalog);
    final isSimpleLocal = isLocalMatch(input) && localResult.issues.isEmpty;

    if (isSimpleLocal) {
      return localResult;
    }

    try {
      final aiResult = await aiService.parseIntentWithAi(
        text: input,
        catalog: catalog,
        accounts: accounts,
        cards: cards,
        pockets: pockets,
      );
      if (aiResult != null) {
        return aiResult;
      }
    } catch (_) {
      // Fallback on network/service failure to local deterministic parse
    }

    return localResult;
  }

  static ParsedTransaction parse(
    String input,
    NlpCatalog catalog, {
    List<Account>? availableAccounts,
    List<Pocket>? availablePockets,
  }) {
    NlpCatalog effectiveCatalog = catalog;
    if ((availableAccounts != null && availableAccounts.isNotEmpty) ||
        (availablePockets != null && availablePockets.isNotEmpty)) {
      final accTargets = [...catalog.accounts];
      if (availableAccounts != null) {
        for (final a in availableAccounts) {
          if (!accTargets.any((t) => t.id == a.id)) {
            accTargets.add(NlpTarget(id: a.id, aliases: [a.name.toLowerCase()]));
          }
        }
      }
      final pocketTargets = [...catalog.pockets];
      if (availablePockets != null) {
        for (final p in availablePockets) {
          if (!pocketTargets.any((t) => t.id == p.id)) {
            pocketTargets.add(NlpPocketTarget(
              id: p.id,
              accountId: p.accountId,
              aliases: [p.name.toLowerCase()],
            ));
          }
        }
      }
      effectiveCatalog = NlpCatalog(
        accounts: accTargets,
        cards: catalog.cards,
        pockets: pocketTargets,
      );
    }

    final text = _normalize(input);
    final issues = <ParseIssue>[];

    final amount = _extractAmount(text);

    // 1. Check entity creation intents first
    if (_createPocketPattern.hasMatch(text)) {
      final intent = _parseCreatePocket(text, effectiveCatalog, amount);
      return ParsedTransaction(
        amount: intent.initialBalance,
        kind: TransactionKind.expense,
        sourceType: SourceType.account,
        sourceId: intent.accountId,
        pocketId: null,
        issues: issues,
        intent: intent,
      );
    }

    if (_createAccountPattern.hasMatch(text)) {
      final intent = _parseCreateAccount(text, amount);
      return ParsedTransaction(
        amount: intent.initialBalance,
        kind: TransactionKind.income,
        sourceType: SourceType.account,
        sourceId: null,
        pocketId: null,
        issues: issues,
        intent: intent,
      );
    }

    if (_createCardPattern.hasMatch(text)) {
      final intent = _parseCreateCard(text, amount);
      return ParsedTransaction(
        amount: intent.creditLimit,
        kind: TransactionKind.expense,
        sourceType: SourceType.card,
        sourceId: null,
        pocketId: null,
        issues: issues,
        intent: intent,
      );
    }

    if (_createRecurringPattern.hasMatch(text)) {
      final intent = _parseCreateRecurring(text, effectiveCatalog, amount);
      return ParsedTransaction(
        amount: intent.amount,
        kind: TransactionKind.expense,
        sourceType: intent.isCard ? SourceType.card : SourceType.account,
        sourceId: intent.sourceId,
        pocketId: intent.pocketId,
        issues: issues,
        intent: intent,
      );
    }

    // 2. Check transfer intent (internal pocket transfers, ignored if it is an explicit incoming transfer/income)
    final isExplicitIncome = _incomePriorityPattern.hasMatch(text);

    if (!isExplicitIncome && _transferPattern.hasMatch(text) && (text.contains(' de ') || text.contains(' desde '))) {
      final intent = _parseTransfer(text, effectiveCatalog, amount);
      if (amount == null) issues.add(ParseIssue.missingAmount);
      return ParsedTransaction(
        amount: amount,
        kind: TransactionKind.expense,
        sourceType: SourceType.account,
        sourceId: null,
        pocketId: intent.fromPocketId,
        issues: issues,
        intent: intent,
      );
    }

    // 3. Regular transaction parsing (Expense, Income, CardPayment)
    if (amount == null) issues.add(ParseIssue.missingAmount);

    final expandedAccounts = _expandAccountTargets(effectiveCatalog.accounts);
    final expandedCards = _expandCardTargets(effectiveCatalog.cards);

    final accountMatch = _bestMatch(text, expandedAccounts);
    final cardMatch = _bestMatch(text, expandedCards);

    SourceType? sourceType;
    String? sourceId;
    if (accountMatch.ambiguous || cardMatch.ambiguous) {
      issues.add(ParseIssue.ambiguousSource);
    } else if (accountMatch.id != null && cardMatch.id != null) {
      if (_cardHintPattern.hasMatch(text) && !_accountHintPattern.hasMatch(text)) {
        sourceType = SourceType.card;
        sourceId = cardMatch.id;
      } else if (_accountHintPattern.hasMatch(text) && !_cardHintPattern.hasMatch(text)) {
        sourceType = SourceType.account;
        sourceId = accountMatch.id;
      } else if (cardMatch.length > accountMatch.length) {
        sourceType = SourceType.card;
        sourceId = cardMatch.id;
      } else if (accountMatch.length > cardMatch.length) {
        sourceType = SourceType.account;
        sourceId = accountMatch.id;
      } else if (accountMatch.matchedAlias == cardMatch.matchedAlias) {
        // Both matched the same word (e.g. "bancolombia") without differentiating hint -> account wins
        sourceType = SourceType.account;
        sourceId = accountMatch.id;
      } else {
        issues.add(ParseIssue.ambiguousSource);
      }
    } else if (cardMatch.id != null) {
      sourceType = SourceType.card;
      sourceId = cardMatch.id;
    } else if (accountMatch.id != null) {
      sourceType = SourceType.account;
      sourceId = accountMatch.id;
    } else {
      // Unspecified source: auto-select primary account if available
      if (effectiveCatalog.accounts.isNotEmpty) {
        sourceType = SourceType.account;
        sourceId = effectiveCatalog.accounts.first.id;
      } else {
        issues.add(ParseIssue.unknownSource);
      }
    }

    // Determine if it is a card payment (Abono a TC)
    final isExplicitCardPayment = _cardPaymentActionPattern.hasMatch(text);
    final isCardWordPayment = sourceType == SourceType.card && _cardPaymentWordPattern.hasMatch(text);
    final isCardPayment = isExplicitCardPayment || isCardWordPayment;

    TransactionKind kind;
    if (isCardPayment) {
      kind = TransactionKind.expense; // Pays from account, restores credit
    } else if (isExplicitIncome || _incomePattern.hasMatch(text)) {
      kind = TransactionKind.income;
    } else {
      kind = TransactionKind.expense;
    }

    if (kind == TransactionKind.income && sourceType == SourceType.card && !isCardPayment) {
      issues.add(ParseIssue.incomeToCard);
    }

    // Pocket resolution:
    // If it's a normal card charge, card expense doesn't need or restrict pockets
    // If it's card payment or account movement, resolve pocket from catalog
    String? pocketId;
    _Match pocketMatch = const _Match(null, false, 0, null);
    if (sourceType == SourceType.card && !isCardPayment) {
      // Normal card charge does not require a pocket
      pocketId = null;
    } else {
      pocketMatch = _resolvePocketMatch(text, effectiveCatalog, sourceType, sourceId, issues, isCardPayment);
      pocketId = pocketMatch.id;
    }

    // Build typed intent
    NlpIntent intent;
    if (isCardPayment) {
      intent = CardPaymentIntent(
        amount: amount,
        cardId: sourceId,
        fromPocketId: pocketId,
      );
    } else if (kind == TransactionKind.income) {
      final cleanDesc = _extractCleanDescription(
        input,
        matchedAlias: accountMatch.matchedAlias ?? cardMatch.matchedAlias,
      );
      intent = IncomeIntent(
        amount: amount,
        sourceId: sourceId,
        pocketId: pocketId,
        description: cleanDesc,
      );
    } else {
      final cleanDesc = _extractCleanExpenseDescription(
        input,
        matchedSourceAlias: accountMatch.matchedAlias ?? cardMatch.matchedAlias,
        matchedPocketAlias: pocketMatch.matchedAlias,
      );
      intent = ExpenseIntent(
        amount: amount,
        sourceType: sourceType,
        sourceId: sourceId,
        pocketId: pocketId,
        description: cleanDesc,
      );
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
    );
  }

  static CreatePocketIntent _parseCreatePocket(String text, NlpCatalog catalog, int? amount) {
    final rawMatch = RegExp(r'(?:crear|nuevo)\s+bolsillo\s+(.+)', caseSensitive: false).firstMatch(text);
    String body = rawMatch?.group(1) ?? 'Bolsillo';

    String? accountId;
    String accountName = '';
    String pocketName = body;

    if (body.contains(' en ')) {
      final parts = body.split(' en ');
      pocketName = parts[0].trim();
      final remainder = parts[1].trim();
      final accQuery = remainder.split(' con ')[0].split(' saldo ')[0].trim();
      final accMatch = _bestMatch(accQuery, _expandAccountTargets(catalog.accounts));
      accountId = accMatch.id;
      accountName = accQuery;
    }

    // Strip numbers and prepositions from pocket name
    pocketName = pocketName
        .replaceAll(RegExp(r'\b(con|saldo|de|\$|\d+)\b', caseSensitive: false), '')
        .trim();
    if (pocketName.isEmpty) pocketName = 'Nuevo Bolsillo';

    return CreatePocketIntent(
      name: _capitalize(pocketName),
      accountId: accountId ?? (catalog.accounts.isNotEmpty ? catalog.accounts.first.id : null),
      accountName: accountName,
      initialBalance: amount,
    );
  }

  static CreateAccountIntent _parseCreateAccount(String text, int? amount) {
    final rawMatch = RegExp(r'(?:crear|nueva)\s+cuenta\s+(.+)', caseSensitive: false).firstMatch(text);
    String body = rawMatch?.group(1) ?? 'Cuenta';

    String name = body
        .replaceAll(RegExp(r'\b(con|saldo|de|\$|\d+)\b', caseSensitive: false), '')
        .trim();
    if (name.isEmpty) name = 'Nueva Cuenta';

    return CreateAccountIntent(
      name: _capitalize(name),
      initialBalance: amount,
    );
  }

  static CreateCardIntent _parseCreateCard(String text, int? amount) {
    final rawMatch = RegExp(r'(?:crear|nueva)\s+(?:tarjeta(?:\s+de\s+credito)?|tc)\s+(.+)', caseSensitive: false).firstMatch(text);
    String body = rawMatch?.group(1) ?? 'Tarjeta';

    int? cutOff;
    final cutMatch = RegExp(r'corte\s+(?:dia\s+)?(\d{1,2})', caseSensitive: false).firstMatch(text);
    if (cutMatch != null) cutOff = int.tryParse(cutMatch.group(1)!);

    int? paymentDue;
    final dueMatch = RegExp(r'pago\s+(?:dia\s+)?(\d{1,2})', caseSensitive: false).firstMatch(text);
    if (dueMatch != null) paymentDue = int.tryParse(dueMatch.group(1)!);

    int? limit = amount;
    final cupoMatch = RegExp(r'cupo\s+(\d[\d.,]*)', caseSensitive: false).firstMatch(text);
    if (cupoMatch != null) {
      final digits = cupoMatch.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      limit = int.tryParse(digits) ?? amount;
    }

    String cardName = body
        .split(' cupo ')[0]
        .split(' corte ')[0]
        .split(' pago ')[0]
        .replaceAll(RegExp(r'\b(\$|\d+)\b'), '')
        .trim();
    if (cardName.isEmpty) cardName = 'Nueva Tarjeta';

    return CreateCardIntent(
      name: _capitalize(cardName),
      entity: _capitalize(cardName),
      creditLimit: limit,
      cutOffDay: cutOff ?? 15,
      paymentDueDay: paymentDue ?? 5,
    );
  }

  static CreateRecurringIntent _parseCreateRecurring(String text, NlpCatalog catalog, int? amount) {
    String body = text;
    final reminderMatch = RegExp(
      r'(?:recuerdame|recuérdame|recordar)\s+(?:a\s+)?(?:pagar\s+)?(?:el\s+|la\s+|los\s+|mi\s+)?(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    final subscriptionMatch = RegExp(
      r'(?:crear|crea|nueva|nuevo|agrega|agregar|anade|añadir)?\s*(?:suscripcion|suscripción|recurrente|pago\s+recurrente)\s*(.+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (reminderMatch != null) {
      body = reminderMatch.group(1) ?? 'Recordatorio';
    } else if (subscriptionMatch != null) {
      body = subscriptionMatch.group(1) ?? 'Suscripcion';
    }

    int? dayOfMonth;
    final dayMatch = RegExp(r'(?:dia|cada|los|el)\s+(\d{1,2})', caseSensitive: false).firstMatch(text);
    if (dayMatch != null) dayOfMonth = int.tryParse(dayMatch.group(1)!);

    String? sourceId;
    String sourceName = '';
    bool isCard = false;

    // Check account or card matches from catalog in the text
    final cardMatch = _bestMatch(text, _expandCardTargets(catalog.cards));
    if (cardMatch.id != null) {
      sourceId = cardMatch.id;
      sourceName = cardMatch.matchedAlias ?? '';
      isCard = true;
    } else {
      final accMatch = _bestMatch(text, _expandAccountTargets(catalog.accounts));
      if (accMatch.id != null) {
        sourceId = accMatch.id;
        sourceName = accMatch.matchedAlias ?? '';
      }
    }

    String name = body
        .split(RegExp(r'\b(?:mensual|cada\s+mes|cada|dia|los\s+\d{1,2}|el\s+\d{1,2}|desde|\$|\d+)\b', caseSensitive: false))[0]
        .replaceAll(RegExp(r'\b(mensual|cada\s+mes|cada|dia|\$|\d+|barras?|lucas?|palos?|cop)\b', caseSensitive: false), '')
        .trim();
    name = name.replaceFirst(RegExp(r'^(?:el|la|los|las|mi|mis)\s+', caseSensitive: false), '').trim();
    if (sourceName.isNotEmpty) {
      name = name.replaceAll(RegExp('\\b${RegExp.escape(sourceName)}\\b', caseSensitive: false), '').trim();
    }
    if (name.isEmpty) name = 'Recordatorio';

    return CreateRecurringIntent(
      name: _capitalize(name),
      amount: amount ?? 0,
      dayOfMonth: dayOfMonth ?? 1,
      sourceName: sourceName,
      sourceId: sourceId,
      isCard: isCard,
    );
  }

  static TransferIntent _parseTransfer(String text, NlpCatalog catalog, int? amount) {
    final transferMatch = RegExp(r'(?:de|desde)\s+(.+?)\s+(?:a|hacia|para)\s+(.+)', caseSensitive: false).firstMatch(text);
    String fromQuery = '';
    String toQuery = '';

    if (transferMatch != null) {
      fromQuery = transferMatch.group(1)!.trim();
      toQuery = transferMatch.group(2)!.trim();
    }

    // Try resolving from & to in pockets first
    String? fromPocketId;
    String? toPocketId;

    for (final pocket in catalog.pockets) {
      if (pocket.aliases.any((a) => _containsAlias(fromQuery, a))) {
        fromPocketId = pocket.id;
        break;
      }
    }
    for (final pocket in catalog.pockets) {
      if (pocket.aliases.any((a) => _containsAlias(toQuery, a))) {
        toPocketId = pocket.id;
        break;
      }
    }

    // If not matched directly to pockets, check accounts and take their primary pocket
    if (fromPocketId == null) {
      final fromAcc = _bestMatch(fromQuery, _expandAccountTargets(catalog.accounts));
      if (fromAcc.id != null) {
        final candidate = catalog.pockets.where((p) => p.accountId == fromAcc.id).firstOrNull;
        fromPocketId = candidate?.id;
      }
    }
    if (toPocketId == null) {
      final toAcc = _bestMatch(toQuery, _expandAccountTargets(catalog.accounts));
      if (toAcc.id != null) {
        final candidate = catalog.pockets.where((p) => p.accountId == toAcc.id).firstOrNull;
        toPocketId = candidate?.id;
      }
    }

    return TransferIntent(
      amount: amount,
      fromPocketId: fromPocketId,
      toPocketId: toPocketId,
      fromPocketName: fromQuery,
      toPocketName: toQuery,
      description: text,
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _capitalizeWords(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String _extractCleanDescription(String rawInput, {String? matchedAlias}) {
    String text = rawInput;

    // 1. Remove income trigger prefix
    text = text.replaceFirst(_incomePriorityPattern, ' ');

    // 2. Remove matched bank/account and common connectors ("a la cuenta de Bancolombia", "en nequi", etc.)
    if (matchedAlias != null && matchedAlias.trim().isNotEmpty) {
      final bankPattern = RegExp(
        r'\b(?:a\s+la\s+cuenta\s+de|a\s+la\s+cta\s+de|a\s+la\s+cuenta|a\s+la\s+cta|a\s+mi\s+cuenta\s+de|a\s+mi\s+cuenta|en\s+la\s+cuenta\s+de|en\s+cuenta\s+de|en\s+cuenta|a|en|para|hacia|de)\s+' +
            RegExp.escape(matchedAlias) +
            r'\b',
        caseSensitive: false,
      );
      text = text.replaceAll(bankPattern, ' ');
      text = text.replaceAll(RegExp('\\b${RegExp.escape(matchedAlias)}\\b', caseSensitive: false), ' ');
    }

    // Also remove generic bank connector phrases
    text = text.replaceAll(RegExp(r'\b(?:a\s+la\s+cuenta\s+de|a\s+la\s+cta\s+de|a\s+la\s+cuenta|a\s+la\s+cta|a\s+mi\s+cuenta\s+de|a\s+mi\s+cuenta)\b', caseSensitive: false), ' ');

    // 3. Remove amounts and currencies
    text = text.replaceAll(RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:palos?|millones?|millon|lucas?|barras?|k|mil)\b', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'(?<![\d.,])(\d{1,3}(?:[.,]\d{3})+|\d+)(?![\d])'), ' ');
    text = text.replaceAll(RegExp(r'\b(?:pesos?|cop|dolares?|usd)\b', caseSensitive: false), ' ');
    text = text.replaceAll(r'$', ' ');

    // 4. Remove leading/trailing filler prepositions
    text = text.replaceAll(RegExp(r'^\s*(?:de|por|a|para|desde)\s+', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\s+(?:de|por|a|para|desde)\s*$', caseSensitive: false), ' ');

    // Clean whitespace and punctuation
    text = text.replaceAll(RegExp(r'[^\w\s\u00C0-\u00FF]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) {
      return 'Ingreso';
    }

    return _capitalizeWords(text);
  }

  static final _expenseTriggerPattern = RegExp(
    r'(?<![a-záéíóúüñ])(?:me\s+gaste|me\s+gasté|gaste|gasté|pague|pagué|compre|compré|debito\s+por|débito\s+por|retiro\s+de|retiro\s+en|compra\s+en|compra\s+por|pago\s+de|pago)(?![a-záéíóúüñ])',
    caseSensitive: false,
  );

  static String _extractCleanExpenseDescription(
    String rawInput, {
    String? matchedSourceAlias,
    String? matchedPocketAlias,
  }) {
    String text = rawInput;

    // 1. Remove expense trigger prefix
    text = text.replaceAll(_expenseTriggerPattern, ' ');

    // 2. Remove matched bank/account/card and common connectors
    if (matchedSourceAlias != null && matchedSourceAlias.trim().isNotEmpty) {
      final bankPattern = RegExp(
        r'(?<![a-záéíóúüñ])(?:desde\s+la\s+cuenta\s+de|desde\s+la\s+cuenta|desde\s+mi\s+cuenta|en\s+la\s+cuenta\s+de|en\s+la\s+cuenta|a\s+la\s+cuenta\s+de|a\s+la\s+cuenta|tarjeta\s+de\s+credito\s+de|tarjeta\s+de\s+credito|tarjeta\s+de|tarjeta|tc\s+de|tc|cuenta\s+de|cuenta|desde|en|de|con|por)\s+' +
            RegExp.escape(matchedSourceAlias) +
            r'(?![a-záéíóúüñ])',
        caseSensitive: false,
      );
      text = text.replaceAll(bankPattern, ' ');
      text = text.replaceAll(RegExp('(?<![a-záéíóúüñ])${RegExp.escape(matchedSourceAlias)}(?![a-záéíóúüñ])', caseSensitive: false), ' ');
    }

    // 3. Remove matched pocket and common connectors
    if (matchedPocketAlias != null && matchedPocketAlias.trim().isNotEmpty) {
      final pocketPattern = RegExp(
        r'(?<![a-záéíóúüñ])(?:desde\s+el\s+bolsillo\s+de|desde\s+el\s+bolsillo|en\s+el\s+bolsillo\s+de|en\s+el\s+bolsillo|del\s+bolsillo\s+de|del\s+bolsillo|de\s+bolsillo|bolsillo\s+de|bolsillo|desde|en|de)\s+' +
            RegExp.escape(matchedPocketAlias) +
            r'(?![a-záéíóúüñ])',
        caseSensitive: false,
      );
      text = text.replaceAll(pocketPattern, ' ');
      text = text.replaceAll(RegExp('(?<![a-záéíóúüñ])${RegExp.escape(matchedPocketAlias)}(?![a-záéíóúüñ])', caseSensitive: false), ' ');
    }

    // Also remove generic connector phrases
    text = text.replaceAll(RegExp(r'(?<![a-záéíóúüñ])(?:desde\s+el\s+bolsillo|en\s+el\s+bolsillo|del\s+bolsillo|de\s+bolsillo|bolsillo)(?![a-záéíóúüñ])', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'(?<![a-záéíóúüñ])(?:desde\s+la\s+cuenta|en\s+la\s+cuenta|tarjeta\s+de\s+credito|tarjeta|tc)(?![a-záéíóúüñ])', caseSensitive: false), ' ');

    // 4. Remove amounts and currencies
    text = text.replaceAll(RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:palos?|millones?|millon|lucas?|barras?|k|mil)(?![a-záéíóúüñ])', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'(?<![\d.,])(\d{1,3}(?:[.,]\d{3})+|\d+)(?![\d])'), ' ');
    text = text.replaceAll(RegExp(r'(?<![a-záéíóúüñ])(?:pesos?|cop|dolares?|usd)(?![a-záéíóúüñ])', caseSensitive: false), ' ');
    text = text.replaceAll(r'$', ' ');

    // 5. Remove leading/trailing filler prepositions and conjunctions
    while (RegExp(r'^\s*(?:en|de|por|para|desde|con|a)\s+', caseSensitive: false).hasMatch(text)) {
      text = text.replaceFirst(RegExp(r'^\s*(?:en|de|por|para|desde|con|a)\s+', caseSensitive: false), ' ');
    }
    while (RegExp(r'\s+(?:en|de|por|para|desde|con|a)\s*$', caseSensitive: false).hasMatch(text)) {
      text = text.replaceFirst(RegExp(r'\s+(?:en|de|por|para|desde|con|a)\s*$', caseSensitive: false), ' ');
    }

    // Clean whitespace and punctuation
    text = text.replaceAll(RegExp(r'[^\w\s\u00C0-\u00FF]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) {
      return 'Gasto';
    }

    return _capitalizeWords(text);
  }

  static List<NlpTarget> _expandCardTargets(List<NlpTarget> cards) {
    return cards.map((card) {
      final expandedAliases = <String>{};
      for (final alias in card.aliases) {
        final norm = _normalize(alias);
        expandedAliases.add(norm);
        expandedAliases.add('tc $norm');
        expandedAliases.add('tarjeta $norm');
        expandedAliases.add('tarjeta de credito $norm');
      }
      return NlpTarget(id: card.id, aliases: expandedAliases.toList());
    }).toList();
  }

  static List<NlpTarget> _expandAccountTargets(List<NlpTarget> accounts) {
    return accounts.map((acc) {
      final expandedAliases = <String>{};
      for (final alias in acc.aliases) {
        final norm = _normalize(alias);
        expandedAliases.add(norm);
        expandedAliases.add('cuenta $norm');
        expandedAliases.add('cta $norm');
      }
      return NlpTarget(id: acc.id, aliases: expandedAliases.toList());
    }).toList();
  }

  static List<NlpPocketTarget> _expandPocketTargets(List<NlpPocketTarget> pockets) {
    return pockets.map((p) {
      final expandedAliases = <String>{};
      for (final alias in p.aliases) {
        final norm = _normalize(alias);
        expandedAliases.add(norm);
        expandedAliases.add('bolsillo $norm');
        expandedAliases.add('del bolsillo $norm');
        expandedAliases.add('de bolsillo $norm');
        expandedAliases.add('en el bolsillo $norm');
        expandedAliases.add('desde el bolsillo $norm');
        expandedAliases.add('el bolsillo $norm');
        expandedAliases.add('en bolsillo $norm');
        expandedAliases.add('desde bolsillo $norm');
      }
      return NlpPocketTarget(id: p.id, accountId: p.accountId, aliases: expandedAliases.toList());
    }).toList();
  }

  static _Match _resolvePocketMatch(
    String text,
    NlpCatalog catalog,
    SourceType? sourceType,
    String? sourceId,
    List<ParseIssue> issues,
    bool isCardPayment,
  ) {
    final accountFilter = (sourceType == SourceType.account && !isCardPayment) ? sourceId : null;
    final candidates = catalog.pockets
        .where((pocket) => accountFilter == null || pocket.accountId == accountFilter)
        .toList();
    final expanded = _expandPocketTargets(candidates);
    final match = _bestMatch(text, expanded);

    if (match.ambiguous) {
      issues.add(ParseIssue.ambiguousPocket);
    }
    return match;
  }

  static int? _extractAmount(String text) {
    final lower = text.toLowerCase();

    // 1. "media luca" = 500 COP
    if (RegExp(r'\bmedia\s+luca\b').hasMatch(lower)) {
      return 500;
    }

    // 2. Millions / palos: "2 palos", "1.5 palos", "2 millones"
    final paloMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:palos?|millones?|millon)\b').firstMatch(lower);
    if (paloMatch != null) {
      final raw = paloMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(raw);
      if (val != null) return (val * 1000000).round();
    }

    // 3. Thousands / lucas / barras / k / mil: "45 barras", "50 lucas", "10k", "15 mil"
    final thousandMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:lucas?|barras?|k|mil)\b').firstMatch(lower);
    if (thousandMatch != null) {
      final raw = thousandMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(raw);
      if (val != null) return (val * 1000).round();
    }

    // 4. Standard numerical amounts (skipping recurring billing days like "cada 15", "dia 15", "los 10", "el 5")
    final textWithoutDays = lower.replaceAll(RegExp(r'\b(?:cada|dia|los|el)\s+\d{1,2}\b'), ' ');
    for (final match in _amountPattern.allMatches(textWithoutDays)) {
      final digits = match.group(1)!.replaceAll(RegExp(r'[.,]'), '');
      final value = int.tryParse(digits);
      if (value != null && value > 0) return value;
    }

    return null;
  }

  static _Match _bestMatch(String text, List<NlpTarget> targets) {
    final lengthById = <String, int>{};
    final aliasById = <String, String>{};
    for (final target in targets) {
      for (final alias in target.aliases) {
        if (_containsAlias(text, alias)) {
          final length = _normalize(alias).length;
          if (length > (lengthById[target.id] ?? 0)) {
            lengthById[target.id] = length;
            aliasById[target.id] = _normalize(alias);
          }
        }
      }
    }
    if (lengthById.isEmpty) return const _Match(null, false, 0, null);
    final longest = lengthById.values.reduce((a, b) => a > b ? a : b);
    final winners = lengthById.entries.where((entry) => entry.value == longest).toList();
    if (winners.length > 1) {
      return const _Match(null, true, 0, null);
    }
    final winningId = winners.single.key;
    return _Match(winningId, false, longest, aliasById[winningId]);
  }

  static bool _containsAlias(String text, String alias) {
    final normalized = RegExp.escape(_normalize(alias));
    return RegExp('(?<![a-z0-9])$normalized(?![a-z0-9])').hasMatch(text);
  }

  static String _normalize(String value) {
    const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
    final lower = value.toLowerCase().trim();
    return lower.split('').map((char) => accents[char] ?? char).join().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _Match {
  const _Match(this.id, this.ambiguous, [this.length = 0, this.matchedAlias]);

  final String? id;
  final bool ambiguous;
  final int length;
  final String? matchedAlias;
}
