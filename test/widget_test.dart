import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/nlp_parser.dart';
import 'package:finanzas_personales/presentation/providers/finance_state_providers.dart';
import 'package:finanzas_personales/presentation/screens/dashboard_screen.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/bank_details_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/card_details_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/credit_card_crud_dialog.dart';
import 'package:finanzas_personales/presentation/screens/dialogs/nlp_entry_dialog.dart';
import 'package:finanzas_personales/presentation/screens/login_screen.dart';
import 'package:finanzas_personales/presentation/screens/onboarding_screen.dart';
import 'package:finanzas_personales/presentation/utils/app_theme.dart';
import 'package:finanzas_personales/presentation/widgets/charts/pocket_distribution_chart.dart';

void main() {
  testWidgets('LoginScreen smoke test: displays form elements and button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Iniciar Sesión'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Correo o Usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('OnboardingScreen renders initial wizard form', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    expect(find.text('Asistente de Configuración Inicial'), findsOneWidget);
    expect(find.text('Cuentas Banco y Bolsillos'), findsOneWidget);
    expect(find.text('Tarjetas de Crédito'), findsOneWidget);
    expect(find.text('Guardar Configuración y Empezar'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders summary cards, accounts and credit cards', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mockAccounts = [
      Account(id: 'a1', name: 'Bancolombia', accountNumber: '123-456789'),
      Account(id: 'a2', name: 'Nequi'),
    ];
    const mockPockets = [
      Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 2500000),
      Pocket(id: 'p2', accountId: 'a2', name: 'Graficolor', balance: 3200000),
    ];
    const mockCards = [
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
          pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
          creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
          activeAlertsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Finanzas Personales'), findsOneWidget);
    expect(find.text('Patrimonio Neto'), findsOneWidget);
    expect(find.text('Activos Totales (Bancos)'), findsOneWidget);
    expect(find.text('Pasivos Totales (Tarjetas)'), findsOneWidget);

    expect(find.text('Ingreso Rápido por Frase'), findsOneWidget);
    expect(find.text('Transferir entre Bolsillos'), findsOneWidget);
    expect(find.text('Abonar a Tarjeta (Pagar TC)'), findsOneWidget);

    // Verify accounts and pockets are displayed
    expect(find.text('Bancolombia'), findsWidgets);
    expect(find.text('N.º 123-456789'), findsOneWidget);
    expect(find.text('  • Personal'), findsOneWidget);
    expect(find.text('Nequi'), findsOneWidget);
    expect(find.text('  • Graficolor'), findsOneWidget);

    // Verify action buttons exist
    expect(find.text('Detalles e Historial'), findsNWidgets(2));
    expect(find.text('Ver Historial y Movimientos'), findsOneWidget);

    // Verify credit card is displayed with debt and limits
    expect(find.text('Bancolombia Única (*9805)'), findsOneWidget);
    expect(find.text('Cupo Total:'), findsOneWidget);
    expect(find.text('Cupo Disponible:'), findsOneWidget);
    expect(find.text('Deuda Actual:'), findsOneWidget);
  });

  testWidgets('CreditCardCrudDialog displays cards and form toggling', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mockCards = [
      CreditCard(
        id: 'c1',
        entity: 'Nu',
        name: 'Moradita',
        franchise: 'Mastercard',
        lastFourDigits: '1122',
        creditLimit: 5000000,
        availableCredit: 4500000,
        cutOffDay: 12,
        paymentDueDay: 27,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creditCardsProvider.overrideWith((ref) => Future.value(mockCards)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CreditCardCrudDialog()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Gestión de Tarjetas de Crédito'), findsOneWidget);
    expect(find.text('Registrar Nueva Tarjeta'), findsOneWidget);
    expect(find.text('Nu Moradita (*1122)'), findsOneWidget);
    expect(find.text('Mastercard'), findsOneWidget);

    // Tap to show creation form
    await tester.tap(find.text('Registrar Nueva Tarjeta'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva Tarjeta de Crédito'), findsOneWidget);
    expect(find.text('Entidad Emisora'), findsOneWidget);
    expect(find.text('Guardar Tarjeta'), findsOneWidget);
  });

  testWidgets('BankDetailsDialog renders breakdown and empty history state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const account = Account(id: 'a1', name: 'Bancolombia', accountNumber: '987-654321');
    const mockPockets = [
      Pocket(id: 'p0', accountId: 'a1', name: 'Disponible en Cuenta', balance: 500000),
      Pocket(id: 'p1', accountId: 'a1', name: 'Viajes', balance: 1500000),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
          accountTransactionsProvider('a1').overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BankDetailsDialog(account: account)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Bancolombia'), findsWidgets);
    expect(find.text('N.º de Cuenta: 987-654321'), findsOneWidget);
    expect(find.text('Saldo Total Banco'), findsOneWidget);
    expect(find.text('Fuera de Bolsillos (Disponible)'), findsOneWidget);
    expect(find.text('Saldo en Bolsillos'), findsOneWidget);
    expect(find.text('No hay transacciones registradas para este banco.'), findsOneWidget);
  });

  testWidgets('CardDetailsDialog renders credit card info, debt and empty history state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const card = CreditCard(
      id: 'c1',
      entity: 'Bancolombia',
      name: 'Black',
      franchise: 'Visa',
      lastFourDigits: '4321',
      creditLimit: 15000000,
      availableCredit: 12000000,
      cutOffDay: 15,
      paymentDueDay: 30,
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

    expect(find.textContaining('Bancolombia Black'), findsWidgets);
    expect(find.textContaining('*4321'), findsWidgets);
    expect(find.text('Cupo Total'), findsOneWidget);
    expect(find.text('Cupo Disponible'), findsOneWidget);
    expect(find.text('Deuda Actual'), findsOneWidget);
    expect(find.textContaining('Corte: Día 15'), findsOneWidget);
    expect(find.textContaining('Límite de Pago: Día 30'), findsOneWidget);
    expect(find.text('No hay compras ni abonos registrados para esta tarjeta.'), findsOneWidget);
  });

  testWidgets('Default theme is dark mode and can be toggled to light mode', (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Verify initial theme mode is dark
    expect(container.read(themeModeProvider), ThemeMode.dark);

    // Toggle theme to light
    container.read(themeModeProvider.notifier).toggle();
    expect(container.read(themeModeProvider), ThemeMode.light);

    // Toggle back to dark
    container.read(themeModeProvider.notifier).toggle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('DashboardScreen displays theme toggle button and switches theme on tap', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Future.value([])),
          pocketsProvider.overrideWith((ref) => Future.value([])),
          creditCardsProvider.overrideWith((ref) => Future.value([])),
          activeAlertsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final themeMode = ref.watch(themeModeProvider);
            return MaterialApp(
              theme: buildAppTheme(brightness: Brightness.light),
              darkTheme: buildAppTheme(brightness: Brightness.dark),
              themeMode: themeMode,
              home: const DashboardScreen(),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // In dark mode (default), the theme toggle button has the light_mode icon with tooltip 'Cambiar a tema claro'
    expect(find.byTooltip('Cambiar a tema claro'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    // Tap toggle button to switch to light mode
    await tester.tap(find.byTooltip('Cambiar a tema claro'));
    await tester.pumpAndSettle();

    // Now in light mode, the toggle button has the dark_mode icon with tooltip 'Cambiar a tema oscuro'
    expect(find.byTooltip('Cambiar a tema oscuro'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

    // Tap again to switch back to dark mode
    await tester.tap(find.byTooltip('Cambiar a tema oscuro'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Cambiar a tema claro'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
  });

  testWidgets('NlpEntryDialog renders without RenderFlex overflow even on compact width', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Future.value([
            const Account(id: 'a1', name: 'Bancolombia'),
          ])),
          pocketsProvider.overrideWith((ref) => Future.value([
            const Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 50000),
          ])),
          creditCardsProvider.overrideWith((ref) => Future.value([])),
          nlpCatalogProvider.overrideWith((ref) => Future.value(NlpCatalog.empty)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: const Scaffold(body: NlpEntryDialog()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ingreso Rápido por Frase (NLP)'), findsOneWidget);
    expect(find.text('Gasto / Compra'), findsOneWidget);
    expect(find.text('Monto COP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardScreen toggles smoothly between Resumen and Gráfico views', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mockAccounts = [
      Account(id: 'a1', name: 'Bancolombia'),
    ];
    const mockPockets = [
      Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 2500000),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Future.value(mockAccounts)),
          pocketsProvider.overrideWith((ref) => Future.value(mockPockets)),
          creditCardsProvider.overrideWith((ref) => Future.value([])),
          activeAlertsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: const DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Default view shows summary cards
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Gráfico'), findsOneWidget);
    expect(find.text('Patrimonio Neto'), findsOneWidget);

    // Tap Gráfico to switch view
    await tester.tap(find.text('Gráfico'));
    await tester.pumpAndSettle();

    // Now chart is rendered
    expect(find.byType(PocketDistributionChart), findsOneWidget);
    expect(find.text('Distribución del Patrimonio'), findsOneWidget);

    // Tap back to Resumen
    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();

    expect(find.text('Patrimonio Neto'), findsOneWidget);
  });
}


