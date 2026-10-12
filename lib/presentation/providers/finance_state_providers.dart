import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/ledger_transaction.dart';
import '../../domain/models/models.dart';
import '../../domain/services/alert_scheduler.dart';
import '../../domain/services/balance_calculator.dart';
import '../../domain/services/nlp_parser.dart';
import 'supabase_providers.dart';

final accountTransactionsProvider = FutureProvider.family<List<LedgerTransaction>, String>((ref, accountId) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getTransactionsForAccount(accountId);
});

final cardTransactionsProvider = FutureProvider.family<List<LedgerTransaction>, String>((ref, cardId) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getTransactionsForCard(cardId);
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getAccounts();
});

final pocketsProvider = FutureProvider<List<Pocket>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getPockets();
});

final creditCardsProvider = FutureProvider<List<CreditCard>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getCreditCards();
});

final recurringPaymentsProvider = FutureProvider<List<RecurringPayment>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getRecurringPayments();
});

final reminderSettingsProvider = FutureProvider<ReminderSettings>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getReminderSettings();
});

final deliveredAlertsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getDeliveredAlertIds();
});

final onboardingStatusProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.isOnboardingCompleted();
});

final nlpCatalogProvider = FutureProvider<NlpCatalog>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getNlpCatalog();
});

/// Computes active and upcoming alerts for cards and recurring subscriptions
final activeAlertsProvider = FutureProvider<List<AppAlert>>((ref) async {
  final cards = await ref.watch(creditCardsProvider.future);
  final payments = await ref.watch(recurringPaymentsProvider.future);
  final settings = await ref.watch(reminderSettingsProvider.future);
  final delivered = await ref.watch(deliveredAlertsProvider.future);

  final now = DateTime.now();
  final events = <AlertEvent>[
    for (final c in cards) ...AlertScheduler.eventsForCard(c, now),
    for (final p in payments) ...AlertScheduler.eventsForRecurring(p, now),
  ];

  final allAlerts = AlertScheduler.generate(events, settings);
  return AlertScheduler.dueAlerts(allAlerts, now, deliveredIds: delivered);
});

class DashboardTotals {
  const DashboardTotals({
    required this.totalAssets,
    required this.totalDebt,
    required this.netWorth,
  });

  final Cop totalAssets;
  final Cop totalDebt;
  final Cop netWorth;
}

final dashboardTotalsProvider = Provider<AsyncValue<DashboardTotals>>((ref) {
  final pocketsAsync = ref.watch(pocketsProvider);
  final cardsAsync = ref.watch(creditCardsProvider);

  if (pocketsAsync.hasError) return AsyncValue.error(pocketsAsync.error!, pocketsAsync.stackTrace!);
  if (cardsAsync.hasError) return AsyncValue.error(cardsAsync.error!, cardsAsync.stackTrace!);
  if (!pocketsAsync.hasValue || !cardsAsync.hasValue) return const AsyncValue.loading();

  final pockets = pocketsAsync.value!;
  final cards = cardsAsync.value!;

  final assets = BalanceCalculator.totalAssets(pockets);
  final debt = BalanceCalculator.totalDebt(cards);
  final net = BalanceCalculator.netWorth(pockets, cards);

  return AsyncValue.data(DashboardTotals(totalAssets: assets, totalDebt: debt, netWorth: net));
});

final recentTransactionsProvider = FutureProvider<List<LedgerTransaction>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getTransactionsForYear(DateTime.now().year);
});

void invalidateFinanceProviders(WidgetRef ref) {
  ref.invalidate(accountsProvider);
  ref.invalidate(pocketsProvider);
  ref.invalidate(creditCardsProvider);
  ref.invalidate(recurringPaymentsProvider);
  ref.invalidate(activeAlertsProvider);
  ref.invalidate(nlpCatalogProvider);
  ref.invalidate(recentTransactionsProvider);
}

/// Controls whether the application is in dark mode (default) or light mode.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Which top section the dashboard shows: numeric summary or chart.
enum DashboardView { summary, chart }

class DashboardViewNotifier extends Notifier<DashboardView> {
  @override
  DashboardView build() => DashboardView.summary;

  void set(DashboardView view) => state = view;
}

final dashboardViewProvider =
    NotifierProvider<DashboardViewNotifier, DashboardView>(DashboardViewNotifier.new);
