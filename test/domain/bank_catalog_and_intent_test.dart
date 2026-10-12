import 'package:finanzas_personales/domain/models/bank_catalog.dart';
import 'package:finanzas_personales/domain/services/nlp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = NlpCatalog(
  accounts: [
    NlpTarget(id: 'a-nequi', aliases: ['nequi']),
    NlpTarget(id: 'a-bancolombia', aliases: ['bancolombia']),
    NlpTarget(id: 'a-davivienda', aliases: ['davivienda']),
    NlpTarget(id: 'a-daviplata', aliases: ['daviplata']),
    NlpTarget(id: 'a-nu', aliases: ['nu', 'nubank']),
  ],
  cards: [
    NlpTarget(id: 'c-bancolombia', aliases: ['tc bancolombia', 'bancolombia']),
    NlpTarget(id: 'c-nu', aliases: ['tc nu', 'nu', 'nubank']),
    NlpTarget(id: 'c-rappi', aliases: ['rappi', 'rappicard']),
  ],
  pockets: [
    NlpPocketTarget(id: 'p-ahorros', accountId: 'a-bancolombia', aliases: ['ahorros']),
    NlpPocketTarget(id: 'p-mercado', accountId: 'a-bancolombia', aliases: ['mercado']),
    NlpPocketTarget(id: 'p-disponible', accountId: 'a-bancolombia', aliases: ['disponible']),
    NlpPocketTarget(id: 'p-arriendo', accountId: 'a-bancolombia', aliases: ['arriendo']),
  ],
);

void main() {
  group('BankCatalog Definitions & Matching', () {
    test('contains 14 predefined items including "otro"', () {
      expect(BankCatalog.items.length, 14);
      expect(BankCatalog.banks.length, 14);
    });

    test('findById retrieves the exact bank or null for unknown', () {
      final bancolombia = BankCatalog.findById('bancolombia');
      expect(bancolombia, isNotNull);
      expect(bancolombia!.name, 'Bancolombia');
      expect(bancolombia.assetPath, 'assets/icons/banks/bancolombia.png');

      final unknown = BankCatalog.findById('non_existent_bank');
      expect(unknown, isNull);
    });

    test('bestMatch resolves Colombian banks and aliases accurately', () {
      expect(BankCatalog.bestMatch('Bancolombia').id, 'bancolombia');
      expect(BankCatalog.bestMatch('bancolombia sa').id, 'bancolombia');
      expect(BankCatalog.bestMatch('banco de colombia').id, 'bancolombia');

      expect(BankCatalog.bestMatch('Nequi').id, 'nequi');
      expect(BankCatalog.bestMatch('Davivienda').id, 'davivienda');
      expect(BankCatalog.bestMatch('Daviplata').id, 'daviplata');
      expect(BankCatalog.bestMatch('Nu').id, 'nu');
      expect(BankCatalog.bestMatch('Nubank').id, 'nu');
      expect(BankCatalog.bestMatch('Lulo Bank').id, 'lulo');
      expect(BankCatalog.bestMatch('Banco de Bogotá').id, 'bogota');
      expect(BankCatalog.bestMatch('BBVA').id, 'bbva');
      expect(BankCatalog.bestMatch('Scotiabank Colpatria').id, 'colpatria');
      expect(BankCatalog.bestMatch('Banco Falabella').id, 'falabella');
      expect(BankCatalog.bestMatch('RappiPay').id, 'rappipay');
      expect(BankCatalog.bestMatch('Dale!').id, 'dale');
      expect(BankCatalog.bestMatch('Revolut').id, 'revolut');
    });

    test('bestMatch falls back to "otro" for unknown custom banks', () {
      final other = BankCatalog.bestMatch('Banco Agrario de Colombia');
      expect(other.id, 'otro');
      expect(other.isCustom, isTrue);
    });
  });

  group('NlpParser Intent Engine - Creation Intents', () {
    test('detects CreatePocketIntent', () {
      final parsed = NlpParser.parse('crear bolsillo viajes 200000 en bancolombia', _catalog);
      expect(parsed.intent, isA<CreatePocketIntent>());
      final intent = parsed.intent as CreatePocketIntent;
      expect(intent.name, 'Viajes');
      expect(intent.initialBalance, 200000);
      expect(intent.accountName, 'bancolombia');
    });

    test('detects CreateAccountIntent', () {
      final parsed = NlpParser.parse('crear cuenta ahorros davivienda', _catalog);
      expect(parsed.intent, isA<CreateAccountIntent>());
      final intent = parsed.intent as CreateAccountIntent;
      expect(intent.name, 'Ahorros davivienda');
    });

    test('detects CreateCardIntent with credit limit', () {
      final parsed = NlpParser.parse('crear tarjeta nu cupo 3000000', _catalog);
      expect(parsed.intent, isA<CreateCardIntent>());
      final intent = parsed.intent as CreateCardIntent;
      expect(intent.name.toLowerCase(), contains('nu'));
      expect(intent.creditLimit, 3000000);
    });

    test('detects CreateRecurringIntent with billing day', () {
      final parsed = NlpParser.parse('crear suscripcion netflix 45000 cada 15', _catalog);
      expect(parsed.intent, isA<CreateRecurringIntent>());
      final intent = parsed.intent as CreateRecurringIntent;
      expect(intent.name, 'Netflix');
      expect(intent.amount, 45000);
      expect(intent.dayOfMonth, 15);
    });

    test('detects CreateRecurringIntent with Colombian slang and day filtering: "crea suscripción Netflix 45 barras cada 15 nequi"', () {
      final parsed = NlpParser.parse('crea suscripción Netflix 45 barras cada 15 nequi', _catalog);
      expect(parsed.intent, isA<CreateRecurringIntent>());
      final intent = parsed.intent as CreateRecurringIntent;
      expect(intent.name, 'Netflix');
      expect(intent.amount, 45000);
      expect(intent.dayOfMonth, 15);
      expect(intent.sourceName.toLowerCase(), 'nequi');
      expect(parsed.amount, 45000);
    });
  });

  group('NlpParser Intent Engine - Transfer Intents', () {
    test('detects TransferIntent with pasar de X a Y', () {
      final parsed = NlpParser.parse('pasar 50000 de ahorros a mercado', _catalog);
      expect(parsed.intent, isA<TransferIntent>());
      final intent = parsed.intent as TransferIntent;
      expect(intent.amount, 50000);
      expect(intent.fromPocketName, 'ahorros');
      expect(intent.toPocketName, 'mercado');
    });

    test('detects TransferIntent with transferir de X a Y', () {
      final parsed = NlpParser.parse('transferir 80000 de disponible a arriendo', _catalog);
      expect(parsed.intent, isA<TransferIntent>());
      final intent = parsed.intent as TransferIntent;
      expect(intent.amount, 80000);
      expect(intent.fromPocketName, 'disponible');
      expect(intent.toPocketName, 'arriendo');
    });
  });

  group('NlpParser Intent Engine - Colloquial Colombian Phrasing', () {
    test('parses "me gasté 45000 en almuerzo nequi"', () {
      final parsed = NlpParser.parse('me gasté 45000 en almuerzo nequi', _catalog);
      expect(parsed.kind, TransactionKind.expense);
      expect(parsed.amount, 45000);
      expect(parsed.sourceId, 'a-nequi');
      expect(parsed.intent, isA<ExpenseIntent>());
    });

    test('parses "tanqueé 50000 con tc nu"', () {
      final parsed = NlpParser.parse('tanqueé 50000 con tc nu', _catalog);
      expect(parsed.kind, TransactionKind.expense);
      expect(parsed.amount, 50000);
      expect(parsed.sourceType, SourceType.card);
      expect(parsed.sourceId, 'c-nu');
      expect(parsed.intent, isA<ExpenseIntent>());
    });

    test('parses "me consignaron 1200000 de quincena en bancolombia"', () {
      final parsed = NlpParser.parse('me consignaron 1200000 de quincena en bancolombia', _catalog);
      expect(parsed.kind, TransactionKind.income);
      expect(parsed.amount, 1200000);
      expect(parsed.sourceId, 'a-bancolombia');
      expect(parsed.intent, isA<IncomeIntent>());
    });

    test('parses "me cayó la prima 800000 davivienda"', () {
      final parsed = NlpParser.parse('me cayó la prima 800000 davivienda', _catalog);
      expect(parsed.kind, TransactionKind.income);
      expect(parsed.amount, 800000);
      expect(parsed.sourceId, 'a-davivienda');
      expect(parsed.intent, isA<IncomeIntent>());
    });

    test('parses "aboné 200000 a la tarjeta bancolombia"', () {
      final parsed = NlpParser.parse('aboné 200000 a la tarjeta bancolombia', _catalog);
      expect(parsed.isCardPayment, isTrue);
      expect(parsed.amount, 200000);
      expect(parsed.sourceId, 'c-bancolombia');
      expect(parsed.intent, isA<CardPaymentIntent>());
      final cardIntent = parsed.intent as CardPaymentIntent;
      expect(cardIntent.cardId, 'c-bancolombia');
    });
  });
}
