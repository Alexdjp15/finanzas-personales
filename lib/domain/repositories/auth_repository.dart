abstract class AuthRepository {
  /// Signs in using either email or username.
  Future<void> signIn({required String identifier, required String password});

  /// Registers a new user with email, password, and unique username.
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  });

  /// Resolves the registered email for a given username.
  Future<String?> getEmailByUsername(String username);

  Future<void> signOut();
  Stream<bool> authStateChanges();
  String? get currentUserId;
}
