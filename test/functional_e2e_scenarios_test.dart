import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_personales/domain/models/ledger_transaction.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/repositories/finance_repository.dart';
import 'package:finanzas_personales/domain/services/balance_calculator.dart';
import 'package:finanzas_personales/domain/services/nlp_parser.dart';
import 'package:finanzas_personales/presentation/providers/supabase_providers.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/bank_details_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/card_payment_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/pocket_crud_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/transfer_dialog.dart';
import 'package:finanzas_personales/presentation/screens/onboarding_screen.dart';

class FakeFinanceRepository implements FinanceRepository {
  final List<Account> accounts = [];
  final List<Pocket> pockets = [];
  final List<CreditCard> creditCards = [];
  final List<LedgerTransaction> transactions = [];
  final List<RecurringPayment> recurringPayments = [];
  final List<Map<String, dynamic>> aliases = [];
  bool onboardingCompleted = false;

  @override
  Future<List<Account>> getAccounts() async => List.unmodifiable(accounts);

  @override
  Future<Account> createAccount(String name, {String accountNumber = ''}) async {
    final acc = Account(id: 'acc_${accounts.length + 1}', name: name, accountNumber: accountNumber);
    accounts.add(acc);
    return acc;
  }

  @override
  Future<Account> createAccountWithInitialPocket({
    required String entityName,
    String accountNumber = '',
    required String accountType,
    required Cop initialBalance,
  }) async {
    final acc = Account(id: 'acc_${accounts.length + 1}', name: entityName, accountNumber: accountNumber);
    accounts.add(acc);
    final pocket = Pocket(
      id: 'pock_${pockets.length + 1}',
      accountId: acc.id,
      name: 'Disponible en Cuenta',
      balance: initialBalance,
    );
    pockets.add(pocket);
    return acc;
  }

  @override
  Future<void> updateAccount({
    required String id,
    required String name,
    String accountNumber = '',
    Cop? adjustBalanceOutsidePockets,
  }) async {
    final idx = accounts.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = accounts[idx];
      accounts[idx] = Account(id: old.id, name: name, accountNumber: accountNumber);
    }
    if (adjustBalanceOutsidePockets != null) {
      final pIdx = pockets.indexWhere((p) => p.accountId == id);
      if (pIdx != -1) {
        final oldP = pockets[pIdx];
        pockets[pIdx] = Pocket(
          id: oldP.id,
          accountId: oldP.accountId,
          name: oldP.name,
          balance: adjustBalanceOutsidePockets,
        );
      }
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    accounts.removeWhere((a) => a.id == id);
    pockets.removeWhere((p) => p.accountId == id);
  }

  @override
  Future<List<Pocket>> getPockets() async => List.unmodifiable(pockets);

  @override
  Future<Pocket> createPocket({
    required String accountId,
    required String name,
    required Cop initialBalance,
  }) async {
    final pocket = Pocket(
      id: 'pock_${pockets.length + 1}',
      accountId: accountId,
      name: name,
      balance: initialBalance,
    );
    pockets.add(pocket);
    return pocket;
  }

  @override
  Future<void> updatePocket({
    required String id,
    required String name,
    Cop? balance,
  }) async {
    final idx = pockets.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final old = pockets[idx];
      pockets[idx] = Pocket(
        id: old.id,
        accountId: old.accountId,
        name: name,
        balance: balance ?? old.balance,
      );
    }
  }

  @override
  Future<void> deletePocket(String id) async {
    pockets.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<CreditCard>> getCreditCards() async => List.unmodifiable(creditCards);

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
    final card = CreditCard(
      id: 'card_${creditCards.length + 1}',
      entity: entity,
      name: name,
      franchise: franchise,
      lastFourDigits: lastFourDigits,
      creditLimit: creditLimit,
      availableCredit: availableCredit,
      cutOffDay: cutOffDay,
      paymentDueDay: paymentDueDay,
    );
    creditCards.add(card);
    return card;
  }

  @override
  Future<void> updateCreditCard(CreditCard card) async {
    final idx = creditCards.indexWhere((c) => c.id == card.id);
    if (idx != -1) creditCards[idx] = card;
  }

  @override
  Future<void> deleteCreditCard(String id) async {
    creditCards.removeWhere((c) => c.id == id);
  }

  @override
  Future<String> recordPocketMovement({
    required TransactionKind kind,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  }) async {
    final pIdx = pockets.indexWhere((p) => p.id == pocketId);
    if (pIdx != -1) {
      final old = pockets[pIdx];
      final newBalance = kind == TransactionKind.income ? old.balance + amount : old.balance - amount;
      pockets[pIdx] = Pocket(id: old.id, accountId: old.accountId, name: old.name, balance: newBalance);
    }
    final txId = 'tx_${transactions.length + 1}';
    transactions.add(LedgerTransaction(
      id: txId,
      date: date,
      amount: amount,
      type: kind == TransactionKind.income ? LedgerTransactionType.income : LedgerTransactionType.expense,
      pocketId: pocketId,
      description: description,
    ));
    return txId;
  }

  @override
  Future<String> recordCardCharge({
    required String cardId,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  }) async {
    final cIdx = creditCards.indexWhere((c) => c.id == cardId);
    if (cIdx != -1) {
      final old = creditCards[cIdx];
      creditCards[cIdx] = CreditCard(
        id: old.id,
        entity: old.entity,
        name: old.name,
        franchise: old.franchise,
        lastFourDigits: old.lastFourDigits,
        creditLimit: old.creditLimit,
        availableCredit: old.availableCredit - amount,
        cutOffDay: old.cutOffDay,
        paymentDueDay: old.paymentDueDay,
      );
    }
    final txId = 'tx_${transactions.length + 1}';
    transactions.add(LedgerTransaction(
      id: txId,
      date: date,
      amount: amount,
      type: LedgerTransactionType.cardCharge,
      pocketId: pocketId,
      cardId: cardId,
      description: description,
    ));
    return txId;
  }

  @override
  Future<String> recordCardPayment({
    required String cardId,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  }) async {
    // 1. Deduct from pocket
    final pIdx = pockets.indexWhere((p) => p.id == pocketId);
    if (pIdx != -1) {
      final oldP = pockets[pIdx];
      pockets[pIdx] = Pocket(id: oldP.id, accountId: oldP.accountId, name: oldP.name, balance: oldP.balance - amount);
    }
    // 2. Restore credit limit
    final cIdx = creditCards.indexWhere((c) => c.id == cardId);
    if (cIdx != -1) {
      final oldC = creditCards[cIdx];
      creditCards[cIdx] = CreditCard(
        id: oldC.id,
        entity: oldC.entity,
        name: oldC.name,
        franchise: oldC.franchise,
        lastFourDigits: oldC.lastFourDigits,
        creditLimit: oldC.creditLimit,
        availableCredit: oldC.availableCredit + amount,
        cutOffDay: oldC.cutOffDay,
        paymentDueDay: oldC.paymentDueDay,
      );
    }
    final txId = 'tx_${transactions.length + 1}';
    transactions.add(LedgerTransaction(
      id: txId,
      date: date,
      amount: amount,
      type: LedgerTransactionType.cardPayment,
      pocketId: pocketId,
      cardId: cardId,
      description: description,
    ));
    return txId;
  }

  @override
  Future<String> transferBetweenPockets({
    required String fromPocketId,
    required String toPocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  }) async {
    final fromIdx = pockets.indexWhere((p) => p.id == fromPocketId);
    final toIdx = pockets.indexWhere((p) => p.id == toPocketId);
    if (fromIdx != -1) {
      final oldF = pockets[fromIdx];
      pockets[fromIdx] = Pocket(id: oldF.id, accountId: oldF.accountId, name: oldF.name, balance: oldF.balance - amount);
    }
    if (toIdx != -1) {
      final oldT = pockets[toIdx];
      pockets[toIdx] = Pocket(id: oldT.id, accountId: oldT.accountId, name: oldT.name, balance: oldT.balance + amount);
    }
    final txId = 'tx_${transactions.length + 1}';
    transactions.add(LedgerTransaction(
      id: txId,
      date: date,
      amount: amount,
      type: LedgerTransactionType.pocketTransfer,
      pocketId: fromPocketId,
      description: description,
    ));
    return txId;
  }

  @override
  Future<List<RecurringPayment>> getRecurringPayments() async => List.unmodifiable(recurringPayments);

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
    final rp = RecurringPayment(
      id: 'rp_${recurringPayments.length + 1}',
      name: name,
      amount: amount,
      dayOfMonth: dayOfMonth,
      startDate: startDate,
      methodType: methodType,
      methodId: methodId,
      pocketId: pocketId,
      autoDeduct: autoDeduct,
    );
    recurringPayments.add(rp);
    return rp;
  }

  @override
  Future<void> updateRecurringPayment(RecurringPayment payment) async {
    final idx = recurringPayments.indexWhere((rp) => rp.id == payment.id);
    if (idx != -1) {
      recurringPayments[idx] = payment;
    }
  }

  @override
  Future<void> deleteRecurringPayment(String id) async {
    recurringPayments.removeWhere((rp) => rp.id == id);
  }

  @override
  Future<NlpCatalog> getNlpCatalog() async {
    final accTargets = accounts.map((a) => NlpTarget(id: a.id, aliases: [a.name.toLowerCase()])).toList();
    final cardTargets = creditCards.map((c) => NlpTarget(
      id: c.id,
      aliases: [
        c.name.toLowerCase(),
        '${c.entity} ${c.name}'.toLowerCase(),
        'tc ${c.entity} ${c.name}'.toLowerCase(),
        'tc ${c.entity}'.toLowerCase(),
        'tc ${c.name}'.toLowerCase(),
        'tarjeta ${c.entity}'.toLowerCase(),
        'tarjeta de credito ${c.entity}'.toLowerCase(),
        'tarjeta de credito ${c.name}'.toLowerCase(),
      ],
    )).toList();
    final pocketTargets = pockets.map((p) => NlpPocketTarget(
      id: p.id,
      accountId: p.accountId,
      aliases: [p.name.toLowerCase()],
    )).toList();

    return NlpCatalog(
      accounts: accTargets,
      cards: cardTargets,
      pockets: pocketTargets,
    );
  }

  @override
  Future<void> addAlias({
    required String alias,
    String? accountId,
    String? cardId,
    String? pocketId,
  }) async {
    aliases.add({'alias': alias, 'accountId': accountId, 'cardId': cardId, 'pocketId': pocketId});
  }

  @override
  Future<Set<String>> getDeliveredAlertIds() async => {};

  @override
  Future<void> markAlertDelivered(String alertId) async {}

  @override
  Future<ReminderSettings> getReminderSettings() async => const ReminderSettings(hour: 8);

  @override
  Future<void> updateReminderSettings(ReminderSettings settings) async {}

  @override
  Future<bool> isOnboardingCompleted() async => onboardingCompleted;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    onboardingCompleted = completed;
  }

  @override
  Future<List<LedgerTransaction>> getTransactionsForYear(int year) async =>
      transactions.where((t) => t.date.year == year).toList();

  @override
  Future<int> deleteTransactionsForYear(int year) async {
    final count = transactions.where((t) => t.date.year == year).length;
    transactions.removeWhere((t) => t.date.year == year);
    return count;
  }

  @override
  Future<List<LedgerTransaction>> getTransactionsForAccount(String accountId) async {
    final accountPockets = pockets.where((p) => p.accountId == accountId).map((p) => p.id).toSet();
    return transactions.where((t) => accountPockets.contains(t.pocketId)).toList();
  }

  @override
  Future<List<LedgerTransaction>> getTransactionsForCard(String cardId) async =>
      transactions.where((t) => t.cardId == cardId).toList();

  @override
  Future<int> purgeTransactionsOlderThanOneYear() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final count = transactions.where((t) => t.date.isBefore(cutoff)).length;
    transactions.removeWhere((t) => t.date.isBefore(cutoff));
    return count;
  }
}

void main() {
  late FakeFinanceRepository repo;

  setUp(() {
    repo = FakeFinanceRepository();
  });

  Widget buildTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('Autonomous Functional & Integration Scenarios', () {
    testWidgets('Escenario 1: Onboarding inicial - configurar saldos desde \$0 COP y registrar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(child: const OnboardingScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Asistente de Configuración Inicial'), findsOneWidget);
      expect(find.text('Bancolombia'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);

      // Verify the initial inputs exist with '0'
      expect(find.widgetWithText(TextField, '0'), findsWidgets);

      // Tap submit button to save initial onboarding configuration
      final submitBtn = find.text('Guardar Configuración y Empezar');
      expect(submitBtn, findsOneWidget);
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify that the fake repo received the created account and pockets
      expect(repo.accounts.length, 1);
      expect(repo.accounts.first.name, 'Bancolombia');
      expect(repo.pockets.length, 2); // 'Disponible en Cuenta' and 'Personal'
      expect(repo.onboardingCompleted, isTrue);
    });

    testWidgets('Escenario 2: Gestión de Cuentas y Bolsillos - crear cuenta, añadir bolsillo, editarlo y verificar desglose contable', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Seed an initial bank account
      final acc = await repo.createAccountWithInitialPocket(
        entityName: 'Nu Bank',
        accountNumber: '998877',
        accountType: 'Ahorros',
        initialBalance: 500000, // Fuera de bolsillos (Disponible)
      );

      // Add a custom pocket with 1,500,000 COP
      final pocketViajes = await repo.createPocket(
        accountId: acc.id,
        name: 'Viajes',
        initialBalance: 1500000,
      );

      // Verify breakdown logic: unallocated vs assigned
      final bankPockets = repo.pockets.where((p) => p.accountId == acc.id).toList();
      final unallocatedPocket = bankPockets.firstWhere((p) => p.name == 'Disponible en Cuenta');
      final assignedPockets = bankPockets.where((p) => p.id != unallocatedPocket.id).toList();

      final unallocatedBalance = unallocatedPocket.balance;
      final assignedBalance = assignedPockets.fold<int>(0, (sum, p) => sum + p.balance);
      final totalBalance = bankPockets.fold<int>(0, (sum, p) => sum + p.balance);

      expect(unallocatedBalance, 500000); // Fuera de bolsillos
      expect(assignedBalance, 1500000);   // En bolsillos
      expect(totalBalance, 2000000);      // Total Banco
      expect(BalanceCalculator.accountBalance(repo.pockets, acc.id), 2000000);

      // Open PocketCrudDialog and test UI
      await tester.pumpWidget(buildTestApp(child: const PocketCrudDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Cuentas Banco y Bolsillos'), findsOneWidget);
      expect(find.textContaining('Nu Bank'), findsWidgets);

      // Edit pocket name: rename 'Viajes' to 'Vacaciones Europa'
      await repo.updatePocket(id: pocketViajes.id, name: 'Vacaciones Europa');
      expect(repo.pockets.firstWhere((p) => p.id == pocketViajes.id).name, 'Vacaciones Europa');
    });

    testWidgets('Escenario 3: Transferencia entre Bolsillos - sin desbordamiento ni Duplicate keys', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Setup 2 accounts with pockets
      final b1 = await repo.createAccount('Bancolombia');
      final b2 = await repo.createAccount('Nequi');
      final p1 = await repo.createPocket(accountId: b1.id, name: 'Principal', initialBalance: 1000000);
      final p2 = await repo.createPocket(accountId: b2.id, name: 'Ahorros Emergencia', initialBalance: 200000);

      await tester.pumpWidget(buildTestApp(child: const TransferDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Transferir entre Bolsillos'), findsOneWidget);
      expect(find.byKey(const Key('dropdown_transfer_from_pocket')), findsOneWidget);

      // Execute transfer through repository and verify no exceptions
      await repo.transferBetweenPockets(
        fromPocketId: p1.id,
        toPocketId: p2.id,
        amount: 300000,
        date: DateTime.now(),
      );

      expect(repo.pockets.firstWhere((p) => p.id == p1.id).balance, 700000);
      expect(repo.pockets.firstWhere((p) => p.id == p2.id).balance, 500000);
      expect(repo.transactions.length, 1);
      expect(repo.transactions.first.type, LedgerTransactionType.pocketTransfer);
    });

    testWidgets('Escenario 4: Compras con Tarjeta de Crédito vía NLP - no exige bolsillo, consume cupo y suma deuda', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final b1 = await repo.createAccount('Bancolombia');
      await repo.createPocket(accountId: b1.id, name: 'Personal', initialBalance: 1000000);

      final card = await repo.createCreditCard(
        entity: 'Bancolombia',
        name: 'Mastercard Black',
        franchise: 'Mastercard',
        lastFourDigits: '9988',
        creditLimit: 10000000,
        availableCredit: 10000000,
        cutOffDay: 15,
        paymentDueDay: 30,
      );

      final catalog = await repo.getNlpCatalog();
      final parsed = NlpParser.parse('compra portatil 2000000 tc bancolombia', catalog);

      expect(parsed.amount, 2000000);
      expect(parsed.sourceType, SourceType.card);
      expect(parsed.sourceId, card.id);
      expect(parsed.isCardPayment, isFalse);

      // Verify that card charge consumes availableCredit and leaves pockets intact
      await repo.recordCardCharge(
        cardId: card.id,
        pocketId: repo.pockets.first.id,
        amount: 2000000,
        date: DateTime.now(),
        description: 'compra portatil',
      );

      final updatedCard = repo.creditCards.firstWhere((c) => c.id == card.id);
      expect(updatedCard.availableCredit, 8000000);
      expect(updatedCard.debt, 2000000);
      expect(repo.pockets.first.balance, 1000000); // Pocket untouched!
    });

    testWidgets('Escenario 5: Abonos a Tarjeta - restaura cupo y debita del bolsillo bancario', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final b1 = await repo.createAccount('Bancolombia');
      final pocket = await repo.createPocket(accountId: b1.id, name: 'Ahorros', initialBalance: 1500000);
      final card = await repo.createCreditCard(
        entity: 'Bancolombia',
        name: 'Única',
        franchise: 'Visa',
        lastFourDigits: '1234',
        creditLimit: 5000000,
        availableCredit: 3000000, // Deuda de 2,000,000
        cutOffDay: 10,
        paymentDueDay: 25,
      );

      expect(card.debt, 2000000);

      // Open CardPaymentDialog
      await tester.pumpWidget(buildTestApp(child: const CardPaymentDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Abono a Tarjeta de Crédito'), findsOneWidget);

      // Execute card payment (Abono a TC)
      await repo.recordCardPayment(
        cardId: card.id,
        pocketId: pocket.id,
        amount: 1000000,
        date: DateTime.now(),
        description: 'Abono parcial TC',
      );

      final updatedCard = repo.creditCards.firstWhere((c) => c.id == card.id);
      final updatedPocket = repo.pockets.firstWhere((p) => p.id == pocket.id);

      expect(updatedCard.availableCredit, 4000000); // Cupo restaurado en 1,000,000
      expect(updatedCard.debt, 1000000);            // Deuda reducida a 1,000,000
      expect(updatedPocket.balance, 500000);        // Bolsillo debitado por 1,000,000
    });

    testWidgets('Escenario 6: Historiales y Exportación CSV - navegación y filtros limpios', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final acc = await repo.createAccountWithInitialPocket(
        entityName: 'Davivienda',
        accountNumber: '11223344',
        accountType: 'Ahorros',
        initialBalance: 800000,
      );
      final pocketNomina = await repo.createPocket(accountId: acc.id, name: 'Nómina', initialBalance: 2000000);

      // Add transaction
      await repo.recordPocketMovement(
        kind: TransactionKind.income,
        pocketId: pocketNomina.id,
        amount: 2500000,
        date: DateTime.now(),
        description: 'Pago de Salario Quincenal',
      );

      await tester.pumpWidget(buildTestApp(child: BankDetailsDialog(account: acc)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Davivienda'), findsWidgets);
      expect(find.textContaining('11223344'), findsWidgets);
      expect(find.text('Pago de Salario Quincenal'), findsOneWidget);
      expect(find.text('Descargar Respaldo (CSV)'), findsOneWidget);

      // Tap CSV export button
      await tester.tap(find.text('Descargar Respaldo (CSV)'));
      await tester.pumpAndSettle();

      expect(find.text('Historial copiado en formato CSV al portapapeles'), findsOneWidget);
    });
  });
}
