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

class BankDetailsDialog extends ConsumerStatefulWidget {
  const BankDetailsDialog({super.key, required this.account});

  final Account account;

  @override
  ConsumerState<BankDetailsDialog> createState() => _BankDetailsDialogState();
}

class _BankDetailsDialogState extends ConsumerState<BankDetailsDialog> {
  String? _selectedPocketId; // null = all pockets

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final pocketsAsync = ref.watch(pocketsProvider);
    final txsAsync = ref.watch(accountTransactionsProvider(widget.account.id));
    final palette = AppPalette.of(context);

    return Dialog(
      backgroundColor: palette.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
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
                            BankLogoAvatar(bankName: widget.account.name, size: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.account.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 20, color: palette.brandAccent),
                              tooltip: 'Editar Cuenta Banco',
                              onPressed: () => _openEditAccountDialog(context, ref, widget.account),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.account.accountNumber.isNotEmpty
                              ? 'N.º de Cuenta: ${widget.account.accountNumber}'
                              : 'Cuenta Banco sin número registrado',
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
                  child: pocketsAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                    error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: palette.liabilityNegative))),
                    data: (allPockets) {
                      final bankPockets = allPockets.where((p) => p.accountId == widget.account.id).toList();

                      // Identify primary/unallocated pocket ("Disponible en Cuenta" / "Principal")
                      Pocket? unallocatedPocket;
                      final assignedPockets = <Pocket>[];

                      for (final p in bankPockets) {
                        final norm = p.name.trim().toLowerCase();
                        if (unallocatedPocket == null &&
                            (norm == 'disponible en cuenta' || norm == 'principal' || norm == 'disponible')) {
                          unallocatedPocket = p;
                        } else {
                          assignedPockets.add(p);
                        }
                      }

                      // Fallback: if no pocket matched the names and there's at least one, the first is unallocated
                      if (unallocatedPocket == null && bankPockets.isNotEmpty) {
                        unallocatedPocket = bankPockets.first;
                        assignedPockets.remove(unallocatedPocket);
                      }

                      final unallocatedBalance = unallocatedPocket?.balance ?? 0;
                      final assignedBalance = assignedPockets.fold<int>(0, (sum, p) => sum + p.balance);
                      final totalBalance = bankPockets.fold<int>(0, (sum, p) => sum + p.balance);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Summary metrics
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildMetricTile(
                                title: 'Saldo Total Banco',
                                value: Formatters.cop(totalBalance),
                                color: palette.brandAccent,
                                bgColor: palette.brandAccentBg,
                                palette: palette,
                              ),
                              _buildMetricTile(
                                title: 'Fuera de Bolsillos (Disponible)',
                                value: Formatters.cop(unallocatedBalance),
                                color: palette.assetPositive,
                                bgColor: palette.assetPositiveBg,
                                palette: palette,
                              ),
                              _buildMetricTile(
                                title: 'Saldo en Bolsillos',
                                value: Formatters.cop(assignedBalance),
                                color: palette.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                                bgColor: palette.isDark ? const Color(0x334C1D95) : const Color(0xFFF5F3FF),
                                palette: palette,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Bolsillos list
                          Text(
                            'Distribución de Bolsillos',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (bankPockets.isEmpty)
                            Text(
                              'No hay bolsillos creados en esta cuenta banco.',
                              style: TextStyle(color: palette.textSecondary, fontSize: 13),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: palette.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: palette.borderSubtle),
                              ),
                              child: Column(
                                children: bankPockets.map((p) {
                                  final isUnallocated = p.id == unallocatedPocket?.id;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                isUnallocated ? Icons.account_balance_wallet_outlined : Icons.folder_outlined,
                                                size: 16,
                                                color: isUnallocated ? palette.assetPositive : palette.textSecondary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${p.name} ${isUnallocated ? '(Dinero libre)' : ''}',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: palette.textPrimary,
                                                    fontWeight: isUnallocated ? FontWeight.w600 : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              Formatters.cop(p.balance),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: p.balance >= 0 ? palette.textPrimary : palette.liabilityNegative,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(Icons.edit_outlined, size: 16, color: palette.brandAccent),
                                              tooltip: 'Editar Bolsillo',
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _openEditPocketDialog(context, ref, p),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // --- Movements History Header & Filter ---
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Historial de Movimientos',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: palette.textPrimary,
                                ),
                              ),
                              if (bankPockets.length > 1)
                                DropdownButton<String?>(
                                  value: _selectedPocketId,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  dropdownColor: palette.surfaceCard,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.brandAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('Todos los bolsillos', overflow: TextOverflow.ellipsis)),
                                    for (final p in bankPockets)
                                      DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (v) => setState(() => _selectedPocketId = v),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Transactions list
                          txsAsync.when(
                            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                            error: (err, _) => Center(child: Text('Error cargando historial: $err', style: TextStyle(color: palette.liabilityNegative))),
                            data: (txList) {
                              final filtered = _selectedPocketId == null
                                  ? txList
                                  : txList.where((t) => t.pocketId == _selectedPocketId).toList();

                              if (filtered.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                                  child: Center(
                                    child: Text(
                                      'No hay transacciones registradas para este banco.',
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
                                    itemCount: filtered.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (ctx, idx) {
                                      final t = filtered[idx];
                                      final pocket = bankPockets.cast<Pocket?>().firstWhere(
                                            (p) => p?.id == t.pocketId,
                                            orElse: () => null,
                                          );

                                      final isIncome = t.type == LedgerTransactionType.income;
                                      final isTransfer = t.type == LedgerTransactionType.pocketTransfer;

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
                                                color: isIncome
                                                    ? palette.assetPositiveBg
                                                    : (isTransfer ? palette.brandAccentBg : palette.liabilityNegativeBg),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isIncome
                                                    ? Icons.arrow_downward_rounded
                                                    : (isTransfer ? Icons.swap_horiz_rounded : Icons.arrow_upward_rounded),
                                                size: 16,
                                                color: isIncome
                                                    ? palette.assetPositive
                                                    : (isTransfer ? palette.brandAccent : palette.liabilityNegative),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.description.isNotEmpty ? t.description : _transactionTypeLabel(t.type),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                      color: palette.textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${Formatters.date(t.date)}${pocket != null ? " • ${pocket.name}" : ""}',
                                                    style: TextStyle(color: palette.textSecondary, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '${isIncome ? "+" : "-"}${Formatters.cop(t.amount)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isIncome ? palette.assetPositive : palette.liabilityNegative,
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
                                          final csv = _buildCsv(filtered, bankPockets);
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
                      );
                    },
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

  String _transactionTypeLabel(LedgerTransactionType type) {
    return switch (type) {
      LedgerTransactionType.income => 'Ingreso',
      LedgerTransactionType.expense => 'Gasto',
      LedgerTransactionType.pocketTransfer => 'Transferencia entre bolsillos',
      LedgerTransactionType.cardPayment => 'Abono a Tarjeta',
      LedgerTransactionType.cardCharge => 'Gasto con Tarjeta',
    };
  }

  String _buildCsv(List<LedgerTransaction> txs, List<Pocket> pockets) {
    final buffer = StringBuffer();
    buffer.writeln('Fecha,Tipo,Monto COP,Bolsillo,Descripcion');
    for (final t in txs) {
      final pocket = pockets.cast<Pocket?>().firstWhere((p) => p?.id == t.pocketId, orElse: () => null);
      final pocketName = pocket?.name ?? '';
      final desc = t.description.replaceAll('"', '""');
      buffer.writeln('${Formatters.date(t.date)},${_transactionTypeLabel(t.type)},${t.amount},"$pocketName","$desc"');
    }
    return buffer.toString();
  }

  void _openEditAccountDialog(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) {
    final allPockets = ref.read(pocketsProvider).asData?.value ?? [];
    final bankPockets = allPockets.where((p) => p.accountId == account.id).toList();
    Pocket? unallocatedPocket;
    for (final p in bankPockets) {
      final norm = p.name.trim().toLowerCase();
      if (unallocatedPocket == null &&
          (norm == 'disponible en cuenta' || norm == 'principal' || norm == 'disponible')) {
        unallocatedPocket = p;
        break;
      }
    }
    if (unallocatedPocket == null && bankPockets.isNotEmpty) {
      unallocatedPocket = bankPockets.first;
    }

    BankItem selectedBank = BankCatalog.bestMatch(account.name);
    final customNameCtrl = TextEditingController(text: account.name);
    final numberCtrl = TextEditingController(text: account.accountNumber);
    final balanceCtrl = TextEditingController(
      text: (unallocatedPocket?.balance ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Editar Cuenta Banco'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BankSelectorField(
                  selectedBank: selectedBank,
                  customNameController: customNameCtrl,
                  onBankSelected: (bank) {
                    setDlgState(() => selectedBank = bank);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'N.º de Cuenta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Saldo Disponible (Fuera de bolsillos)',
                    prefixText: r'$ ',
                    border: OutlineInputBorder(),
                  ),
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
                final finalName = selectedBank.isCustom
                    ? customNameCtrl.text.trim()
                    : selectedBank.name;
                final num = numberCtrl.text.trim();
                final bal = int.tryParse(balanceCtrl.text.trim());

                if (finalName.isNotEmpty) {
                  final repo = ref.read(financeRepositoryProvider);
                  await repo.updateAccount(
                    id: account.id,
                    name: finalName,
                    accountNumber: num,
                    adjustBalanceOutsidePockets: bal,
                  );
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

  void _openEditPocketDialog(
    BuildContext context,
    WidgetRef ref,
    Pocket pocket,
  ) {
    final nameCtrl = TextEditingController(text: pocket.name);
    final balanceCtrl = TextEditingController(text: pocket.balance.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Bolsillo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del Bolsillo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Saldo del Bolsillo COP',
                prefixText: r'$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final bal = int.tryParse(balanceCtrl.text.trim());
              if (name.isNotEmpty) {
                final repo = ref.read(financeRepositoryProvider);
                await repo.updatePocket(
                  id: pocket.id,
                  name: name,
                  balance: bal,
                );
                invalidateFinanceProviders(ref);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
