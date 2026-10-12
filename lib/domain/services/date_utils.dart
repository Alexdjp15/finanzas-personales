import '../errors.dart';

/// Builds a date clamped to the last day of the month, so a payment set on
/// day 31 is still charged in shorter months.
DateTime clampedDate(int year, int month, int day) {
  _assertValidDay(day);
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > lastDayOfMonth ? lastDayOfMonth : day);
}

/// First occurrence of [dayOfMonth] that is on or after [from] (date only).
DateTime nextOccurrence(int dayOfMonth, DateTime from) {
  final reference = dateOnly(from);
  final candidate = clampedDate(reference.year, reference.month, dayOfMonth);
  if (!candidate.isBefore(reference)) return candidate;
  return clampedDate(reference.year, reference.month + 1, dayOfMonth);
}

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

void _assertValidDay(int day) {
  if (day < 1 || day > 31) {
    throw DomainException(DomainErrorCode.invalidDayOfMonth, '$day');
  }
}
