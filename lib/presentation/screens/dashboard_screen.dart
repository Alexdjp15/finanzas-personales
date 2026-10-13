import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_state_providers.dart';
import '../providers/supabase_providers.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/charts/pocket_distribution_chart.dart';
import '../widgets/dashboard_micro_widgets.dart';
import '../widgets/bank_logo_avatar.dart';
import '../widgets/app_logo_widget.dart';
import '../widgets/sofia_floating_orb.dart';
import 'dialogs/expense_audit_dialog.dart';
import 'dialogs/bank_details_dialog.dart';
import 'dialogs/card_details_dialog.dart';
import 'dialogs/card_payment_dialog.dart';
import 'dialogs/credit_card_crud_dialog.dart';
import 'dialogs/fiscal_close_dialog.dart';
import 'dialogs/in_app_alerts_sheet.dart';
import 'dialogs/nlp_entry_dialog.dart';
import 'dialogs/pocket_crud_dialog.dart';
import 'dialogs/recurring_payment_dialog.dart';
import 'dialogs/reminder_settings_dialog.dart';
import 'dialogs/transfer_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
    this.initialAction,
  });

  /// Optional initial action (e.g. 'nlp' or 'voice').
  /// If null, it will be extracted automatically from the URL query parameters (`Uri.base`).
  final String? initialAction;

  /// Pure parser that extracts the 'action' query parameter from either:
  /// 1. Direct query parameters: `https://.../?action=nlp`
  /// 2. Fragment query parameters: `https://.../#/?action=voice` or `https://.../#/dashboard?action=nlp`
  static String? parseActionFromUri(Uri uri) {
    final directAction = uri.queryParameters['action'];
    if (directAction != null && directAction.isNotEmpty) {
      return directAction;
    }
    if (uri.hasFragment && uri.fragment.contains('?')) {
      final queryPart = uri.fragment.split('?').last;
      final parsed = Uri.splitQueryString(queryPart);
      return parsed['action'];
    }
    return null;
  }

  /// Reads current action parameter from [Uri.base].
  static String? getUrlAction() => parseActionFromUri(Uri.base);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _accountsExpanded = true;
  bool _cardsExpanded = false;
  bool _hasHandledUrlAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleUrlAction();
    });
  }

  void _handleUrlAction() {
    if (!mounted || _hasHandledUrlAction) return;
    _hasHandledUrlAction = true;

    final action = (widget.initialAction ?? DashboardScreen.getUrlAction())?.trim().toLowerCase();
    if (action == 'nlp') {
      showDialog(
        context: context,
        builder: (_) => const NlpEntryDialog(),
      );
    } else if (action == 'voice') {
      showDialog(
        context: context,
        builder: (_) => const NlpEntryDialog(startListeningImmediately: true),
      );
    }
  }

  void _showQuickActionsBottomSheet(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.brandAccentBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.bolt_rounded, color: colors.brandAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚡ Acciones Rápidas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'Operaciones financieras y gestión en 1 toque',
                              style: TextStyle(fontSize: 12, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: colors.borderSubtle, height: 1),
                  const SizedBox(height: 12),
                  _buildQuickActionTile(
                    colors: colors,
                    icon: Icons.swap_horiz_rounded,
                    title: 'Transferir entre Bolsillos',
                    subtitle: 'Mueve fondos entre cuentas y bolsillos',
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(context: context, builder: (_) => const TransferDialog());
                    },
                  ),
                  _buildQuickActionTile(
                    colors: colors,
                    icon: Icons.payment_rounded,
                    title: 'Abonar a Tarjeta (Pagar TC)',
                    subtitle: 'Registra un pago para restaurar tu cupo',
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(context: context, builder: (_) => const CardPaymentDialog());
                    },
                  ),
                  _buildQuickActionTile(
                    colors: colors,
                    icon: Icons.folder_open_rounded,
                    title: 'Gestionar Cuentas Banco y Bolsillos',
                    subtitle: 'Crea, edita o elimina entidades bancarias',
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(context: context, builder: (_) => const PocketCrudDialog());
                    },
                  ),
                  _buildQuickActionTile(
                    colors: colors,
                    icon: Icons.credit_card_rounded,
                    title: 'Gestionar Tarjetas de Crédito',
                    subtitle: 'Configura cupos, franquicias y fechas',
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(context: context, builder: (_) => const CreditCardCrudDialog());
                    },
                  ),
                  _buildQuickActionTile(
                    colors: colors,
                    icon: Icons.autorenew_rounded,
                    title: 'Suscripciones y Recurrentes',
                    subtitle: 'Monitorea cobros fijos y servicios',
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(context: context, builder: (_) => const RecurringPaymentDialog());
                    },
                  ),
                  _buildQuickActionTile(
                    key: const Key('dashboard_audit_expenses_button'),
                    colors: colors,
                    icon: Icons.troubleshoot_rounded,
                    title: 'Auditar Gastos Hormiga (IA)',
                    subtitle: 'Analiza fugas de liquidez y consumos',
                    iconColor: colors.brandAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog(context: context, builder: (_) => const ExpenseAuditDialog());
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionTile({
    Key? key,
    required AppPalette colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surfaceBase,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? colors.brandAccent).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor ?? colors.brandAccent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalsAsync = ref.watch(dashboardTotalsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final pocketsAsync = ref.watch(pocketsProvider);
    final cardsAsync = ref.watch(creditCardsProvider);
    final alertsAsync = ref.watch(activeAlertsProvider);
    final dashboardView = ref.watch(dashboardViewProvider);
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final iconPadding = isMobile ? EdgeInsets.zero : const EdgeInsets.all(8);
    final iconConstraints = isMobile ? const BoxConstraints.tightFor(width: 32, height: 32) : null;
    final iconSize = isMobile ? 20.0 : 24.0;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      floatingActionButton: const SofiaFloatingOrb(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        backgroundColor: colors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.borderSubtle),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: isMobile ? 32 : 38,
              width: isMobile ? 32 : 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 5 : 7),
                child: AppLogoWidget(size: isMobile ? 26 : 32, useIsotype: true),
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Flexible(
              child: Text(
                isMobile ? 'Finanzas' : 'Finanzas Personales',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: isMobile ? 16 : 18,
                  letterSpacing: -0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Theme Switcher (Dark / Light)
          IconButton(
            padding: iconPadding,
            constraints: iconConstraints,
            iconSize: iconSize,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: colors.textSecondary,
            ),
            tooltip: isDark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
          // Alert Bell with Badge
          alertsAsync.when(
            data: (alerts) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  padding: iconPadding,
                  constraints: iconConstraints,
                  iconSize: iconSize,
                  icon: Icon(Icons.notifications_outlined, color: colors.textSecondary),
                  tooltip: 'Notificaciones y Alertas',
                  onPressed: () => showDialog(context: context, builder: (_) => const InAppAlertsSheet()),
                ),
                if (alerts.isNotEmpty)
                  Positioned(
                    top: isMobile ? 2 : 8,
                    right: isMobile ? 2 : 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.liabilityNegative,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${alerts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          IconButton(
            padding: iconPadding,
            constraints: iconConstraints,
            iconSize: iconSize,
            icon: Icon(Icons.alarm_rounded, color: colors.textSecondary),
            tooltip: 'Configurar Hora de Alertas',
            onPressed: () => showDialog(context: context, builder: (_) => const ReminderSettingsDialog()),
          ),
          IconButton(
            padding: iconPadding,
            constraints: iconConstraints,
            iconSize: iconSize,
            icon: Icon(Icons.archive_outlined, color: colors.textSecondary),
            tooltip: 'Cierre Fiscal Anual',
            onPressed: () => showDialog(context: context, builder: (_) => const FiscalCloseDialog()),
          ),
          IconButton(
            padding: iconPadding,
            constraints: iconConstraints,
            iconSize: iconSize,
            icon: Icon(Icons.logout_rounded, color: colors.liabilityNegative),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              final authRepo = ref.read(authRepositoryProvider);
              await authRepo.signOut();
            },
          ),
          SizedBox(width: isMobile ? 6 : 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateFinanceProviders(ref),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Quick NLP Entry Bar (Command Bar Style) ---
                  Container(
                    decoration: AppDecorations.card(
                      backgroundColor: colors.surfaceCard,
                      borderColor: colors.borderSubtle,
                      borderRadius: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 620;

                        final phraseButton = ElevatedButton.icon(
                          key: const Key('dashboard_phrase_entry_button'),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const NlpEntryDialog(),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text(
                            'Ingreso por Frase',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.brandAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        );

                        final voiceButton = OutlinedButton.icon(
                          key: const Key('dashboard_voice_dictation_button'),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const NlpEntryDialog(startListeningImmediately: true),
                          ),
                          icon: const Icon(Icons.mic_rounded, size: 18),
                          label: const Text(
                            'Dictar por Voz',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.brandAccent,
                            side: BorderSide(
                              color: colors.brandAccent.withValues(alpha: 0.7),
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colors.brandAccentBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.auto_awesome, color: colors.brandAccent, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Registro Inteligente',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: colors.textPrimary,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        Text(
                                          'Escribe o dicta tu movimiento',
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: phraseButton),
                                  const SizedBox(width: 8),
                                  Expanded(child: voiceButton),
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.brandAccentBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.auto_awesome, color: colors.brandAccent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Registro Inteligente',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: colors.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Escribe o dicta tu movimiento',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                phraseButton,
                                const SizedBox(width: 10),
                                voiceButton,
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- View switcher: numeric summary vs. chart ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<DashboardView>(
                      key: const Key('dashboard_view_selector'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: DashboardView.summary,
                          icon: Icon(Icons.dashboard_outlined, size: 18),
                          label: Text('Resumen'),
                        ),
                        ButtonSegment(
                          value: DashboardView.chart,
                          icon: Icon(Icons.donut_large_rounded, size: 18),
                          label: Text('Gráfico'),
                        ),
                      ],
                      selected: {dashboardView},
                      onSelectionChanged: (selection) =>
                          ref.read(dashboardViewProvider.notifier).set(selection.first),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Top Summary Cards (Unified Hero Layout) / Chart ---
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: dashboardView == DashboardView.chart
                        ? KeyedSubtree(
                            key: const ValueKey('dashboard_chart_view'),
                            child: PocketDistributionChart(
                              accounts: accountsAsync.value ?? const [],
                              pockets: pocketsAsync.value ?? const [],
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('dashboard_summary_view'),
                            child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 850;
                      return totalsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, stack) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.liabilityNegativeBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.liabilityNegativeBorder),
                          ),
                          child: Text('Error al calcular totales: $err', style: TextStyle(color: colors.liabilityNegative)),
                        ),
                        data: (totals) {
                          final netWorthCard = Container(
                            decoration: AppDecorations.heroDarkCard(),
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'POSICIÓN FINANCIERA NETA',
                                          style: TextStyle(
                                            color: AppColors.textOnDark,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.account_balance_rounded, color: Colors.white54, size: 20),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Patrimonio Neto',
                                  style: TextStyle(
                                    color: AppColors.textOnDarkMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedCopText(
                                    value: totals.netWorth,
                                    style: TextStyle(
                                      color: totals.netWorth >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          final assetsCard = _buildMetricPill(
                            colors: colors,
                            title: 'Activos Totales (Bancos)',
                            amount: totals.totalAssets,
                            icon: Icons.savings_rounded,
                            accentColor: colors.assetPositive,
                            bgColor: colors.assetPositiveBg,
                            borderColor: colors.assetPositiveBorder,
                          );

                          final liabilitiesCard = _buildMetricPill(
                            colors: colors,
                            title: 'Pasivos Totales (Tarjetas)',
                            amount: totals.totalDebt,
                            icon: Icons.credit_card_off_rounded,
                            accentColor: colors.liabilityNegative,
                            bgColor: colors.liabilityNegativeBg,
                            borderColor: colors.liabilityNegativeBorder,
                          );

                          if (isWide) {
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 5, child: netWorthCard),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        assetsCard,
                                        const SizedBox(height: 12),
                                        liabilitiesCard,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Column(
                              children: [
                                netWorthCard,
                                const SizedBox(height: 12),
                                assetsCard,
                                const SizedBox(height: 12),
                                liabilitiesCard,
                              ],
                            );
                          }
                        },
                      );
                    },
                  ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // --- Action Shortcuts ---
                  if (isMobile)
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: colors.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          key: const Key('dashboard_quick_actions_button'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showQuickActionsBottomSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.brandAccent.withValues(alpha: 0.35)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0D000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colors.brandAccentBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.bolt_rounded, color: colors.brandAccent, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '⚡ Acciones Rápidas',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Transferir, pagar TC, cuentas, suscripciones e IA',
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down_rounded, color: colors.brandAccent, size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => showDialog(context: context, builder: (_) => const TransferDialog()),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Transferir entre Bolsillos'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showDialog(context: context, builder: (_) => const CardPaymentDialog()),
                          icon: const Icon(Icons.payment_rounded, size: 18),
                          label: const Text('Abonar a Tarjeta (Pagar TC)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showDialog(context: context, builder: (_) => const PocketCrudDialog()),
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('Gestionar Cuentas Banco y Bolsillos'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showDialog(context: context, builder: (_) => const CreditCardCrudDialog()),
                          icon: const Icon(Icons.credit_card_rounded, size: 18),
                          label: const Text('Gestionar Tarjetas de Crédito'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showDialog(context: context, builder: (_) => const RecurringPaymentDialog()),
                          icon: const Icon(Icons.autorenew_rounded, size: 18),
                          label: const Text('Suscripciones y Recurrentes'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('dashboard_audit_expenses_button'),
                          onPressed: () => showDialog(context: context, builder: (_) => const ExpenseAuditDialog()),
                          icon: const Icon(Icons.troubleshoot_rounded, size: 18),
                          label: const Text('Auditar Gastos Hormiga (IA)'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 28),

                  // --- Split View: Cuentas Banco & Bolsillos | Tarjetas de Crédito ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 850;

                      final accountsList = accountsAsync.value ?? [];
                      final pocketsList = pocketsAsync.value ?? [];
                      final totalAssets = pocketsList.fold<int>(0, (sum, p) => sum + p.balance);

                      final accountsSection = Container(
                        decoration: AppDecorations.card(
                          backgroundColor: colors.surfaceCard,
                          borderColor: colors.borderSubtle,
                          borderRadius: 16,
                        ),
                        padding: EdgeInsets.all(isMobile ? 16.0 : 22.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              key: const Key('dashboard_accounts_toggle_header'),
                              borderRadius: BorderRadius.circular(10),
                              onTap: isMobile
                                  ? () => setState(() => _accountsExpanded = !_accountsExpanded)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colors.brandAccentBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.account_tree_outlined, color: colors.brandAccent, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        (isMobile && !_accountsExpanded)
                                            ? 'Cuentas Banco (${accountsList.length}) · ${Formatters.cop(totalAssets)}'
                                            : 'Cuentas Banco y Bolsillos',
                                        style: AppTypography.sectionTitle.copyWith(color: colors.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isMobile)
                                      IconButton(
                                        icon: Icon(
                                          _accountsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          color: colors.textSecondary,
                                          size: 24,
                                        ),
                                        onPressed: () => setState(() => _accountsExpanded = !_accountsExpanded),
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.add, size: 20, color: colors.brandAccent),
                                      tooltip: 'Agregar Bolsillo',
                                      onPressed: () => showDialog(context: context, builder: (_) => const PocketCrudDialog()),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_accountsExpanded || !isMobile) ...[
                              const SizedBox(height: 16),
                              Divider(color: colors.borderSubtle),
                              const SizedBox(height: 16),
                              accountsAsync.when(
                              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                              error: (err, stack) => Text('Error: $err', style: TextStyle(color: colors.liabilityNegative)),
                              data: (accounts) {
                                final pockets = pocketsAsync.value ?? [];
                                if (accounts.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text('No hay cuentas registradas.', style: TextStyle(color: colors.textMuted)),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: accounts.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                                  itemBuilder: (ctx, idx) {
                                    final acc = accounts[idx];
                                    final accPockets = pockets.where((p) => p.accountId == acc.id).toList();
                                    final totalAcc = accPockets.fold<int>(0, (sum, p) => sum + p.balance);

                                    return HoverCard(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    BankLogoAvatar(
                                                      bankName: acc.name,
                                                      size: 38,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            acc.name,
                                                            style: AppTypography.itemTitle.copyWith(color: colors.textPrimary),
                                                          ),
                                                          if (acc.accountNumber.isNotEmpty)
                                                            Text(
                                                              'N.º ${acc.accountNumber}',
                                                              style: TextStyle(fontSize: 12, color: colors.textMuted),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                Formatters.cop(totalAcc),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 17,
                                                  letterSpacing: -0.5,
                                                  color: colors.brandAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          if (accPockets.isEmpty)
                                            Text('Sin bolsillos asignados.', style: TextStyle(color: colors.textMuted, fontSize: 13))
                                          else
                                            ...accPockets.map(
                                              (p) => Container(
                                                margin: const EdgeInsets.only(bottom: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: colors.surfaceCard,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: colors.borderSubtle),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            p.name.contains('Disponible') ? Icons.account_balance_wallet_outlined : Icons.folder_outlined,
                                                            size: 15,
                                                            color: colors.textSecondary,
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              '  • ${p.name}',
                                                              style: TextStyle(
                                                                color: colors.textPrimary,
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: p.balance < 0 ? colors.liabilityNegativeBg : Colors.transparent,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        Formatters.cop(p.balance),
                                                        style: TextStyle(
                                                          color: p.balance >= 0 ? colors.textPrimary : colors.liabilityNegative,
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: OutlinedButton.icon(
                                              onPressed: () => showDialog(
                                                context: context,
                                                builder: (_) => BankDetailsDialog(account: acc),
                                              ),
                                              icon: const Icon(Icons.receipt_long_rounded, size: 15),
                                              label: const Text('Detalles e Historial', style: TextStyle(fontSize: 12)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: colors.textPrimary,
                                                side: BorderSide(color: colors.borderSubtle),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              ),
                            ],
                          ],
                        ),
                      );

                      final cardsList = cardsAsync.value ?? [];
                      final totalDebt = cardsList.fold<int>(0, (sum, c) => sum + c.debt);

                      final cardsSection = Container(
                        decoration: AppDecorations.card(
                          backgroundColor: colors.surfaceCard,
                          borderColor: colors.borderSubtle,
                          borderRadius: 16,
                        ),
                        padding: EdgeInsets.all(isMobile ? 16.0 : 22.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              key: const Key('dashboard_cards_toggle_header'),
                              borderRadius: BorderRadius.circular(10),
                              onTap: isMobile
                                  ? () => setState(() => _cardsExpanded = !_cardsExpanded)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colors.liabilityNegativeBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.credit_card_rounded, color: colors.liabilityNegative, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        (isMobile && !_cardsExpanded)
                                            ? 'Tarjetas (${cardsList.length}) · Deuda ${Formatters.cop(totalDebt)}'
                                            : 'Tarjetas de Crédito',
                                        style: AppTypography.sectionTitle.copyWith(color: colors.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isMobile)
                                      IconButton(
                                        icon: Icon(
                                          _cardsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          color: colors.textSecondary,
                                          size: 24,
                                        ),
                                        onPressed: () => setState(() => _cardsExpanded = !_cardsExpanded),
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.add, size: 20, color: colors.brandAccent),
                                      tooltip: 'Gestionar o Añadir Tarjeta',
                                      onPressed: () => showDialog(context: context, builder: (_) => const CreditCardCrudDialog()),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_cardsExpanded || !isMobile) ...[
                              const SizedBox(height: 16),
                              Divider(color: colors.borderSubtle),
                              const SizedBox(height: 16),
                              cardsAsync.when(
                              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                              error: (err, stack) => Text('Error: $err', style: TextStyle(color: colors.liabilityNegative)),
                              data: (cards) {
                                if (cards.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text('No hay tarjetas registradas.', style: TextStyle(color: colors.textMuted)),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: cards.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                                  itemBuilder: (ctx, idx) {
                                    final c = cards[idx];
                                    final double usedRatio = c.creditLimit > 0
                                        ? (c.debt / c.creditLimit).clamp(0.0, 1.0)
                                        : 0.0;
                                    final int usedPercentage = (usedRatio * 100).round();

                                    return HoverCard(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    BankLogoAvatar(
                                                      bankName: c.entity,
                                                      size: 38,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        '${c.entity} ${c.name} (*${c.lastFourDigits})',
                                                        style: AppTypography.itemTitle.copyWith(color: colors.textPrimary),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: colors.surfaceCard,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: colors.borderSubtle),
                                                ),
                                                child: Text(
                                                  c.franchise,
                                                  style: TextStyle(
                                                    color: colors.brandPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),

                                          // Utilization Progress Bar
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Utilización: $usedPercentage%',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: creditUsageColor(colors, usedRatio),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              CreditUsageBar(ratio: usedRatio),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Amounts Box
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: colors.surfaceCard,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: colors.borderSubtle),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Cupo Total:',
                                                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      Formatters.cop(c.creditLimit),
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Cupo Disponible:',
                                                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      Formatters.cop(c.availableCredit),
                                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.assetPositive),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Deuda Actual:',
                                                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      Formatters.cop(c.debt),
                                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.liabilityNegative),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Dates Chips
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: colors.surfaceCard,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: colors.borderSubtle),
                                                ),
                                                child: Text(
                                                  'Día corte: ${c.cutOffDay}',
                                                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: colors.liabilityNegativeBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: colors.liabilityNegativeBorder),
                                                ),
                                                child: Text(
                                                  'Límite de pago: Día ${c.paymentDueDay}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: colors.liabilityNegative,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () => showDialog(
                                                context: context,
                                                builder: (_) => CardDetailsDialog(card: c),
                                              ),
                                              icon: const Icon(Icons.history_rounded, size: 15),
                                              label: const Text('Ver Historial y Movimientos', style: TextStyle(fontSize: 12)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: colors.textPrimary,
                                                side: BorderSide(color: colors.borderSubtle),
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: accountsSection),
                            const SizedBox(width: 20),
                            Expanded(flex: 5, child: cardsSection),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            accountsSection,
                            const SizedBox(height: 20),
                            cardsSection,
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required AppPalette colors,
    required String title,
    required int amount,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: AppDecorations.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedCopText(
                    value: amount,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
