import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'firebase_web_config_source_stub.dart'
    if (dart.library.html) 'firebase_web_config_source_web.dart'
    as web_config;

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
  static FirebaseOptions? optionsForCurrentPlatform() {
    final FirebaseOptions? override = _overrideOptionsForCurrentPlatform();
    if (override != null) {
      return override;
    }
    try {
      return DefaultFirebaseOptions.currentPlatform;
    } catch (_) {
      return null;
    }
  }

  static FirebaseOptions? _overrideOptionsForCurrentPlatform() {
    if (kIsWeb) {
      return webOptions;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidOptions;
    }
    return null;
  }

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

  static FirebaseOptions? get webOptions {
    final Map<String, String> windowConfig =
        web_config.readFirebaseWebConfigFromWindow();

    const String apiKeyDefine = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const String appIdDefine = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const String messagingSenderIdDefine = String.fromEnvironment(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
    );
    const String projectIdDefine = String.fromEnvironment(
      'FIREBASE_WEB_PROJECT_ID',
    );
    const String authDomainDefine = String.fromEnvironment(
      'FIREBASE_WEB_AUTH_DOMAIN',
    );
    const String storageBucketDefine = String.fromEnvironment(
      'FIREBASE_WEB_STORAGE_BUCKET',
    );
    const String measurementIdDefine = String.fromEnvironment(
      'FIREBASE_WEB_MEASUREMENT_ID',
    );

    final String apiKey = _pickWebValue(
      defineValue: apiKeyDefine,
      windowValue: windowConfig['apiKey'],
    );
    final String appId = _pickWebValue(
      defineValue: appIdDefine,
      windowValue: windowConfig['appId'],
    );
    final String messagingSenderId = _pickWebValue(
      defineValue: messagingSenderIdDefine,
      windowValue: windowConfig['messagingSenderId'],
    );
    final String projectId = _pickWebValue(
      defineValue: projectIdDefine,
      windowValue: windowConfig['projectId'],
    );
    final String authDomain = _pickWebValue(
      defineValue: authDomainDefine,
      windowValue: windowConfig['authDomain'],
    );
    final String storageBucket = _pickWebValue(
      defineValue: storageBucketDefine,
      windowValue: windowConfig['storageBucket'],
    );
    final String measurementId = _pickWebValue(
      defineValue: measurementIdDefine,
      windowValue: windowConfig['measurementId'],
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
      authDomain: authDomain.trim().isEmpty ? null : authDomain,
      storageBucket: storageBucket.trim().isEmpty ? null : storageBucket,
      measurementId: measurementId.trim().isEmpty ? null : measurementId,
    );
  }

  static String _pickWebValue({
    required String defineValue,
    required String? windowValue,
  }) {
    if (defineValue.trim().isNotEmpty) {
      return defineValue;
    }
    return (windowValue ?? '').trim();
  }
}
