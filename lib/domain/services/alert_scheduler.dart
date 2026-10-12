import '../models/models.dart';
import 'date_utils.dart';

class AlertScheduler {
  const AlertScheduler._();

  static List<AppAlert> generate(List<AlertEvent> events, ReminderSettings settings) {
    return [
      for (final event in events)
        for (final days in settings.daysBefore)
          AppAlert(
            id: _alertId(event, days),
            event: event,
            daysBefore: days,
            triggerAt: DateTime(
              event.dueDate.year,
              event.dueDate.month,
              event.dueDate.day - days,
              settings.hour,
              settings.minute,
            ),
          ),
    ];
  }

  /// Alerts that already fired and whose due day has not fully passed.
  /// The due day itself still counts so a late opening of the app shows it.
  static List<AppAlert> dueAlerts(
    List<AppAlert> alerts,
    DateTime now, {
    Set<String> deliveredIds = const {},
  }) {
    return alerts.where((alert) {
      final dueDay = dateOnly(alert.event.dueDate);
      final expiresAt = DateTime(dueDay.year, dueDay.month, dueDay.day + 1);
      return !alert.triggerAt.isAfter(now) &&
          now.isBefore(expiresAt) &&
          !deliveredIds.contains(alert.id);
    }).toList();
  }

  static List<AlertEvent> eventsForCard(CreditCard card, DateTime now) => [
        AlertEvent(
          sourceId: card.id,
          kind: AlertKind.creditCardDue,
          label: card.name,
          dueDate: nextOccurrence(card.paymentDueDay, now),
        ),
      ];

  static List<AlertEvent> eventsForRecurring(RecurringPayment payment, DateTime now) {
    final start = dateOnly(payment.startDate);
    final reference = dateOnly(now).isBefore(start) ? start : now;
    return [
      AlertEvent(
        sourceId: payment.id,
        kind: AlertKind.recurringPayment,
        label: payment.name,
        dueDate: nextOccurrence(payment.dayOfMonth, reference),
      ),
    ];
  }

  static String _alertId(AlertEvent event, int daysBefore) {
    final due = event.dueDate;
    final month = due.month.toString().padLeft(2, '0');
    final day = due.day.toString().padLeft(2, '0');
    return '${event.kind.name}:${event.sourceId}:${due.year}-$month-$day:$daysBefore';
  }
}
