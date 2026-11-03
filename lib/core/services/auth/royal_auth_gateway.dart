import 'package:firebase_auth/firebase_auth.dart';

/// Authentication boundary for the login experience.
abstract interface class RoyalAuthGateway {
  Future<void> signIn({required String email, required String password});

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> signInWithGoogle();

  Future<void> signOut();

  Future<void> deleteAccount();

  Future<void> updateProfile({String? displayName, String? photoURL});

  Stream<User?>? get authStateChanges;

  User? get currentUser;
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

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() =>
      Future<void>.error(const AuthProviderNotConfigured());

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) =>
      Future<void>.error(const AuthProviderNotConfigured());

  @override
  Stream<User?>? get authStateChanges => null;

  @override
  User? get currentUser => null;
}
