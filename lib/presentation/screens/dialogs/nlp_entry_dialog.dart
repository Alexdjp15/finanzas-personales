import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/models.dart';
import '../../../domain/services/nlp_parser.dart';
import '../../../domain/services/voice_dictation_service.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../providers/voice_dictation_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/voice_dictation_widgets.dart';

class NlpEntryDialog extends ConsumerStatefulWidget {
  const NlpEntryDialog({
    super.key,
    this.startListeningImmediately = false,
  });

  final bool startListeningImmediately;

  @override
  ConsumerState<NlpEntryDialog> createState() => _NlpEntryDialogState();
}

class _NlpEntryDialogState extends ConsumerState<NlpEntryDialog> {
  final _phraseController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  TransactionKind _kind = TransactionKind.expense;
  SourceType? _sourceType;
  String? _sourceId;
  String? _pocketId;
  bool _isCardPayment = false;
  NlpIntent? _intent;
  List<ParseIssue> _issues = [];
  bool _isLoading = false;
  bool _isAiAnalyzed = false;
  bool _isAiLoading = false;
  Timer? _debounceTimer;
  VoiceDictationService? _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceDictationServiceProvider);
    if (widget.startListeningImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final catalog = ref.read(nlpCatalogProvider).value ?? NlpCatalog.empty;
        _toggleVoiceDictation(catalog);
      });
    }
  }

  Future<void> _toggleVoiceDictation(NlpCatalog catalog) async {
    final dictationState = ref.read(voiceDictationProvider);
    final notifier = ref.read(voiceDictationProvider.notifier);

    if (dictationState.isListening) {
      await notifier.stopListening();
      return;
    }

    if (!dictationState.isAvailable) {
      final ok = await notifier.initialize();
      if (!ok) {
        if (mounted) {
          final err = ref.read(voiceDictationProvider).errorMessage ??
              'El micrófono o reconocimiento de voz no está disponible.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
        }
        return;
      }
    }

    await notifier.startListening(
      localeId: 'es_CO',
      onResult: (words, isFinal) {
        if (!mounted) return;
        _phraseController.text = words;
        _phraseController.selection = TextSelection.fromPosition(
          TextPosition(offset: words.length),
        );
        _onPhraseChanged(words, catalog);
      },
    );
  }

  Future<void> _onPhraseChanged(String text, NlpCatalog catalog) async {
    _debounceTimer?.cancel();

    if (text.trim().isEmpty) {
      setState(() {
        _issues = [];
        _isCardPayment = false;
        _intent = null;
        _isAiAnalyzed = false;
        _isAiLoading = false;
      });
      return;
    }

    final parsed = NlpParser.parse(text, catalog);
    setState(() {
      _intent = parsed.intent;
      _issues = parsed.issues;
      _kind = parsed.kind;
      _sourceType = parsed.sourceType;
      _sourceId = parsed.sourceId;
      _pocketId = parsed.pocketId;
      _isCardPayment = parsed.isCardPayment;
      _isAiAnalyzed = parsed.isAiAnalyzed;
      if (parsed.amount != null) {
        _amountController.text = parsed.amount.toString();
      }
      _descController.text = text.trim();
    });

    // If phrase involves creation intents, Colombian slang, or local parser has issues,
    // invoke Gemini Flash in the background with 350ms debounce to refine the interpretation.
    if (!NlpParser.isLocalMatch(text) || parsed.issues.isNotEmpty) {
      setState(() => _isAiLoading = true);
      _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
        final aiService = ref.read(aiAssistantServiceProvider);
        final accounts = ref.read(accountsProvider).value ?? [];
        final cards = ref.read(creditCardsProvider).value ?? [];
        final pockets = ref.read(pocketsProvider).value ?? [];

        try {
          final aiResult = await aiService.parseIntentWithAi(
            text: text,
            catalog: catalog,
            accounts: accounts,
            cards: cards,
            pockets: pockets,
          );

          if (!mounted || _phraseController.text.trim() != text.trim()) return;

          if (aiResult != null) {
            setState(() {
              _intent = aiResult.intent;
              _issues = aiResult.issues;
              _kind = aiResult.kind;
              _sourceType = aiResult.sourceType ?? _sourceType;
              _sourceId = aiResult.sourceId ?? _sourceId;
              _pocketId = aiResult.pocketId ?? _pocketId;
              _isCardPayment = aiResult.isCardPayment;
              _isAiAnalyzed = true;
              if (aiResult.amount != null) {
                _amountController.text = aiResult.amount.toString();
              }
            });
          }
        } catch (_) {
          // Retain local parse results seamlessly on network failure
        } finally {
          if (mounted && _phraseController.text.trim() == text.trim()) {
            setState(() => _isAiLoading = false);
          }
        }
      });
    } else {
      setState(() => _isAiLoading = false);
    }
  }

  String _getActionLabel() {
    if (_isLoading) return 'Guardando...';
    if (_intent is CreatePocketIntent) return 'Crear Bolsillo';
    if (_intent is CreateAccountIntent) return 'Crear Cuenta';
    if (_intent is CreateCardIntent) return 'Crear Tarjeta';
    if (_intent is CreateRecurringIntent) return 'Crear Suscripción';
    if (_intent is TransferIntent) return 'Confirmar Transferencia';
    if (_isCardPayment || _intent is CardPaymentIntent) return 'Confirmar Abono a Tarjeta';
    if (_kind == TransactionKind.income || _intent is IncomeIntent) return 'Confirmar Ingreso';
    return 'Confirmar Gasto';
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final repo = ref.read(financeRepositoryProvider);
    final desc = _descController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_intent is CreatePocketIntent) {
        final pIntent = _intent as CreatePocketIntent;
        final accounts = ref.read(accountsProvider).value ?? [];
        final targetAccountId = pIntent.accountId ?? _sourceId ?? (accounts.isNotEmpty ? accounts.first.id : null);
        if (targetAccountId == null) {
          throw StateError('No se encontró una cuenta banco donde crear el bolsillo');
        }
        await repo.createPocket(
          accountId: targetAccountId,
          name: pIntent.name,
          initialBalance: amount,
        );
        await repo.addAlias(alias: pIntent.name.toLowerCase(), accountId: targetAccountId);
        invalidateFinanceProviders(ref);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bolsillo "${pIntent.name}" creado exitosamente')),
          );
        }
        return;
      }

      if (_intent is CreateAccountIntent) {
        final aIntent = _intent as CreateAccountIntent;
        await repo.createAccountWithInitialPocket(
          entityName: aIntent.name,
          accountType: 'Ahorros',
          initialBalance: amount,
        );
        invalidateFinanceProviders(ref);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cuenta "${aIntent.name}" creada exitosamente')),
          );
        }
        return;
      }

      if (_intent is CreateCardIntent) {
        final cIntent = _intent as CreateCardIntent;
        await repo.createCreditCard(
          entity: cIntent.entity.isNotEmpty ? cIntent.entity : cIntent.name,
          name: cIntent.name,
          franchise: cIntent.franchise,
          lastFourDigits: cIntent.lastFourDigits.isNotEmpty ? cIntent.lastFourDigits : '0000',
          creditLimit: amount > 0 ? amount : (cIntent.creditLimit ?? 2000000),
          availableCredit: amount > 0 ? amount : (cIntent.creditLimit ?? 2000000),
          cutOffDay: cIntent.cutOffDay ?? 15,
          paymentDueDay: cIntent.paymentDueDay ?? 30,
        );
        invalidateFinanceProviders(ref);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tarjeta de Crédito "${cIntent.name}" creada exitosamente')),
          );
        }
        return;
      }

      if (_intent is CreateRecurringIntent) {
        final rIntent = _intent as CreateRecurringIntent;
        final pockets = ref.read(pocketsProvider).value ?? [];
        final cards = ref.read(creditCardsProvider).value ?? [];
        final defaultPocket = pockets.firstOrNull;
        final defaultCard = cards.firstOrNull;

        final isCard = rIntent.isCard;
        final methodId = isCard
            ? (rIntent.sourceId ?? defaultCard?.id ?? '')
            : (rIntent.sourceId ?? defaultPocket?.id ?? '');
        final pocketId = defaultPocket?.id ?? '';

        await repo.createRecurringPayment(
          name: rIntent.name,
          amount: amount > 0 ? amount : (rIntent.amount ?? 50000),
          dayOfMonth: rIntent.dayOfMonth ?? 1,
          startDate: DateTime.now(),
          methodType: isCard ? PaymentMethodType.creditCard : PaymentMethodType.accountPocket,
          methodId: methodId,
          pocketId: pocketId,
          autoDeduct: true,
        );
        invalidateFinanceProviders(ref);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Suscripción "${rIntent.name}" creada exitosamente')),
          );
        }
        return;
      }

      if (_intent is TransferIntent) {
        final tIntent = _intent as TransferIntent;
        final pockets = ref.read(pocketsProvider).value ?? [];
        final fromPocketId = tIntent.fromPocketId ?? _pocketId;
        final toPocketId = tIntent.toPocketId ??
            pockets.where((p) => p.id != fromPocketId).firstOrNull?.id;

        if (fromPocketId == null || toPocketId == null) {
          throw StateError('Debes seleccionar bolsillos de origen y destino para transferir');
        }
        if (amount <= 0) {
          throw StateError('El monto a transferir debe ser mayor a 0');
        }

        await repo.transferBetweenPockets(
          fromPocketId: fromPocketId,
          toPocketId: toPocketId,
          amount: amount,
          date: DateTime.now(),
          description: desc.isNotEmpty ? desc : 'Transferencia entre bolsillos',
        );
        invalidateFinanceProviders(ref);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transferencia entre bolsillos realizada con éxito')),
          );
        }
        return;
      }

      // Standard transaction validations
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor ingresa un monto válido mayor a 0')),
        );
        return;
      }

      if (_sourceType == null || _sourceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes seleccionar un origen o tarjeta')),
        );
        return;
      }

      final pockets = ref.read(pocketsProvider).value ?? [];

      // Validation according to operation mode
      if (_isCardPayment) {
        if (_pocketId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona el bolsillo de donde saldrá el dinero para pagar la tarjeta')),
          );
          return;
        }
      } else if (_sourceType == SourceType.card) {
        if (_pocketId == null) {
          final defaultPocket = pockets.where((p) => p.name.toLowerCase() == 'personal' || p.name.toLowerCase() == 'general').firstOrNull ??
              (pockets.isNotEmpty ? pockets.first : null);
          if (defaultPocket != null) {
            _pocketId = defaultPocket.id;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No hay bolsillos registrados en el sistema.')),
            );
            return;
          }
        }
      } else {
        if (_pocketId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes seleccionar un bolsillo de tu cuenta banco')),
          );
          return;
        }
      }

      final date = DateTime.now();

      if (_isCardPayment) {
        await repo.recordCardPayment(
          cardId: _sourceId!,
          pocketId: _pocketId!,
          amount: amount,
          date: date,
          description: desc.isNotEmpty ? desc : 'Abono a tarjeta de crédito',
        );
      } else if (_sourceType == SourceType.card) {
        await repo.recordCardCharge(
          cardId: _sourceId!,
          pocketId: _pocketId!,
          amount: amount,
          date: date,
          description: desc,
        );
      } else {
        await repo.recordPocketMovement(
          kind: _kind,
          pocketId: _pocketId!,
          amount: amount,
          date: date,
          description: desc,
        );
      }

      invalidateFinanceProviders(ref);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isCardPayment
                ? 'Abono a tarjeta de crédito registrado exitosamente'
                : 'Transacción registrada exitosamente'),
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (_voiceService?.isListening == true) {
      _voiceService?.stopListening();
    }
    _phraseController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(nlpCatalogProvider);
    final pocketsAsync = ref.watch(pocketsProvider);
    final cardsAsync = ref.watch(creditCardsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final dictationState = ref.watch(voiceDictationProvider);
    final colors = AppColors.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: catalogAsync.when(
            loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
            error: (err, _) => Text('Error al cargar catálogo: $err'),
            data: (catalog) {
              final pockets = pocketsAsync.value ?? [];
              final cards = cardsAsync.value ?? [];
              final accounts = accountsAsync.value ?? [];

              final uniquePockets = {for (final p in pockets) p.id: p}.values.toList();
              final uniqueCards = {for (final c in cards) c.id: c}.values.toList();
              final uniqueAccounts = {for (final a in accounts) a.id: a}.values.toList();

              String accountName(String accId) {
                for (final a in accounts) {
                  if (a.id == accId) return a.name;
                }
                return 'Banco';
              }

              // Pockets available for selection:
              // - If card payment, any pocket can be the funding source.
              // - If account movement, only pockets belonging to that account.
              final availablePockets = _isCardPayment
                  ? uniquePockets
                  : (_sourceType == SourceType.account
                      ? uniquePockets.where((p) => p.accountId == _sourceId).toList()
                      : <Pocket>[]);

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology_alt_rounded, color: colors.brandAccent, size: 28),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Ingreso Rápido por Frase (NLP)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phraseController,
                      decoration: InputDecoration(
                        hintText: 'Ej: 50000 compra tc bancolombia | pago tc 100000',
                        labelText: 'Escribe o dicta tu transacción en lenguaje natural',
                        prefixIcon: const Icon(Icons.chat_bubble_outline),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: VoiceDictationButton(
                            key: const Key('voice_dictation_button'),
                            isListening: dictationState.isListening,
                            onPressed: () => _toggleVoiceDictation(catalog),
                          ),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => _onPhraseChanged(val, catalog),
                    ),
                    if (dictationState.isListening) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.liabilityNegativeBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.liabilityNegativeBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Escuchando en vivo... Habla con naturalidad (ej. "compra 45000 tc")',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.liabilityNegative,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (dictationState.errorMessage != null && !dictationState.isListening) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.warningBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: colors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dictationState.errorMessage!,
                                style: TextStyle(fontSize: 12, color: colors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_issues.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.warningBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: colors.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ajusta los campos resaltados: ${_issues.map((i) => i.name).join(', ')}',
                                style: TextStyle(fontSize: 12, color: colors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 28),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        const Text(
                          'Confirmación y Edición:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_isAiLoading)
                          Container(
                            key: const Key('ai_loading_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.brandAccentBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.brandAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.brandAccent,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '✨ Interpretando con IA...',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.brandAccent),
                                ),
                              ],
                            ),
                          )
                        else if (_isAiAnalyzed)
                          Container(
                            key: const Key('ai_analyzed_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.brandAccentBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.brandAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 12, color: colors.brandAccent),
                                const SizedBox(width: 4),
                                Text(
                                  '✨ Analizado con IA',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.brandAccent),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dedicated preview card for CreateRecurringIntent
                    if (_intent is CreateRecurringIntent)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.brandAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.event_repeat_rounded, color: colors.brandAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Suscripción Detectada: "${(_intent as CreateRecurringIntent).name}"',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceCard,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.borderSubtle),
                                  ),
                                  child: Text(
                                    'Cobro mensual: Día ${(_intent as CreateRecurringIntent).dayOfMonth ?? 1}',
                                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceCard,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.borderSubtle),
                                  ),
                                  child: Text(
                                    (_intent as CreateRecurringIntent).isCard ? 'Método: Tarjeta de Crédito' : 'Método: Bolsillo Débito',
                                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Dedicated preview card for CreateCardIntent
                    if (_intent is CreateCardIntent)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.liabilityNegativeBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.credit_card_rounded, color: colors.liabilityNegative, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Alta de Tarjeta: ${(_intent as CreateCardIntent).entity} ${(_intent as CreateCardIntent).name}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceCard,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.borderSubtle),
                                  ),
                                  child: Text(
                                    'Corte: Día ${(_intent as CreateCardIntent).cutOffDay ?? 15}',
                                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.liabilityNegativeBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: colors.liabilityNegativeBorder),
                                  ),
                                  child: Text(
                                    'Límite Pago: Día ${(_intent as CreateCardIntent).paymentDueDay ?? 30}',
                                    style: TextStyle(fontSize: 11, color: colors.liabilityNegative, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Dedicated preview card for CreatePocketIntent
                    if (_intent is CreatePocketIntent)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.assetPositiveBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_special_rounded, color: colors.assetPositive, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nuevo Bolsillo: "${(_intent as CreatePocketIntent).name}"',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Mode indicator badge if it is a card payment
                    if (_isCardPayment)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.brandAccentBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.brandAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.payment_rounded, color: colors.brandAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Abono / Pago de Tarjeta detectado: Se descontará de tu bolsillo y se restaurará el cupo de la tarjeta.',
                                style: TextStyle(fontSize: 12, color: colors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Kind & Amount
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: DropdownButtonFormField<String>(
                            key: Key('dropdown_nlp_op_mode_${_isCardPayment ? "payment" : _kind.name}'),
                            isExpanded: true,
                            initialValue: _isCardPayment ? 'card_payment' : _kind.name,
                            decoration: const InputDecoration(
                              labelText: 'Operación',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'expense', child: Text('Gasto / Compra', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'income', child: Text('Ingreso', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'card_payment', child: Text('Abonar a Tarjeta (Pagar TC)', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) {
                              setState(() {
                                if (v == 'card_payment') {
                                  _isCardPayment = true;
                                  _kind = TransactionKind.expense;
                                  if (uniqueCards.isNotEmpty) {
                                    _sourceType = SourceType.card;
                                    _sourceId = uniqueCards.first.id;
                                  }
                                } else {
                                  _isCardPayment = false;
                                  _kind = v == 'income' ? TransactionKind.income : TransactionKind.expense;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Monto COP',
                              prefixText: '\$ ',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Target / Source Selector
                    if (_isCardPayment) ...[
                      // Select Credit Card to pay
                      DropdownButtonFormField<String>(
                        key: Key('dropdown_nlp_card_target_$_sourceId'),
                        isExpanded: true,
                        initialValue: uniqueCards.any((c) => c.id == _sourceId) ? _sourceId : null,
                        decoration: const InputDecoration(
                          labelText: 'Tarjeta de Crédito a Abonar',
                          border: OutlineInputBorder(),
                        ),
                        items: uniqueCards
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    '${c.entity} ${c.name} (*${c.lastFourDigits}) • Deuda: ${Formatters.cop(c.debt)}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _sourceType = SourceType.card;
                            _sourceId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // Select Pocket to deduct from
                      DropdownButtonFormField<String>(
                        key: Key('dropdown_nlp_funding_pocket_$_pocketId'),
                        isExpanded: true,
                        initialValue: availablePockets.any((p) => p.id == _pocketId) ? _pocketId : null,
                        decoration: const InputDecoration(
                          labelText: 'Bolsillo de Origen (de donde sale el dinero)',
                          border: OutlineInputBorder(),
                        ),
                        items: availablePockets
                            .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    '${accountName(p.accountId)} • ${p.name} (${Formatters.cop(p.balance)})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _pocketId = val),
                      ),
                    ] else ...[
                      // Normal Account or Card Selection
                      DropdownButtonFormField<String>(
                        key: Key('dropdown_nlp_source_${_sourceType?.name}_$_sourceId'),
                        isExpanded: true,
                        initialValue: _sourceId != null &&
                                ((_sourceType == SourceType.card && uniqueCards.any((c) => c.id == _sourceId)) ||
                                    (_sourceType == SourceType.account && uniqueAccounts.any((a) => a.id == _sourceId)))
                            ? '${_sourceType!.name}:$_sourceId'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Origen (Cuenta Banco o Tarjeta)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          ...uniqueAccounts.map(
                            (a) => DropdownMenuItem(
                              value: 'account:${a.id}',
                              child: Text('Cuenta: ${a.name}', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          ...uniqueCards.map(
                            (c) => DropdownMenuItem(
                              value: 'card:${c.id}',
                              child: Text('TC: ${c.entity} ${c.name} (*${c.lastFourDigits})', overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          final parts = val.split(':');
                          setState(() {
                            _sourceType = parts[0] == 'card' ? SourceType.card : SourceType.account;
                            _sourceId = parts[1];
                            _pocketId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // If origin is a Credit Card: NO pocket dropdown is needed!
                      if (_sourceType == SourceType.card)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.liabilityNegativeBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.liabilityNegativeBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: colors.liabilityNegative, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Gasto con Tarjeta de Crédito: Consume tu cupo disponible directamente y no descuenta dinero de tus bolsillos.',
                                  style: TextStyle(fontSize: 12, color: colors.liabilityNegative),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // If origin is an Account: Pocket dropdown ONLY displays that account's pockets
                        DropdownButtonFormField<String>(
                          key: Key('dropdown_nlp_pocket_${_sourceId}_${_pocketId ?? "none"}'),
                          isExpanded: true,
                          initialValue: availablePockets.any((p) => p.id == _pocketId) ? _pocketId : null,
                          decoration: InputDecoration(
                            labelText: 'Bolsillo de la Cuenta',
                            border: const OutlineInputBorder(),
                            helperText: availablePockets.isEmpty
                                ? 'Esta cuenta no tiene bolsillos registrados'
                                : null,
                          ),
                          items: availablePockets
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
                    ],

                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Nota',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                          : const Icon(Icons.check),
                      label: Text(_getActionLabel()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brandAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
