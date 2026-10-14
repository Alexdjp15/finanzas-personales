import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finanzas_personales/presentation/widgets/sofia_floating_orb.dart';
import 'package:finanzas_personales/presentation/screens/dashboard_screen.dart';
import 'package:finanzas_personales/presentation/providers/finance_state_providers.dart';
import 'package:finanzas_personales/domain/models/models.dart';

void main() {
  group('SofiaFloatingOrb Widget Tests', () {
    testWidgets('renders SofiaFloatingOrb with badge, tooltip and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SofiaFloatingOrb(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('sofia_floating_orb')), findsOneWidget);
      expect(find.text('Sof.IA'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('triggers onTap callback when pressed', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SofiaFloatingOrb(
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('sofia_floating_orb')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('animates breathing pulse in idle loop without errors', (tester) async {
      SofiaFloatingOrb.enablePulseInTests = true;
      addTearDown(() => SofiaFloatingOrb.enablePulseInTests = false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SofiaFloatingOrb(),
          ),
        ),
      );

      // Advance time through pulse animation
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 1200));

      expect(tester.takeException(), isNull);
    });
  });

  group('DashboardScreen Command Bar & Floating Orb Integration', () {
    testWidgets('renders Registro Inteligente bar and SofiaFloatingOrb, no Copiloto IA button in command bar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
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
                  const Pocket(id: 'p1', accountId: 'a1', name: 'Personal', balance: 500000),
                ])),
            creditCardsProvider.overrideWith((ref) => Future.value(<CreditCard>[])),
            activeAlertsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Command Bar assertions
      expect(find.text('Registro Inteligente'), findsOneWidget);
      expect(find.text('Escribe o dicta tu movimiento'), findsOneWidget);
      expect(find.text('Ingreso por Frase'), findsOneWidget);
      expect(find.text('Dictar por Voz'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_phrase_entry_button')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_voice_dictation_button')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_scan_receipt_button')), findsOneWidget);

      // Verify "Copiloto IA" button is completely removed from command bar
      expect(find.byKey(const Key('dashboard_ai_copilot_button')), findsNothing);

      // Verify SofiaFloatingOrb is present in Scaffold
      expect(find.byType(SofiaFloatingOrb), findsOneWidget);
      expect(find.byKey(const Key('sofia_floating_orb')), findsOneWidget);
    });

    testWidgets('renders mobile command bar (<600px) with balanced buttons', (tester) async {
      tester.view.physicalSize = const Size(360, 750);
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
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registro Inteligente'), findsOneWidget);
      expect(find.text('Ingreso por Frase'), findsOneWidget);
      expect(find.text('Dictar por Voz'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_scan_receipt_button')), findsOneWidget);
      expect(find.byType(SofiaFloatingOrb), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
