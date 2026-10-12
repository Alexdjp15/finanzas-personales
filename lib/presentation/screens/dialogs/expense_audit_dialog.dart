import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/ledger_transaction.dart';
import '../../../domain/services/ai_assistant_service.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../providers/finance_state_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';

class ExpenseAuditDialog extends ConsumerStatefulWidget {
  const ExpenseAuditDialog({super.key});

  @override
  ConsumerState<ExpenseAuditDialog> createState() => _ExpenseAuditDialogState();
}

class _ExpenseAuditDialogState extends ConsumerState<ExpenseAuditDialog> {
  ExpenseAuditResult? _auditResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAudit();
    });
  }

  Future<void> _runAudit() async {
    setState(() {
      _isLoading = true;
    });

    final txs = ref.read(recentTransactionsProvider).value ?? [];
    final pockets = ref.read(pocketsProvider).value ?? [];
    final cards = ref.read(creditCardsProvider).value ?? [];

    try {
      final aiService = ref.read(aiAssistantServiceProvider);
      final result = await aiService.auditExpenses(
        transactions: txs,
        pockets: pockets,
        cards: cards,
      );
      if (mounted) {
        setState(() {
          _auditResult = result;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Deterministic local audit fallback if edge function is unreachable
      final expenseTxs = txs.where((t) => t.type == LedgerTransactionType.expense).toList();
      final antExpenses = expenseTxs.where((t) => t.amount < 20000).toList();
      final antTotal = antExpenses.fold<int>(0, (sum, t) => sum + t.amount);

      // Detect potential duplicates (same amount on same calendar day)
      final duplicates = <DuplicateExpenseItem>[];
      final seen = <String, List<LedgerTransaction>>{};
      for (final t in expenseTxs) {
        final dayKey = '${t.date.year}-${t.date.month}-${t.date.day}_${t.amount}';
        seen.putIfAbsent(dayKey, () => []).add(t);
      }
      for (final entry in seen.entries) {
        if (entry.value.length > 1) {
          final first = entry.value.first;
          duplicates.add(DuplicateExpenseItem(
            description: first.description.isNotEmpty ? first.description : 'Gasto recurrente',
            amount: first.amount,
            dates: entry.value.map((e) => Formatters.date(e.date)).toList(),
            note: '${entry.value.length} cobros idénticos registrados el mismo día',
          ));
        }
      }

      final fallbackResult = ExpenseAuditResult(
        totalAnalyzedExpenses: expenseTxs.fold<int>(0, (sum, t) => sum + t.amount),
        antExpensesTotal: antTotal,
        antExpensesCount: antExpenses.length,
        antExpensesItems: antExpenses
            .map((t) => AntExpenseItem(
                  description: t.description.isNotEmpty ? t.description : 'Gasto menor a \$20k',
                  amount: t.amount,
                  date: Formatters.date(t.date),
                ))
            .toList(),
        potentialDuplicates: duplicates,
        liquidityLeaks: [
          LiquidityLeakItem(
            category: 'Gastos Hormiga',
            totalImpact: antTotal,
            recommendation: 'Agrupar compras pequeñas en un presupuesto semanal con tope fijo.',
          ),
        ],
        actionableTips: [
          'Fija una cuota semanal de gastos menores en un solo bolsillo para evitar dispersión.',
          'Revisa suscripciones y débitos automáticos que puedan estar duplicados.',
          'Prioriza pagar el saldo total de la tarjeta antes del día límite para no generar intereses.',
        ],
        summaryText: 'Auditoría basada en tus transacciones registradas. Se detectaron ${antExpenses.length} gastos hormiga por un total de ${Formatters.cop(antTotal)}.',
      );

      if (mounted) {
        setState(() {
          _auditResult = fallbackResult;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: mediaQuery.size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.warningBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.warningBorder),
                    ),
                    child: Icon(Icons.troubleshoot_rounded, color: palette.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auditoría de Gastos Hormiga y Fugas',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: palette.textPrimary),
                        ),
                        Text(
                          'Detección inteligente de micro-gastos (< \$20.000 COP) y cobros duplicados',
                          style: TextStyle(fontSize: 12, color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: palette.brandAccent),
                        const SizedBox(height: 16),
                        Text(
                          'Auditoría en proceso con IA...',
                          style: TextStyle(color: palette.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_auditResult != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Summary Cards Row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: palette.liabilityNegativeBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: palette.liabilityNegativeBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Gastos Hormiga', style: TextStyle(fontSize: 11, color: palette.liabilityNegative, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.cop(_auditResult!.antExpensesTotal),
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.liabilityNegative),
                                    ),
                                    Text(
                                      '${_auditResult!.antExpensesCount} transacciones menores a \$20k',
                                      style: TextStyle(fontSize: 11, color: palette.liabilityNegative.withValues(alpha: 0.8)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: palette.brandAccentBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: palette.brandAccent.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Gastos Totales Auditados', style: TextStyle(fontSize: 11, color: palette.brandAccent, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.cop(_auditResult!.totalAnalyzedExpenses),
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.brandAccent),
                                    ),
                                    Text(
                                      'Fugas potenciales identificadas',
                                      style: TextStyle(fontSize: 11, color: palette.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Summary Text Banner
                        if (_auditResult!.summaryText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: palette.surfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: palette.borderSubtle),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: palette.brandAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _auditResult!.summaryText,
                                    style: TextStyle(fontSize: 12, color: palette.textPrimary, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Section: Gastos Hormiga List
                        Text(
                          'Detalle de Gastos Hormiga (< \$20.000 COP)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        if (_auditResult!.antExpensesItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: palette.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: palette.borderSubtle),
                            ),
                            child: Text(
                              '¡Excelente! No se detectaron micro-gastos hormiga en este período.',
                              style: TextStyle(color: palette.assetPositive, fontSize: 12),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: palette.surfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: palette.borderSubtle),
                            ),
                            child: Column(
                              children: _auditResult!.antExpensesItems.take(6).map((item) {
                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: Icon(Icons.coffee_outlined, size: 18, color: palette.warning),
                                  title: Text(item.description, style: TextStyle(fontSize: 13, color: palette.textPrimary)),
                                  subtitle: item.date.isNotEmpty ? Text(item.date, style: TextStyle(fontSize: 11, color: palette.textSecondary)) : null,
                                  trailing: Text(
                                    Formatters.cop(item.amount),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: palette.liabilityNegative),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Section: Potential Duplicates
                        if (_auditResult!.potentialDuplicates.isNotEmpty) ...[
                          Text(
                            '⚠️ Posibles Cobros Duplicados',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.warning),
                          ),
                          const SizedBox(height: 8),
                          ..._auditResult!.potentialDuplicates.map((dupe) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: palette.warningBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: palette.warningBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 18, color: palette.warning),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(dupe.description, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: palette.textPrimary)),
                                        Text(dupe.note, style: TextStyle(fontSize: 11, color: palette.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    Formatters.cop(dupe.amount),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: palette.warning),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],

                        // Section: Actionable Tips
                        Text(
                          'Consejos de Optimización Financiera',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        ..._auditResult!.actionableTips.map((tip) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_circle_outline, size: 16, color: palette.assetPositive),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(tip, style: TextStyle(fontSize: 12, color: palette.textPrimary, height: 1.3)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _runAudit,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Re-analizar Auditoría'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
