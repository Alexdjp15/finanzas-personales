import '../errors.dart';
import '../models/models.dart';

/// Pure balance rules for accounts, pockets and net worth.
class BalanceCalculator {
  const BalanceCalculator._();

  /// An account balance is, by definition, the sum of its pockets.
  static Cop accountBalance(List<Pocket> pockets, String accountId) => pockets
      .where((pocket) => pocket.accountId == accountId)
      .fold(0, (sum, pocket) => sum + pocket.balance);

  static Cop totalAssets(List<Pocket> pockets) =>
      pockets.fold(0, (sum, pocket) => sum + pocket.balance);

  /// Credit card debt is a liability and is never mixed into account balances.
  static Cop totalDebt(List<CreditCard> cards) =>
      cards.fold(0, (sum, card) => sum + card.debt);

  static Cop netWorth(List<Pocket> pockets, List<CreditCard> cards) =>
      totalAssets(pockets) - totalDebt(cards);

  /// Moves money between two pockets of the same account; the bank balance
  /// does not change.
  static List<Pocket> transferBetweenPockets({
    required List<Pocket> pockets,
    required String fromPocketId,
    required String toPocketId,
    required Cop amount,
  }) {
    if (amount <= 0) throw DomainException(DomainErrorCode.invalidAmount, '$amount');
    final from = pockets.firstWhere((pocket) => pocket.id == fromPocketId);
    final to = pockets.firstWhere((pocket) => pocket.id == toPocketId);
    if (from.accountId != to.accountId) {
      throw const DomainException(DomainErrorCode.pocketsInDifferentAccounts);
    }
    // Pockets are allowed to go negative on purpose: the user prefers to
    // record real life spending over blocking it.
    return [
      for (final pocket in pockets)
        if (pocket.id == from.id)
          pocket.copyWith(balance: pocket.balance - amount)
        else if (pocket.id == to.id)
          pocket.copyWith(balance: pocket.balance + amount)
        else
          pocket,
    ];
  }
}
