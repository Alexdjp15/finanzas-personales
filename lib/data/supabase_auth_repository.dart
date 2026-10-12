import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<bool> authStateChanges() {
    return _client.auth.onAuthStateChange.map((data) => data.session != null);
  }

  @override
  Future<String?> getEmailByUsername(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // 1. Try querying the profiles table
    try {
      final res = await _client
          .from('profiles')
          .select('email')
          .ilike('username', clean)
          .maybeSingle();
      if (res != null && res['email'] != null) {
        return res['email'].toString().trim().toLowerCase();
      }
    } catch (_) {
      // Direct table select might fail if table or permissions are not yet ready; fallback to RPC
    }

    // 2. Try calling RPC get_email_by_username
    try {
      final rpcRes = await _client.rpc('get_email_by_username', params: {
        'p_username': clean,
      });
      if (rpcRes != null && rpcRes.toString().trim().isNotEmpty) {
        return rpcRes.toString().trim().toLowerCase();
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> signIn({required String identifier, required String password}) async {
    final clean = identifier.trim();
    if (clean.isEmpty) {
      throw StateError('Por favor ingresa tu correo o nombre de usuario.');
    }

    String emailToUse;
    if (clean.contains('@')) {
      emailToUse = clean.toLowerCase();
    } else {
      final resolvedEmail = await getEmailByUsername(clean);
      if (resolvedEmail == null || resolvedEmail.isEmpty) {
        throw StateError(
          'No se encontró ninguna cuenta asociada al usuario "$clean". Por favor verifica tus datos o ingresa con tu correo.',
        );
      }
      emailToUse = resolvedEmail;
    }

    await _client.auth.signInWithPassword(email: emailToUse, password: password);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim().toLowerCase();

    if (cleanUsername.length < 3) {
      throw StateError('El nombre de usuario debe tener al menos 3 caracteres.');
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_.-]+$');
    if (!usernameRegex.hasMatch(cleanUsername)) {
      throw StateError('El nombre de usuario solo puede contener letras, números, puntos, guiones y guiones bajos.');
    }

    // Validate that username is not already taken
    final existingEmail = await getEmailByUsername(cleanUsername);
    if (existingEmail != null && existingEmail.isNotEmpty) {
      throw StateError('El nombre de usuario "$cleanUsername" ya está en uso. Por favor elige otro.');
    }

    final res = await _client.auth.signUp(
      email: cleanEmail,
      password: password,
      data: {'username': cleanUsername},
    );

    if (res.user != null && (res.user!.identities == null || res.user!.identities!.isEmpty)) {
      throw StateError('Este correo electrónico ya se encuentra registrado. Por favor inicia sesión con tu contraseña.');
    }

    // Register user profile
    if (res.user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': res.user!.id,
          'username': cleanUsername,
          'email': cleanEmail,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Ignored if handled by database trigger
      }
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
