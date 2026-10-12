import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/ai_assistant_service.dart';
import 'supabase_providers.dart';

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AiAssistantService(client: client);
});
