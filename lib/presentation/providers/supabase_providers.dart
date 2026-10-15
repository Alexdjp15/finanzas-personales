import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/supabase_auth_repository.dart';
import '../../data/supabase_finance_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/finance_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseFinanceRepository(client);
});

final authStateProvider = StreamProvider<bool>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges();
});

final currentUsernameProvider = Provider<String?>((ref) {
  try {
    ref.watch(authStateProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    return authRepo.currentUsername;
  } catch (_) {
    return null;
  }
});

