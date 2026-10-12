import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/ledger_transaction.dart';
import '../../../domain/models/models.dart';
import '../../../domain/models/bank_catalog.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/bank_logo_avatar.dart';

class CardDetailsDialog extends ConsumerWidget {
  const CardDetailsDialog({super.key, required this.card});

  final CreditCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final txsAsync = ref.watch(cardTransactionsProvider(card.id));
    final palette = AppPalette.of(context);

    return Dialog(
      backgroundColor: palette.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: mediaQuery.size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Header ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BankLogoAvatar(bankName: card.entity, size: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${card.entity} ${card.name}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 20, color: palette.brandAccent),
                              tooltip: 'Editar Tarjeta',
                              onPressed: () => _openEditCardDialog(context, ref, card),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${card.franchise} • Terminada en *${card.lastFourDigits}',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 20, color: palette.borderSubtle),

              // --- Content ---
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Summary metrics
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricTile(
                            title: 'Cupo Total',
                            value: Formatters.cop(card.creditLimit),
                            color: palette.textPrimary,
                            bgColor: const Color(0xFFF1F5F9),
                            palette: palette,
                          ),
                          _buildMetricTile(
                            title: 'Cupo Disponible',
                            value: Formatters.cop(card.availableCredit),
                            color: palette.assetPositive,
                            bgColor: palette.assetPositiveBg,
                            palette: palette,
                          ),
                          _buildMetricTile(
                            title: 'Deuda Actual',
                            value: Formatters.cop(card.debt),
                            color: palette.liabilityNegative,
                            bgColor: palette.liabilityNegativeBg,
                            palette: palette,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: palette.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.warningBorder),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 14, color: palette.warning),
                                const SizedBox(width: 6),
                                Text(
                                  'Corte: Día ${card.cutOffDay}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 15, color: palette.warning),
                                const SizedBox(width: 6),
                                Text(
                                  'Límite de Pago: Día ${card.paymentDueDay}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // History header
                      Text(
                        'Historial de Compras y Abonos',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // History list
                      txsAsync.when(
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                        error: (err, _) => Center(child: Text('Error cargando historial: $err', style: TextStyle(color: palette.liabilityNegative))),
                        data: (txList) {
                          if (txList.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(
                                child: Text(
                                  'No hay compras ni abonos registrados para esta tarjeta.',
                                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: txList.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 8),
                                itemBuilder: (ctx, idx) {
                                  final t = txList[idx];
                                  final isPayment = t.type == LedgerTransactionType.cardPayment;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: palette.borderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isPayment ? palette.assetPositiveBg : palette.liabilityNegativeBg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isPayment ? Icons.payment_rounded : Icons.shopping_bag_outlined,
                                            size: 16,
                                            color: isPayment ? palette.assetPositive : palette.liabilityNegative,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.description.isNotEmpty
                                                    ? t.description
                                                    : (isPayment ? 'Abono a Tarjeta' : 'Compra con Tarjeta'),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: palette.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                Formatters.date(t.date),
                                                style: TextStyle(color: palette.textSecondary, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${isPayment ? "+" : "-"}${Formatters.cop(t.amount)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isPayment ? palette.assetPositive : palette.liabilityNegative,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      final csv = _buildCsv(txList, card);
                                      Clipboard.setData(ClipboardData(text: csv));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Historial copiado en formato CSV al portapapeles')),
                                      );
                                    },
                                    icon: const Icon(Icons.download_rounded, size: 16),
                                    label: const Text('Descargar Respaldo (CSV)'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: palette.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'El historial se conserva durante 1 año. Puedes descargar copias de respaldo en cualquier momento.',
                                style: TextStyle(fontSize: 11, color: palette.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    required AppPalette palette,
  }) {
    final effectiveBg = palette.isDark ? color.withValues(alpha: 0.15) : bgColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: palette.isDark ? 0.35 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _buildCsv(List<LedgerTransaction> txs, CreditCard card) {
    final buffer = StringBuffer();
    buffer.writeln('Tarjeta: ${card.entity} ${card.name} (*${card.lastFourDigits})');
    buffer.writeln('Fecha,Tipo,Monto COP,Descripcion');
    for (final t in txs) {
      final isPayment = t.type == LedgerTransactionType.cardPayment;
      final tipo = isPayment ? 'Abono a Tarjeta' : 'Compra / Cargo';
      final desc = t.description.replaceAll('"', '""');
      buffer.writeln('${Formatters.date(t.date)},$tipo,${t.amount},"$desc"');
    }
    return buffer.toString();
  }

  void _openEditCardDialog(
    BuildContext context,
    WidgetRef ref,
    CreditCard card,
  ) {
    BankItem selectedBank = BankCatalog.bestMatch(card.entity);
    final customEntityCtrl = TextEditingController(text: card.entity);
    final nameCtrl = TextEditingController(text: card.name);
    final lastFourCtrl = TextEditingController(text: card.lastFourDigits);
    final limitCtrl = TextEditingController(text: card.creditLimit.toString());
    final cutOffCtrl = TextEditingController(text: card.cutOffDay.toString());
    final dueCtrl = TextEditingController(text: card.paymentDueDay.toString());
    String franchise = card.franchise;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Editar Tarjeta de Crédito'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BankSelectorField(
                  selectedBank: selectedBank,
                  customNameController: customEntityCtrl,
                  labelText: 'Entidad Emisora',
                  onBankSelected: (b) => setDlgState(() => selectedBank = b),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre / Tipo de Tarjeta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: franchise,
                  decoration: const InputDecoration(
                    labelText: 'Franquicia',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Visa', child: Text('Visa')),
                    DropdownMenuItem(value: 'Mastercard', child: Text('Mastercard')),
                    DropdownMenuItem(value: 'American Express', child: Text('American Express')),
                    DropdownMenuItem(value: 'Diners Club', child: Text('Diners Club')),
                    DropdownMenuItem(value: 'Otra', child: Text('Otra')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => franchise = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastFourCtrl,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Últimos 4 dígitos',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cupo Total COP',
                    prefixText: r'$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cutOffCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Día de Corte (1-31)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: dueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Día de Pago (1-31)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final entity = selectedBank.isCustom
                    ? customEntityCtrl.text.trim()
                    : selectedBank.name;
                final name = nameCtrl.text.trim();
                final lastFour = lastFourCtrl.text.trim();
                final limit = int.tryParse(limitCtrl.text.trim()) ?? card.creditLimit;
                final cutOff = int.tryParse(cutOffCtrl.text.trim()) ?? card.cutOffDay;
                final due = int.tryParse(dueCtrl.text.trim()) ?? card.paymentDueDay;

                if (entity.isNotEmpty && name.isNotEmpty) {
                  final debt = card.debt;
                  final newAvail = (limit - debt).clamp(0, limit);
                  final updatedCard = card.copyWith(
                    entity: entity,
                    name: name,
                    franchise: franchise,
                    lastFourDigits: lastFour.isNotEmpty ? lastFour : card.lastFourDigits,
                    creditLimit: limit,
                    availableCredit: newAvail,
                    cutOffDay: cutOff,
                    paymentDueDay: due,
                  );

                  final repo = ref.read(financeRepositoryProvider);
                  await repo.updateCreditCard(updatedCard);
                  invalidateFinanceProviders(ref);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
