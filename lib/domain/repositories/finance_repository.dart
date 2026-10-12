import '../models/ledger_transaction.dart';
import '../models/models.dart';
import '../services/nlp_parser.dart';

abstract class FinanceRepository {
  // --- Accounts & Pockets ---
  Future<List<Account>> getAccounts();
  Future<Account> createAccount(String name, {String accountNumber = ''});
  Future<Account> createAccountWithInitialPocket({
    required String entityName,
    String accountNumber = '',
    required String accountType,
    required Cop initialBalance,
  });
  Future<void> updateAccount({
    required String id,
    required String name,
    String accountNumber = '',
    Cop? adjustBalanceOutsidePockets,
  });
  Future<void> deleteAccount(String id);

  Future<List<Pocket>> getPockets();
  Future<Pocket> createPocket({
    required String accountId,
    required String name,
    required Cop initialBalance,
  });
  Future<void> updatePocket({
    required String id,
    required String name,
    Cop? balance,
  });
  Future<void> deletePocket(String id);

  // --- Credit Cards ---
  Future<List<CreditCard>> getCreditCards();
  Future<CreditCard> createCreditCard({
    required String entity,
    required String name,
    required String franchise,
    required String lastFourDigits,
    required Cop creditLimit,
    required Cop availableCredit,
    required int cutOffDay,
    required int paymentDueDay,
  });
  Future<void> updateCreditCard(CreditCard card);
  Future<void> deleteCreditCard(String id);

  // --- Transactions / RPC Operations ---
  Future<String> recordPocketMovement({
    required TransactionKind kind,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  });

  Future<String> recordCardCharge({
    required String cardId,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  });

  Future<String> recordCardPayment({
    required String cardId,
    required String pocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  });

  Future<String> transferBetweenPockets({
    required String fromPocketId,
    required String toPocketId,
    required Cop amount,
    required DateTime date,
    String description = '',
  });

  // --- Recurring Payments ---
  Future<List<RecurringPayment>> getRecurringPayments();
  Future<RecurringPayment> createRecurringPayment({
    required String name,
    required Cop amount,
    required int dayOfMonth,
    required DateTime startDate,
    required PaymentMethodType methodType,
    required String methodId,
    required String pocketId,
    required bool autoDeduct,
  });
  Future<void> updateRecurringPayment(RecurringPayment payment);
  Future<void> deleteRecurringPayment(String id);

  // --- NLP Catalog & Aliases ---
  Future<NlpCatalog> getNlpCatalog();
  Future<void> addAlias({
    required String alias,
    String? accountId,
    String? cardId,
    String? pocketId,
  });

  // --- Alerts & User Settings ---
  Future<Set<String>> getDeliveredAlertIds();
  Future<void> markAlertDelivered(String alertId);

  Future<ReminderSettings> getReminderSettings();
  Future<void> updateReminderSettings(ReminderSettings settings);

  Future<bool> isOnboardingCompleted();
  Future<void> setOnboardingCompleted(bool completed);

  // --- Fiscal Close & Retention ---
  Future<List<LedgerTransaction>> getTransactionsForYear(int year);
  Future<int> deleteTransactionsForYear(int year);
  Future<List<LedgerTransaction>> getTransactionsForAccount(String accountId);
  Future<List<LedgerTransaction>> getTransactionsForCard(String cardId);
  Future<int> purgeTransactionsOlderThanOneYear();
}
