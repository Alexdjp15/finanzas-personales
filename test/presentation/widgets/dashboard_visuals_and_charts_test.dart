import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_personales/domain/models/models.dart';
import 'package:finanzas_personales/domain/services/dashboard_visuals.dart';
import 'package:finanzas_personales/presentation/utils/app_theme.dart';
import 'package:finanzas_personales/presentation/utils/formatters.dart';
import 'package:finanzas_personales/presentation/widgets/charts/pocket_distribution_chart.dart';
import 'package:finanzas_personales/presentation/widgets/dashboard_micro_widgets.dart';

void main() {
  group('DashboardVisuals Pure Business Logic Tests', () {
    const mockAccounts = [
      Account(id: 'a1', name: 'Bancolombia'),
      Account(id: 'a2', name: 'Nequi'),
    ];

    const mockPockets = [
      Pocket(id: 'p1', accountId: 'a1', name: 'Disponible', balance: 600000),
      Pocket(id: 'p2', accountId: 'a1', name: 'Ahorro', balance: 400000),
      Pocket(id: 'p3', accountId: 'a2', name: 'Gastos Mes', balance: 1000000),
    ];

    test('byPocket filters positive pockets and computes correct percentages', () {
      final result = DashboardVisuals.byPocket(mockPockets);
      final slices = result.slices;

      // Total balance = 2,000,000
      expect(result.total, 2000000);
      expect(slices.length, 3);
      expect(slices[0].label, 'Gastos Mes');
      expect(slices[0].amount, 1000000);
      expect(slices[0].percentage, closeTo(50.0, 0.01));

      expect(slices[1].label, 'Disponible');
      expect(slices[1].amount, 600000);
      expect(slices[1].percentage, closeTo(30.0, 0.01));

      expect(slices[2].label, 'Ahorro');
      expect(slices[2].amount, 400000);
      expect(slices[2].percentage, closeTo(20.0, 0.01));
    });

    test('byPocket ignores pockets with zero or negative balances and records excluded count', () {
      const mixedPockets = [
        Pocket(id: 'p1', accountId: 'a1', name: 'Positivo', balance: 500000),
        Pocket(id: 'p2', accountId: 'a1', name: 'Cero', balance: 0),
        Pocket(id: 'p3', accountId: 'a1', name: 'Negativo', balance: -150000),
      ];

      final result = DashboardVisuals.byPocket(mixedPockets);
      expect(result.slices.length, 1);
      expect(result.slices.first.label, 'Positivo');
      expect(result.slices.first.percentage, 100.0);
      expect(result.excludedNegativeCount, 2);
    });

    test('byPocket returns empty slices when total balance is 0 or negative', () {
      const zeroPockets = [
        Pocket(id: 'p1', accountId: 'a1', name: 'Cero', balance: 0),
        Pocket(id: 'p2', accountId: 'a1', name: 'Negativo', balance: -50000),
      ];

      final result = DashboardVisuals.byPocket(zeroPockets);
      expect(result.isEmpty, isTrue);
      expect(result.slices, isEmpty);
    });

    test('byAccount aggregates pockets by account correctly', () {
      final result = DashboardVisuals.byAccount(mockAccounts, mockPockets);
      final slices = result.slices;

      // Total = 2,000,000; Bancolombia = 1,000,000 (50%); Nequi = 1,000,000 (50%)
      expect(result.total, 2000000);
      expect(slices.length, 2);
      expect(slices[0].label, anyOf('Bancolombia', 'Nequi'));
      expect(slices[0].amount, 1000000);
      expect(slices[0].percentage, closeTo(50.0, 0.01));

      expect(slices[1].amount, 1000000);
      expect(slices[1].percentage, closeTo(50.0, 0.01));
    });

    test('creditUsageLevel categorizes thresholds accurately: <30% healthy, 30%-70% moderate, >70% critical', () {
      expect(DashboardVisuals.creditUsageLevel(0.0), CreditUsageLevel.healthy);
      expect(DashboardVisuals.creditUsageLevel(0.25), CreditUsageLevel.healthy);
      expect(DashboardVisuals.creditUsageLevel(0.29), CreditUsageLevel.healthy);

      expect(DashboardVisuals.creditUsageLevel(0.30), CreditUsageLevel.moderate);
      expect(DashboardVisuals.creditUsageLevel(0.50), CreditUsageLevel.moderate);
      expect(DashboardVisuals.creditUsageLevel(0.70), CreditUsageLevel.moderate);

      expect(DashboardVisuals.creditUsageLevel(0.71), CreditUsageLevel.critical);
      expect(DashboardVisuals.creditUsageLevel(0.95), CreditUsageLevel.critical);
      expect(DashboardVisuals.creditUsageLevel(1.20), CreditUsageLevel.critical);
    });
  });

  group('Widget Tests: Microinteractions & Visual Indicators', () {
    testWidgets('AnimatedCopText renders formatted Colombian Peso amount', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedCopText(
              value: 1500000,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(Formatters.cop(1500000)), findsOneWidget);
    });

    testWidgets('CreditUsageBar renders with correct theme colors across stress ratios', (WidgetTester tester) async {
      const colors = AppPalette.dark;

      // 1. Healthy ratio (< 30%) -> assetPositive
      expect(creditUsageColor(colors, 0.20), colors.assetPositive);

      // 2. Moderate ratio (30% - 70%) -> warning
      expect(creditUsageColor(colors, 0.55), colors.warning);

      // 3. Critical ratio (> 70%) -> liabilityNegative
      expect(creditUsageColor(colors, 0.85), colors.liabilityNegative);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: CreditUsageBar(ratio: 0.65),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CreditUsageBar), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('HoverCard responds to mouse enter and exit without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: HoverCard(
              child: Text('Hover Content Target'),
            ),
          ),
        ),
      );

      expect(find.text('Hover Content Target'), findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Hover Content Target')));
      await tester.pumpAndSettle();

      await gesture.moveTo(const Offset(500, 500));
      await tester.pumpAndSettle();
    });
  });

  group('Widget Tests: PocketDistributionChart', () {
    const testAccounts = [
      Account(id: 'a1', name: 'Bancolombia'),
      Account(id: 'a2', name: 'Nequi'),
    ];

    const testPockets = [
      Pocket(id: 'p1', accountId: 'a1', name: 'Disponible', balance: 700000),
      Pocket(id: 'p2', accountId: 'a1', name: 'Ahorro', balance: 300000),
      Pocket(id: 'p3', accountId: 'a2', name: 'Viajes', balance: 500000),
    ];

    testWidgets('Renders empty state when accounts or pockets have no balance', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: PocketDistributionChart(
              accounts: [],
              pockets: [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Aún no hay saldos positivos para graficar.'), findsOneWidget);
    });

    testWidgets('Renders donut chart, legends and allows toggling to account distribution', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PocketDistributionChart(
                accounts: testAccounts,
                pockets: testPockets,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header and Mode selector
      expect(find.text('Distribución del Patrimonio'), findsOneWidget);
      expect(find.text('Por Bolsillos'), findsOneWidget);
      expect(find.text('Por Cuentas Banco'), findsOneWidget);

      // Default view is Por Bolsillos
      expect(find.textContaining('Disponible'), findsOneWidget);
      expect(find.textContaining('Ahorro'), findsOneWidget);
      expect(find.textContaining('Viajes'), findsOneWidget);

      // Toggle to Por Cuentas Banco
      await tester.tap(find.text('Por Cuentas Banco'));
      await tester.pumpAndSettle();

      // Legend should now display account names
      expect(find.textContaining('Bancolombia'), findsOneWidget);
      expect(find.textContaining('Nequi'), findsOneWidget);
    });
  });
}
