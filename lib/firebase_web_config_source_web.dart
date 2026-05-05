import 'dart:html' as html;
import 'dart:js_util' as js_util;

String _readString(dynamic source, String key) {
  if (!js_util.hasProperty(source, key)) {
    return '';
  }
  final dynamic value = js_util.getProperty(source, key);
  return value is String ? value : '';
}

Map<String, String> readFirebaseWebConfigFromWindow() {
  final dynamic window = html.window;
  const String configKey = '__firebaseWebConfig';
  if (!js_util.hasProperty(window, configKey)) {
    return const <String, String>{};
  }

  final dynamic config = js_util.getProperty(window, configKey);
  return <String, String>{
    'apiKey': _readString(config, 'apiKey'),
    'appId': _readString(config, 'appId'),
    'messagingSenderId': _readString(config, 'messagingSenderId'),
    'projectId': _readString(config, 'projectId'),
    'authDomain': _readString(config, 'authDomain'),
    'storageBucket': _readString(config, 'storageBucket'),
    'measurementId': _readString(config, 'measurementId'),
  };
}
