import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthFailureReason {
  cancelled,
  unavailable,
  popupBlocked,
  network,
  providerNotEnabled,
  invalidConfiguration,
  unknown,
}

class GoogleAuthResult {
  const GoogleAuthResult._({
    required this.user,
    this.errorMessage,
    this.failureReason,
  });

  final User? user;
  final String? errorMessage;
  final AuthFailureReason? failureReason;

  bool get isSuccess => user != null;

  factory GoogleAuthResult.success(User user) => GoogleAuthResult._(user: user);

  factory GoogleAuthResult.failure({
    required AuthFailureReason reason,
    String? message,
  }) {
    return GoogleAuthResult._(
      user: null,
      failureReason: reason,
      errorMessage: message,
    );
  }
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  GoTrueClient get _auth => Supabase.instance.client.auth;
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((AuthState data) => data.session?.user);

  Future<GoogleAuthResult> signInWithGoogle() async {
    try {
      final bool started = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : null,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      if (!started) {
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.cancelled,
          message: 'Connexion Google annulée.',
        );
      }

      final User? user = _auth.currentUser;
      if (user == null) {
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.unknown,
          message:
              'Connexion Google démarrée. Utilisateur non disponible immédiatement (possible redirection OAuth).',
        );
      }

      await _upsertProfile(user);
      debugPrint('[AuthService] Google sign-in success: uid=${user.id}');
      return GoogleAuthResult.success(user);
    } on AuthException catch (e) {
      return _mapSupabaseAuthException(e);
    } catch (e) {
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.unknown,
        message: '$e',
      );
    }
  }

  Future<void> signOut() async {
    debugPrint('[AuthService] Sign out requested.');
    await _auth.signOut();
  }

  Future<void> ensureProfileForCurrentUser() async {
    final User? user = currentUser;
    if (user == null) return;
    await _upsertProfile(user);
  }

  Future<void> _upsertProfile(User user) async {
    final String displayName =
        (user.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (user.userMetadata?['full_name'] as String).trim()
        : ((user.userMetadata?['name'] as String?)?.trim().isNotEmpty == true
              ? (user.userMetadata?['name'] as String).trim()
              : 'Joueur');

    await _client.from('profiles').upsert(<String, dynamic>{
      'id': user.id,
      'display_name': displayName,
      'email': user.email,
      'photo_url': user.userMetadata?['avatar_url'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  GoogleAuthResult _mapSupabaseAuthException(AuthException e) {
    final String message = (e.message).toLowerCase();

    if (message.contains('popup') && message.contains('closed')) {
      return GoogleAuthResult.failure(reason: AuthFailureReason.cancelled);
    }
    if (message.contains('popup') && message.contains('blocked')) {
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.popupBlocked,
        message:
            'Popup Google bloquée par le navigateur. Autorisez les popups puis réessayez.',
      );
    }
    if (message.contains('network')) {
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.network,
        message: 'Erreur réseau pendant la connexion Google.',
      );
    }
    if (message.contains('provider') && message.contains('disabled')) {
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.providerNotEnabled,
        message: 'Google Sign-In n’est pas activé dans Supabase Auth.',
      );
    }
    if (message.contains('redirect') ||
        message.contains('domain') ||
        message.contains('invalid')) {
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.invalidConfiguration,
        message:
            'Configuration Supabase Auth invalide. Vérifiez Google provider, redirect URL et domaine autorisé.',
      );
    }

    return GoogleAuthResult.failure(
      reason: AuthFailureReason.unknown,
      message: e.message,
    );
  }
}
