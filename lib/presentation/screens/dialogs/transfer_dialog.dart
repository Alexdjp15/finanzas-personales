import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../utils/formatters.dart';

class TransferDialog extends ConsumerStatefulWidget {
  const TransferDialog({super.key});

  @override
  ConsumerState<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<TransferDialog> {
  String? _fromPocketId;
  String? _toPocketId;
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un monto válido mayor a 0')),
      );
      return;
    }

    if (_fromPocketId == null || _toPocketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar el bolsillo de origen y el de destino')),
      );
      return;
    }

    if (_fromPocketId == _toPocketId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El bolsillo de origen y destino deben ser diferentes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.transferBetweenPockets(
        fromPocketId: _fromPocketId!,
        toPocketId: _toPocketId!,
        amount: amount,
        date: DateTime.now(),
        description: _descController.text.trim(),
      );

      invalidateFinanceProviders(ref);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transferencia entre bolsillos realizada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pocketsAsync = ref.watch(pocketsProvider);
    final accountsAsync = ref.watch(accountsProvider);

    final mediaQuery = MediaQuery.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: pocketsAsync.when(
            loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
            data: (pockets) {
              final accounts = accountsAsync.value ?? [];
              final uniquePockets = {for (final p in pockets) p.id: p}.values.toList();

              String accountName(String accId) {
                for (final a in accounts) {
                  if (a.id == accId) return a.name;
                }
                return 'Cuenta';
              }

              if (uniquePockets.length < 2) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 28),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Transferir entre Bolsillos',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Necesitas al menos 2 bolsillos (en el mismo o en distintos bancos) para realizar transferencias.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
                  ],
                );
              }

              final destinationPockets = uniquePockets.where((p) => p.id != _fromPocketId).toList();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 28),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Transferir entre Bolsillos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('dropdown_transfer_from_pocket'),
                    isExpanded: true,
                    initialValue: uniquePockets.any((p) => p.id == _fromPocketId) ? _fromPocketId : null,
                    decoration: const InputDecoration(
                      labelText: 'Bolsillo Origen',
                      border: OutlineInputBorder(),
                    ),
                    items: uniquePockets
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${accountName(p.accountId)} • ${p.name} (${Formatters.cop(p.balance)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _fromPocketId = val;
                        if (_toPocketId == val) {
                          _toPocketId = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: Key('dropdown_transfer_to_pocket_${_fromPocketId ?? "all"}'),
                    isExpanded: true,
                    initialValue: destinationPockets.any((p) => p.id == _toPocketId) ? _toPocketId : null,
                    decoration: InputDecoration(
                      labelText: 'Bolsillo Destino',
                      border: const OutlineInputBorder(),
                      helperText: destinationPockets.isEmpty ? 'Selecciona primero un bolsillo de origen distinto' : null,
                    ),
                    items: destinationPockets
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${accountName(p.accountId)} • ${p.name} (${Formatters.cop(p.balance)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _toPocketId = val),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto a transferir',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Nota (Opcional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_isLoading ? 'Transfiriendo...' : 'Realizar Transferencia'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
