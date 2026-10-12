import 'package:finanzas_personales/domain/services/nlp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = NlpCatalog(
  accounts: [
    NlpTarget(id: 'a-nequi', aliases: ['nequi']),
    NlpTarget(id: 'a-bancolombia', aliases: ['bancolombia']),
  ],
  cards: [
    NlpTarget(id: 'c-rappi', aliases: ['rappi', 'rappicard']),
    NlpTarget(id: 'c-unica', aliases: ['unica', 'bancolombia unica']),
  ],
  pockets: [
    NlpPocketTarget(id: 'p-personal', accountId: 'a-bancolombia', aliases: ['personal']),
    NlpPocketTarget(id: 'p-graficolor-nequi', accountId: 'a-nequi', aliases: ['graficolor']),
    NlpPocketTarget(id: 'p-favores', accountId: 'a-bancolombia', aliases: ['favores']),
  ],
);

void main() {
  group('NlpParser amounts', () {
    test('parses a plain number', () {
      expect(NlpParser.parse('15000 gasolina', _catalog).amount, 15000);
    });

    test('parses thousand separators and currency symbol', () {
      expect(NlpParser.parse('gasté 500.000 en mercado', _catalog).amount, 500000);
      expect(NlpParser.parse(r'pagué $1,250,000 arriendo', _catalog).amount, 1250000);
    });

    test('parses Colombian slang multipliers (barras, lucas, palos, media luca)', () {
      expect(NlpParser.parse('45 barras almuerzo', _catalog).amount, 45000);
      expect(NlpParser.parse('50 lucas cine', _catalog).amount, 50000);
      expect(NlpParser.parse('2 palos moto', _catalog).amount, 2000000);
      expect(NlpParser.parse('media luca tinto', _catalog).amount, 500);
      expect(NlpParser.parse('15k empanadas', _catalog).amount, 15000);
    });

    test('reports a missing amount', () {
      final result = NlpParser.parse('gasolina tarjeta rappi', _catalog);
      expect(result.amount, isNull);
      expect(result.issues, contains(ParseIssue.missingAmount));
    });
  });

  group('NlpParser operation', () {
    test('defaults to an expense', () {
      expect(NlpParser.parse('15000 gasolina', _catalog).kind, TransactionKind.expense);
    });

    test('detects income keywords, with or without accents', () {
      for (final phrase in ['Ingresaron 500000 nequi', 'recibí 20000 nequi', 'consignaron 300000 nequi', 'me pagaron 100000 nequi']) {
        expect(NlpParser.parse(phrase, _catalog).kind, TransactionKind.income, reason: phrase);
      }
    });

    test('detects card payment (abono a TC) from phrases', () {
      for (final phrase in [
        'pago tc 100000 rappi',
        'abono tc unica 50000',
        'pagar tarjeta rappi 80000',
        'abono a tarjeta de credito rappi 150000',
      ]) {
        final parsed = NlpParser.parse(phrase, _catalog);
        expect(parsed.isCardPayment, isTrue, reason: phrase);
        expect(parsed.sourceType, SourceType.card, reason: phrase);
        expect(parsed.issues, isNot(contains(ParseIssue.incomeToCard)));
      }
    });
  });

  group('NlpParser source and pocket', () {
    test('spec example 1: card expense', () {
      final result = NlpParser.parse('15000 gasolina tarjeta de credito rappi', _catalog);
      expect(result.amount, 15000);
      expect(result.kind, TransactionKind.expense);
      expect(result.sourceType, SourceType.card);
      expect(result.sourceId, 'c-rappi');
      expect(result.isCardPayment, isFalse);
      expect(result.issues, isEmpty);
    });

    test('spec example 2: income into a pocket of an account', () {
      final result = NlpParser.parse('Ingresaron 500000 graficolor nequi', _catalog);
      expect(result.amount, 500000);
      expect(result.kind, TransactionKind.income);
      expect(result.sourceType, SourceType.account);
      expect(result.sourceId, 'a-nequi');
      expect(result.pocketId, 'p-graficolor-nequi');
      expect(result.issues, isEmpty);
    });

    test('longest alias wins when aliases overlap', () {
      final result = NlpParser.parse('20000 almuerzo tarjeta bancolombia unica', _catalog);
      expect(result.sourceType, SourceType.card);
      expect(result.sourceId, 'c-unica');
    });

    test('unspecified source automatically defaults to primary account', () {
      final result = NlpParser.parse('15000 gasolina', _catalog);
      expect(result.sourceType, SourceType.account);
      expect(result.sourceId, _catalog.accounts.first.id);
      expect(result.issues, isNot(contains(ParseIssue.unknownSource)));
    });

    test('unknown source is reported when no accounts exist', () {
      const emptyCatalog = NlpCatalog(accounts: [], cards: [], pockets: []);
      final result = NlpParser.parse('15000 gasolina', emptyCatalog);
      expect(result.sourceId, isNull);
      expect(result.issues, contains(ParseIssue.unknownSource));
    });

    test('detects credit card by expanded alias with tc and tarjeta prefixes', () {
      final res1 = NlpParser.parse('15000 gasolina tc rappi', _catalog);
      expect(res1.sourceType, SourceType.card);
      expect(res1.sourceId, 'c-rappi');

      final res2 = NlpParser.parse('20000 almuerzo tarjeta unica', _catalog);
      expect(res2.sourceType, SourceType.card);
      expect(res2.sourceId, 'c-unica');

      final res3 = NlpParser.parse('30000 cena tarjeta de credito rappi', _catalog);
      expect(res3.sourceType, SourceType.card);
      expect(res3.sourceId, 'c-rappi');
    });

    test('detects explicit account even when card shares entity name', () {
      const catalogWithSharedEntity = NlpCatalog(
        accounts: [NlpTarget(id: 'a-bancolombia', aliases: ['bancolombia'])],
        cards: [NlpTarget(id: 'c-bancolombia', aliases: ['bancolombia', 'unica'])],
        pockets: [],
      );
      final res = NlpParser.parse('40000 transporte bancolombia', catalogWithSharedEntity);
      expect(res.sourceType, SourceType.account);
      expect(res.sourceId, 'a-bancolombia');

      final resTc = NlpParser.parse('40000 transporte tc bancolombia', catalogWithSharedEntity);
      expect(resTc.sourceType, SourceType.card);
      expect(resTc.sourceId, 'c-bancolombia');
    });

    test('account and card both mentioned without card hint is ambiguous', () {
      final result = NlpParser.parse('30000 mercado nequi rappi', _catalog);
      expect(result.issues, contains(ParseIssue.ambiguousSource));
    });

    test('income into a card is flagged if not a payment', () {
      final result = NlpParser.parse('ingresaron 100000 rappi', _catalog);
      expect(result.issues, contains(ParseIssue.incomeToCard));
    });

    test('pocket is filtered by the resolved account', () {
      final result = NlpParser.parse('10000 favores bancolombia', _catalog);
      expect(result.pocketId, 'p-favores');
    });

    test('pocket belonging to another account is not selected', () {
      final result = NlpParser.parse('10000 graficolor bancolombia', _catalog);
      expect(result.pocketId, isNull);
    });

    test('card payment resolves funding pocket', () {
      final result = NlpParser.parse('pago tc rappi 50000 de personal', _catalog);
      expect(result.isCardPayment, isTrue);
      expect(result.sourceType, SourceType.card);
      expect(result.sourceId, 'c-rappi');
      expect(result.pocketId, 'p-personal');
    });

    test('empty input reports missing amount and defaults source', () {
      final result = NlpParser.parse('   ', _catalog);
      expect(result.issues, contains(ParseIssue.missingAmount));
      expect(result.sourceType, SourceType.account);
      expect(result.sourceId, _catalog.accounts.first.id);
    });
  });
}
