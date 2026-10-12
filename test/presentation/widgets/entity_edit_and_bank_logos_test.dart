import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/domain/models/bank_catalog.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/presentation/providers/finance_state_providers.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/bank_details_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/card_details_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/credit_card_crud_dialog.dart';
import 'package:finanzas_personales/presentation/widgets/app_logo_widget.dart';
import 'package:finanzas_personales/presentation/widgets/bank_logo_avatar.dart';

void main() {
  group('AppLogoWidget and BankLogoAvatar', () {
    testWidgets('AppLogoWidget renders without error and falls back on error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogoWidget(size: 32),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppLogoWidget), findsOneWidget);
    });

    testWidgets('BankLogoAvatar renders for predefined bank and custom bank', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BankLogoAvatar(bankName: 'Bancolombia', size: 40),
                BankLogoAvatar(bankName: 'Cooperativa Financiera', size: 40),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BankLogoAvatar), findsNWidgets(2));
    });

    testWidgets('BankSelectorField opens picker and selects bank', (tester) async {
      BankItem selected = BankCatalog.banks.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => BankSelectorField(
                selectedBank: selected,
                onBankSelected: (bank) => setState(() => selected = bank),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(BankCatalog.banks.first.name), findsOneWidget);

      // Tap to open picker
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.text('Seleccionar Entidad'), findsOneWidget);
      expect(find.text('Nequi'), findsOneWidget);

      // Select Nequi
      await tester.tap(find.text('Nequi'));
      await tester.pumpAndSettle();

      expect(selected.id, 'nequi');
      expect(find.text('Nequi'), findsOneWidget);
    });
  });

  group('BankDetailsDialog Entity Editing Flow', () {
    testWidgets('renders bank logo avatar and opens edit account dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const account = Account(id: 'acc1', name: 'Bancolombia', accountNumber: '123456789');
      const pockets = [
        Pocket(id: 'p1', accountId: 'acc1', name: 'Disponible en Cuenta', balance: 500000),
        Pocket(id: 'p2', accountId: 'acc1', name: 'Viajes', balance: 250000),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pocketsProvider.overrideWith((ref) => Future.value(pockets)),
            accountTransactionsProvider('acc1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: BankDetailsDialog(account: account)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header bank avatar and account name
      expect(find.byType(BankLogoAvatar), findsWidgets);
      expect(find.text('Bancolombia'), findsWidgets);

      // Tap edit account button
      final editAccountBtn = find.byTooltip('Editar Cuenta Banco');
      expect(editAccountBtn, findsOneWidget);
      await tester.tap(editAccountBtn);
      await tester.pumpAndSettle();

      // Edit account dialog opens with prefilled details
      expect(find.text('Editar Cuenta Banco'), findsOneWidget);
      expect(find.text('123456789'), findsOneWidget);
      expect(find.text('500000'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Tap edit pocket button on 'Viajes' pocket
      final editPocketButtons = find.byTooltip('Editar Bolsillo');
      expect(editPocketButtons, findsWidgets);
      await tester.tap(editPocketButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Editar Bolsillo'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });
  });

  group('CardDetailsDialog Entity Editing Flow', () {
    testWidgets('renders bank logo avatar and opens edit card dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const card = CreditCard(
        id: 'c1',
        entity: 'Nu',
        name: 'Moradita',
        franchise: 'Mastercard',
        lastFourDigits: '9876',
        creditLimit: 4000000,
        availableCredit: 3200000,
        cutOffDay: 12,
        paymentDueDay: 25,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardTransactionsProvider('c1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CardDetailsDialog(card: card)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header avatar and card title
      expect(find.byType(BankLogoAvatar), findsWidgets);
      expect(find.text('Nu Moradita'), findsWidgets);

      // Tap edit card button
      final editCardBtn = find.byTooltip('Editar Tarjeta');
      expect(editCardBtn, findsOneWidget);
      await tester.tap(editCardBtn);
      await tester.pumpAndSettle();

      // Verify edit dialog open with pre-filled fields
      expect(find.text('Editar Tarjeta de Crédito'), findsOneWidget);
      expect(find.text('Moradita'), findsOneWidget);
      expect(find.text('9876'), findsOneWidget);
      expect(find.text('4000000'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });
  });

  group('CreditCardCrudDialog In-Place Editing', () {
    testWidgets('displays list with edit icon and clicking it populates form in edit mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const cards = [
        CreditCard(
          id: 'card_demo',
          entity: 'Davivienda',
          name: 'G-Zero',
          franchise: 'Visa',
          lastFourDigits: '1122',
          creditLimit: 5000000,
          availableCredit: 4500000,
          cutOffDay: 18,
          paymentDueDay: 28,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            creditCardsProvider.overrideWith((ref) => Future.value(cards)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CreditCardCrudDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Davivienda G-Zero (*1122)'), findsOneWidget);
      expect(find.byTooltip('Editar tarjeta'), findsOneWidget);

      // Tap edit button on the card item
      await tester.tap(find.byTooltip('Editar tarjeta'));
      await tester.pumpAndSettle();

      // Form is now shown in edit mode
      expect(find.text('Editar Tarjeta de Crédito'), findsOneWidget);
      expect(find.text('Actualizar Tarjeta'), findsOneWidget);
      expect(find.text('G-Zero'), findsOneWidget);
      expect(find.text('1122'), findsOneWidget);

      // Cancel edit mode
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Tarjeta de Crédito'), findsNothing);
      expect(find.text('Registrar Nueva Tarjeta'), findsOneWidget);
    });
  });
}
