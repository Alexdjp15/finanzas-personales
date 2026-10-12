import 'models.dart';

enum LedgerTransactionType { income, expense, cardCharge, cardPayment, pocketTransfer }

/// One recorded movement. Exactly the fields needed by the annual export.
class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    this.pocketId,
    this.cardId,
    this.description = '',
  });

  final String id;
  final DateTime date;
  final LedgerTransactionType type;
  final Cop amount;
  final String? pocketId;
  final String? cardId;
  final String description;
}
