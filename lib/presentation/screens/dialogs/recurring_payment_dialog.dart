import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/models.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../utils/app_theme.dart';

class RecurringPaymentDialog extends ConsumerStatefulWidget {
  const RecurringPaymentDialog({super.key});

  @override
  ConsumerState<RecurringPaymentDialog> createState() => _RecurringPaymentDialogState();
}

class _RecurringPaymentDialogState extends ConsumerState<RecurringPaymentDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dayController = TextEditingController(text: '1');
  bool _autoDeduct = true;
  PaymentMethodType _methodType = PaymentMethodType.creditCard;
  String? _methodId;
  String? _pocketId;
  RecurringPayment? _editingPayment;
  bool _isCreating = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _startEdit(RecurringPayment r) {
    setState(() {
      _editingPayment = r;
      _nameController.text = r.name;
      _amountController.text = r.amount.toString();
      _dayController.text = r.dayOfMonth.toString();
      _methodType = r.methodType;
      _methodId = r.methodId;
      _pocketId = r.pocketId;
      _autoDeduct = r.autoDeduct;
      _isCreating = true;
    });
  }

  Future<void> _createPayment() async {
    final name = _nameController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());
    final day = int.tryParse(_dayController.text.trim());

    if (name.isEmpty || amount == null || amount <= 0 || day == null || day < 1 || day > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena los campos con valores válidos (Día 1-31)')),
      );
      return;
    }

    if (_methodId == null || _pocketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el método de pago y el bolsillo de categoría')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(financeRepositoryProvider);
      if (_editingPayment != null) {
        final updated = _editingPayment!.copyWith(
          name: name,
          amount: amount,
          dayOfMonth: day,
          methodType: _methodType,
          methodId: _methodId!,
          pocketId: _pocketId!,
          autoDeduct: _autoDeduct,
        );
        await repo.updateRecurringPayment(updated);
      } else {
        await repo.createRecurringPayment(
          name: name,
          amount: amount,
          dayOfMonth: day,
          startDate: DateTime.now(),
          methodType: _methodType,
          methodId: _methodId!,
          pocketId: _pocketId!,
          autoDeduct: _autoDeduct,
        );
      }

      invalidateFinanceProviders(ref);
      setState(() {
        _isCreating = false;
        _editingPayment = null;
        _nameController.clear();
        _amountController.clear();
        _dayController.text = '1';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingPayment != null
                ? 'Suscripción actualizada con éxito'
                : 'Suscripción registrada con éxito'),
          ),
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

  Future<void> _deletePayment(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Suscripción'),
        content: Text('¿Deseas eliminar la suscripción "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(financeRepositoryProvider);
        await repo.deleteRecurringPayment(id);
        invalidateFinanceProviders(ref);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recurringAsync = ref.watch(recurringPaymentsProvider);
    final cardsAsync = ref.watch(creditCardsProvider);
    final pocketsAsync = ref.watch(pocketsProvider);

    final palette = AppPalette.of(context);
    final mediaQuery = MediaQuery.of(context);
    return Dialog(
      backgroundColor: palette.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.autorenew_rounded, color: palette.brandAccent, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Suscripciones y Recurrentes',
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
              const SizedBox(height: 16),
              if (!_isCreating)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.brandAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _isCreating = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Suscripción'),
                  ),
                ),
              if (_isCreating) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nombre (ej. Netflix, Gemini)'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Monto mensual COP', prefixText: '\$ '),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _dayController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Día del mes (1-31)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<PaymentMethodType>(
                              key: const Key('dropdown_recurring_method_type'),
                              isExpanded: true,
                              initialValue: _methodType,
                              decoration: const InputDecoration(labelText: 'Tipo de Pago'),
                              items: const [
                                DropdownMenuItem(value: PaymentMethodType.creditCard, child: Text('Tarjeta de Crédito', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: PaymentMethodType.accountPocket, child: Text('Bolsillo de Cuenta', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _methodType = val!;
                                  _methodId = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_methodType == PaymentMethodType.creditCard)
                        cardsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (err, _) => Text('Error: $err', style: TextStyle(color: palette.liabilityNegative)),
                          data: (cards) {
                            final uniqueCards = {for (final c in cards) c.id: c}.values.toList();
                            return DropdownButtonFormField<String>(
                              key: const Key('dropdown_recurring_card_method'),
                              isExpanded: true,
                              initialValue: uniqueCards.any((c) => c.id == _methodId) ? _methodId : null,
                              decoration: const InputDecoration(labelText: 'Tarjeta de Crédito'),
                              items: uniqueCards
                                  .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text('${c.entity} ${c.name}', overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) => setState(() => _methodId = val),
                            );
                          },
                        )
                      else
                        pocketsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (err, _) => Text('Error: $err', style: TextStyle(color: palette.liabilityNegative)),
                          data: (pockets) {
                            final uniquePockets = {for (final p in pockets) p.id: p}.values.toList();
                            return DropdownButtonFormField<String>(
                              key: const Key('dropdown_recurring_pocket_method'),
                              isExpanded: true,
                              initialValue: uniquePockets.any((p) => p.id == _methodId) ? _methodId : null,
                              decoration: const InputDecoration(labelText: 'Bolsillo de cobro'),
                              items: uniquePockets
                                  .map((p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) => setState(() => _methodId = val),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      pocketsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (err, _) => Text('Error: $err', style: TextStyle(color: palette.liabilityNegative)),
                        data: (pockets) {
                          final uniquePockets = {for (final p in pockets) p.id: p}.values.toList();
                          return DropdownButtonFormField<String>(
                            key: const Key('dropdown_recurring_category_pocket'),
                            isExpanded: true,
                            initialValue: uniquePockets.any((p) => p.id == _pocketId) ? _pocketId : null,
                            decoration: const InputDecoration(labelText: 'Bolsillo de categoría / imputación'),
                            items: uniquePockets
                                .map((p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _pocketId = val),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: Text('Deducción automática en fecha', style: TextStyle(color: palette.textPrimary)),
                        subtitle: Text(
                          'Si está activo, el servidor registrará el cobro automáticamente',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                        value: _autoDeduct,
                        onChanged: (val) => setState(() => _autoDeduct = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _isCreating = false;
                              _editingPayment = null;
                              _nameController.clear();
                              _amountController.clear();
                              _dayController.text = '1';
                            }),
                            child: Text('Cancelar', style: TextStyle(color: palette.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.brandAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isLoading ? null : _createPayment,
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Divider(color: palette.borderSubtle),
              recurringAsync.when(
                loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
                error: (err, _) => Text('Error: $err', style: TextStyle(color: palette.liabilityNegative)),
                data: (list) {
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No hay suscripciones configuradas',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: palette.borderSubtle),
                    itemBuilder: (ctx, idx) {
                      final r = list[idx];
                      return ListTile(
                        title: Text(
                          r.name,
                          style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary),
                        ),
                        subtitle: Text(
                          'Día ${r.dayOfMonth} de cada mes • \$${r.amount} • Auto: ${r.autoDeduct ? "Sí" : "No"}',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: palette.brandAccent, size: 20),
                              tooltip: 'Editar Suscripción',
                              onPressed: () => _startEdit(r),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: palette.liabilityNegative, size: 20),
                              tooltip: 'Eliminar',
                              onPressed: () => _deletePayment(r.id, r.name),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
