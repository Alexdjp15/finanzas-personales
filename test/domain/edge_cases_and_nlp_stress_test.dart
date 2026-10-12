import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_personales/domain/errors.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/balance_calculator.dart';
import 'package:finanzas_personales/domain/services/credit_card_service.dart';
import 'package:finanzas_personales/domain/services/nlp_parser.dart';

void main() {
  group('a) Saldos Negativos en Bolsillos', () {
    const accountId = 'acc_bancolombia';
    const pocketInitialBalance = 50000;
    const expenseAmount = 120000;

    final pocketA = Pocket(
      id: 'p_personal',
      accountId: accountId,
      name: 'Personal',
      balance: pocketInitialBalance,
    );

    final pocketAvailable = Pocket(
      id: 'p_disponible',
      accountId: accountId,
      name: 'Disponible en Cuenta',
      balance: 100000,
    );

    test('un gasto de \$120.000 sobre un saldo de \$50.000 resulta exactamente en -\$70.000 COP', () {
      final updatedPocket = pocketA.copyWith(balance: pocketA.balance - expenseAmount);

      expect(updatedPocket.balance, -70000);
    });

    test('BalanceCalculator mantiene la coherencia matemática total con saldos negativos', () {
      final updatedPocketA = pocketA.copyWith(balance: pocketA.balance - expenseAmount);
      final pockets = [updatedPocketA, pocketAvailable];

      // Saldo de la cuenta: -70.000 + 100.000 = 30.000 COP
      final totalAccountBalance = BalanceCalculator.accountBalance(pockets, accountId);
      expect(totalAccountBalance, 30000);

      // Activos totales: 30.000 COP
      expect(BalanceCalculator.totalAssets(pockets), 30000);

      // Patrimonio neto con pasivos en 0: 30.000 COP
      expect(BalanceCalculator.netWorth(pockets, []), 30000);

      // Patrimonio neto con deuda de tarjeta de $50.000: 30.000 - 50.000 = -20.000 COP
      const cardWithDebt = CreditCard(
        id: 'c1',
        entity: 'Bancolombia',
        name: 'Única',
        franchise: 'Visa',
        lastFourDigits: '1234',
        creditLimit: 5000000,
        availableCredit: 4950000, // Deuda de 50.000 COP
        cutOffDay: 10,
        paymentDueDay: 25,
      );
      expect(cardWithDebt.debt, 50000);
      expect(BalanceCalculator.netWorth(pockets, [cardWithDebt]), -20000);
    });

    test('transferencia por \$120.000 desde un bolsillo de \$50.000 deja el origen en -\$70.000 sin alterar el total del banco', () {
      final pockets = [pocketA, pocketAvailable];
      final initialBankTotal = BalanceCalculator.accountBalance(pockets, accountId); // 150.000 COP

      final transferResult = BalanceCalculator.transferBetweenPockets(
        pockets: pockets,
        fromPocketId: pocketA.id,
        toPocketId: pocketAvailable.id,
        amount: expenseAmount,
      );

      final resultPocketA = transferResult.firstWhere((p) => p.id == pocketA.id);
      final resultPocketAvailable = transferResult.firstWhere((p) => p.id == pocketAvailable.id);

      expect(resultPocketA.balance, -70000);
      expect(resultPocketAvailable.balance, 220000);
      expect(BalanceCalculator.accountBalance(transferResult, accountId), initialBankTotal);
    });
  });

  group('b) Validación contra Sobrepagos a Tarjetas de Crédito', () {
    const totalLimit = 5000000;
    const accumulatedDebt = 1146164;
    // Cupo disponible = 5.000.000 - 1.146.164 = 3.853.836 COP
    const availableCredit = totalLimit - accumulatedDebt;

    const creditCard = CreditCard(
      id: 'c_bancolombia',
      entity: 'Bancolombia',
      name: 'Mastercard Black',
      franchise: 'Mastercard',
      lastFourDigits: '9805',
      creditLimit: totalLimit,
      availableCredit: availableCredit,
      cutOffDay: 10,
      paymentDueDay: 25,
    );

    const pocketFunding = Pocket(
      id: 'p_banco',
      accountId: 'acc1',
      name: 'Ahorros',
      balance: 2000000,
    );

    test('comprobar que la deuda calculada de la tarjeta es exactamente \$1.146.164 COP', () {
      expect(creditCard.debt, 1146164);
    });

    test('intentar abonar \$1.500.000 COP a una tarjeta con deuda de \$1.146.164 lanza excepción paymentExceedsDebt', () {
      const overpaymentAmount = 1500000;

      expect(
        () => CreditCardService.applyPayment(
          card: creditCard,
          pocket: pocketFunding,
          amount: overpaymentAmount,
        ),
        throwsA(
          isA<DomainException>()
              .having((e) => e.code, 'code', DomainErrorCode.paymentExceedsDebt)
              .having((e) => e.details, 'details', creditCard.id),
        ),
      );
    });

    test('sobrepago por incluso 1 peso (\$1.146.165 COP) es rechazado', () {
      expect(
        () => CreditCardService.applyPayment(
          card: creditCard,
          pocket: pocketFunding,
          amount: accumulatedDebt + 1,
        ),
        throwsA(isA<DomainException>().having((e) => e.code, 'code', DomainErrorCode.paymentExceedsDebt)),
      );
    });

    test('abono exacto por el valor de la deuda (\$1.146.164 COP) liquida la deuda por completo', () {
      final result = CreditCardService.applyPayment(
        card: creditCard,
        pocket: pocketFunding,
        amount: accumulatedDebt,
      );

      expect(result.card.debt, 0);
      expect(result.card.availableCredit, totalLimit);
      expect(result.pocket.balance, pocketFunding.balance - accumulatedDebt);
    });

    test('abono parcial legítimo (ej. \$500.000 COP) reduce la deuda y restaura cupo adecuadamente', () {
      const partialPayment = 500000;
      final result = CreditCardService.applyPayment(
        card: creditCard,
        pocket: pocketFunding,
        amount: partialPayment,
      );

      expect(result.card.debt, accumulatedDebt - partialPayment); // 646.164 COP
      expect(result.card.availableCredit, availableCredit + partialPayment); // 4.353.836 COP
      expect(result.pocket.balance, pocketFunding.balance - partialPayment);
    });

    test('abono con monto cero o negativo es rechazado con invalidAmount', () {
      expect(
        () => CreditCardService.applyPayment(
          card: creditCard,
          pocket: pocketFunding,
          amount: 0,
        ),
        throwsA(isA<DomainException>().having((e) => e.code, 'code', DomainErrorCode.invalidAmount)),
      );

      expect(
        () => CreditCardService.applyPayment(
          card: creditCard,
          pocket: pocketFunding,
          amount: -50000,
        ),
        throwsA(isA<DomainException>().having((e) => e.code, 'code', DomainErrorCode.invalidAmount)),
      );
    });
  });

  group('c) Casos de Estrés y Variaciones Lingüísticas en NlpParser', () {
    const accountBancolombia = NlpTarget(id: 'acc_bancolombia', aliases: ['bancolombia']);
    const accountNequi = NlpTarget(id: 'acc_nequi', aliases: ['nequi']);

    const cardBancolombia = NlpTarget(id: 'card_bancolombia', aliases: ['bancolombia', 'unica', 'bancolombia unica']);
    const cardRappi = NlpTarget(id: 'card_rappi', aliases: ['rappi', 'rappicard']);

    const pocketGraficolor = NlpPocketTarget(
      id: 'pock_graficolor',
      accountId: 'acc_nequi',
      aliases: ['graficolor'],
    );
    const pocketPersonal = NlpPocketTarget(
      id: 'pock_personal',
      accountId: 'acc_bancolombia',
      aliases: ['personal'],
    );

    final catalog = NlpCatalog(
      accounts: [accountBancolombia, accountNequi],
      cards: [cardBancolombia, cardRappi],
      pockets: [pocketGraficolor, pocketPersonal],
    );

    test('parsear ingresos con puntuación y separadores: "recibí 1.500.000 abono graficolor nequi"', () {
      final parsed = NlpParser.parse('recibí 1.500.000 abono graficolor nequi', catalog);

      expect(parsed.kind, TransactionKind.income);
      expect(parsed.amount, 1500000);
      expect(parsed.sourceType, SourceType.account);
      expect(parsed.sourceId, 'acc_nequi');
      expect(parsed.pocketId, 'pock_graficolor');
      expect(parsed.isCardPayment, isFalse);
      expect(parsed.issues, isEmpty);
    });

    test('parsear gastos sin entidad ni categoría explícita: "almuerzo 25000" preselecciona cuenta principal', () {
      final parsed = NlpParser.parse('almuerzo 25000', catalog);

      expect(parsed.kind, TransactionKind.expense);
      expect(parsed.amount, 25000);
      expect(parsed.sourceType, SourceType.account);
      expect(parsed.sourceId, 'acc_bancolombia'); // Primera cuenta disponible en catálogo
      expect(parsed.isCardPayment, isFalse);
      // No contiene errores bloqueantes como missingAmount o unknownSource
      expect(parsed.issues.contains(ParseIssue.missingAmount), isFalse);
      expect(parsed.issues.contains(ParseIssue.unknownSource), isFalse);
    });

    test('parsear abonos directos a tarjeta: "pago tc bancolombia 150000" identifica isCardPayment y tarjeta', () {
      final parsed = NlpParser.parse('pago tc bancolombia 150000', catalog);

      expect(parsed.isCardPayment, isTrue);
      expect(parsed.sourceType, SourceType.card);
      expect(parsed.sourceId, 'card_bancolombia');
      expect(parsed.amount, 150000);
      expect(parsed.issues.contains(ParseIssue.missingAmount), isFalse);
    });

    test('parsear combinaciones con signos de moneda y espacios irregulares: "\$  350.000  mercado exito"', () {
      final parsed = NlpParser.parse('\$  350.000  mercado exito', catalog);

      expect(parsed.amount, 350000);
      expect(parsed.kind, TransactionKind.expense);
      expect(parsed.sourceType, SourceType.account);
      expect(parsed.sourceId, 'acc_bancolombia');
      expect(parsed.issues.contains(ParseIssue.missingAmount), isFalse);
    });

    test('variaciones de signos y espacios: "\$15000 taxi aeropuerto"', () {
      final parsed = NlpParser.parse('\$15000 taxi aeropuerto', catalog);

      expect(parsed.amount, 15000);
      expect(parsed.kind, TransactionKind.expense);
    });

    test('variaciones de ingresos: "recibi \$ 2.800.000 de salario en cuenta bancolombia"', () {
      final parsed = NlpParser.parse('recibi \$ 2.800.000 de salario en cuenta bancolombia', catalog);

      expect(parsed.amount, 2800000);
      expect(parsed.kind, TransactionKind.income);
      expect(parsed.sourceType, SourceType.account);
      expect(parsed.sourceId, 'acc_bancolombia');
      expect(parsed.isCardPayment, isFalse);
    });

    test('variación de abono a tarjeta con prefijo abreviado: "abono tc rappi 500.000"', () {
      final parsed = NlpParser.parse('abono tc rappi 500.000', catalog);

      expect(parsed.isCardPayment, isTrue);
      expect(parsed.sourceType, SourceType.card);
      expect(parsed.sourceId, 'card_rappi');
      expect(parsed.amount, 500000);
    });

    test('variación de compra con tarjeta de crédito extensa: "compra tarjeta de credito 450000 bancolombia"', () {
      final parsed = NlpParser.parse('compra tarjeta de credito 450000 bancolombia', catalog);

      expect(parsed.isCardPayment, isFalse);
      expect(parsed.kind, TransactionKind.expense);
      expect(parsed.sourceType, SourceType.card);
      expect(parsed.sourceId, 'card_bancolombia');
      expect(parsed.amount, 450000);
      // Las compras con tarjeta no restringen bolsillo en el parser
      expect(parsed.pocketId, isNull);
    });

    test('espacios en blanco extremos y múltiples tabuladores: "   gasto     \$    120.000    en    supermercado   "', () {
      final parsed = NlpParser.parse('   gasto     \$    120.000    en    supermercado   ', catalog);

      expect(parsed.amount, 120000);
      expect(parsed.kind, TransactionKind.expense);
      expect(parsed.sourceType, SourceType.account);
    });
  });
}
