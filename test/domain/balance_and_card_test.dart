import 'package:finanzas_personales/domain/errors.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/balance_calculator.dart';
import 'package:finanzas_personales/domain/services/credit_card_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _pocketPersonal = Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 1000000);
const _pocketBusiness = Pocket(id: 'p2', accountId: 'a1', name: 'Graficolor', balance: 500000);
const _pocketOtherAccount = Pocket(id: 'p3', accountId: 'a2', name: 'Personal', balance: 200000);

const _card = CreditCard(
  id: 'c1',
  entity: 'Bancolombia',
  name: 'Única',
  franchise: 'Mastercard',
  lastFourDigits: '9805',
  creditLimit: 10000000,
  availableCredit: 4475912,
  cutOffDay: 10,
  paymentDueDay: 25,
);

void main() {
  group('BalanceCalculator', () {
    final pockets = [_pocketPersonal, _pocketBusiness, _pocketOtherAccount];

    test('account balance is the exact sum of its pockets', () {
      expect(BalanceCalculator.accountBalance(pockets, 'a1'), 1500000);
      expect(BalanceCalculator.accountBalance(pockets, 'a2'), 200000);
    });

    test('account without pockets has zero balance', () {
      expect(BalanceCalculator.accountBalance(pockets, 'none'), 0);
    });

    test('total assets equals the sum of all account balances', () {
      expect(BalanceCalculator.totalAssets(pockets), 1700000);
    });

    test('debt is kept separate from assets and net worth subtracts it', () {
      expect(BalanceCalculator.totalDebt([_card]), 5524088);
      expect(BalanceCalculator.netWorth(pockets, [_card]), 1700000 - 5524088);
    });

    test('transfer between pockets of the same account keeps account total', () {
      final result = BalanceCalculator.transferBetweenPockets(
        pockets: pockets,
        fromPocketId: 'p1',
        toPocketId: 'p2',
        amount: 300000,
      );
      expect(BalanceCalculator.accountBalance(result, 'a1'), 1500000);
      expect(result.firstWhere((p) => p.id == 'p1').balance, 700000);
      expect(result.firstWhere((p) => p.id == 'p2').balance, 800000);
    });

    test('transfer across different accounts is rejected', () {
      expect(
        () => BalanceCalculator.transferBetweenPockets(
          pockets: pockets,
          fromPocketId: 'p1',
          toPocketId: 'p3',
          amount: 1,
        ),
        throwsA(isA<DomainException>().having((e) => e.code, 'code', DomainErrorCode.pocketsInDifferentAccounts)),
      );
    });

    test('transfer above the available balance leaves the pocket negative', () {
      final result = BalanceCalculator.transferBetweenPockets(
        pockets: pockets,
        fromPocketId: 'p1',
        toPocketId: 'p2',
        amount: 1200000,
      );
      expect(result.firstWhere((p) => p.id == 'p1').balance, -200000);
      expect(BalanceCalculator.accountBalance(result, 'a1'), 1500000);
    });

    test('non positive amounts are rejected', () {
      for (final amount in [0, -5]) {
        expect(
          () => BalanceCalculator.transferBetweenPockets(
            pockets: pockets,
            fromPocketId: 'p1',
            toPocketId: 'p2',
            amount: amount,
          ),
          throwsA(isA<DomainException>().having((e) => e.code, 'code', DomainErrorCode.invalidAmount)),
        );
      }
    });
  });

  group('CreditCardService', () {
    test('a charge reduces the available credit and leaves pockets untouched', () {
      final updated = CreditCardService.applyCharge(_card, 15000);
      expect(updated.availableCredit, 4475912 - 15000);
      expect(updated.debt, _card.debt + 15000);
    });

    test('a charge above the available credit is rejected', () {
      expect(
        () => CreditCardService.applyCharge(_card, 4475913),
        throwsA(isA<DomainException>().having((e) => e.code, 'code', DomainErrorCode.insufficientCredit)),
      );
    });

    test('a charge equal to the available credit is accepted', () {
      expect(CreditCardService.applyCharge(_card, 4475912).availableCredit, 0);
    });

    test('a payment deducts from the pocket and restores the credit', () {
      final result = CreditCardService.applyPayment(card: _card, pocket: _pocketPersonal, amount: 400000);
      expect(result.pocket.balance, 600000);
      expect(result.card.availableCredit, 4475912 + 400000);
    });

    test('a payment above the pocket balance leaves the pocket negative', () {
      final result = CreditCardService.applyPayment(card: _card, pocket: _pocketPersonal, amount: 1200000);
      expect(result.pocket.balance, -200000);
      expect(result.card.availableCredit, 4475912 + 1200000);
    });

    test('a payment above the current debt is rejected', () {
      const richPocket = Pocket(id: 'p9', accountId: 'a1', name: 'Personal', balance: 9000000);
      expect(
        () => CreditCardService.applyPayment(card: _card, pocket: richPocket, amount: 5524089),
        throwsA(isA<DomainException>().having((e) => e.code, 'code', DomainErrorCode.paymentExceedsDebt)),
      );
    });
  });
}
