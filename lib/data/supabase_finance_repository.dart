import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/ledger_transaction.dart';
import '../domain/models/models.dart';
import '../domain/repositories/finance_repository.dart';
import '../domain/services/nlp_parser.dart';

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this._client);

  final SupabaseClient _client;

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  // --- Accounts & Pockets ---
  @override
  Future<List<Account>> getAccounts() async {
    final res = await _client.from('accounts').select('id, name, account_number').order('name');
    return (res as List)
        .map((r) => Account(
              id: r['id'] as String,
              name: r['name'] as String,
              accountNumber: (r['account_number'] as String?) ?? '',
            ))
        .toList();
  }

  @override
  Future<Account> createAccount(String name, {String accountNumber = ''}) async {
    final existing = await _client
        .from('accounts')
        .select('id, name, account_number')
        .eq('name', name)
        .maybeSingle();

    if (existing != null) {
      if (accountNumber.isNotEmpty && (existing['account_number'] == null || (existing['account_number'] as String).isEmpty)) {
        await _client.from('accounts').update({'account_number': accountNumber}).eq('id', existing['id']);
      }
      return Account(
        id: existing['id'] as String,
        name: existing['name'] as String,
        accountNumber: (existing['account_number'] as String?) ?? accountNumber,
      );
    }

    final res = await _client
        .from('accounts')
        .insert({
          'name': name,
          'account_number': accountNumber,
        })
        .select('id, name, account_number')
        .single();
    return Account(
      id: res['id'] as String,
      name: res['name'] as String,
      accountNumber: (res['account_number'] as String?) ?? '',
    );
  }

  @override
  Future<Account> createAccountWithInitialPocket({
    required String entityName,
    String accountNumber = '',
    required String accountType,
    required Cop initialBalance,
  }) async {
    final accountName = accountType.trim().isEmpty || accountType.trim().toLowerCase() == 'banco'
        ? entityName.trim()
        : '${entityName.trim()} (${accountType.trim()})';

    final acc = await createAccount(accountName, accountNumber: accountNumber);

    final pocketName = 'Disponible en Cuenta';
    final pocket = await createPocket(
      accountId: acc.id,
      name: pocketName,
      initialBalance: initialBalance,
    );

    // Register NLP aliases for entity and pocket
    await addAlias(alias: entityName.trim().toLowerCase(), accountId: acc.id);
    await addAlias(alias: pocketName.trim().toLowerCase(), pocketId: pocket.id);

    return acc;
  }

  @override
  Future<void> updateAccount({
    required String id,
    required String name,
    String accountNumber = '',
    Cop? adjustBalanceOutsidePockets,
  }) async {
    await _client.from('accounts').update({
      'name': name,
      'account_number': accountNumber,
    }).eq('id', id);

    if (adjustBalanceOutsidePockets != null) {
      final pocketsRes = await _client
          .from('pockets')
          .select('id, name, balance')
          .eq('account_id', id);
      final pocketsList = pocketsRes as List;
      final unallocated = pocketsList.where((p) {
        final n = (p['name'] as String).toLowerCase();
        return n.contains('disponible') || n.contains('principal') || n.contains('cuenta');
      }).firstOrNull ?? pocketsList.firstOrNull;

      if (unallocated != null) {
        await _client
            .from('pockets')
            .update({'balance': adjustBalanceOutsidePockets})
            .eq('id', unallocated['id']);
      } else {
        await createPocket(
          accountId: id,
          name: 'Disponible en Cuenta',
          initialBalance: adjustBalanceOutsidePockets,
        );
      }
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    // 1. Get pockets for this account
    final pocketsRes = await _client.from('pockets').select('id').eq('account_id', id);
    final pocketIds = (pocketsRes as List).map((p) => p['id'] as String).toList();

    if (pocketIds.isNotEmpty) {
      // 2. Check if any transaction references these pockets
      final txRes = await _client
          .from('transactions')
          .select('id')
          .or('pocket_id.in.(${pocketIds.join(",")}),target_pocket_id.in.(${pocketIds.join(",")})')
          .limit(1);

      if ((txRes as List).isNotEmpty) {
        throw StateError('No se puede eliminar la cuenta porque tiene transacciones registradas.');
      }
    }

    // 3. Delete account (cascade deletes pockets and aliases)
    await _client.from('accounts').delete().eq('id', id);
  }

  @override
  Future<List<Pocket>> getPockets() async {
    final res = await _client
        .from('pockets')
        .select('id, account_id, name, balance')
        .order('name');
    return (res as List)
        .map((r) => Pocket(
              id: r['id'] as String,
              accountId: r['account_id'] as String,
              name: r['name'] as String,
              balance: (r['balance'] as num).toInt(),
            ))
        .toList();
  }

  @override
  Future<Pocket> createPocket({
    required String accountId,
    required String name,
    required Cop initialBalance,
  }) async {
    final res = await _client
        .from('pockets')
        .insert({
          'account_id': accountId,
          'name': name,
          'balance': initialBalance,
        })
        .select('id, account_id, name, balance')
        .single();
    return Pocket(
      id: res['id'] as String,
      accountId: res['account_id'] as String,
      name: res['name'] as String,
      balance: (res['balance'] as num).toInt(),
    );
  }

  @override
  Future<void> updatePocket({
    required String id,
    required String name,
    Cop? balance,
  }) async {
    final data = <String, dynamic>{'name': name};
    if (balance != null) {
      data['balance'] = balance;
    }
    await _client.from('pockets').update(data).eq('id', id);
  }

  @override
  Future<void> deletePocket(String id) async {
    await _client.from('pockets').delete().eq('id', id);
  }

  // --- Credit Cards ---
  @override
  Future<List<CreditCard>> getCreditCards() async {
    final res = await _client
        .from('credit_cards')
        .select('id, entity, name, franchise, last_four_digits, credit_limit, available_credit, cut_off_day, payment_due_day')
        .order('name');
    return (res as List)
        .map((r) => CreditCard(
              id: r['id'] as String,
              entity: r['entity'] as String,
              name: r['name'] as String,
              franchise: r['franchise'] as String,
              lastFourDigits: r['last_four_digits'] as String,
              creditLimit: (r['credit_limit'] as num).toInt(),
              availableCredit: (r['available_credit'] as num).toInt(),
              cutOffDay: (r['cut_off_day'] as num).toInt(),
              paymentDueDay: (r['payment_due_day'] as num).toInt(),
            ))
        .toList();
  }

  @override
  Future<CreditCard> createCreditCard({
    required String entity,
    required String name,
    required String franchise,
    required String lastFourDigits,
    required Cop creditLimit,
    required Cop availableCredit,
    required int cutOffDay,
    required int paymentDueDay,
  }) async {
    // Prevent duplicate cards with same entity and last four digits
    final existing = await _client
        .from('credit_cards')
        .select()
        .eq('entity', entity)
        .eq('last_four_digits', lastFourDigits)
        .maybeSingle();

    if (existing != null) {
      return CreditCard(
        id: existing['id'] as String,
        entity: existing['entity'] as String,
        name: existing['name'] as String,
        franchise: existing['franchise'] as String,
        lastFourDigits: existing['last_four_digits'] as String,
        creditLimit: (existing['credit_limit'] as num).toInt(),
        availableCredit: (existing['available_credit'] as num).toInt(),
        cutOffDay: (existing['cut_off_day'] as num).toInt(),
        paymentDueDay: (existing['payment_due_day'] as num).toInt(),
      );
    }

    final res = await _client
        .from('credit_cards')
        .insert({
          'entity': entity,
          'name': name,
          'franchise': franchise,
          'last_four_digits': lastFourDigits,
          'credit_limit': creditLimit,
          'available_credit': availableCredit,
          'currency': 'COP',
          'cut_off_day': cutOffDay,
          'payment_due_day': paymentDueDay,
        })
        .select()
        .single();
    final card = CreditCard(
      id: res['id'] as String,
      entity: res['entity'] as String,
      name: res['name'] as String,
      franchise: res['franchise'] as String,
      lastFourDigits: res['last_four_digits'] as String,
      creditLimit: (res['credit_limit'] as num).toInt(),
      availableCredit: (res['available_credit'] as num).toInt(),
      cutOffDay: (res['cut_off_day'] as num).toInt(),
      paymentDueDay: (res['payment_due_day'] as num).toInt(),
    );

    // Register aliases for NLP
    try {
      await addAlias(alias: name.trim().toLowerCase(), cardId: card.id);
      if (entity.trim().toLowerCase() != name.trim().toLowerCase()) {
        await addAlias(alias: entity.trim().toLowerCase(), cardId: card.id);
        await addAlias(alias: '${entity.trim()} ${name.trim()}'.toLowerCase(), cardId: card.id);
      }
      await addAlias(alias: 'tc ${name.trim().toLowerCase()}', cardId: card.id);
      await addAlias(alias: 'tarjeta ${name.trim().toLowerCase()}', cardId: card.id);
      await addAlias(alias: 'tarjeta de credito ${name.trim().toLowerCase()}', cardId: card.id);
      await addAlias(alias: 'tarjeta de credito ${entity.trim().toLowerCase()}', cardId: card.id);
    } catch (_) {
      // Ignore alias duplicates if any
    }

    return card;
  }

  @override
  Future<void> updateCreditCard(CreditCard card) async {
    await _client.from('credit_cards').update({
      'entity': card.entity,
      'name': card.name,
      'franchise': card.franchise,
      'last_four_digits': card.lastFourDigits,
      'credit_limit': card.creditLimit,
      'available_credit': card.availableCredit,
      'cut_off_day': card.cutOffDay,
      'payment_due_day': card.paymentDueDay,
    }).eq('id', card.id);
  }

  @override
  Future<void> deleteCreditCard(String id) async {
    // 1. Check if any transaction references this credit card
    final txRes = await _client.from('transactions').select('id').eq('card_id', id).limit(1);
    if ((txRes as List).isNotEmpty) {
      throw StateError('No se puede eliminar la tarjeta porque tiene transacciones registradas.');
    }

    // 2. Check if any recurring payment references this credit card
    final recRes = await _client.from('recurring_payments').select('id').eq('card_id', id).limit(1);
    if ((recRes as List).isNotEmpty) {
      throw StateError('No se puede eliminar la tarjeta porque tiene suscripciones o pagos recurrentes asociados.');
    }

    // 3. Delete aliases pointing to this card
    await _client.from('aliases').delete().eq('card_id', id);

    // 4. Delete card
    await _client.from('credit_cards').delete().eq('id', id);
  }

  // --- Transactions / RPC Operations ---
  @override
  Future<String> recordPocketMovement({
    required TransactionKind kind,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  }) async {
    final res = await _client.rpc('record_pocket_movement', params: {
      'p_type': kind == TransactionKind.income ? 'income' : 'expense',
      'p_pocket_id': pocketId,
      'p_amount': amount,
      'p_date': _formatDate(date),
      'p_description': description,
    });
    return res as String;
  }

  @override
  Future<String> recordCardCharge({
    required String cardId,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  }) async {
    String effectivePocketId = pocketId;
    if (effectivePocketId.isEmpty) {
      final pockets = await getPockets();
      final defaultPocket = pockets.firstWhere(
        (p) => p.name.toLowerCase() == 'personal' || p.name.toLowerCase() == 'general',
        orElse: () => pockets.isNotEmpty ? pockets.first : throw StateError('No hay bolsillos disponibles'),
      );
      effectivePocketId = defaultPocket.id;
    }
    final res = await _client.rpc('record_card_charge', params: {
      'p_card_id': cardId,
      'p_pocket_id': effectivePocketId,
      'p_amount': amount,
      'p_date': _formatDate(date),
      'p_description': description,
    });
    return res as String;
  }

  @override
  Future<String> recordCardPayment({
    required String cardId,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  }) async {
    final res = await _client.rpc('record_card_payment', params: {
      'p_card_id': cardId,
      'p_pocket_id': pocketId,
      'p_amount': amount,
      'p_date': _formatDate(date),
      'p_description': description,
    });
    return res as String;
  }

  @override
  Future<String> transferBetweenPockets({
    required String fromPocketId,
    required String toPocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  }) async {
    final res = await _client.rpc('transfer_between_pockets', params: {
      'p_from_pocket_id': fromPocketId,
      'p_to_pocket_id': toPocketId,
      'p_amount': amount,
      'p_date': _formatDate(date),
      'p_description': description,
    });
    return res as String;
  }

  // --- Recurring Payments ---
  @override
  Future<List<RecurringPayment>> getRecurringPayments() async {
    final res = await _client
        .from('recurring_payments')
        .select('id, name, amount, day_of_month, start_date, method_type, pocket_id, card_id, auto_deduct, last_processed_date')
        .order('name');
    return (res as List).map((r) {
      final isCard = r['method_type'] == 'credit_card';
      return RecurringPayment(
        id: r['id'] as String,
        name: r['name'] as String,
        amount: (r['amount'] as num).toInt(),
        dayOfMonth: (r['day_of_month'] as num).toInt(),
        startDate: DateTime.parse(r['start_date'] as String),
        methodType: isCard ? PaymentMethodType.creditCard : PaymentMethodType.accountPocket,
        methodId: isCard ? (r['card_id'] as String) : (r['pocket_id'] as String),
        pocketId: r['pocket_id'] as String,
        autoDeduct: r['auto_deduct'] as bool,
        lastProcessedDate: r['last_processed_date'] != null
            ? DateTime.parse(r['last_processed_date'] as String)
            : null,
      );
    }).toList();
  }

  @override
  Future<RecurringPayment> createRecurringPayment({
    required String name,
    required Cop amount,
    required int dayOfMonth,
    required DateTime startDate,
    required PaymentMethodType methodType,
    required String methodId,
    required String pocketId,
    required bool autoDeduct,
  }) async {
    final isCard = methodType == PaymentMethodType.creditCard;
    final res = await _client
        .from('recurring_payments')
        .insert({
          'name': name,
          'amount': amount,
          'day_of_month': dayOfMonth,
          'start_date': _formatDate(startDate),
          'method_type': isCard ? 'credit_card' : 'account_pocket',
          'pocket_id': pocketId,
          'card_id': isCard ? methodId : null,
          'auto_deduct': autoDeduct,
        })
        .select()
        .single();

    return RecurringPayment(
      id: res['id'] as String,
      name: res['name'] as String,
      amount: (res['amount'] as num).toInt(),
      dayOfMonth: (res['day_of_month'] as num).toInt(),
      startDate: DateTime.parse(res['start_date'] as String),
      methodType: methodType,
      methodId: methodId,
      pocketId: pocketId,
      autoDeduct: res['auto_deduct'] as bool,
      lastProcessedDate: null,
    );
  }

  @override
  Future<void> updateRecurringPayment(RecurringPayment payment) async {
    final isCard = payment.methodType == PaymentMethodType.creditCard;
    await _client.from('recurring_payments').update({
      'name': payment.name,
      'amount': payment.amount,
      'day_of_month': payment.dayOfMonth,
      'start_date': _formatDate(payment.startDate),
      'method_type': isCard ? 'credit_card' : 'account_pocket',
      'pocket_id': payment.pocketId,
      'card_id': isCard ? payment.methodId : null,
      'auto_deduct': payment.autoDeduct,
    }).eq('id', payment.id);
  }

  @override
  Future<void> deleteRecurringPayment(String id) async {
    await _client.from('recurring_payments').delete().eq('id', id);
  }

  // --- NLP Catalog & Aliases ---
  @override
  Future<NlpCatalog> getNlpCatalog() async {
    final accs = await getAccounts();
    final cards = await getCreditCards();
    final pockets = await getPockets();
    final aliasRes = await _client.from('aliases').select('alias, account_id, card_id, pocket_id');

    final accountAliases = <String, List<String>>{};
    final cardAliases = <String, List<String>>{};
    final pocketAliases = <String, List<String>>{};

    for (final a in accs) {
      accountAliases[a.id] = [a.name.toLowerCase()];
    }
    for (final c in cards) {
      cardAliases[c.id] = [
        c.name.toLowerCase(),
        c.entity.toLowerCase(),
        '${c.entity} ${c.name}'.toLowerCase(),
        'tc ${c.name.toLowerCase()}',
        'tc ${c.entity.toLowerCase()}',
        'tarjeta ${c.name.toLowerCase()}',
        'tarjeta ${c.entity.toLowerCase()}',
        'tarjeta de credito ${c.name.toLowerCase()}',
        'tarjeta de credito ${c.entity.toLowerCase()}',
        'tarjeta de crédito ${c.name.toLowerCase()}',
        'tarjeta de crédito ${c.entity.toLowerCase()}',
      ];
    }
    for (final p in pockets) {
      pocketAliases[p.id] = [p.name.toLowerCase()];
    }

    for (final row in aliasRes as List) {
      final aliasStr = (row['alias'] as String).toLowerCase();
      if (row['account_id'] != null) {
        accountAliases[row['account_id'] as String]?.add(aliasStr);
      } else if (row['card_id'] != null) {
        cardAliases[row['card_id'] as String]?.add(aliasStr);
      } else if (row['pocket_id'] != null) {
        pocketAliases[row['pocket_id'] as String]?.add(aliasStr);
      }
    }

    return NlpCatalog(
      accounts: [
        for (final a in accs)
          NlpTarget(id: a.id, aliases: accountAliases[a.id] ?? [a.name.toLowerCase()]),
      ],
      cards: [
        for (final c in cards)
          NlpTarget(id: c.id, aliases: cardAliases[c.id] ?? [c.name.toLowerCase()]),
      ],
      pockets: [
        for (final p in pockets)
          NlpPocketTarget(
            id: p.id,
            accountId: p.accountId,
            aliases: pocketAliases[p.id] ?? [p.name.toLowerCase()],
          ),
      ],
    );
  }

  @override
  Future<void> addAlias({
    required String alias,
    String? accountId,
    String? cardId,
    String? pocketId,
  }) async {
    await _client.from('aliases').insert({
      'alias': alias,
      'account_id': accountId,
      'card_id': cardId,
      'pocket_id': pocketId,
    });
  }

  // --- Alerts & User Settings ---
  @override
  Future<Set<String>> getDeliveredAlertIds() async {
    final res = await _client.from('alert_deliveries').select('alert_id');
    return (res as List).map((r) => r['alert_id'] as String).toSet();
  }

  @override
  Future<void> markAlertDelivered(String alertId) async {
    await _client.from('alert_deliveries').upsert({'alert_id': alertId});
  }

  @override
  Future<ReminderSettings> getReminderSettings() async {
    final res = await _client.from('user_settings').select('reminder_hour, reminder_minute').maybeSingle();
    if (res == null) return const ReminderSettings();
    return ReminderSettings(
      hour: (res['reminder_hour'] as num?)?.toInt() ?? 8,
      minute: (res['reminder_minute'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> updateReminderSettings(ReminderSettings settings) async {
    await _client.from('user_settings').upsert({
      'reminder_hour': settings.hour,
      'reminder_minute': settings.minute,
    });
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    final res = await _client.from('user_settings').select('onboarding_completed').maybeSingle();
    return (res?['onboarding_completed'] as bool?) ?? false;
  }

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    await _client.from('user_settings').upsert({
      'onboarding_completed': completed,
    });
  }

  // --- Fiscal Close ---
  @override
  Future<List<LedgerTransaction>> getTransactionsForYear(int year) async {
    final start = '$year-01-01';
    final end = '$year-12-31';
    final res = await _client
        .from('transactions')
        .select('id, occurred_on, type, amount, pocket_id, card_id, description')
        .gte('occurred_on', start)
        .lte('occurred_on', end)
        .order('occurred_on');

    return (res as List).map((r) {
      final typeStr = r['type'] as String;
      final type = switch (typeStr) {
        'income' => LedgerTransactionType.income,
        'expense' => LedgerTransactionType.expense,
        'card_charge' => LedgerTransactionType.cardCharge,
        'card_payment' => LedgerTransactionType.cardPayment,
        _ => LedgerTransactionType.pocketTransfer,
      };
      return LedgerTransaction(
        id: r['id'] as String,
        date: DateTime.parse(r['occurred_on'] as String),
        type: type,
        amount: (r['amount'] as num).toInt(),
        pocketId: r['pocket_id'] as String?,
        cardId: r['card_id'] as String?,
        description: (r['description'] as String?) ?? '',
      );
    }).toList();
  }

  @override
  Future<int> deleteTransactionsForYear(int year) async {
    final res = await _client.rpc('delete_transactions_of_year', params: {'p_year': year});
    return (res as num).toInt();
  }

  @override
  Future<List<LedgerTransaction>> getTransactionsForAccount(String accountId) async {
    final pocketsRes = await _client.from('pockets').select('id').eq('account_id', accountId);
    final pocketIds = (pocketsRes as List).map((p) => p['id'] as String).toList();
    if (pocketIds.isEmpty) return [];

    final res = await _client
        .from('transactions')
        .select('id, occurred_on, type, amount, pocket_id, target_pocket_id, card_id, description')
        .or('pocket_id.in.(${pocketIds.join(",")}),target_pocket_id.in.(${pocketIds.join(",")})')
        .order('occurred_on', ascending: false);

    return (res as List).map((r) {
      final typeStr = r['type'] as String;
      final type = switch (typeStr) {
        'income' => LedgerTransactionType.income,
        'expense' => LedgerTransactionType.expense,
        'card_charge' => LedgerTransactionType.cardCharge,
        'card_payment' => LedgerTransactionType.cardPayment,
        _ => LedgerTransactionType.pocketTransfer,
      };
      return LedgerTransaction(
        id: r['id'] as String,
        date: DateTime.parse(r['occurred_on'] as String),
        type: type,
        amount: (r['amount'] as num).toInt(),
        pocketId: r['pocket_id'] as String?,
        cardId: r['card_id'] as String?,
        description: (r['description'] as String?) ?? '',
      );
    }).toList();
  }

  @override
  Future<List<LedgerTransaction>> getTransactionsForCard(String cardId) async {
    final res = await _client
        .from('transactions')
        .select('id, occurred_on, type, amount, pocket_id, card_id, description')
        .eq('card_id', cardId)
        .order('occurred_on', ascending: false);

    return (res as List).map((r) {
      final typeStr = r['type'] as String;
      final type = switch (typeStr) {
        'income' => LedgerTransactionType.income,
        'expense' => LedgerTransactionType.expense,
        'card_charge' => LedgerTransactionType.cardCharge,
        'card_payment' => LedgerTransactionType.cardPayment,
        _ => LedgerTransactionType.pocketTransfer,
      };
      return LedgerTransaction(
        id: r['id'] as String,
        date: DateTime.parse(r['occurred_on'] as String),
        type: type,
        amount: (r['amount'] as num).toInt(),
        pocketId: r['pocket_id'] as String?,
        cardId: r['card_id'] as String?,
        description: (r['description'] as String?) ?? '',
      );
    }).toList();
  }

  @override
  Future<int> purgeTransactionsOlderThanOneYear() async {
    final res = await _client.rpc('delete_transactions_older_than_one_year');
    return (res as num).toInt();
  }
}
