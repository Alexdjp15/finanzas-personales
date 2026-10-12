import '../models/models.dart';

/// One wedge of the distribution chart.
class DistributionSlice {
  const DistributionSlice({
    required this.label,
    required this.amount,
    required this.percentage,
  });

  final String label;
  final Cop amount;

  /// Share of the positive total, in the range 0..100.
  final double percentage;
}

class DistributionResult {
  const DistributionResult({
    required this.slices,
    required this.total,
    required this.excludedNegativeCount,
  });

  final List<DistributionSlice> slices;
  final Cop total;

  /// Entries with a zero or negative balance cannot be drawn in a pie; they
  /// are reported so the UI can explain why they are missing.
  final int excludedNegativeCount;

  bool get isEmpty => slices.isEmpty;
}

enum CreditUsageLevel { healthy, moderate, critical }

class DashboardVisuals {
  const DashboardVisuals._();

  static DistributionResult byPocket(List<Pocket> pockets) {
    return _build([for (final p in pockets) MapEntry(p.name, p.balance)]);
  }

  static DistributionResult byAccount(List<Account> accounts, List<Pocket> pockets) {
    final entries = <MapEntry<String, Cop>>[];
    for (final account in accounts) {
      final sum = pockets
          .where((p) => p.accountId == account.id)
          .fold<Cop>(0, (acc, p) => acc + p.balance);
      entries.add(MapEntry(account.name, sum));
    }
    return _build(entries);
  }

  static DistributionResult _build(List<MapEntry<String, Cop>> entries) {
    final positive = entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final excluded = entries.length - positive.length;
    final total = positive.fold<Cop>(0, (sum, e) => sum + e.value);

    return DistributionResult(
      slices: [
        for (final e in positive)
          DistributionSlice(
            label: e.key,
            amount: e.value,
            percentage: total == 0 ? 0 : e.value * 100 / total,
          ),
      ],
      total: total,
      excludedNegativeCount: excluded,
    );
  }

  /// Fraction of the credit limit currently used, clamped to 0..1.
  static double creditUsageRatio(CreditCard card) {
    if (card.creditLimit <= 0) return 0;
    return (card.debt / card.creditLimit).clamp(0.0, 1.0);
  }

  /// Green below 30 %, yellow from 30 % up to and including 70 %, red above.
  static CreditUsageLevel creditUsageLevel(double ratio) {
    if (ratio < 0.30) return CreditUsageLevel.healthy;
    if (ratio <= 0.70) return CreditUsageLevel.moderate;
    return CreditUsageLevel.critical;
  }
}
