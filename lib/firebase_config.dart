import 'package:firebase_core/firebase_core.dart';

/// Firebase options loaded from --dart-define.
///
/// Android required defines:
/// - FIREBASE_ANDROID_API_KEY
/// - FIREBASE_ANDROID_APP_ID
/// - FIREBASE_ANDROID_MESSAGING_SENDER_ID
/// - FIREBASE_ANDROID_PROJECT_ID
///
/// Web required defines:
/// - FIREBASE_WEB_API_KEY
/// - FIREBASE_WEB_APP_ID
/// - FIREBASE_WEB_MESSAGING_SENDER_ID
/// - FIREBASE_WEB_PROJECT_ID
class FirebaseConfig {
  static FirebaseOptions? get androidOptions {
    const String apiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    const String appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const String messagingSenderId = String.fromEnvironment(
      'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
    );
    const String projectId = String.fromEnvironment(
      'FIREBASE_ANDROID_PROJECT_ID',
    );
    const String storageBucket = String.fromEnvironment(
      'FIREBASE_ANDROID_STORAGE_BUCKET',
    );

    return _buildOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );
  }

  static FirebaseOptions? get webOptions {
    const String apiKey = String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: 'AIzaSyAsgBrxqgSCt83BxDHQyeScSAVRj7pwK7s',
    );
    const String appId = String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: '1:894004314968:web:27109f9dc09e72758ddb2d',
    );
    const String messagingSenderId = String.fromEnvironment(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
      defaultValue: '894004314968',
    );
    const String projectId = String.fromEnvironment(
      'FIREBASE_WEB_PROJECT_ID',
      defaultValue: 'huit-americain',
    );
    const String authDomain = String.fromEnvironment(
      'FIREBASE_WEB_AUTH_DOMAIN',
      defaultValue: 'huit-americain.firebaseapp.com',
    );
    const String storageBucket = String.fromEnvironment(
      'FIREBASE_WEB_STORAGE_BUCKET',
      defaultValue: 'huit-americain.firebasestorage.app',
    );
    const String measurementId = String.fromEnvironment(
      'FIREBASE_WEB_MEASUREMENT_ID',
    );

    return _buildOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
      measurementId: measurementId,
    );
  }

  static FirebaseOptions? _buildOptions({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
    String? authDomain,
    String? storageBucket,
    String? measurementId,
  }) {
    final List<String> requiredValues = <String>[
      apiKey,
      appId,
      messagingSenderId,
      projectId,
    ];

    final bool hasAllRequired = requiredValues.every(
      (String value) => value.trim().isNotEmpty,
    );

    if (!hasAllRequired) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: _nullIfEmpty(authDomain),
      storageBucket: _nullIfEmpty(storageBucket),
      measurementId: _nullIfEmpty(measurementId),
    );
  }

  static String? _nullIfEmpty(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
