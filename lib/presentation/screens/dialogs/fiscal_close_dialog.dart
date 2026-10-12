import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/services/fiscal_close_service.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../utils/app_theme.dart';

class FiscalCloseDialog extends ConsumerStatefulWidget {
  const FiscalCloseDialog({super.key});

  @override
  ConsumerState<FiscalCloseDialog> createState() => _FiscalCloseDialogState();
}

class _FiscalCloseDialogState extends ConsumerState<FiscalCloseDialog> {
  int _selectedYear = DateTime.now().year;
  FiscalCloseResult? _result;
  bool _isLoading = false;
  bool _confirmedBackup = false;
  final _confirmTextController = TextEditingController();

  Future<void> _generateExport() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      final pockets = await ref.read(pocketsProvider.future);
      final cards = await ref.read(creditCardsProvider.future);
      final txs = await repo.getTransactionsForYear(_selectedYear);

      final res = FiscalCloseService.close(
        year: _selectedYear,
        pockets: pockets,
        cards: cards,
        transactions: txs,
        exportedAt: DateTime.now().toUtc(),
      );

      setState(() {
        _result = res;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeReset() async {
    if (!_confirmedBackup || _confirmTextController.text.trim().toUpperCase() != 'CONFIRMAR') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes confirmar el respaldo y escribir CONFIRMAR')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      final count = await repo.deleteTransactionsForYear(_selectedYear);
      invalidateFinanceProviders(ref);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cierre fiscal completado. Se eliminaron $count transacciones del año $_selectedYear.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al resetear: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _confirmTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Dialog(
      backgroundColor: palette.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.archive_rounded, color: palette.brandAccent, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cierre Fiscal Anual',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'El cierre fiscal exporta todas las transacciones del año en formato JSON y CSV, y posteriormente resetea el histórico en la base de datos dejando intactos los saldos actuales como saldos iniciales del nuevo año.',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Año fiscal a cerrar:', style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary)),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _selectedYear,
                          dropdownColor: palette.surfaceCard,
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600),
                          items: [
                            for (int y = DateTime.now().year; y >= DateTime.now().year - 5; y--)
                              DropdownMenuItem(value: y, child: Text('$y')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedYear = val!;
                              _result = null;
                              _confirmedBackup = false;
                            });
                          },
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.brandAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _generateExport,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Generar Exportación'),
                    ),
                  ],
                ),
                if (_result != null) ...[
                  Divider(height: 28, color: palette.borderSubtle),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.assetPositiveBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.assetPositiveBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✅ Exportación lista: ${_result!.closedTransactionIds.length} transacciones procesadas.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: palette.assetPositive),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _result!.jsonExport));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('JSON copiado al portapapeles')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copiar JSON'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _result!.csvExport));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('CSV copiado al portapapeles')),
                                );
                              },
                              icon: const Icon(Icons.table_chart_outlined, size: 16),
                              label: const Text('Copiar CSV'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.liabilityNegativeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.liabilityNegativeBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Confirmación Doble de Reseteo',
                          style: TextStyle(fontWeight: FontWeight.bold, color: palette.liabilityNegative),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'He copiado y respaldado mi archivo de exportación JSON/CSV.',
                            style: TextStyle(color: palette.textPrimary, fontSize: 13),
                          ),
                          value: _confirmedBackup,
                          onChanged: (val) => setState(() => _confirmedBackup = val ?? false),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _confirmTextController,
                          decoration: const InputDecoration(
                            labelText: 'Escribe "CONFIRMAR" para proceder a borrar',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _executeReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.liabilityNegative,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(_isLoading ? 'Borrando...' : 'Borrar Transacciones y Cerrar Año'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
