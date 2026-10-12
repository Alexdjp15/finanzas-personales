/// All monetary amounts are whole COP pesos stored as [int] to avoid
/// floating point rounding errors (spec decision: COP only).
typedef Cop = int;

class Account {
  const Account({
    required this.id,
    required this.name,
    this.accountNumber = '',
  });

  final String id;
  final String name;
  final String accountNumber;

  Account copyWith({
    String? name,
    String? accountNumber,
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        accountNumber: accountNumber ?? this.accountNumber,
      );
}

/// A logical sub-balance that belongs to exactly one [Account].
class Pocket {
  const Pocket({
    required this.id,
    required this.accountId,
    required this.name,
    required this.balance,
  });

  final String id;
  final String accountId;
  final String name;
  final Cop balance;

  Pocket copyWith({
    String? name,
    Cop? balance,
  }) =>
      Pocket(
        id: id,
        accountId: accountId,
        name: name ?? this.name,
        balance: balance ?? this.balance,
      );
}

class CreditCard {
  const CreditCard({
    required this.id,
    required this.entity,
    required this.name,
    required this.franchise,
    required this.lastFourDigits,
    required this.creditLimit,
    required this.availableCredit,
    required this.cutOffDay,
    required this.paymentDueDay,
  });

  final String id;
  final String entity;
  final String name;
  final String franchise;
  final String lastFourDigits;
  final Cop creditLimit;
  final Cop availableCredit;
  final int cutOffDay;
  final int paymentDueDay;

  /// Amount currently owed to the bank.
  Cop get debt => creditLimit - availableCredit;

  CreditCard copyWith({
    String? entity,
    String? name,
    String? franchise,
    String? lastFourDigits,
    Cop? creditLimit,
    Cop? availableCredit,
    int? cutOffDay,
    int? paymentDueDay,
  }) =>
      CreditCard(
        id: id,
        entity: entity ?? this.entity,
        name: name ?? this.name,
        franchise: franchise ?? this.franchise,
        lastFourDigits: lastFourDigits ?? this.lastFourDigits,
        creditLimit: creditLimit ?? this.creditLimit,
        availableCredit: availableCredit ?? this.availableCredit,
        cutOffDay: cutOffDay ?? this.cutOffDay,
        paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      );
}

enum PaymentMethodType { accountPocket, creditCard }

/// Monthly fixed payment (subscription). Only monthly frequency is modelled.
class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.dayOfMonth,
    required this.startDate,
    required this.methodType,
    required this.methodId,
    required this.pocketId,
    required this.autoDeduct,
    this.lastProcessedDate,
  });

  final String id;
  final String name;
  final Cop amount;
  final int dayOfMonth;
  final DateTime startDate;
  final PaymentMethodType methodType;

  /// Pocket id when [methodType] is accountPocket, card id otherwise.
  final String methodId;

  /// Pocket the expense is categorised under.
  final String pocketId;
  final bool autoDeduct;
  final DateTime? lastProcessedDate;

  RecurringPayment copyWith({
    String? name,
    Cop? amount,
    int? dayOfMonth,
    DateTime? startDate,
    PaymentMethodType? methodType,
    String? methodId,
    String? pocketId,
    bool? autoDeduct,
    DateTime? lastProcessedDate,
  }) =>
      RecurringPayment(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        startDate: startDate ?? this.startDate,
        methodType: methodType ?? this.methodType,
        methodId: methodId ?? this.methodId,
        pocketId: pocketId ?? this.pocketId,
        autoDeduct: autoDeduct ?? this.autoDeduct,
        lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
      );
}

enum AlertKind { recurringPayment, creditCardDue }

class AlertEvent {
  const AlertEvent({
    required this.sourceId,
    required this.kind,
    required this.label,
    required this.dueDate,
  });

  final String sourceId;
  final AlertKind kind;
  final String label;
  final DateTime dueDate;
}

class AppAlert {
  const AppAlert({
    required this.id,
    required this.event,
    required this.daysBefore,
    required this.triggerAt,
  });

  /// Deterministic id so the same reminder is never generated twice.
  final String id;
  final AlertEvent event;
  final int daysBefore;
  final DateTime triggerAt;
}

/// User preference: hour of day at which reminders fire and how many days
/// ahead of the due date.
class ReminderSettings {
  const ReminderSettings({
    this.hour = 8,
    this.minute = 0,
    this.daysBefore = const [2, 1],
  });

  final int hour;
  final int minute;
  final List<int> daysBefore;
}
