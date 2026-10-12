import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/alert_scheduler.dart';
import 'package:finanzas_personales/domain/services/date_utils.dart';
import 'package:finanzas_personales/domain/services/recurring_payment_processor.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringPayment _payment({
  int day = 15,
  DateTime? start,
  DateTime? lastProcessed,
}) =>
    RecurringPayment(
      id: 'r1',
      name: 'Gemini',
      amount: 85000,
      dayOfMonth: day,
      startDate: start ?? DateTime(2026, 1, 1),
      methodType: PaymentMethodType.creditCard,
      methodId: 'c1',
      pocketId: 'p1',
      autoDeduct: true,
      lastProcessedDate: lastProcessed,
    );

void main() {
  group('date utils', () {
    test('clamps day 31 to the last day of shorter months', () {
      expect(clampedDate(2026, 2, 31), DateTime(2026, 2, 28));
      expect(clampedDate(2028, 2, 31), DateTime(2028, 2, 29));
      expect(clampedDate(2026, 4, 31), DateTime(2026, 4, 30));
    });

    test('next occurrence is on or after the reference date', () {
      expect(nextOccurrence(15, DateTime(2026, 3, 15)), DateTime(2026, 3, 15));
      expect(nextOccurrence(15, DateTime(2026, 3, 16)), DateTime(2026, 4, 15));
      expect(nextOccurrence(10, DateTime(2026, 12, 20)), DateTime(2027, 1, 10));
    });
  });

  group('RecurringPaymentProcessor', () {
    test('returns every unprocessed due date up to today', () {
      final dates = RecurringPaymentProcessor.pendingDueDates(
        _payment(start: DateTime(2026, 1, 1)),
        DateTime(2026, 3, 20),
      );
      expect(dates, [DateTime(2026, 1, 15), DateTime(2026, 2, 15), DateTime(2026, 3, 15)]);
    });

    test('is idempotent: already processed dates are not returned again', () {
      final dates = RecurringPaymentProcessor.pendingDueDates(
        _payment(lastProcessed: DateTime(2026, 2, 15)),
        DateTime(2026, 3, 20),
      );
      expect(dates, [DateTime(2026, 3, 15)]);
    });

    test('does not return a charge whose day has not arrived yet', () {
      final dates = RecurringPaymentProcessor.pendingDueDates(
        _payment(start: DateTime(2026, 3, 1)),
        DateTime(2026, 3, 14),
      );
      expect(dates, isEmpty);
    });

    test('skips a due date that falls before the start date', () {
      final dates = RecurringPaymentProcessor.pendingDueDates(
        _payment(start: DateTime(2026, 3, 20)),
        DateTime(2026, 4, 30),
      );
      expect(dates, [DateTime(2026, 4, 15)]);
    });

    test('day 31 is charged on the last day of February', () {
      final dates = RecurringPaymentProcessor.pendingDueDates(
        _payment(day: 31, start: DateTime(2026, 2, 1)),
        DateTime(2026, 2, 28),
      );
      expect(dates, [DateTime(2026, 2, 28)]);
    });
  });

  group('AlertScheduler', () {
    final event = AlertEvent(
      sourceId: 'c1',
      kind: AlertKind.creditCardDue,
      label: 'RappiCard',
      dueDate: DateTime(2026, 5, 25),
    );
    const settings = ReminderSettings(hour: 8, minute: 30);

    test('creates reminders 2 and 1 days before at the configured time', () {
      final alerts = AlertScheduler.generate([event], settings);
      expect(alerts.map((a) => a.triggerAt), [
        DateTime(2026, 5, 23, 8, 30),
        DateTime(2026, 5, 24, 8, 30),
      ]);
      expect(alerts.map((a) => a.daysBefore), [2, 1]);
    });

    test('alert ids are deterministic so duplicates cannot be generated', () {
      final first = AlertScheduler.generate([event], settings);
      final second = AlertScheduler.generate([event], settings);
      expect(first.map((a) => a.id), second.map((a) => a.id));
      expect(first.map((a) => a.id).toSet().length, 2);
    });

    test('only alerts already triggered and not yet overdue are due', () {
      final alerts = AlertScheduler.generate([event], settings);
      expect(AlertScheduler.dueAlerts(alerts, DateTime(2026, 5, 23, 8, 29)), isEmpty);
      expect(
        AlertScheduler.dueAlerts(alerts, DateTime(2026, 5, 23, 8, 30)).map((a) => a.daysBefore),
        [2],
      );
      expect(
        AlertScheduler.dueAlerts(alerts, DateTime(2026, 5, 24, 9, 0)).map((a) => a.daysBefore),
        [2, 1],
      );
      expect(AlertScheduler.dueAlerts(alerts, DateTime(2026, 5, 26)), isEmpty);
    });

    test('already delivered alerts are excluded', () {
      final alerts = AlertScheduler.generate([event], settings);
      final due = AlertScheduler.dueAlerts(
        alerts,
        DateTime(2026, 5, 24, 9),
        deliveredIds: {alerts.first.id},
      );
      expect(due.map((a) => a.daysBefore), [1]);
    });

    test('builds credit card events from the payment due day', () {
      const card = CreditCard(
        id: 'c1',
        entity: 'Rappi',
        name: 'RappiCard',
        franchise: 'Visa',
        lastFourDigits: '0001',
        creditLimit: 5000000,
        availableCredit: 3853836,
        cutOffDay: 5,
        paymentDueDay: 25,
      );
      final events = AlertScheduler.eventsForCard(card, DateTime(2026, 5, 10));
      expect(events.single.dueDate, DateTime(2026, 5, 25));
      expect(events.single.kind, AlertKind.creditCardDue);
    });

    test('builds subscription events from the next billing day', () {
      final events = AlertScheduler.eventsForRecurring(_payment(day: 15), DateTime(2026, 5, 20));
      expect(events.single.dueDate, DateTime(2026, 6, 15));
      expect(events.single.kind, AlertKind.recurringPayment);
    });

    test('a subscription that has not started yet alerts for its first charge', () {
      final events = AlertScheduler.eventsForRecurring(
        _payment(day: 15, start: DateTime(2026, 8, 1)),
        DateTime(2026, 5, 20),
      );
      expect(events.single.dueDate, DateTime(2026, 8, 15));
    });
  });
}
