import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../providers/finance_state_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';

class AiCopilotDialog extends ConsumerStatefulWidget {
  const AiCopilotDialog({super.key});

  /// Displays Sof.IA chat dialog with smooth scale and fade transition.
  static Future<void> show(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar Sof.IA',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => const AiCopilotDialog(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        if (isMobile) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: child,
            ),
          );
        }
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

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
      text:
          '¡Hola! Soy Sof.IA, tu asistente financiera personal. Analizo tus cuentas y bolsillos en tiempo real. ¿Qué te gustaría consultar o planear hoy?',
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
          'Nota: ${e.toString().replaceAll("Exception: ", "")}. Si configuraste GEMINI_API_KEY en Supabase, Sof.IA responderá con análisis profundo.';

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
    final isMobile = mediaQuery.size.width < 600;

    return Dialog(
      alignment: isMobile ? Alignment.bottomCenter : Alignment.center,
      insetPadding: isMobile
          ? const EdgeInsets.only(top: 48)
          : const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      backgroundColor: palette.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.0 : 20.0,
            vertical: isMobile ? 14.0 : 20.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMobile) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: palette.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],

              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF3B82F6), // Azul vibrante
                          Color(0xFF8B5CF6), // Púrpura eléctrico
                          Color(0xFF06B6D4), // Cian luminoso
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sof.IA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: palette.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Tu asesora financiera inteligente',
                          style: TextStyle(fontSize: 12, color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
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
                          constraints: BoxConstraints(maxWidth: mediaQuery.size.width * 0.75),
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
                      'Sof.IA está analizando tus finanzas...',
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
                        hintText: 'Pregúntale a Sof.IA...',
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
