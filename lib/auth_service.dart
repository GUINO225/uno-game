import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthFailureReason { cancelled, unavailable, network, unknown }

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
      final GoogleSignInAccount? account = await GoogleSignIn.instance.authenticate();
      if (account == null) {
        return GoogleAuthResult.failure(reason: AuthFailureReason.cancelled);
      }
      final GoogleSignInAuthentication authentication = await account.authentication;
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
      if (e.code == 'network-request-failed') {
        return GoogleAuthResult.failure(
          reason: AuthFailureReason.network,
          message: 'Erreur réseau pendant la connexion Google.',
        );
      }
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.unknown,
        message: e.message,
      );
    } catch (e) {
      return GoogleAuthResult.failure(
        reason: AuthFailureReason.unknown,
        message: '$e',
      );
    }
  }
}
