import 'dart:convert';
import 'dart:math';

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

  final Map<AppSfxEvent, AudioPlayer> _players = <AppSfxEvent, AudioPlayer>{};
  final Map<AppSfxEvent, String> _eventToAsset = <AppSfxEvent, String>{};
  final Set<AppSfxEvent> _readyEvents = <AppSfxEvent>{};
  final Random _random = Random();
  AudioPlayer? _backgroundPlayer;
  String? _backgroundTrackPath;
  bool _initialized = false;
  bool _initializing = false;
  bool _enabled = true;

  bool get isEnabled => _enabled;
  bool get isReady => _initialized && _readyEvents.isNotEmpty;

  set isEnabled(bool value) {
    _enabled = value;
    if (!value) {
      for (final AudioPlayer player in _players.values) {
        unawaited(player.stop());
      }
      final AudioPlayer? backgroundPlayer = _backgroundPlayer;
      if (backgroundPlayer != null) {
        unawaited(backgroundPlayer.stop());
      }
    } else {
      unawaited(_resumeBackgroundMusic());
    }
  }

  Future<void> initialize({bool strict = false}) async {
    if (_initialized) return;
    if (_initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      return;
    }
    _initializing = true;

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

    for (final MapEntry<AppSfxEvent, String> entry in _eventToAsset.entries) {
      await _preparePlayer(entry.key, entry.value);
    }
    await _prepareBackgroundPlayer(availableAssets);

    _initialized = true;
    _initializing = false;

    if (strict && !_hasMinimumRequiredAssetsReady()) {
      throw StateError('No minimum SFX assets available.');
    }
  }

  Future<Set<String>> _loadSfxAssetPaths() async {
    const Set<String> fallbackAssets = <String>{
      'assets/sfx/click.mp3',
      'assets/sfx/pioche.mp3',
      'assets/sfx/play_card.mp3',
      'assets/sfx/notif_chat.mp3',
      'assets/sfx/notif_chat_pop_up.mp3',
      'assets/sfx/win.mp3',
      'assets/sfx/loose.mp3',
    };
    try {
      final String manifestRaw = await rootBundle.loadString(
        'AssetManifest.json',
      );
      final Map<String, dynamic> manifest =
          jsonDecode(manifestRaw) as Map<String, dynamic>;
      final Set<String> fromManifest = manifest.keys
          .where((String key) => key.startsWith('assets/sfx/'))
          .toSet();
      return fromManifest.isEmpty ? fallbackAssets : fromManifest;
    } catch (_) {
      return fallbackAssets;
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
    if (!_readyEvents.contains(event)) {
      return;
    }
    final AudioPlayer? player = _players[event];
    if (player == null) return;

    try {
      final double safeVolume = volume.clamp(0, 1).toDouble();
      await player.setVolume(safeVolume);
      await player.seek(Duration.zero);
      await player.resume();
    } catch (error, stackTrace) {
      debugPrint('SFX skipped for $event: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _hasMinimumRequiredAssetsReady() {
    const Set<AppSfxEvent> priorities = <AppSfxEvent>{
      AppSfxEvent.click,
      AppSfxEvent.draw,
      AppSfxEvent.playCard,
      AppSfxEvent.notif,
      AppSfxEvent.chat,
      AppSfxEvent.win,
      AppSfxEvent.lose,
    };
    return _readyEvents.any(priorities.contains);
  }

  Future<void> _preparePlayer(AppSfxEvent event, String assetPath) async {
    final String sourcePath = assetPath.startsWith('assets/')
        ? assetPath.substring('assets/'.length)
        : assetPath;

    final AudioPlayer player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      // best effort on unsupported platforms
    }
    try {
      await rootBundle.load(assetPath);
      await player.setSource(AssetSource(sourcePath));
      _players[event] = player;
      _readyEvents.add(event);
      debugPrint('SFX ready: $event => $assetPath');
    } catch (error, stackTrace) {
      debugPrint('SFX asset unavailable for $event ($assetPath): $error');
      debugPrintStack(stackTrace: stackTrace);
      await player.dispose();
    }
  }

  Future<void> _prepareBackgroundPlayer(Set<String> availableAssets) async {
    final List<String> tracks = availableAssets
        .where(
          (String path) =>
              _basenameWithoutExtension(path).startsWith('sound_background'),
        )
        .toList()
      ..sort();
    if (tracks.isEmpty) {
      return;
    }

    final String selectedTrack = tracks[_random.nextInt(tracks.length)];
    final String sourcePath = selectedTrack.startsWith('assets/')
        ? selectedTrack.substring('assets/'.length)
        : selectedTrack;
    final AudioPlayer player = AudioPlayer();

    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setVolume(0.28);
      await rootBundle.load(selectedTrack);
      await player.setSource(AssetSource(sourcePath));
      _backgroundPlayer = player;
      _backgroundTrackPath = selectedTrack;
      if (_enabled) {
        await player.resume();
      }
      debugPrint('BGM ready: $selectedTrack');
    } catch (error, stackTrace) {
      debugPrint('Background music unavailable for $selectedTrack: $error');
      debugPrintStack(stackTrace: stackTrace);
      await player.dispose();
      _backgroundPlayer = null;
      _backgroundTrackPath = null;
    }
  }

  Future<void> _resumeBackgroundMusic() async {
    final AudioPlayer? player = _backgroundPlayer;
    if (player == null || _backgroundTrackPath == null) {
      return;
    }
    try {
      await player.setVolume(0.28);
      await player.resume();
    } catch (_) {
      // best effort: gameplay SFX should keep working even if BGM resume fails
    }
  }
}
