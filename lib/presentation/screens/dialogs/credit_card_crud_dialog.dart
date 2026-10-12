import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/bank_catalog.dart';
import '../../../domain/models/models.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/bank_logo_avatar.dart';

class CreditCardCrudDialog extends ConsumerStatefulWidget {
  const CreditCardCrudDialog({super.key});

  @override
  ConsumerState<CreditCardCrudDialog> createState() => _CreditCardCrudDialogState();
}

class _CreditCardCrudDialogState extends ConsumerState<CreditCardCrudDialog> {
  BankItem _selectedBank = BankCatalog.banks.first;
  final _customEntityController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastFourController = TextEditingController();
  final _limitController = TextEditingController(text: '3000000');
  final _availableController = TextEditingController(text: '3000000');
  String _franchise = 'Visa';
  int _cutOffDay = 15;
  int _paymentDueDay = 30;

  CreditCard? _editingCard;
  bool _isCreating = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _customEntityController.dispose();
    _nameController.dispose();
    _lastFourController.dispose();
    _limitController.dispose();
    _availableController.dispose();
    super.dispose();
  }

  void _startCreate() {
    setState(() {
      _editingCard = null;
      _selectedBank = BankCatalog.banks.first;
      _customEntityController.clear();
      _nameController.clear();
      _lastFourController.clear();
      _limitController.text = '3000000';
      _availableController.text = '3000000';
      _franchise = 'Visa';
      _cutOffDay = 15;
      _paymentDueDay = 30;
      _isCreating = true;
    });
  }

  void _startEdit(CreditCard card) {
    final bank = BankCatalog.bestMatch(card.entity);
    setState(() {
      _editingCard = card;
      _selectedBank = bank;
      _customEntityController.text = bank.isCustom ? card.entity : '';
      _nameController.text = card.name;
      _lastFourController.text = card.lastFourDigits;
      _limitController.text = card.creditLimit.toString();
      _availableController.text = card.availableCredit.toString();
      _franchise = card.franchise;
      _cutOffDay = card.cutOffDay;
      _paymentDueDay = card.paymentDueDay;
      _isCreating = true;
    });
  }

  Future<void> _saveCard() async {
    final entity = _selectedBank.isCustom
        ? _customEntityController.text.trim()
        : _selectedBank.name;
    final name = _nameController.text.trim();
    final lastFour = _lastFourController.text.trim();
    final limit = int.tryParse(_limitController.text.trim()) ?? 0;
    final available = int.tryParse(_availableController.text.trim()) ?? 0;

    if (entity.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa la entidad y el nombre de la tarjeta')),
      );
      return;
    }

    if (!RegExp(r'^[0-9]{4}$').hasMatch(lastFour)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los últimos dígitos deben ser exactamente 4 números')),
      );
      return;
    }

    if (limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cupo total debe ser mayor a 0')),
      );
      return;
    }

    if (available < 0 || available > limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cupo disponible no puede exceder el cupo total')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final isEditing = _editingCard != null;

    try {
      final repo = ref.read(financeRepositoryProvider);
      if (isEditing) {
        final debt = _editingCard!.debt;
        final newAvail = (limit - debt).clamp(0, limit);
        final updated = _editingCard!.copyWith(
          entity: entity,
          name: name,
          franchise: _franchise,
          lastFourDigits: lastFour,
          creditLimit: limit,
          availableCredit: newAvail,
          cutOffDay: _cutOffDay,
          paymentDueDay: _paymentDueDay,
        );
        await repo.updateCreditCard(updated);
      } else {
        await repo.createCreditCard(
          entity: entity,
          name: name,
          franchise: _franchise,
          lastFourDigits: lastFour,
          creditLimit: limit,
          availableCredit: available,
          cutOffDay: _cutOffDay,
          paymentDueDay: _paymentDueDay,
        );
      }

      invalidateFinanceProviders(ref);
      setState(() {
        _isCreating = false;
        _editingCard = null;
        _customEntityController.clear();
        _nameController.clear();
        _lastFourController.clear();
        _limitController.text = '3000000';
        _availableController.text = '3000000';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Tarjeta de crédito actualizada exitosamente'
                : 'Tarjeta de Crédito registrada exitosamente'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar tarjeta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCard(CreditCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Tarjeta de Crédito'),
        content: Text(
          '¿Deseas eliminar la tarjeta "${card.entity} ${card.name} (*${card.lastFourDigits})"?\n\n'
          'Solo se podrá eliminar si no tiene transacciones asociadas.',
        ),
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
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(financeRepositoryProvider);
        await repo.deleteCreditCard(card.id);
        invalidateFinanceProviders(ref);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarjeta de crédito eliminada')),
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
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(creditCardsProvider);
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
          maxWidth: 640,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.credit_card_rounded, color: palette.liabilityNegative, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Gestión de Tarjetas de Crédito',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: palette.textPrimary,
                            ),
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header action button
                      if (!_isCreating)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.liabilityNegative,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _startCreate,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Registrar Nueva Tarjeta'),
                          ),
                        ),

                      // Form to add or edit a card
                      if (_isCreating)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: palette.surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: palette.liabilityNegative.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _editingCard != null
                                          ? 'Editar Tarjeta de Crédito'
                                          : 'Nueva Tarjeta de Crédito',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: palette.liabilityNegative,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, size: 20, color: palette.textSecondary),
                                    onPressed: () => setState(() {
                                      _isCreating = false;
                                      _editingCard = null;
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              BankSelectorField(
                                selectedBank: _selectedBank,
                                customNameController: _customEntityController,
                                labelText: 'Entidad Emisora',
                                onBankSelected: (bank) => setState(() => _selectedBank = bank),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre / Tipo',
                                  hintText: 'ej. Clásica, Oro, Black',
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (mediaQuery.size.width < 440) ...[
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _franchise,
                                  decoration: const InputDecoration(
                                    labelText: 'Franquicia',
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Visa', child: Text('Visa')),
                                    DropdownMenuItem(value: 'Mastercard', child: Text('Mastercard')),
                                    DropdownMenuItem(value: 'American Express', child: Text('American Express')),
                                    DropdownMenuItem(value: 'Diners Club', child: Text('Diners Club')),
                                    DropdownMenuItem(value: 'Otra', child: Text('Otra')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _franchise = v);
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _lastFourController,
                                  maxLength: 4,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Últimos 4 dígitos',
                                    hintText: '1234',
                                    counterText: '',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _limitController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Cupo Total',
                                    prefixText: r'$ ',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _availableController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Cupo Disponible',
                                    prefixText: r'$ ',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: _cutOffDay,
                                  decoration: const InputDecoration(
                                    labelText: 'Día de corte',
                                  ),
                                  items: [
                                    for (int i = 1; i <= 31; i++)
                                      DropdownMenuItem(value: i, child: Text('Día $i')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _cutOffDay = v);
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: _paymentDueDay,
                                  decoration: const InputDecoration(
                                    labelText: 'Día de pago',
                                  ),
                                  items: [
                                    for (int i = 1; i <= 31; i++)
                                      DropdownMenuItem(value: i, child: Text('Día $i')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _paymentDueDay = v);
                                  },
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: _franchise,
                                        decoration: const InputDecoration(
                                          labelText: 'Franquicia',
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'Visa', child: Text('Visa')),
                                          DropdownMenuItem(value: 'Mastercard', child: Text('Mastercard')),
                                          DropdownMenuItem(value: 'American Express', child: Text('American Express')),
                                          DropdownMenuItem(value: 'Diners Club', child: Text('Diners Club')),
                                          DropdownMenuItem(value: 'Otra', child: Text('Otra')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) setState(() => _franchise = v);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _lastFourController,
                                        maxLength: 4,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Últimos 4 dígitos',
                                          hintText: '1234',
                                          counterText: '',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _limitController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Cupo Total',
                                          prefixText: r'$ ',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _availableController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Cupo Disponible',
                                          prefixText: r'$ ',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        isExpanded: true,
                                        initialValue: _cutOffDay,
                                        decoration: const InputDecoration(
                                          labelText: 'Día de corte',
                                        ),
                                        items: [
                                          for (int i = 1; i <= 31; i++)
                                            DropdownMenuItem(value: i, child: Text('Día $i')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) setState(() => _cutOffDay = v);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<int>(
                                        isExpanded: true,
                                        initialValue: _paymentDueDay,
                                        decoration: const InputDecoration(
                                          labelText: 'Día de pago',
                                        ),
                                        items: [
                                          for (int i = 1; i <= 31; i++)
                                            DropdownMenuItem(value: i, child: Text('Día $i')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) setState(() => _paymentDueDay = v);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _isCreating = false;
                                      _editingCard = null;
                                    }),
                                    child: Text('Cancelar', style: TextStyle(color: palette.textSecondary)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: palette.liabilityNegative,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _isLoading ? null : _saveCard,
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : Text(_editingCard != null ? 'Actualizar Tarjeta' : 'Guardar Tarjeta'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      // List of current cards
                      cardsAsync.when(
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator())),
                        error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: palette.liabilityNegative))),
                        data: (cards) {
                          if (cards.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  'No tienes tarjetas de crédito registradas.\nPresiona "Registrar Nueva Tarjeta" para añadir una.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: palette.textSecondary),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cards.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final card = cards[idx];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: palette.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: palette.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        BankLogoAvatar(bankName: card.entity, size: 38),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${card.entity} ${card.name} (*${card.lastFourDigits})',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: palette.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                card.franchise,
                                                style: TextStyle(color: palette.textSecondary, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: palette.brandAccent, size: 20),
                                          tooltip: 'Editar tarjeta',
                                          onPressed: _isLoading ? null : () => _startEdit(card),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, color: palette.liabilityNegative, size: 20),
                                          tooltip: 'Eliminar tarjeta',
                                          onPressed: _isLoading ? null : () => _deleteCard(card),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      runSpacing: 4,
                                      spacing: 8,
                                      children: [
                                        Text('Cupo Total: ${Formatters.cop(card.creditLimit)}',
                                            style: TextStyle(fontSize: 13, color: palette.textSecondary)),
                                        Text('Disponible: ${Formatters.cop(card.availableCredit)}',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: palette.assetPositive)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      runSpacing: 4,
                                      spacing: 8,
                                      children: [
                                        Text('Deuda: ${Formatters.cop(card.debt)}',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: palette.liabilityNegative)),
                                        Text('Corte: día ${card.cutOffDay} | Pago: día ${card.paymentDueDay}',
                                            style: TextStyle(fontSize: 12, color: palette.textSecondary)),
                                      ],
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
            ],
          ),
        ),
      ),
    );
  }
}
