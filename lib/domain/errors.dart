/// Base type for every rule violation raised by the pure domain layer.
///
/// The presentation layer translates these into Spanish user messages, so the
/// domain keeps only machine-readable codes.
class DomainException implements Exception {
  const DomainException(this.code, [this.details = '']);

  final DomainErrorCode code;
  final String details;

  @override
  String toString() => 'DomainException(${code.name}${details.isEmpty ? '' : ': $details'})';
}

enum DomainErrorCode {
  invalidAmount,
  insufficientCredit,
  paymentExceedsDebt,
  pocketsInDifferentAccounts,
  invalidDayOfMonth,
}
