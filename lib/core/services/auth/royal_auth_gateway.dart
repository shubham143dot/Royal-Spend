/// Authentication boundary for the login experience.
///
/// The app does not currently include an authentication provider. Keeping the
/// interface here lets a Firebase or other provider be added without coupling
/// the login UI to its SDK.
abstract interface class RoyalAuthGateway {
  Future<void> signIn({required String email, required String password});

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> signInWithGoogle();
}

class AuthProviderNotConfigured implements Exception {
  const AuthProviderNotConfigured();
}

/// Safe default until a real provider is configured; it never reports success.
class UnconfiguredRoyalAuthGateway implements RoyalAuthGateway {
  const UnconfiguredRoyalAuthGateway();

  @override
  Future<void> signIn({required String email, required String password}) =>
      Future<void>.error(const AuthProviderNotConfigured());

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) => Future<void>.error(const AuthProviderNotConfigured());

  @override
  Future<void> sendPasswordReset({required String email}) =>
      Future<void>.error(const AuthProviderNotConfigured());

  @override
  Future<void> signInWithGoogle() =>
      Future<void>.error(const AuthProviderNotConfigured());
}
