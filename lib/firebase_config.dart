import 'package:firebase_core/firebase_core.dart';

/// Minimal Firebase options loaded from --dart-define for Android.
///
/// Required defines:
/// - FIREBASE_ANDROID_API_KEY
/// - FIREBASE_ANDROID_APP_ID
/// - FIREBASE_ANDROID_MESSAGING_SENDER_ID
/// - FIREBASE_ANDROID_PROJECT_ID
///
/// Optional define:
/// - FIREBASE_ANDROID_STORAGE_BUCKET
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
      storageBucket: storageBucket.trim().isEmpty ? null : storageBucket,
    );
  }
}
