import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

class AudioService extends ChangeNotifier with WidgetsBindingObserver {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const double _bgmVolume = 0.28;
  static const String _assetRoot = 'assets/sfx/';

  final Map<AppSfxEvent, AudioPlayer> _players = <AppSfxEvent, AudioPlayer>{};
  final Map<AppSfxEvent, String> _eventToAsset = <AppSfxEvent, String>{};
  final Set<AppSfxEvent> _readyEvents = <AppSfxEvent>{};
  final Set<String> _preloadedAssets = <String>{};
  final Random _random = Random();

  Set<String> _availableAssets = <String>{};
  List<String> _backgroundTracks = <String>[];
  AudioPlayer? _backgroundPlayer;
  String? _currentBackgroundTrack;
  StreamSubscription<void>? _backgroundCompleteSubscription;
  StreamSubscription<PlayerState>? _backgroundStateSubscription;

  bool _initialized = false;
  bool _initializing = false;
  bool _sfxEnabled = true;
  bool _backgroundMusicEnabled = true;
  bool _isBackgroundPlaying = false;
  bool _isBackgroundPaused = false;
  bool _isTransitioningToNextTrack = false;
  bool _isBackgroundToggleInFlight = false;
  bool _backgroundMusicUnlocked = !kIsWeb;
  bool _lifecycleBound = false;
  PlayerState? _backgroundPlayerState;

  bool get isEnabled => _sfxEnabled;
  bool get isReady => _initialized && _readyEvents.isNotEmpty;
  bool get isBackgroundMusicEnabled => _backgroundMusicEnabled;
  bool get isBackgroundMusicPlaying => _isBackgroundPlaying;
  bool get isBackgroundMusicPaused => _isBackgroundPaused;
  bool get isBackgroundMusicActive => _backgroundMusicEnabled && _isBackgroundPlaying;
  bool get isBackgroundMusicUnlocked => _backgroundMusicUnlocked;
  bool get isTransitioningToNextTrack => _isTransitioningToNextTrack;
  String? get currentBackgroundTrack => _currentBackgroundTrack;
  List<String> get backgroundTracks => List<String>.unmodifiable(_backgroundTracks);
  PlayerState? get playerState => _backgroundPlayerState;

  set isEnabled(bool value) {
    _sfxEnabled = value;
    _log('Global audio enabled = $value');
    notifyListeners();
    if (!value) {
      for (final AudioPlayer player in _players.values) {
        unawaited(player.stop());
      }
      _backgroundMusicEnabled = false;
      unawaited(stopBackgroundMusic());
      return;
    }
    _backgroundMusicEnabled = true;
    unawaited(_resumeOrStartBackgroundMusic());
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
      _backgroundTracks = _backgroundCandidates();
      _log('bgm init: ${_backgroundTracks.length} background tracks.');

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
    _log('web audio unlocked');
    notifyListeners();
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
    if (!_sfxEnabled) {
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
    if (_backgroundPlayer != null) {
      return;
    }
    final AudioPlayer player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.stop);
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
    _backgroundCompleteSubscription = player.onPlayerComplete.listen((_) {
      unawaited(_handleBackgroundTrackCompleted());
    });
    _backgroundStateSubscription = player.onPlayerStateChanged.listen((PlayerState state) {
      _backgroundPlayerState = state;
      _log('playerState changed => $state');
      if (state == PlayerState.playing) {
        _isBackgroundPlaying = true;
        _isBackgroundPaused = false;
      } else if (state == PlayerState.paused) {
        _isBackgroundPlaying = false;
        _isBackgroundPaused = true;
      } else if (state == PlayerState.stopped || state == PlayerState.completed) {
        _isBackgroundPlaying = false;
        _isBackgroundPaused = false;
      }
      notifyListeners();
    });
    _log('bgm init');
  }

  Future<void> _resumeOrStartBackgroundMusic() async {
    if (!_backgroundMusicEnabled || !_canPlayBackgroundMusic) {
      return;
    }
    final AudioPlayer? player = _backgroundPlayer;
    if (player == null) {
      return;
    }

    if (_isBackgroundPaused && _currentBackgroundTrack != null) {
      try {
        await player.setVolume(_bgmVolume);
        await player.resume();
        _isBackgroundPlaying = true;
        _isBackgroundPaused = false;
        _backgroundPlayerState = PlayerState.playing;
        _log('bgm resumed: $_currentBackgroundTrack');
        notifyListeners();
        return;
      } catch (error) {
        _log('BGM resume skipped: $error');
      }
    }

    await _playRandomBackgroundTrack(trigger: 'resume_or_start');
  }

  Future<void> _pauseBackgroundMusic() async {
    final AudioPlayer? player = _backgroundPlayer;
    if (player == null) {
      return;
    }

    try {
      await player.pause();
      _isBackgroundPlaying = false;
      _isBackgroundPaused = true;
      _backgroundPlayerState = PlayerState.paused;
      _log('bgm paused');
      notifyListeners();
    } catch (error) {
      _log('BGM pause skipped: $error');
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
      notifyListeners();
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

    await _resumeOrStartBackgroundMusic();
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
    return allBackgroundTracks;
  }

  Future<void> toggleBackgroundMusic() async {
    if (_isBackgroundToggleInFlight) {
      _log('toggle pressed but guard locked');
      return;
    }
    _log('toggle pressed');
    _isBackgroundToggleInFlight = true;
    _log('guard locked');
    notifyListeners();
    try {
      final bool beforeEnabled = _backgroundMusicEnabled;
      final PlayerState? beforeState = _backgroundPlayerState;
      _log('musicEnabled before=$beforeEnabled, playerState before=$beforeState');

      if (_backgroundMusicEnabled) {
        _backgroundMusicEnabled = false;
        _log('musicEnabled after=$_backgroundMusicEnabled');
        notifyListeners();
        await _pauseBackgroundMusic();
      } else {
        _backgroundMusicEnabled = true;
        _log('musicEnabled after=$_backgroundMusicEnabled');
        notifyListeners();
        if (!_backgroundMusicUnlocked) {
          _log('toggle on requires web unlock before playback');
        }
        await playDefaultBackgroundMusic();
      }
      _log('playerState after=${_backgroundPlayerState}');
    } catch (error, stackTrace) {
      _log('toggleMusic error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isBackgroundToggleInFlight = false;
      _log('guard released');
      notifyListeners();
    }
  }

  Future<void> toggleBackgroundMusicFromUserGesture() async {
    registerUserGesture();
    await toggleBackgroundMusic();
  }

  @Deprecated('Use playDefaultBackgroundMusic() for deterministic background music.')
  Future<void> playRandomBackgroundTrack() => playDefaultBackgroundMusic();

  Future<void> stopBackgroundMusic() async {
    _backgroundMusicEnabled = false;
    notifyListeners();
    final AudioPlayer? player = _backgroundPlayer;
    if (player == null) {
      return;
    }
    try {
      await player.stop();
      _isBackgroundPlaying = false;
      _isBackgroundPaused = false;
      _backgroundPlayerState = PlayerState.stopped;
      _log('BGM stopped.');
      notifyListeners();
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
      unawaited(_pauseBackgroundMusic());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _log('Lifecycle -> resumed, restoring BGM if enabled.');
      unawaited(_resumeOrStartBackgroundMusic());
    }
  }

  Future<void> _handleBackgroundTrackCompleted() async {
    _log('completed received for: $_currentBackgroundTrack');
    _isBackgroundPlaying = false;
    _isBackgroundPaused = false;
    _backgroundPlayerState = PlayerState.completed;
    notifyListeners();
    if (!_backgroundMusicEnabled || !_canPlayBackgroundMusic) {
      return;
    }
    if (_isTransitioningToNextTrack) {
      return;
    }
    _isTransitioningToNextTrack = true;
    notifyListeners();
    try {
      await _playRandomBackgroundTrack(trigger: 'completed');
    } catch (error, stackTrace) {
      _log('bgm transition failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isTransitioningToNextTrack = false;
      notifyListeners();
    }
  }

  Future<void> _playRandomBackgroundTrack({required String trigger}) async {
    final AudioPlayer? player = _backgroundPlayer;
    if (player == null) {
      return;
    }

    if (_backgroundTracks.isEmpty) {
      _backgroundTracks = _backgroundCandidates();
    }
    if (_backgroundTracks.isEmpty) {
      _log('missing asset: no sound_background* track found in assets/sfx');
      _isBackgroundPlaying = false;
      _isBackgroundPaused = false;
      return;
    }

    final String? previousTrack = _currentBackgroundTrack;
    String selectedTrack = _backgroundTracks[_random.nextInt(_backgroundTracks.length)];
    if (_backgroundTracks.length > 1 && previousTrack != null) {
      int attempts = 0;
      while (selectedTrack == previousTrack && attempts < 6) {
        selectedTrack = _backgroundTracks[_random.nextInt(_backgroundTracks.length)];
        attempts += 1;
      }
    }
    _log('next random bgm selected: $selectedTrack (trigger=$trigger)');

    final String sourcePath = selectedTrack.startsWith('assets/')
        ? selectedTrack.substring('assets/'.length)
        : selectedTrack;

    try {
      if (!_preloadedAssets.contains(selectedTrack)) {
        await rootBundle.load(selectedTrack);
      }
      await player.stop();
      await player.setSource(AssetSource(sourcePath));
      await player.setVolume(_bgmVolume);
      await player.resume();
      _currentBackgroundTrack = selectedTrack;
      _isBackgroundPlaying = true;
      _isBackgroundPaused = false;
      _backgroundPlayerState = PlayerState.playing;
      _log('bgm play success: $selectedTrack');
      notifyListeners();
    } catch (error, stackTrace) {
      _isBackgroundPlaying = false;
      _isBackgroundPaused = false;
      _backgroundPlayerState = PlayerState.stopped;
      _log('bgm play fail for $selectedTrack: $error');
      notifyListeners();
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _log(String message) {
    debugPrint('[AudioService] $message');
  }
}

class AppSfxService {
  AppSfxService._();

  static final AppSfxService instance = AppSfxService._();

  AudioService get _audio => AudioService.instance;

  bool get isEnabled => _audio.isEnabled;
  set isEnabled(bool value) => _audio.isEnabled = value;

  bool get isReady => _audio.isReady;
  bool get isBackgroundMusicEnabled => _audio.isBackgroundMusicEnabled;
  bool get isBackgroundMusicPlaying => _audio.isBackgroundMusicPlaying;
  bool get isBackgroundMusicPaused => _audio.isBackgroundMusicPaused;
  bool get isBackgroundMusicActive => _audio.isBackgroundMusicActive;
  bool get isBackgroundMusicUnlocked => _audio.isBackgroundMusicUnlocked;
  bool get isTransitioningToNextTrack => _audio.isTransitioningToNextTrack;
  String? get currentBackgroundTrack => _audio.currentBackgroundTrack;
  List<String> get backgroundTracks => _audio.backgroundTracks;

  Future<void> initialize({bool strict = false}) => _audio.initialize(strict: strict);
  void registerUserGesture() => _audio.registerUserGesture();

  Future<void> playClick() => _audio.playClick();
  Future<void> playDraw() => _audio.playDraw();
  Future<void> playCard() => _audio.playCard();
  Future<void> playWin() => _audio.playWin();
  Future<void> playLose() => _audio.playLose();
  Future<void> playNotif() => _audio.playNotif();
  Future<void> playChat() => _audio.playChat();
  Future<void> playPopup() => _audio.playPopup();
  Future<void> playError() => _audio.playError();
  Future<void> playSuccess() => _audio.playSuccess();
  Future<void> playShuffle() => _audio.playShuffle();

  Future<void> enableBackgroundMusic() => _audio.enableBackgroundMusic();
  Future<void> playDefaultBackgroundMusic({bool fromUserGesture = false}) =>
      _audio.playDefaultBackgroundMusic(fromUserGesture: fromUserGesture);
  Future<void> toggleBackgroundMusic() => _audio.toggleBackgroundMusic();
  Future<void> toggleBackgroundMusicFromUserGesture() =>
      _audio.toggleBackgroundMusicFromUserGesture();
  Future<void> playRandomBackgroundTrack() => _audio.playRandomBackgroundTrack();
  Future<void> stopBackgroundMusic() => _audio.stopBackgroundMusic();
}
