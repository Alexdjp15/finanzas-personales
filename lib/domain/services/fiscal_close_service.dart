import 'dart:convert';

import 'package:csv/csv.dart';

import '../models/ledger_transaction.dart';
import '../models/models.dart';

class FiscalCloseResult {
  const FiscalCloseResult({
    required this.jsonExport,
    required this.csvExport,
    required this.closedTransactionIds,
    required this.openingPockets,
    required this.openingCards,
  });

  final String jsonExport;
  final String csvExport;

  /// Ids the data layer must delete once the export has been saved.
  final List<String> closedTransactionIds;

  /// Balances that become the starting point of the new year.
  final List<Pocket> openingPockets;
  final List<CreditCard> openingCards;
}

class FiscalCloseService {
  const FiscalCloseService._();

  /// Pure computation of the annual close. Deleting the transactions is left
  /// to the caller so nothing is erased before the export is safely stored.
  static FiscalCloseResult close({
    required int year,
    required List<Pocket> pockets,
    required List<CreditCard> cards,
    required List<LedgerTransaction> transactions,
    required DateTime exportedAt,
  }) {
    final closed = transactions.where((t) => t.date.year == year).toList();

    return FiscalCloseResult(
      jsonExport: const JsonEncoder.withIndent('  ').convert({
        'year': year,
        'exportedAt': exportedAt.toIso8601String(),
        'pockets': [
          for (final p in pockets)
            {'id': p.id, 'accountId': p.accountId, 'name': p.name, 'balance': p.balance},
        ],
        'cards': [
          for (final c in cards)
            {
              'id': c.id,
              'name': c.name,
              'creditLimit': c.creditLimit,
              'availableCredit': c.availableCredit,
            },
        ],
        'transactions': [for (final t in closed) _transactionToMap(t)],
      }),
      csvExport: _toCsv(closed),
      closedTransactionIds: [for (final t in closed) t.id],
      openingPockets: List.unmodifiable(pockets),
      openingCards: List.unmodifiable(cards),
    );
  }

  static Map<String, Object?> _transactionToMap(LedgerTransaction t) => {
        'id': t.id,
        'date': _formatDate(t.date),
        'type': t.type.name,
        'amount': t.amount,
        'pocketId': t.pocketId,
        'cardId': t.cardId,
        'description': t.description,
      };

  static String _toCsv(List<LedgerTransaction> transactions) {
    final rows = <List<Object?>>[
      ['id', 'date', 'type', 'amount', 'pocketId', 'cardId', 'description'],
      for (final t in transactions)
        [t.id, _formatDate(t.date), t.type.name, t.amount, t.pocketId ?? '', t.cardId ?? '', t.description],
    ];
    // "\n" avoids doubled carriage returns when saved on Windows.
    return Csv(lineDelimiter: '\n').encode(rows);
  }

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
