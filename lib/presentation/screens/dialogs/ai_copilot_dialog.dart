import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../providers/finance_state_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';

class AiCopilotDialog extends ConsumerStatefulWidget {
  const AiCopilotDialog({super.key});

  @override
  ConsumerState<AiCopilotDialog> createState() => _AiCopilotDialogState();
}

class _ChatMessage {
  const _ChatMessage({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

class _AiCopilotDialogState extends ConsumerState<AiCopilotDialog> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    '¿Cómo está mi patrimonio neto actual?',
    '¿Cuánto debo en tarjetas y qué estrategia de pago me recomiendas?',
    '¿En qué bolsillos tengo más liquidez libre?',
    'Dame 3 consejos de ahorro según mis balances.',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMessage(
      isUser: false,
      text: '¡Hola! Soy tu Copiloto Financiero IA. Conozco tus cuentas, bolsillos y tarjetas de crédito en tiempo real. ¿En qué te puedo asesorar hoy?',
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, dynamic> _buildFinancialContext() {
    final totals = ref.read(dashboardTotalsProvider).value;
    final accounts = ref.read(accountsProvider).value ?? [];
    final pockets = ref.read(pocketsProvider).value ?? [];
    final cards = ref.read(creditCardsProvider).value ?? [];

    return {
      'net_worth': totals?.netWorth ?? 0,
      'total_assets': totals?.totalAssets ?? 0,
      'total_debt': totals?.totalDebt ?? 0,
      'accounts': accounts.map((a) => {'name': a.name}).toList(),
      'pockets': pockets.map((p) => {'name': p.name, 'balance': p.balance}).toList(),
      'cards': cards
          .map((c) => {
                'name': c.name,
                'entity': c.entity,
                'debt': c.debt,
                'available': c.availableCredit,
                'cut_off_day': c.cutOffDay,
                'payment_due_day': c.paymentDueDay,
              })
          .toList(),
    };
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (presetText == null) {
      _inputController.clear();
    }

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final aiService = ref.read(aiAssistantServiceProvider);
      final history = _messages
          .sublist(0, _messages.length - 1)
          .map((m) => {
                'role': m.isUser ? 'user' : 'model',
                'text': m.text,
              })
          .toList();

      final financialContext = _buildFinancialContext();
      final reply = await aiService.chatCopilot(
        message: text,
        history: history,
        financialContext: financialContext,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: reply));
      });
    } catch (e) {
      if (!mounted) return;
      // Fallback response with local data if edge function / key is not available
      final totals = ref.read(dashboardTotalsProvider).value;
      final fallbackText = 'Analizando tus datos locales:\n'
          '• Patrimonio Neto: ${Formatters.cop(totals?.netWorth ?? 0)}\n'
          '• Total Activos: ${Formatters.cop(totals?.totalAssets ?? 0)}\n'
          '• Total Deuda Tarjetas: ${Formatters.cop(totals?.totalDebt ?? 0)}\n\n'
          'Nota: ${e.toString().replaceAll("Exception: ", "")}. Si configuraste GEMINI_API_KEY en Supabase, el asistente responderá con análisis profundo.';

      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: fallbackText));
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.brandAccentBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.brandAccent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.auto_awesome, color: palette.brandAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Copiloto Financiero IA',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          'Asesor personal con Gemini Flash y contexto de tus balances',
                          style: TextStyle(fontSize: 12, color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Quick prompt suggestions
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPrompts.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(p, style: TextStyle(fontSize: 11, color: palette.textPrimary)),
                        backgroundColor: palette.surfaceSubtle,
                        side: BorderSide(color: palette.borderSubtle),
                        onPressed: _isLoading ? null : () => _sendMessage(p),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Chat messages list
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.borderSubtle),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final m = _messages[i];
                      return Align(
                        alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: mediaQuery.size.width * 0.7),
                          decoration: BoxDecoration(
                            color: m.isUser ? palette.brandAccent : palette.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: m.isUser ? palette.brandAccent : palette.borderSubtle,
                            ),
                          ),
                          child: SelectableText(
                            m.text,
                            style: TextStyle(
                              fontSize: 13,
                              color: m.isUser ? Colors.white : palette.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: palette.brandAccent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Gemini Flash está analizando tus finanzas...',
                      style: TextStyle(fontSize: 12, color: palette.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Input bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'Pregúntale a tu copiloto financiero...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: palette.brandAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
