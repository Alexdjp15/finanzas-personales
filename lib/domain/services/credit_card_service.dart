import '../errors.dart';
import '../models/models.dart';

class CardPaymentResult {
  const CardPaymentResult({required this.card, required this.pocket});

  final CreditCard card;
  final Pocket pocket;
}

class CreditCardService {
  const CreditCardService._();

  /// A card charge only consumes credit; no account pocket moves until the
  /// card is paid.
  static CreditCard applyCharge(CreditCard card, Cop amount) {
    _assertPositive(amount);
    if (amount > card.availableCredit) {
      throw DomainException(DomainErrorCode.insufficientCredit, card.id);
    }
    return card.copyWith(availableCredit: card.availableCredit - amount);
  }

  /// Pays the card from an account pocket and restores the available credit.
  static CardPaymentResult applyPayment({
    required CreditCard card,
    required Pocket pocket,
    required Cop amount,
  }) {
    _assertPositive(amount);
    if (amount > card.debt) {
      throw DomainException(DomainErrorCode.paymentExceedsDebt, card.id);
    }
    return CardPaymentResult(
      card: card.copyWith(availableCredit: card.availableCredit + amount),
      pocket: pocket.copyWith(balance: pocket.balance - amount),
    );
  }

  static void _assertPositive(Cop amount) {
    if (amount <= 0) throw DomainException(DomainErrorCode.invalidAmount, '$amount');
  }
}
