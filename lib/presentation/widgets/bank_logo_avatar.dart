import 'package:flutter/material.dart';
import '../../domain/models/bank_catalog.dart';

class BankLogoAvatar extends StatelessWidget {
  const BankLogoAvatar({
    super.key,
    this.bankName,
    this.bankId,
    this.size = 36,
  });

  final String? bankName;
  final String? bankId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bank = _resolveBank();
    final initial = (bank.isCustom && (bankName?.isNotEmpty ?? false))
        ? bankName!.trim()[0].toUpperCase()
        : bank.name.isNotEmpty
            ? bank.name[0].toUpperCase()
            : 'B';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.10),
      child: Image.asset(
        bank.assetPath,
        width: size * 0.80,
        height: size * 0.80,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              initial,
              style: TextStyle(
                color: bank.primaryColor == const Color(0xFFFDDA24)
                    ? const Color(0xFFB78103)
                    : bank.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.44,
              ),
            ),
          );
        },
      ),
    );
  }

  BankItem _resolveBank() {
    if (bankId != null) {
      final byId = BankCatalog.findById(bankId!);
      if (byId != null) return byId;
    }
    if (bankName != null && bankName!.trim().isNotEmpty) {
      return BankCatalog.bestMatch(bankName!);
    }
    return BankCatalog.other;
  }
}

class BankSelectorField extends StatelessWidget {
  const BankSelectorField({
    super.key,
    required this.selectedBank,
    required this.onBankSelected,
    this.customNameController,
    this.labelText = 'Entidad Bancaria',
  });

  final BankItem selectedBank;
  final ValueChanged<BankItem> onBankSelected;
  final TextEditingController? customNameController;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCustom = selectedBank.isCustom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _openBankPicker(context),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: labelText,
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: BankLogoAvatar(
                  bankId: selectedBank.id,
                  bankName: selectedBank.name,
                  size: 28,
                ),
              ),
              suffixIcon: const Icon(Icons.arrow_drop_down),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              selectedBank.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (isCustom && customNameController != null) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: customNameController,
            decoration: InputDecoration(
              labelText: 'Nombre de la Entidad',
              hintText: 'Ej. Banco Agrario, Cooperativa...',
              prefixIcon: const Icon(Icons.account_balance_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa el nombre de la entidad' : null,
          ),
        ],
      ],
    );
  }

  void _openBankPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BankPickerSheet(
        selected: selectedBank,
        onSelected: (bank) {
          Navigator.pop(ctx);
          onBankSelected(bank);
        },
      ),
    );
  }
}

class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({
    required this.selected,
    required this.onSelected,
  });

  final BankItem selected;
  final ValueChanged<BankItem> onSelected;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchController = TextEditingController();
  List<BankItem> _filtered = BankCatalog.items;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filter);
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = BankCatalog.items;
      } else {
        _filtered = BankCatalog.items.where((b) {
          return b.name.toLowerCase().contains(query) ||
              b.aliases.any((a) => a.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Seleccionar Entidad',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Buscar banco o billetera...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _filtered[index];
                  final isCurrent = item.id == widget.selected.id;
                  return ListTile(
                    leading: BankLogoAvatar(
                      bankId: item.id,
                      bankName: item.name,
                      size: 32,
                    ),
                    title: Text(
                      item.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? theme.colorScheme.primary : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20)
                        : null,
                    onTap: () => widget.onSelected(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
