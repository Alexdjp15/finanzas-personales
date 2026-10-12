import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/models.dart';
import '../../providers/finance_state_providers.dart';
import '../../providers/supabase_providers.dart';

class ReminderSettingsDialog extends ConsumerStatefulWidget {
  const ReminderSettingsDialog({super.key});

  @override
  ConsumerState<ReminderSettingsDialog> createState() => _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState extends ConsumerState<ReminderSettingsDialog> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final settingsAsync = ref.read(reminderSettingsProvider);
    settingsAsync.whenData((settings) {
      setState(() {
        _selectedTime = TimeOfDay(hour: settings.hour, minute: settings.minute);
      });
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(financeRepositoryProvider);
      await repo.updateReminderSettings(ReminderSettings(
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      ));

      ref.invalidate(reminderSettingsProvider);
      ref.invalidate(activeAlertsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferencia de horario guardada')),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.alarm_rounded, color: Color(0xFF2563EB), size: 28),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Hora de Alertas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Define la hora del día en que se deben activar los recordatorios de prevención de mora (1 y 2 días antes del vencimiento) y cobros de suscripciones.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Hora seleccionada:'),
                subtitle: Text(
                  _selectedTime.format(context),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
                trailing: ElevatedButton(
                  onPressed: _pickTime,
                  child: const Text('Cambiar'),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_isLoading ? 'Guardando...' : 'Guardar Horario'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
