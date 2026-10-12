import 'package:finanzas_personales/domain/models/ledger_transaction.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/fiscal_close_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

const _pockets = [
  Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 1200000),
  Pocket(id: 'p2', accountId: 'a1', name: 'Graficolor', balance: -50000),
];
const _cards = [
  CreditCard(
    id: 'c1',
    entity: 'Bancolombia',
    name: 'Única',
    franchise: 'Mastercard',
    lastFourDigits: '9805',
    creditLimit: 10000000,
    availableCredit: 4475912,
    cutOffDay: 10,
    paymentDueDay: 25,
  ),
];

final _transactions = [
  LedgerTransaction(
    id: 't1',
    date: DateTime(2026, 3, 5),
    type: LedgerTransactionType.expense,
    amount: 15000,
    pocketId: 'p1',
    description: 'gasolina',
  ),
  LedgerTransaction(
    id: 't2',
    date: DateTime(2026, 12, 31),
    type: LedgerTransactionType.income,
    amount: 500000,
    pocketId: 'p2',
    description: 'abono, "Graficolor"',
  ),
  LedgerTransaction(
    id: 't3',
    date: DateTime(2025, 12, 31),
    type: LedgerTransactionType.cardCharge,
    amount: 9000,
    cardId: 'c1',
    description: 'previous year',
  ),
];

FiscalCloseResult _close() => FiscalCloseService.close(
      year: 2026,
      pockets: _pockets,
      cards: _cards,
      transactions: _transactions,
      exportedAt: DateTime.utc(2027, 1, 1),
    );

void main() {
  group('FiscalCloseService', () {
    test('closes only transactions of the requested year', () {
      expect(_close().closedTransactionIds, ['t1', 't2']);
    });

    test('json export contains the year, balances and only that year transactions', () {
      final json = jsonDecode(_close().jsonExport) as Map<String, dynamic>;
      expect(json['year'], 2026);
      expect(json['exportedAt'], '2027-01-01T00:00:00.000Z');
      expect((json['transactions'] as List).map((t) => t['id']), ['t1', 't2']);
      expect((json['pockets'] as List).first, containsPair('balance', 1200000));
      expect((json['cards'] as List).first, containsPair('availableCredit', 4475912));
    });

    test('csv export has a header, escapes commas and quotes, and keeps integers', () {
      final lines = _close().csvExport.split('\n');
      expect(lines.first, 'id,date,type,amount,pocketId,cardId,description');
      expect(lines[1], 't1,2026-03-05,expense,15000,p1,,gasolina');
      expect(lines[2], 't2,2026-12-31,income,500000,p2,,"abono, ""Graficolor"""');
      expect(lines.length, 3);
    });

    test('opening balances equal the current balances, including negatives', () {
      final result = _close();
      expect(result.openingPockets.map((p) => p.balance), [1200000, -50000]);
      expect(result.openingCards.single.availableCredit, 4475912);
    });

    test('a year without transactions still exports and closes nothing', () {
      final result = FiscalCloseService.close(
        year: 2030,
        pockets: _pockets,
        cards: _cards,
        transactions: _transactions,
        exportedAt: DateTime.utc(2031, 1, 1),
      );
      expect(result.closedTransactionIds, isEmpty);
      expect(result.csvExport.split('\n'), hasLength(1));
    });
  });
}
