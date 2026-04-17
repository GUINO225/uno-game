import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

class AudioService with WidgetsBindingObserver {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const double _bgmVolume = 0.28;
  static const String _assetRoot = 'assets/sfx/';
  static const String _defaultBackgroundTrack =
      'assets/sfx/sound_background_10.mp3';

  final Map<AppSfxEvent, AudioPlayer> _players = <AppSfxEvent, AudioPlayer>{};
  final Map<AppSfxEvent, String> _eventToAsset = <AppSfxEvent, String>{};
  final Set<AppSfxEvent> _readyEvents = <AppSfxEvent>{};
  final Set<String> _preloadedAssets = <String>{};

  Set<String> _availableAssets = <String>{};
  AudioPlayer? _backgroundPlayer;
  String? _backgroundTrackPath;

  bool _initialized = false;
  bool _initializing = false;
  bool _enabled = true;
  bool _backgroundMusicEnabled = true;
  bool _isBackgroundPlaying = false;
  bool _backgroundMusicUnlocked = !kIsWeb;
  bool _lifecycleBound = false;

  bool get isEnabled => _enabled;
  bool get isReady => _initialized && _readyEvents.isNotEmpty;
  bool get isBackgroundMusicEnabled => _backgroundMusicEnabled;
  bool get isBackgroundMusicPlaying => _isBackgroundPlaying;
  bool get isBackgroundMusicActive => _backgroundMusicEnabled && _isBackgroundPlaying;
  bool get isBackgroundMusicUnlocked => _backgroundMusicUnlocked;

  set isEnabled(bool value) {
    _enabled = value;
    _log('Global audio enabled = $value');
    if (!value) {
      for (final AudioPlayer player in _players.values) {
        unawaited(player.stop());
      }
      final AudioPlayer? backgroundPlayer = _backgroundPlayer;
      if (backgroundPlayer != null) {
        unawaited(backgroundPlayer.stop());
        _isBackgroundPlaying = false;
      }
      return;
    }
    unawaited(_resumeBackgroundMusic());
  }

  Future<void> initialize({bool strict = false}) async {
    if (_initialized) {
      return;
    }
    if (_initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      return;
    }

    _initializing = true;
    _bindLifecycleIfNeeded();
    _log('Initializing audio service...');

    try {
      _availableAssets = await _loadSfxAssetPaths();
      await _preloadAllAudioAssets();
      _buildEventMappings();

      for (final MapEntry<AppSfxEvent, String> entry in _eventToAsset.entries) {
        await _preparePlayer(entry.key, entry.value);
      }
      await _prepareBackgroundPlayer();

      _initialized = true;
      _log(
        'Audio initialization complete '
        '(assets=${_availableAssets.length}, preloaded=${_preloadedAssets.length}, readyEvents=${_readyEvents.length}).',
      );

      if (_backgroundMusicEnabled) {
        await playDefaultBackgroundMusic();
      }

      if (strict && !_hasMinimumRequiredAssetsReady()) {
        throw StateError('No minimum SFX assets available.');
      }
    } finally {
      _initializing = false;
    }
  }

  void registerUserGesture() {
    if (_backgroundMusicUnlocked) {
      return;
    }
    _backgroundMusicUnlocked = true;
    _log('Audio unlocked from first user gesture (web policy).');
    if (_backgroundMusicEnabled) {
      unawaited(playDefaultBackgroundMusic(fromUserGesture: true));
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
      'assets/sfx/sound_background.mp3',
      'assets/sfx/sound_background_10.mp3',
    };

    try {
      final String manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest =
          jsonDecode(manifestRaw) as Map<String, dynamic>;
      final Set<String> fromManifest = manifest.keys
          .where((String key) => key.startsWith(_assetRoot))
          .toSet();
      if (fromManifest.isEmpty) {
        _log('AssetManifest has no sfx assets, using fallback list.');
        return fallbackAssets;
      }
      _log('Found ${fromManifest.length} audio assets in AssetManifest.');
      return fromManifest;
    } catch (error, stackTrace) {
      _log('Failed to read AssetManifest, using fallback list. Error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallbackAssets;
    }
  }

  Future<void> _preloadAllAudioAssets() async {
    for (final String assetPath in _availableAssets.toList()..sort()) {
      try {
        await rootBundle.load(assetPath);
        _preloadedAssets.add(assetPath);
      } catch (error, stackTrace) {
        _log('Preload failed for $assetPath: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    _log('Preloaded ${_preloadedAssets.length}/${_availableAssets.length} audio assets.');
  }

  void _buildEventMappings() {
    _eventToAsset.clear();
    _eventToAsset[AppSfxEvent.click] = _pickAsset(
      exactBaseNames: <String>['click'],
    );
    _eventToAsset[AppSfxEvent.draw] = _pickAsset(
      exactBaseNames: <String>['draw', 'pioche'],
      contains: <String>['draw', 'pioche'],
    );
    _eventToAsset[AppSfxEvent.playCard] = _pickAsset(
      exactBaseNames: <String>['play_card'],
      contains: <String>['play', 'card'],
    );
    _eventToAsset[AppSfxEvent.win] = _pickAsset(
      exactBaseNames: <String>['win', 'victory'],
      contains: <String>['win', 'victory'],
    );
    _eventToAsset[AppSfxEvent.lose] = _pickAsset(
      exactBaseNames: <String>['lose', 'loose', 'defeat'],
      contains: <String>['lose', 'loose', 'defeat'],
    );
    _eventToAsset[AppSfxEvent.notif] = _pickAsset(
      exactBaseNames: <String>['notif', 'notification'],
      contains: <String>['notif'],
    );
    _eventToAsset[AppSfxEvent.chat] = _pickAsset(
      exactBaseNames: <String>['chat', 'notif_chat'],
      contains: <String>['chat'],
    );
    _eventToAsset[AppSfxEvent.popup] = _pickAsset(
      exactBaseNames: <String>['popup', 'pop_up'],
      contains: <String>['popup', 'pop_up'],
    );
    _eventToAsset[AppSfxEvent.error] = _pickAsset(
      exactBaseNames: <String>['error'],
      contains: <String>['error'],
    );
    _eventToAsset[AppSfxEvent.success] = _pickAsset(
      exactBaseNames: <String>['success'],
      contains: <String>['success'],
    );
    _eventToAsset[AppSfxEvent.shuffle] = _pickAsset(
      exactBaseNames: <String>['shuffle'],
      contains: <String>['shuffle'],
    );

    _eventToAsset.removeWhere((AppSfxEvent _, String path) => path.isEmpty);
    _log('Mapped ${_eventToAsset.length}/${AppSfxEvent.values.length} SFX events to assets.');
  }

  String _pickAsset({
    List<String> exactBaseNames = const <String>[],
    List<String> contains = const <String>[],
  }) {
    for (final String wanted in exactBaseNames) {
      for (final String assetPath in _availableAssets) {
        if (_basenameWithoutExtension(assetPath) == wanted) {
          return assetPath;
        }
      }
    }

    for (final String wanted in contains) {
      for (final String assetPath in _availableAssets) {
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
      _log('Skipped SFX $event: event not ready.');
      return;
    }

    final AudioPlayer? player = _players[event];
    if (player == null) {
      _log('Skipped SFX $event: no player available.');
      return;
    }

    try {
      final double safeVolume = volume.clamp(0, 1).toDouble();
      await player.setVolume(safeVolume);
      await player.seek(Duration.zero);
      await player.resume();
    } catch (error, stackTrace) {
      _log('Skipped SFX $event: $error');
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
      // Best effort for unsupported platforms.
    }

    try {
      if (!_preloadedAssets.contains(assetPath)) {
        await rootBundle.load(assetPath);
      }
      await player.setSource(AssetSource(sourcePath));
      _players[event] = player;
      _readyEvents.add(event);
      _log('SFX ready: $event => $assetPath');
    } catch (error, stackTrace) {
      _log('SFX unavailable for $event ($assetPath): $error');
      debugPrintStack(stackTrace: stackTrace);
      await player.dispose();
    }
  }

  Future<void> _prepareBackgroundPlayer() async {
    final AudioPlayer player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      try {
        await player.setPlayerMode(PlayerMode.mediaPlayer);
      } catch (_) {
        // Best effort for unsupported platforms.
      }
      await player.setVolume(_bgmVolume);
    } catch (error, stackTrace) {
      _log('BGM player configuration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    _backgroundPlayer = player;
    _log('BGM player ready (loop mode enabled).');
  }

  Future<void> _resumeBackgroundMusic() async {
    if (!_backgroundMusicEnabled || !_canPlayBackgroundMusic) {
      return;
    }
    final AudioPlayer? player = _backgroundPlayer;
    if (player == null) {
      return;
    }

    try {
      await player.setVolume(_bgmVolume);
      await player.resume();
      _isBackgroundPlaying = true;
      _log('BGM resumed.');
    } catch (error) {
      _log('BGM resume skipped: $error');
    }
  }

  Future<void> enableBackgroundMusic() async {
    _backgroundMusicEnabled = true;
    await playDefaultBackgroundMusic();
  }

  bool get _canPlayBackgroundMusic => !kIsWeb || _backgroundMusicUnlocked;

  Future<void> playDefaultBackgroundMusic({bool fromUserGesture = false}) async {
    if (!_initialized) {
      await initialize();
    }
    if (fromUserGesture) {
      _backgroundMusicUnlocked = true;
    }

    final AudioPlayer? player = _backgroundPlayer;
    if (player == null || !_backgroundMusicEnabled) {
      _log('BGM play skipped: disabled or player missing.');
      return;
    }
    if (!_canPlayBackgroundMusic) {
      _isBackgroundPlaying = false;
      _log('BGM waiting for first user gesture (web).');
      return;
    }

    final List<String> candidates = _backgroundCandidates();
    if (candidates.isEmpty) {
      _log('BGM play skipped: no background track found in assets.');
      return;
    }

    final String preferredTrack = candidates.first;
    if (_isBackgroundPlaying && _backgroundTrackPath == preferredTrack) {
      return;
    }

    for (final String track in candidates) {
      final String sourcePath = track.startsWith('assets/')
          ? track.substring('assets/'.length)
          : track;

      try {
        if (!_preloadedAssets.contains(track)) {
          await rootBundle.load(track);
        }
        await player.stop();
        await player.setSource(AssetSource(sourcePath));
        await player.setVolume(_bgmVolume);
        await player.resume();
        _backgroundTrackPath = track;
        _isBackgroundPlaying = true;
        _log('BGM playing in loop: $track');
        return;
      } catch (error, stackTrace) {
        _log('BGM track unavailable for $track: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _isBackgroundPlaying = false;
  }

  List<String> _backgroundCandidates() {
    final List<String> allBackgroundTracks = _availableAssets
        .where(
          (String path) =>
              _basenameWithoutExtension(path).startsWith('sound_background'),
        )
        .toList()
      ..sort();
    if (allBackgroundTracks.isEmpty) {
      return const <String>[];
    }

    final List<String> ordered = <String>[];
    if (allBackgroundTracks.contains(_defaultBackgroundTrack)) {
      ordered.add(_defaultBackgroundTrack);
    }
    ordered.addAll(
      allBackgroundTracks.where((String track) => track != _defaultBackgroundTrack),
    );
    return ordered;
  }

  Future<void> toggleBackgroundMusic() async {
    if (_backgroundMusicEnabled && _isBackgroundPlaying) {
      await stopBackgroundMusic();
      return;
    }
    _backgroundMusicEnabled = true;
    await playDefaultBackgroundMusic();
  }

  Future<void> toggleBackgroundMusicFromUserGesture() async {
    registerUserGesture();
    if (_backgroundMusicEnabled && _isBackgroundPlaying) {
      await stopBackgroundMusic();
      return;
    }
    _backgroundMusicEnabled = true;
    await playDefaultBackgroundMusic(fromUserGesture: true);
  }

  @Deprecated('Use playDefaultBackgroundMusic() for deterministic background music.')
  Future<void> playRandomBackgroundTrack() => playDefaultBackgroundMusic();

  Future<void> stopBackgroundMusic() async {
    _backgroundMusicEnabled = false;
    final AudioPlayer? player = _backgroundPlayer;
    if (player == null) {
      return;
    }
    try {
      await player.stop();
      _isBackgroundPlaying = false;
      _log('BGM stopped.');
    } catch (error) {
      _log('BGM stop skipped: $error');
    }
  }

  void _bindLifecycleIfNeeded() {
    if (_lifecycleBound) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _lifecycleBound = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _log('Lifecycle -> $state, pausing BGM.');
      unawaited(_backgroundPlayer?.pause());
      _isBackgroundPlaying = false;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _log('Lifecycle -> resumed, restoring BGM if enabled.');
      unawaited(_resumeBackgroundMusic());
    }
  }

  void _log(String message) {
    debugPrint('[AudioService] $message');
  }
}

class AppSfxService {
  AppSfxService._();

  static AudioService get instance => AudioService.instance;
}
