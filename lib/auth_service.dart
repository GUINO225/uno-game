import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  factory GoogleAuthResult.success(User user) =>
      GoogleAuthResult._(user: user);

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
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _isGoogleSignInInitialized = false;

  FirebaseAuth? get _authOrNull {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _authOrNull?.currentUser;

  Future<GoogleAuthResult> signInWithGoogle() async {
    final FirebaseAuth? auth = _authOrNull;
    if (auth == null) {
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.unavailable,
        message: 'Authentification indisponible sur cet appareil.',
      );
    }

    try {
      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        final UserCredential result = await auth.signInWithPopup(provider);
        final User? user = result.user;
        if (user == null) {
          return GoogleAuthResult.failure(
            reason: AuthFailureReason.unknown,
            message: 'Connexion Google incomplète.',
          );
        }
        return GoogleAuthResult.success(user);
      }

      await _ensureGoogleSignInInitialized();
      final GoogleSignInAccount account = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication authentication = account.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: authentication.idToken,
      );
      final UserCredential result = await auth.signInWithCredential(credential);
      final User? user = result.user;
      if (user == null) {
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.unknown,
          message: 'Connexion Google incomplète.',
        );
      }
      return GoogleAuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthException(e);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return GoogleAuthResult.failure(reason: AuthFailureReason.cancelled);
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.invalidConfiguration,
          message:
              'Configuration Google Sign-In invalide. Vérifiez la configuration Firebase/Google.',
        );
      }
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.unknown,
        message: e.description ?? 'Erreur Google Sign-In inconnue.',
      );
    } catch (e) {
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.unknown,
        message: '$e',
      );
    }
  }


  Future<void> _ensureGoogleSignInInitialized() async {
    if (_isGoogleSignInInitialized) {
      return;
    }

    await _googleSignIn.initialize();
    _isGoogleSignInInitialized = true;
  }

  GoogleAuthResult _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return GoogleAuthResult.failure(reason: AuthFailureReason.cancelled);
      case 'popup-blocked':
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.popupBlocked,
          message:
              'Popup Google bloquée par le navigateur. Autorisez les popups puis réessayez.',
        );
      case 'network-request-failed':
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.network,
          message: 'Erreur réseau pendant la connexion Google.',
        );
      case 'operation-not-allowed':
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.providerNotEnabled,
          message:
              'Google Sign-In n’est pas activé dans Firebase Authentication.',
        );
      case 'invalid-api-key':
      case 'app-not-authorized':
      case 'unauthorized-domain':
      case 'web-storage-unsupported':
      case 'invalid-credential':
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.invalidConfiguration,
          message:
              'Configuration Firebase Web invalide. Vérifiez apiKey, authDomain et domaines autorisés.',
        );
      default:
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.unknown,
          message: e.message,
        );
    }
  }
}
