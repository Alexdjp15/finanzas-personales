import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_state_providers.dart';
import '../providers/supabase_providers.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../../domain/models/bank_catalog.dart';
import '../widgets/bank_logo_avatar.dart';
import '../widgets/app_logo_widget.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _PocketDraft {
  _PocketDraft({required this.name, required int initialBalance})
      : controller = TextEditingController(text: initialBalance.toString());
  String name;
  final TextEditingController controller;
}

class _AccountDraft {
  _AccountDraft({
    required this.name,
    String accountNumber = '',
    required int unallocatedBalance,
    required this.pockets,
  })  : accountNumberController = TextEditingController(text: accountNumber),
        unallocatedController = TextEditingController(text: unallocatedBalance.toString());

  String name;
  final TextEditingController accountNumberController;
  final TextEditingController unallocatedController;
  final List<_PocketDraft> pockets;
}

class _CardDraft {
  _CardDraft({
    required this.entity,
    required this.name,
    required this.franchise,
    required this.lastFourDigits,
    required int limit,
    required int available,
    required this.cutOffDay,
    required this.paymentDueDay,
  })  : limitController = TextEditingController(text: limit.toString()),
        availableController = TextEditingController(text: available.toString());

  String entity;
  String name;
  String franchise;
  String lastFourDigits;
  final TextEditingController limitController;
  final TextEditingController availableController;
  int cutOffDay;
  int paymentDueDay;
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _isLoading = false;

  late final List<_AccountDraft> _accounts;
  late final List<_CardDraft> _cards;

  @override
  void initState() {
    super.initState();
    // Default initial draft starts completely clean at 0 COP
    _accounts = [
      _AccountDraft(
        name: 'Bancolombia',
        accountNumber: '',
        unallocatedBalance: 0,
        pockets: [
          _PocketDraft(name: 'Personal', initialBalance: 0),
        ],
      ),
    ];

    _cards = [];
  }

  @override
  void dispose() {
    for (final acc in _accounts) {
      acc.accountNumberController.dispose();
      acc.unallocatedController.dispose();
      for (final p in acc.pockets) {
        p.controller.dispose();
      }
    }
    for (final c in _cards) {
      c.limitController.dispose();
      c.availableController.dispose();
    }
    super.dispose();
  }

  void _addAccount() {
    BankItem selectedBank = BankCatalog.items.first;
    final customNameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Añadir Cuenta Banco'),
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
                    labelText: 'N.º de Cuenta (Opcional)',
                    hintText: 'ej. 123-456789-01',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Saldo Disponible en Cuenta (Fuera de bolsillos)',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final finalName = selectedBank.isCustom
                    ? customNameCtrl.text.trim()
                    : selectedBank.name;
                final num = numberCtrl.text.trim();
                final bal = int.tryParse(balanceCtrl.text.trim()) ?? 0;
                if (finalName.isNotEmpty) {
                  setState(() {
                    _accounts.add(_AccountDraft(
                      name: finalName,
                      accountNumber: num,
                      unallocatedBalance: bal,
                      pockets: [],
                    ));
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Agregar Banco'),
            ),
          ],
        ),
      ),
    );
  }

  void _addPocketToAccount(_AccountDraft account) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nuevo Bolsillo en ${account.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del Bolsillo',
                hintText: 'ej. Apartamentos, Graficolor, Ahorro',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Saldo Inicial COP', prefixText: '\$ ', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final bal = int.tryParse(balanceCtrl.text.trim()) ?? 0;
              if (name.isNotEmpty) {
                setState(() {
                  account.pockets.add(_PocketDraft(name: name, initialBalance: bal));
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Agregar Bolsillo'),
          ),
        ],
      ),
    );
  }

  void _addCard() {
    BankItem selectedBank = BankCatalog.items.first;
    final customNameCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final digitsCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '0');
    final availCtrl = TextEditingController(text: '0');
    String franchise = 'Visa';
    int cutOffDay = 15;
    int paymentDueDay = 30;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Añadir Tarjeta de Crédito'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BankSelectorField(
                  selectedBank: selectedBank,
                  customNameController: customNameCtrl,
                  labelText: 'Entidad Emisora',
                  onBankSelected: (bank) {
                    setDlgState(() => selectedBank = bank);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre / Tipo (ej. Clásica, Oro, Black)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: franchise,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Franquicia', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Visa', child: Text('Visa')),
                    DropdownMenuItem(value: 'Mastercard', child: Text('Mastercard')),
                    DropdownMenuItem(value: 'American Express', child: Text('American Express')),
                    DropdownMenuItem(value: 'Diners Club', child: Text('Diners Club')),
                    DropdownMenuItem(value: 'Otra', child: Text('Otra')),
                  ],
                  onChanged: (v) => setDlgState(() => franchise = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: digitsCtrl,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Últimos 4 dígitos', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cupo Total COP', prefixText: r'$ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: availCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cupo Disponible COP', prefixText: r'$ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: cutOffDay,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Día corte', border: OutlineInputBorder()),
                        items: [
                          for (int i = 1; i <= 31; i++) DropdownMenuItem(value: i, child: Text('Día $i')),
                        ],
                        onChanged: (v) => setDlgState(() => cutOffDay = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: paymentDueDay,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Límite pago', border: OutlineInputBorder()),
                        items: [
                          for (int i = 1; i <= 31; i++) DropdownMenuItem(value: i, child: Text('Día $i')),
                        ],
                        onChanged: (v) => setDlgState(() => paymentDueDay = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final entity = selectedBank.isCustom
                    ? customNameCtrl.text.trim()
                    : selectedBank.name;
                final name = nameCtrl.text.trim();
                final digits = digitsCtrl.text.trim();
                final limit = int.tryParse(limitCtrl.text.trim()) ?? 0;
                final avail = int.tryParse(availCtrl.text.trim()) ?? limit;

                if (entity.isNotEmpty && name.isNotEmpty && digits.length == 4) {
                  setState(() {
                    _cards.add(_CardDraft(
                      entity: entity,
                      name: name,
                      franchise: franchise,
                      lastFourDigits: digits,
                      limit: limit,
                      available: avail,
                      cutOffDay: cutOffDay,
                      paymentDueDay: paymentDueDay,
                    ));
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Agregar Tarjeta'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOnboarding() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(financeRepositoryProvider);

      // 1. Create accounts, their unallocated pocket, and their sub-pockets
      for (final accDraft in _accounts) {
        final acc = await repo.createAccount(
          accDraft.name,
          accountNumber: accDraft.accountNumberController.text.trim(),
        );
        await repo.addAlias(alias: accDraft.name.toLowerCase(), accountId: acc.id);

        // Create unallocated pocket ("Disponible en Cuenta" / fuera de bolsillos)
        final unallocatedBal = int.tryParse(accDraft.unallocatedController.text.trim()) ?? 0;
        final unallocatedPocket = await repo.createPocket(
          accountId: acc.id,
          name: 'Disponible en Cuenta',
          initialBalance: unallocatedBal,
        );
        await repo.addAlias(alias: 'disponible ${accDraft.name}'.toLowerCase(), pocketId: unallocatedPocket.id);

        // Create custom pockets
        for (final pDraft in accDraft.pockets) {
          final balance = int.tryParse(pDraft.controller.text.trim()) ?? 0;
          final pocket = await repo.createPocket(
            accountId: acc.id,
            name: pDraft.name,
            initialBalance: balance,
          );
          await repo.addAlias(alias: pDraft.name.toLowerCase(), pocketId: pocket.id);
        }
      }

      // 2. Create credit cards
      for (final cDraft in _cards) {
        final limit = int.tryParse(cDraft.limitController.text.trim()) ?? 0;
        final available = int.tryParse(cDraft.availableController.text.trim()) ?? limit;

        final card = await repo.createCreditCard(
          entity: cDraft.entity,
          name: cDraft.name,
          franchise: cDraft.franchise,
          lastFourDigits: cDraft.lastFourDigits,
          creditLimit: limit,
          availableCredit: available,
          cutOffDay: cDraft.cutOffDay,
          paymentDueDay: cDraft.paymentDueDay,
        );

        await repo.addAlias(alias: cDraft.name.toLowerCase(), cardId: card.id);
        await repo.addAlias(alias: '${cDraft.entity} ${cDraft.name}'.toLowerCase(), cardId: card.id);
      }

      // 3. Mark Onboarding completed
      await repo.setOnboardingCompleted(true);

      invalidateFinanceProviders(ref);
      ref.invalidate(onboardingStatusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar configuración: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate preview metrics
    int totalAssets = 0;
    for (final acc in _accounts) {
      totalAssets += int.tryParse(acc.unallocatedController.text.trim()) ?? 0;
      for (final p in acc.pockets) {
        totalAssets += int.tryParse(p.controller.text.trim()) ?? 0;
      }
    }

    int totalDebt = 0;
    for (final c in _cards) {
      final lim = int.tryParse(c.limitController.text.trim()) ?? 0;
      final avail = int.tryParse(c.availableController.text.trim()) ?? lim;
      totalDebt += (lim - avail).clamp(0, lim);
    }

    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.surfaceBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                decoration: AppDecorations.card(context: context, borderRadius: 20),
                child: Padding(
                  padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 500 ? 14.0 : 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const AppLogoWidget(size: 48),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Asistente de Configuración Inicial',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: palette.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Configura tus Cuentas Banco y Tarjetas de Crédito reales para iniciar tu balance.',
                                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),

                      // --- SECTION 1: CUENTAS BANCO Y BOLSILLOS ---
                      Row(
                        children: [
                          Icon(Icons.account_balance, color: palette.brandAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cuentas Banco y Bolsillos',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addAccount,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Añadir Banco'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._accounts.map((acc) {
                        final unalloc = int.tryParse(acc.unallocatedController.text.trim()) ?? 0;
                        final pocketsSum = acc.pockets.fold<int>(
                          0,
                          (sum, p) => sum + (int.tryParse(p.controller.text.trim()) ?? 0),
                        );
                        final accTotal = unalloc + pocketsSum;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                                  BankLogoAvatar(bankName: acc.name, size: 28),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          acc.name,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: palette.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (acc.accountNumberController.text.isNotEmpty)
                                          Text(
                                            'N.º: ${acc.accountNumberController.text}',
                                            style: TextStyle(fontSize: 11, color: palette.textSecondary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    Formatters.cop(accTotal),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: palette.brandAccent),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: () => _addPocketToAccount(acc),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(Icons.add, size: 14),
                                    label: const Text('Bolsillo', style: TextStyle(fontSize: 11)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    tooltip: 'Eliminar Cuenta Banco',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      setState(() => _accounts.remove(acc));
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 14),

                              // Saldo en cuenta (fuera de bolsillos)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          Icon(Icons.account_balance_wallet_outlined, size: 16, color: palette.assetPositive),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text('Dinero en Cuenta (Libre)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: palette.textPrimary)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: acc.unallocatedController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'Saldo fuera de bolsillos',
                                          prefixText: r'$ ',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 32), // spacer aligning with delete pocket button
                                  ],
                                ),
                              ),

                              // Bolsillos adicionales
                              ...acc.pockets.map((pocket) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Icon(Icons.folder_outlined, size: 16, color: palette.textSecondary),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(pocket.name, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: palette.textPrimary)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: pocket.controller,
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) => setState(() {}),
                                          decoration: const InputDecoration(
                                            labelText: 'Saldo Bolsillo COP',
                                            prefixText: r'$ ',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                        tooltip: 'Eliminar bolsillo',
                                        onPressed: () {
                                          setState(() => acc.pockets.remove(pocket));
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // --- SECTION 2: TARJETAS DE CRÉDITO ---
                      Row(
                        children: [
                          Icon(Icons.credit_card, color: palette.liabilityNegative, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tarjetas de Crédito',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addCard,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Añadir Tarjeta'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_cards.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: palette.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: palette.borderSubtle),
                          ),
                          child: Center(
                            child: Text(
                              'No has añadido tarjetas de crédito. Puedes pulsar "Añadir Tarjeta" o continuar si no tienes.',
                              style: TextStyle(color: palette.textSecondary, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ..._cards.map((c) {
                          final limit = int.tryParse(c.limitController.text.trim()) ?? 0;
                          final avail = int.tryParse(c.availableController.text.trim()) ?? limit;
                          final debt = (limit - avail).clamp(0, limit);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: palette.surfaceSubtle,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: palette.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          BankLogoAvatar(bankName: c.entity, size: 32),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${c.entity} ${c.name} (*${c.lastFourDigits}) - ${c.franchise}',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: palette.textPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: palette.liabilityNegative, size: 18),
                                      tooltip: 'Eliminar Tarjeta',
                                      onPressed: () => setState(() => _cards.remove(c)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: palette.surfaceCard,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: palette.borderSubtle),
                                      ),
                                      child: Text(
                                        'Corte: Día ${c.cutOffDay}',
                                        style: TextStyle(fontSize: 11, color: palette.textSecondary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: palette.liabilityNegativeBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: palette.liabilityNegativeBorder),
                                      ),
                                      child: Text(
                                        'Límite Pago: Día ${c.paymentDueDay}',
                                        style: TextStyle(fontSize: 11, color: palette.liabilityNegative, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: c.limitController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'Cupo Total COP',
                                          prefixText: r'$ ',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: c.availableController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'Cupo Disponible COP',
                                          prefixText: r'$ ',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Deuda calculada: ${Formatters.cop(debt)}',
                                  style: TextStyle(fontSize: 12, color: palette.liabilityNegative, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 20),

                      // --- SUMMARY BAR ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: palette.surfaceDarkCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.borderSubtle),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceAround,
                          runAlignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            Column(
                              children: [
                                Text('Activos Iniciales', style: TextStyle(color: palette.textOnDarkMuted, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.cop(totalAssets),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text('Deuda Inicial', style: TextStyle(color: palette.textOnDarkMuted, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.cop(totalDebt),
                                  style: TextStyle(color: palette.liabilityNegative, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text('Patrimonio Neto', style: TextStyle(color: palette.textOnDarkMuted, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.cop(totalAssets - totalDebt),
                                  style: TextStyle(color: palette.assetPositive, fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submitOnboarding,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isLoading ? 'Guardando configuración...' : 'Guardar Configuración y Empezar',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.brandAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
