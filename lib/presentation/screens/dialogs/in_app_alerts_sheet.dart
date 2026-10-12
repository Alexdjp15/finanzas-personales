import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/models.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';
import '../../utils/formatters.dart';

class InAppAlertsSheet extends ConsumerWidget {
  const InAppAlertsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(activeAlertsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 28),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Centro de Alertas In-App',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 12),
              alertsAsync.when(
                loading: () => const Center(heightFactor: 3, child: CircularProgressIndicator()),
                error: (err, _) => Text('Error: $err'),
                data: (alerts) {
                  if (alerts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                          SizedBox(height: 12),
                          Text(
                            '¡Todo al día! No tienes pagos o vencimientos inmediatos pendientes de alerta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: alerts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final a = alerts[idx];
                      final isCard = a.event.kind == AlertKind.creditCardDue;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCard ? const Color(0xFFFEE2E2) : const Color(0xFFE0E7FF),
                          child: Icon(
                            isCard ? Icons.credit_card : Icons.autorenew,
                            color: isCard ? Colors.red : Colors.indigo,
                          ),
                        ),
                        title: Text(
                          isCard
                              ? 'Recordatorio de pago: ${a.event.label}'
                              : 'Cobro de suscripción: ${a.event.label}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Vence el ${Formatters.date(a.event.dueDate)} (Faltan ${a.daysBefore} día${a.daysBefore == 1 ? "" : "s"})',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final repo = ref.read(financeRepositoryProvider);
                            await repo.markAlertDelivered(a.id);
                            ref.invalidate(activeAlertsProvider);
                          },
                          child: const Text('Entendido'),
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
