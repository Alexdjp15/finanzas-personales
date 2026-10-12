import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../utils/formatters.dart';

class CardPaymentDialog extends ConsumerStatefulWidget {
  const CardPaymentDialog({super.key});

  @override
  ConsumerState<CardPaymentDialog> createState() => _CardPaymentDialogState();
}

class _CardPaymentDialogState extends ConsumerState<CardPaymentDialog> {
  String? _cardId;
  String? _pocketId;
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
        const SnackBar(content: Text('Por favor ingresa un monto válido')),
      );
      return;
    }

    if (_cardId == null || _pocketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar la tarjeta y el bolsillo de origen')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.recordCardPayment(
        cardId: _cardId!,
        pocketId: _pocketId!,
        amount: amount,
        date: DateTime.now(),
        description: _descController.text.trim().isEmpty ? 'Abono a tarjeta de crédito' : _descController.text.trim(),
      );

      invalidateFinanceProviders(ref);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abono registrado: cupo restaurado exitosamente')),
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
    final cardsAsync = ref.watch(creditCardsProvider);
    final pocketsAsync = ref.watch(pocketsProvider);

    final mediaQuery = MediaQuery.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: cardsAsync.when(
            loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
            data: (cards) {
              final pockets = pocketsAsync.value ?? [];
              final uniqueCards = {for (final c in cards) c.id: c}.values.toList();
              final uniquePockets = {for (final p in pockets) p.id: p}.values.toList();

              if (uniqueCards.isEmpty || uniquePockets.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, color: Color(0xFF2563EB), size: 28),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Abono a Tarjeta de Crédito',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      uniqueCards.isEmpty
                          ? 'No hay tarjetas de crédito registradas para abonar.'
                          : 'No hay bolsillos con saldo disponibles para realizar el abono.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card_rounded, color: Color(0xFF2563EB), size: 28),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Abono a Tarjeta de Crédito',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('dropdown_card_payment_card'),
                    isExpanded: true,
                    initialValue: uniqueCards.any((c) => c.id == _cardId) ? _cardId : null,
                    decoration: const InputDecoration(labelText: 'Tarjeta a abonar', border: OutlineInputBorder()),
                    items: uniqueCards
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                '${c.entity} ${c.name} - Deuda: ${Formatters.cop(c.debt)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _cardId = val;
                        if (val != null) {
                          final card = uniqueCards.firstWhere((c) => c.id == val);
                          if (card.debt > 0) {
                            _amountController.text = card.debt.toString();
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('dropdown_card_payment_pocket'),
                    isExpanded: true,
                    initialValue: uniquePockets.any((p) => p.id == _pocketId) ? _pocketId : null,
                    decoration: const InputDecoration(
                      labelText: 'Bolsillo de donde sale el dinero',
                      border: OutlineInputBorder(),
                    ),
                    items: uniquePockets
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.name} (Saldo: ${Formatters.cop(p.balance)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _pocketId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto del abono',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Descripción / Nota', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_isLoading ? 'Procesando...' : 'Pagar Tarjeta'),
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
