import '../models/models.dart';
import 'date_utils.dart';

class RecurringPaymentProcessor {
  const RecurringPaymentProcessor._();

  /// Due dates not yet processed, up to and including [today].
  ///
  /// Idempotent: anything on or before `lastProcessedDate` is skipped, so
  /// running the server cron twice never charges twice.
  static List<DateTime> pendingDueDates(RecurringPayment payment, DateTime today) {
    final limit = dateOnly(today);
    final start = dateOnly(payment.startDate);
    final lastProcessed = payment.lastProcessedDate == null ? null : dateOnly(payment.lastProcessedDate!);
    final result = <DateTime>[];

    var month = DateTime(start.year, start.month);
    while (true) {
      final due = clampedDate(month.year, month.month, payment.dayOfMonth);
      if (due.isAfter(limit)) break;
      final isAfterStart = !due.isBefore(start);
      final isUnprocessed = lastProcessed == null || due.isAfter(lastProcessed);
      if (isAfterStart && isUnprocessed) result.add(due);
      month = DateTime(month.year, month.month + 1);
    }
    return result;
  }
}
