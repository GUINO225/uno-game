import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppSfxEvent {
  click,
  draw,
  playCard,
  win,
  lose,
  notif,
  chat,
  popup,
  error,
  success,
  shuffle,
}

class AppSfxService {
  AppSfxService._();

  static final AppSfxService instance = AppSfxService._();

  final AudioPlayer _player = AudioPlayer();
  final Map<AppSfxEvent, String> _eventToAsset = <AppSfxEvent, String>{};
  bool _initialized = false;
  bool _enabled = true;

  bool get isEnabled => _enabled;

  set isEnabled(bool value) {
    _enabled = value;
    if (!value) {
      _player.stop();
    }
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      await _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      // Player mode is best-effort depending on platform.
    }

    final Set<String> availableAssets = await _loadSfxAssetPaths();

    _eventToAsset[AppSfxEvent.click] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['click'],
    );
    _eventToAsset[AppSfxEvent.draw] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['draw', 'pioche'],
      contains: <String>['draw', 'pioche'],
    );
    _eventToAsset[AppSfxEvent.playCard] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['play_card'],
      contains: <String>['play', 'card'],
    );
    _eventToAsset[AppSfxEvent.win] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['win', 'victory'],
      contains: <String>['win', 'victory'],
    );
    _eventToAsset[AppSfxEvent.lose] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['lose', 'loose', 'defeat'],
      contains: <String>['lose', 'loose', 'defeat'],
    );
    _eventToAsset[AppSfxEvent.notif] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['notif', 'notification'],
      contains: <String>['notif'],
    );
    _eventToAsset[AppSfxEvent.chat] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['chat', 'notif_chat'],
      contains: <String>['chat'],
    );
    _eventToAsset[AppSfxEvent.popup] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['popup', 'pop_up'],
      contains: <String>['popup', 'pop_up'],
    );
    _eventToAsset[AppSfxEvent.error] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['error'],
      contains: <String>['error'],
    );
    _eventToAsset[AppSfxEvent.success] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['success'],
      contains: <String>['success'],
    );
    _eventToAsset[AppSfxEvent.shuffle] = _pickAsset(
      availableAssets,
      exactBaseNames: <String>['shuffle'],
      contains: <String>['shuffle'],
    );

    _eventToAsset.removeWhere((AppSfxEvent _, String path) => path.isEmpty);
  }

  Future<Set<String>> _loadSfxAssetPaths() async {
    try {
      final String manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest =
          jsonDecode(manifestRaw) as Map<String, dynamic>;
      return manifest.keys
          .where((String key) => key.startsWith('assets/sfx/'))
          .toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  String _pickAsset(
    Set<String> availablePaths, {
    List<String> exactBaseNames = const <String>[],
    List<String> contains = const <String>[],
  }) {
    for (final String wanted in exactBaseNames) {
      for (final String assetPath in availablePaths) {
        if (_basenameWithoutExtension(assetPath) == wanted) {
          return assetPath;
        }
      }
    }

    for (final String wanted in contains) {
      for (final String assetPath in availablePaths) {
        if (_basenameWithoutExtension(assetPath).contains(wanted)) {
          return assetPath;
        }
      }
    }

    return '';
  }

  String _basenameWithoutExtension(String path) {
    final String fileName = path.split('/').last;
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return fileName;
    }
    return fileName.substring(0, dotIndex);
  }

  Future<void> playClick() => _play(AppSfxEvent.click, volume: 0.8);
  Future<void> playDraw() => _play(AppSfxEvent.draw, volume: 0.85);
  Future<void> playCard() => _play(AppSfxEvent.playCard, volume: 0.85);
  Future<void> playWin() => _play(AppSfxEvent.win, volume: 0.95);
  Future<void> playLose() => _play(AppSfxEvent.lose, volume: 0.9);
  Future<void> playNotif() => _play(AppSfxEvent.notif, volume: 0.75);
  Future<void> playChat() => _play(AppSfxEvent.chat, volume: 0.78);
  Future<void> playPopup() => _play(AppSfxEvent.popup, volume: 0.72);
  Future<void> playError() => _play(AppSfxEvent.error, volume: 0.75);
  Future<void> playSuccess() => _play(AppSfxEvent.success, volume: 0.78);
  Future<void> playShuffle() => _play(AppSfxEvent.shuffle, volume: 0.82);

  Future<void> _play(AppSfxEvent event, {double volume = 1}) async {
    if (!_enabled) {
      return;
    }
    if (!_initialized) {
      await initialize();
    }
    final String? assetPath = _eventToAsset[event];
    if (assetPath == null || assetPath.isEmpty) {
      return;
    }

    final String sourcePath = assetPath.startsWith('assets/')
        ? assetPath.substring('assets/'.length)
        : assetPath;

    try {
      await _player.stop();
      await _player.play(
        AssetSource(sourcePath),
        volume: volume.clamp(0, 1).toDouble(),
      );
    } catch (error, stackTrace) {
      debugPrint('SFX skipped for $event: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
