import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/bank_catalog.dart';
import '../../../domain/models/models.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/bank_logo_avatar.dart';

class PocketCrudDialog extends ConsumerStatefulWidget {
  const PocketCrudDialog({super.key});

  @override
  ConsumerState<PocketCrudDialog> createState() => _PocketCrudDialogState();
}

class _PocketCrudDialogState extends ConsumerState<PocketCrudDialog> {
  // Pocket controllers
  final _pocketNameController = TextEditingController();
  final _pocketBalanceController = TextEditingController(text: '0');
  String? _selectedAccountId;
  bool _isCreatingPocket = false;

  // Account controllers
  BankItem _selectedBank = BankCatalog.banks.first;
  final _accountEntityController = TextEditingController();
  final _accountTypeController = TextEditingController(text: 'Ahorros');
  final _accountNumberController = TextEditingController();
  final _accountBalanceController = TextEditingController(text: '0');
  bool _isCreatingAccount = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _pocketNameController.dispose();
    _pocketBalanceController.dispose();
    _accountEntityController.dispose();
    _accountTypeController.dispose();
    _accountNumberController.dispose();
    _accountBalanceController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final entity = _selectedBank.isCustom
        ? _accountEntityController.text.trim()
        : _selectedBank.name;
    final type = _accountTypeController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final balance = int.tryParse(_accountBalanceController.text.trim()) ?? 0;

    if (entity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre de la entidad (ej: Davivienda, Bancolombia, Nu)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.createAccountWithInitialPocket(
        entityName: entity,
        accountType: type.isEmpty ? 'Ahorros' : type,
        accountNumber: accountNumber,
        initialBalance: balance,
      );

      invalidateFinanceProviders(ref);
      setState(() {
        _isCreatingAccount = false;
        _selectedBank = BankCatalog.banks.first;
        _accountEntityController.clear();
        _accountTypeController.text = 'Ahorros';
        _accountNumberController.clear();
        _accountBalanceController.text = '0';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta Banco creada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear cuenta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cuenta Banco'),
        content: Text('¿Deseas eliminar la cuenta "$name"? Solo se podrá eliminar si no tiene movimientos registrados.'),
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
        await repo.deleteAccount(id);
        invalidateFinanceProviders(ref);
        if (_selectedAccountId == id) {
          setState(() => _selectedAccountId = null);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta eliminada exitosamente')),
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

  Future<void> _createPocket() async {
    final name = _pocketNameController.text.trim();
    if (name.isEmpty) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una Cuenta Banco')),
      );
      return;
    }

    final balance = int.tryParse(_pocketBalanceController.text.trim()) ?? 0;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(financeRepositoryProvider);
      final newPocket = await repo.createPocket(
        accountId: _selectedAccountId!,
        name: name,
        initialBalance: balance,
      );
      await repo.addAlias(alias: name.toLowerCase(), pocketId: newPocket.id);

      invalidateFinanceProviders(ref);
      setState(() {
        _isCreatingPocket = false;
        _pocketNameController.clear();
        _pocketBalanceController.text = '0';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bolsillo creado exitosamente')),
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

  Future<void> _openEditAccountDialog(Account account) async {
    final pockets = ref.read(pocketsProvider).value ?? [];
    final bankPockets = pockets.where((p) => p.accountId == account.id).toList();

    Pocket? unallocatedPocket;
    for (final p in bankPockets) {
      final norm = p.name.trim().toLowerCase();
      if (norm == 'disponible en cuenta' || norm == 'principal' || norm == 'disponible') {
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

    await showDialog(
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
                  try {
                    final repo = ref.read(financeRepositoryProvider);
                    await repo.updateAccount(
                      id: account.id,
                      name: finalName,
                      accountNumber: num,
                      adjustBalanceOutsidePockets: bal,
                    );
                    invalidateFinanceProviders(ref);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al editar cuenta: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPocket(Pocket pocket) async {
    final nameCtrl = TextEditingController(text: pocket.name);
    final balanceCtrl = TextEditingController(text: pocket.balance.toString());
    final confirmed = await showDialog<bool>(
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(financeRepositoryProvider);
        final bal = int.tryParse(balanceCtrl.text.trim());
        await repo.updatePocket(id: pocket.id, name: nameCtrl.text.trim(), balance: bal);
        invalidateFinanceProviders(ref);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePocket(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Bolsillo'),
        content: Text('¿Estás seguro de eliminar el bolsillo "$name"?'),
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
        await repo.deletePocket(id);
        invalidateFinanceProviders(ref);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
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
          maxWidth: 620,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: DefaultTabController(
          length: 2,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: palette.brandAccent, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cuentas Banco y Bolsillos',
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
                TabBar(
                  labelColor: palette.brandAccent,
                  unselectedLabelColor: palette.textSecondary,
                  indicatorColor: palette.brandAccent,
                  tabs: const [
                    Tab(icon: Icon(Icons.account_balance), text: 'Cuentas Banco'),
                    Tab(icon: Icon(Icons.folder_special), text: 'Bolsillos'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      // --- TAB 1: CUENTAS BANCO ---
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isCreatingAccount)
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.brandAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => setState(() {
                                    _isCreatingAccount = true;
                                    _selectedBank = BankCatalog.banks.first;
                                    _accountEntityController.clear();
                                  }),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Nueva Cuenta Banco'),
                                ),
                              ),
                            if (_isCreatingAccount) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: palette.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: palette.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Añadir Nueva Cuenta Banco',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    BankSelectorField(
                                      selectedBank: _selectedBank,
                                      customNameController: _accountEntityController,
                                      onBankSelected: (bank) {
                                        setState(() {
                                          _selectedBank = bank;
                                          if (!bank.isCustom) {
                                            _accountEntityController.text = bank.name;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _accountNumberController,
                                      decoration: const InputDecoration(
                                        labelText: 'Número de Cuenta (opcional, ej. 123-456789-01)',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _accountTypeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Tipo de Cuenta (ej. Ahorros, Corriente, Digital)',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _accountBalanceController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Saldo Inicial (COP)',
                                        prefixText: '\$ ',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => setState(() => _isCreatingAccount = false),
                                          child: Text('Cancelar', style: TextStyle(color: palette.textSecondary)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: palette.brandAccent,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: _isLoading ? null : _createAccount,
                                          child: Text(_isLoading ? 'Guardando...' : 'Crear Cuenta'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Divider(color: palette.borderSubtle),
                            accountsAsync.when(
                              loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
                              error: (err, _) => Text('Error: $err', style: TextStyle(color: palette.liabilityNegative)),
                              data: (accounts) {
                                final pockets = pocketsAsync.value ?? [];
                                final uniqueAccounts = {for (final a in accounts) a.id: a}.values.toList();

                                if (uniqueAccounts.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Text(
                                        'No hay cuentas banco registradas.',
                                        style: TextStyle(color: palette.textSecondary),
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: uniqueAccounts.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: palette.borderSubtle),
                                  itemBuilder: (ctx, idx) {
                                    final acc = uniqueAccounts[idx];
                                    final accPockets = pockets.where((p) => p.accountId == acc.id).toList();
                                    final total = accPockets.fold<int>(0, (sum, p) => sum + p.balance);

                                    return ListTile(
                                      leading: BankLogoAvatar(bankName: acc.name, size: 38),
                                      title: Text(
                                        acc.accountNumber.isNotEmpty
                                            ? '${acc.name} (${acc.accountNumber})'
                                            : acc.name,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: palette.textPrimary),
                                      ),
                                      subtitle: Text(
                                        '${accPockets.length} bolsillos • Saldo Total: ${Formatters.cop(total)}',
                                        style: TextStyle(color: palette.textSecondary),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit_outlined, size: 20, color: palette.brandAccent),
                                            tooltip: 'Editar Cuenta Banco',
                                            onPressed: () => _openEditAccountDialog(acc),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, color: palette.liabilityNegative, size: 20),
                                            tooltip: 'Eliminar si no tiene movimientos',
                                            onPressed: () => _deleteAccount(acc.id, acc.name),
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

                      // --- TAB 2: BOLSILLOS ---
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isCreatingPocket)
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.brandAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => setState(() => _isCreatingPocket = true),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Nuevo Bolsillo'),
                                ),
                              ),
                            if (_isCreatingPocket) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: palette.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: palette.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Añadir Nuevo Bolsillo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    accountsAsync.when(
                                      loading: () => const LinearProgressIndicator(),
                                      error: (err, _) => Text('Error: $err', style: TextStyle(color: palette.liabilityNegative)),
                                      data: (accs) {
                                        final uniqueAccs = {for (final a in accs) a.id: a}.values.toList();
                                        return DropdownButtonFormField<String>(
                                          key: Key('dropdown_pocket_crud_acc_${_selectedAccountId ?? "none"}'),
                                          isExpanded: true,
                                          initialValue: uniqueAccs.any((a) => a.id == _selectedAccountId)
                                              ? _selectedAccountId
                                              : (uniqueAccs.isNotEmpty ? uniqueAccs.first.id : null),
                                          decoration: const InputDecoration(labelText: 'Cuenta Banco'),
                                          items: uniqueAccs
                                              .map((a) => DropdownMenuItem(
                                                    value: a.id,
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        BankLogoAvatar(bankName: a.name, size: 24),
                                                        const SizedBox(width: 8),
                                                        Flexible(
                                                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                          onChanged: (val) => setState(() => _selectedAccountId = val),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _pocketNameController,
                                      decoration: const InputDecoration(labelText: 'Nombre del Bolsillo'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _pocketBalanceController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Saldo Inicial (COP)',
                                        prefixText: '\$ ',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => setState(() => _isCreatingPocket = false),
                                          child: Text('Cancelar', style: TextStyle(color: palette.textSecondary)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: palette.brandAccent,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: _isLoading ? null : _createPocket,
                                          child: Text(_isLoading ? 'Guardando...' : 'Crear Bolsillo'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Divider(color: palette.borderSubtle),
                            pocketsAsync.when(
                              loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
                              error: (err, _) => Text('Error: $err', style: TextStyle(color: palette.liabilityNegative)),
                              data: (pockets) {
                                final accounts = accountsAsync.value ?? [];
                                final uniquePockets = {for (final p in pockets) p.id: p}.values.toList();

                                String accountName(String accId) {
                                  for (final a in accounts) {
                                    if (a.id == accId) return a.name;
                                  }
                                  return 'Cuenta';
                                }

                                if (uniquePockets.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Text(
                                        'No hay bolsillos creados',
                                        style: TextStyle(color: palette.textSecondary),
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: uniquePockets.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: palette.borderSubtle),
                                  itemBuilder: (ctx, idx) {
                                    final p = uniquePockets[idx];
                                    return ListTile(
                                      title: Text(
                                        p.name,
                                        style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary),
                                      ),
                                      subtitle: Text(
                                        '${accountName(p.accountId)} • Saldo: ${Formatters.cop(p.balance)}',
                                        style: TextStyle(color: palette.textSecondary),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit_outlined, size: 20, color: palette.brandAccent),
                                            tooltip: 'Editar Bolsillo',
                                            onPressed: () => _editPocket(p),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, color: palette.liabilityNegative, size: 20),
                                            tooltip: 'Eliminar',
                                            onPressed: () => _deletePocket(p.id, p.name),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
