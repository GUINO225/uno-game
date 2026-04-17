import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_sfx_service.dart';
import 'firebase_config.dart';
import 'duel_mode.dart';
import 'premium_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await _initializeFirebaseIfConfigured();
  runApp(const MyApp());
}

Future<void> _initializeFirebaseIfConfigured() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    final FirebaseOptions? options = FirebaseConfig.optionsForCurrentPlatform();
    if (options != null) {
      await Firebase.initializeApp(options: options);
    }
  } catch (_) {
    // Firebase remains optional in solo mode if configuration is absent.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNO GAME',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: PremiumColors.tableGreenMid,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.92),
          labelStyle: const TextStyle(color: PremiumColors.textDark),
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.45)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            foregroundColor: PremiumColors.textDark,
            backgroundColor: PremiumColors.accent,
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFF8F6F0),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: PremiumColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          contentTextStyle: const TextStyle(
            color: PremiumColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      routes: <String, WidgetBuilder>{
        GameModeRoutes.solo: (_) => const CrazyEightsPage(),
        GameModeRoutes.duel: (_) => const DuelLobbyPage(),
        GameModeRoutes.credits: (_) =>
            const DuelLobbyPage(mode: DuelRoomMode.credits),
      },
      home: const AppBootstrapPage(),
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  late final Future<void> _bootFuture;

  @override
  void initState() {
    super.initState();
    _bootFuture = AppSfxService.instance.initialize(strict: true).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Audio warmup fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AudioWarmupPage();
        }
        return const IntroLandingPage();
      },
    );
  }
}

class _AudioWarmupPage extends StatefulWidget {
  const _AudioWarmupPage();

  @override
  State<_AudioWarmupPage> createState() => _AudioWarmupPageState();
}

class _AudioWarmupPageState extends State<_AudioWarmupPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameModePalette.background,
      body: Stack(
        children: <Widget>[
          const BackgroundDecoration(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const GameLogoHeader(scaleFactor: 0.82),
                      const SizedBox(height: 28),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (BuildContext context, _) {
                            return LinearProgressIndicator(
                              minHeight: 8,
                              value: _progressController.value,
                              color: GameModePalette.accentGreen,
                              backgroundColor: Colors.white24,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



enum GameMode { solo, duel, credits }

class GameModeRoutes {
  static const String solo = '/solo';
  static const String duel = '/duel';
  static const String credits = '/credits';
}

class GameModePalette {
  static const Color background = Color(0xFF004F2C);
  static const Color backgroundShade = Color(0xFF013C25);
  static const Color cardGreen = Color(0xFF08BF63);
  static const Color cardGreenSoft = Color(0xFF0BA957);
  static const Color cardGreenDeep = Color(0xFF0A6B3D);
  static const Color accentGreen = Color(0xFF73F38A);
  static const Color white = Color(0xFFF6FFF9);
}

class IntroLandingPage extends StatefulWidget {
  const IntroLandingPage({super.key});

  @override
  State<IntroLandingPage> createState() => _IntroLandingPageState();
}

class _IntroLandingPageState extends State<IntroLandingPage> {
  bool _backgroundMusicEnabled = _readBackgroundMusicEnabled();
  bool _isTogglingMusic = false;

  static bool _readBackgroundMusicEnabled() {
    final dynamic sfx = AppSfxService.instance;
    try {
      final dynamic value = sfx.isBackgroundMusicActive;
      if (value is bool) {
        return value;
      }
    } on NoSuchMethodError {
      // Backward compatibility.
    }
    try {
      final dynamic value = sfx.isBackgroundMusicEnabled;
      if (value is bool) {
        return value;
      }
    } on NoSuchMethodError {
      // Backward compatibility when the app_sfx_service API only exposes isEnabled.
    }
    return AppSfxService.instance.isEnabled;
  }

  static Future<void> _setBackgroundMusicEnabled(bool enabled) async {
    final dynamic sfx = AppSfxService.instance;
    try {
      if (enabled) {
        await sfx.playDefaultBackgroundMusic(fromUserGesture: true);
      } else {
        await sfx.stopBackgroundMusic();
      }
      return;
    } on NoSuchMethodError {
      // Backward compatibility when the app_sfx_service API only exposes isEnabled.
    }
    AppSfxService.instance.isEnabled = enabled;
  }

  Future<void> _toggleBackgroundMusic() async {
    if (_isTogglingMusic) {
      return;
    }
    setState(() {
      _isTogglingMusic = true;
    });
    await _setBackgroundMusicEnabled(!_backgroundMusicEnabled);
    if (!mounted) {
      return;
    }
    setState(() {
      _backgroundMusicEnabled = _readBackgroundMusicEnabled();
      _isTogglingMusic = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameModePalette.background,
      body: Stack(
        children: <Widget>[
          const BackgroundDecoration(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: GameLogoHeader(scaleFactor: 1.4),
                      ),
                      const SizedBox(height: 34),
                      OutlinedButton.icon(
                        onPressed: _toggleBackgroundMusic,
                        icon: Icon(
                          _backgroundMusicEnabled
                              ? Icons.music_note_rounded
                              : Icons.music_off_rounded,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.45)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        label: Text(
                          _backgroundMusicEnabled
                              ? 'Musique activée'
                              : 'Musique désactivée',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (_isTogglingMusic) ...<Widget>[
                        const SizedBox(height: 10),
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _IntroPlayButton(
                        onTap: () {
                          unawaited(AppSfxService.instance.playClick());
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GameModePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GameModePage extends StatefulWidget {
  const GameModePage({super.key});

  @override
  State<GameModePage> createState() => _GameModePageState();
}

class _GameModePageState extends State<GameModePage>
    with SingleTickerProviderStateMixin {
  static const double _designWidth = 393;
  static const double _designHeight = 852;
  static const double _frameHorizontalPadding = 18;
  static const double _frameVerticalPadding = 14;
  static const double _logoTopSpacing = 10;
  static const double _modeCardsTopSpacing = 16;
  static const double _controlsTopSpacing = 24;
  static const double _centerBlockVerticalOffset = -10;
  static const double _modeLabelFontSize = 34;
  static const double _playLabelFontSize = 20;
  static const double _versionFontSize = 14;
  static const double _modeCardWidth = 94;
  static const double _modeCardHeight = 146;

  late final AnimationController _introController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _soloFade;
  late final Animation<Offset> _soloSlideUp;
  late final Animation<double> _soloScale;
  late final Animation<double> _duelFade;
  late final Animation<Offset> _duelSlideUp;
  late final Animation<double> _duelScale;
  late final Animation<double> _creditsFade;
  late final Animation<Offset> _creditsSlideUp;
  late final Animation<double> _creditsScale;
  GameMode? _selectedMode;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
    _soloFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.18, 0.74, curve: Curves.easeOut),
    );
    _soloSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.09),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.18, 0.74, curve: Curves.easeOutCubic),
      ),
    );
    _soloScale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.18, 0.74, curve: Curves.easeOutCubic),
      ),
    );
    _duelFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );
    _duelSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _duelScale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _creditsFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.42, 1, curve: Curves.easeOut),
    );
    _creditsSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.11),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
      ),
    );
    _creditsScale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
      ),
    );
    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameModePalette.background,
      body: Stack(
                children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withOpacity(0.14),
                    Colors.transparent,
                    Colors.black.withOpacity(0.08),
                  ],
                  stops: const <double>[0.0, 0.32, 1.0],
                ),
              ),
            ),
          ),
          const BackgroundDecoration(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: _designWidth,
                      height: _designHeight,
                      child: SafeArea(
                        minimum: const EdgeInsets.symmetric(
                          horizontal: _frameHorizontalPadding,
                          vertical: _frameVerticalPadding,
                        ),
                        child: Column(
                          children: <Widget>[
                            const SizedBox(height: _logoTopSpacing),
                            const GameLogoHeader(),
                            Expanded(
                              child: Center(
                                child: Transform.translate(
                                  offset: const Offset(
                                    0,
                                    _centerBlockVerticalOffset,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const SizedBox(height: _modeCardsTopSpacing),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            FadeTransition(
                                              opacity: _soloFade,
                                              child: SlideTransition(
                                                position: _soloSlideUp,
                                                child: ScaleTransition(
                                                  scale: _soloScale,
                                                  child: ModeCardSolo(
                                                    width: _modeCardWidth,
                                                    height: _modeCardHeight,
                                                    labelFontSize:
                                                        _modeLabelFontSize,
                                                    isSelected:
                                                        _selectedMode ==
                                                        GameMode.solo,
                                                    onTap:
                                                        () => _selectMode(
                                                          GameMode.solo,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            FadeTransition(
                                              opacity: _duelFade,
                                              child: SlideTransition(
                                                position: _duelSlideUp,
                                                child: ScaleTransition(
                                                  scale: _duelScale,
                                                  child: ModeCardDuel(
                                                    width: _modeCardWidth,
                                                    height: _modeCardHeight,
                                                    labelFontSize:
                                                        _modeLabelFontSize,
                                                    isSelected:
                                                        _selectedMode ==
                                                        GameMode.duel,
                                                    onTap:
                                                        () => _selectMode(
                                                          GameMode.duel,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            FadeTransition(
                                              opacity: _creditsFade,
                                              child: SlideTransition(
                                                position: _creditsSlideUp,
                                                child: ScaleTransition(
                                                  scale: _creditsScale,
                                                  child: ModeCardCredits(
                                                    width: _modeCardWidth,
                                                    height: _modeCardHeight,
                                                    labelFontSize:
                                                        _modeLabelFontSize,
                                                    isSelected: _selectedMode ==
                                                        GameMode.credits,
                                                    onTap: () => _selectMode(
                                                      GameMode.credits,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: _controlsTopSpacing),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 280,
                                        ),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (
                                          Widget child,
                                          Animation<double> animation,
                                        ) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.18),
                                                end: Offset.zero,
                                              ).animate(animation),
                                              child: ScaleTransition(
                                                scale: Tween<double>(
                                                  begin: 0.96,
                                                  end: 1,
                                                ).animate(animation),
                                                child: child,
                                              ),
                                            ),
                                          );
                                        },
                                        child: _selectedMode == null
                                            ? const SizedBox.shrink(
                                                key: ValueKey<String>(
                                                  'play-hidden',
                                                ),
                                              )
                                            : _PlayModeButton(
                                                key: const ValueKey<String>(
                                                  'play-visible',
                                                ),
                                                fontSize: _playLabelFontSize,
                                                onTap: _startSelectedMode,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  'v2.4',
                                  style: TextStyle(
                                    color: GameModePalette.white.withOpacity(
                                      0.9,
                                    ),
                                    fontSize: _versionFontSize,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  ' DESIGNED BY AKENOO',
                                  style: TextStyle(
                                    color: GameModePalette.white.withOpacity(
                                      0.85,
                                    ),
                                    fontSize: _versionFontSize,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectMode(GameMode mode) {
    if (_selectedMode == mode) {
      return;
    }
    unawaited(AppSfxService.instance.playClick());
    setState(() {
      _selectedMode = mode;
    });
  }

  void _startSelectedMode() {
    final GameMode? mode = _selectedMode;
    if (mode == null) {
      return;
    }
    unawaited(AppSfxService.instance.playClick());
    Navigator.of(context).pushNamed(switch (mode) {
      GameMode.solo => GameModeRoutes.solo,
      GameMode.duel => GameModeRoutes.duel,
      GameMode.credits => GameModeRoutes.credits,
    });
  }
}

class BackgroundDecoration extends StatelessWidget {
  const BackgroundDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -70,
              left: -40,
              child: Transform.rotate(
                angle: -0.55,
                child: _decorCard(230, 360),
              ),
            ),
            Positioned(
              right: -95,
              bottom: -115,
              child: Transform.rotate(
                angle: -0.36,
                child: _decorCard(260, 360),
              ),
            ),
            Positioned(
              top: 65,
              left: -38,
              child: Text(
                '♠',
                style: TextStyle(
                  fontSize: 150,
                  color: Colors.white.withOpacity(0.055),
                  height: 1,
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 40,
              child: Text(
                '♣',
                style: TextStyle(
                  fontSize: 132,
                  color: Colors.white.withOpacity(0.05),
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCard(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.black.withOpacity(0.1),
      ),
    );
  }
}

class GameLogoHeader extends StatelessWidget {
  const GameLogoHeader({super.key, this.scaleFactor = 1});

  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    final double logoScaleFactor = 0.544 * scaleFactor;

    return SizedBox(
      height: 172 * logoScaleFactor,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: (18 * logoScaleFactor) - 5,
            child: Transform.translate(
              offset: Offset((34 * logoScaleFactor) + 10, 0),
              child: Text(
                '8AMERICAIN',
                style: GoogleFonts.poppins(
                  color: GameModePalette.accentGreen,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.55,
                  fontSize: 22 * logoScaleFactor,
                ),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.leagueSpartan(
                  fontWeight: FontWeight.w700,
                  fontSize: 118 * logoScaleFactor,
                  color: GameModePalette.white,
                  letterSpacing: 0.2,
                  height: 0.88,
                ),
                children: <InlineSpan>[
                  const TextSpan(text: 'G'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.5),
                      child: Transform.translate(
                        offset: Offset(-2.5 * logoScaleFactor, 0),
                        child: _MiniLogoCard(scaleFactor: logoScaleFactor),
                      ),
                    ),
                  ),
                  const TextSpan(text: 'INO'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLogoCard extends StatelessWidget {
  const _MiniLogoCard({required this.scaleFactor});

  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.32,
      child: Container(
        width: 60 * scaleFactor,
        height: 92 * scaleFactor,
        decoration: BoxDecoration(
          color: GameModePalette.cardGreen,
          borderRadius: BorderRadius.circular(15 * scaleFactor),
        ),
        child: Center(
          child: Text(
            '♠',
            style: TextStyle(
              color: GameModePalette.white,
              fontSize: 42 * scaleFactor,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class ModeCardSolo extends StatelessWidget {
  const ModeCardSolo({
    super.key,
    required this.width,
    required this.height,
    required this.labelFontSize,
    required this.isSelected,
    required this.onTap,
  });

  final double width;
  final double height;
  final double labelFontSize;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableModeCard(
      onTap: onTap,
      isSelected: isSelected,
      label: 'SOLO',
      labelFontSize: labelFontSize,
      child: SizedBox(
        width: width + 34,
        height: height + 20,
        child: Align(
          alignment: Alignment.topCenter,
          child: _GameCardFace(width: width, height: height),
        ),
      ),
    );
  }
}

class ModeCardDuel extends StatelessWidget {
  const ModeCardDuel({
    super.key,
    required this.width,
    required this.height,
    required this.labelFontSize,
    required this.isSelected,
    required this.onTap,
  });

  final double width;
  final double height;
  final double labelFontSize;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableModeCard(
      onTap: onTap,
      isSelected: isSelected,
      label: 'DUEL',
      labelFontSize: labelFontSize,
      child: SizedBox(
        width: width + 34,
        height: height + 20,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              top: 16,
              child: _GameCardFace(
                width: width,
                height: height,
                color: GameModePalette.cardGreenSoft,
              ),
            ),
            Positioned(
              child: Transform.rotate(
                angle: -0.2,
                child: _GameCardFace(width: width, height: height),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModeCardCredits extends StatelessWidget {
  const ModeCardCredits({
    super.key,
    required this.width,
    required this.height,
    required this.labelFontSize,
    required this.isSelected,
    required this.onTap,
  });

  final double width;
  final double height;
  final double labelFontSize;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableModeCard(
      onTap: onTap,
      isSelected: isSelected,
      label: 'PARI',
      labelFontSize: labelFontSize,
      child: SizedBox(
        width: width + 34,
        height: height + 20,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              top: 16,
              child: _GameCardFace(
                width: width,
                height: height,
                color: GameModePalette.cardGreenDeep,
                symbol: '♦',
              ),
            ),
            Positioned(
              child: Transform.rotate(
                angle: -0.2,
                child: _GameCardFace(
                  width: width,
                  height: height,
                  symbol: '8♦',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressableModeCard extends StatefulWidget {
  const _PressableModeCard({
    required this.child,
    required this.label,
    required this.labelFontSize,
    required this.isSelected,
    required this.onTap,
  });

  final Widget child;
  final String label;
  final double labelFontSize;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_PressableModeCard> createState() => _PressableModeCardState();
}

class _PressableModeCardState extends State<_PressableModeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed
            ? 0.965
            : widget.isSelected
                ? 1.02
                : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.isSelected
                ? Colors.white.withOpacity(0.07)
                : Colors.transparent,
            border: Border.all(
              color: widget.isSelected
                  ? Colors.white.withOpacity(0.45)
                  : Colors.transparent,
            ),
            boxShadow: widget.isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: GameModePalette.accentGreen.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              widget.child,
              const SizedBox(height: 11),
              Text(
                widget.label,
                style: GoogleFonts.poppins(
                  color: GameModePalette.white,
                  fontSize: widget.labelFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayModeButton extends StatefulWidget {
  const _PlayModeButton({
    super.key,
    required this.fontSize,
    required this.onTap,
  });

  final double fontSize;
  final VoidCallback onTap;

  @override
  State<_PlayModeButton> createState() => _PlayModeButtonState();
}

class _PlayModeButtonState extends State<_PlayModeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          scale: _isPressed ? 0.97 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF96F8A6),
                  Color(0xFF5DD978),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF8BFFAA).withOpacity(0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              "LET'S GO",
              style: GoogleFonts.poppins(
                color: GameModePalette.backgroundShade,
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPlayButton extends StatefulWidget {
  const _IntroPlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_IntroPlayButton> createState() => _IntroPlayButtonState();
}

class _IntroPlayButtonState extends State<_IntroPlayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _isPressed ? 0.97 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF96F8A6), Color(0xFF5DD978)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF8BFFAA).withOpacity(0.28),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            'JOUER',
            style: GoogleFonts.poppins(
              color: GameModePalette.backgroundShade,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCardFace extends StatelessWidget {
  const _GameCardFace({
    required this.width,
    required this.height,
    this.color = GameModePalette.cardGreen,
    this.symbol = '♠',
  });

  final double width;
  final double height;
  final Color color;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final double cornerSpadeSize = (width * 0.16).clamp(18, 24);
    final double centerSpadeSize = (height * 0.50).clamp(84, 106);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(color, Colors.white, 0.14)!,
            color,
            Color.lerp(color, Colors.black, 0.12)!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.12),
            offset: const Offset(-1, -1),
            blurRadius: 5,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withOpacity(0.14),
                    Colors.transparent,
                    Colors.black.withOpacity(0.08),
                  ],
                  stops: const <double>[0.0, 0.32, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Text(
              symbol,
              style: TextStyle(
                color: GameModePalette.white,
                fontSize: cornerSpadeSize,
                height: 1,
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: RotatedBox(
              quarterTurns: 2,
              child: Text(
                symbol,
                style: TextStyle(
                  color: GameModePalette.white,
                  fontSize: cornerSpadeSize,
                  height: 1,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              symbol,
              style: TextStyle(
                color: GameModePalette.white,
                fontSize: centerSpadeSize,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum Suit { hearts, spades, diamonds, clubs }

enum JokerKind { red, black }

enum PlayerTurn { human, bot }

class PlayingCard {
  const PlayingCard._({this.suit, this.rank, this.jokerKind});

  const PlayingCard.normal({required Suit suit, required int rank})
      : this._(suit: suit, rank: rank);

  const PlayingCard.joker({required JokerKind kind})
      : this._(jokerKind: kind);

  final Suit? suit;
  final int? rank;
  final JokerKind? jokerKind;

  bool get isJoker => jokerKind != null;

  bool get isRed {
    if (jokerKind != null) {
      return jokerKind == JokerKind.red;
    }
    return suit == Suit.hearts || suit == Suit.diamonds;
  }

  bool get isBlack => !isRed;

  bool get canFinishGame => rank != 10 && rank != 11;

  String get rankLabel {
    if (isJoker) {
      return 'JOKER';
    }

    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '${rank!}';
    }
  }

  String get suitSymbol {
    if (isJoker) {
      return jokerKind == JokerKind.red ? '🟥' : '⬛';
    }

    switch (suit!) {
      case Suit.hearts:
        return '♥';
      case Suit.spades:
        return '♠';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  String get label =>
      isJoker ? 'Joker ${isRed ? 'rouge' : 'noir'}' : '$rankLabel$suitSymbol';

  Color get suitColor {
    if (isJoker) {
      return isRed ? Colors.red.shade700 : Colors.black87;
    }
    return isRed ? Colors.red.shade700 : Colors.black87;
  }
}

class _PlayResolution {
  const _PlayResolution({
    required this.extraTurn,
    required this.skipTurnSwitch,
  });

  final bool extraTurn;
  final bool skipTurnSwitch;
}

class CrazyEightsPage extends StatefulWidget {
  const CrazyEightsPage({super.key});

  @override
  State<CrazyEightsPage> createState() => _CrazyEightsPageState();
}

class _CrazyEightsPageState extends State<CrazyEightsPage>
{
  final Random _random = Random();
  final AppSfxService _sfx = AppSfxService.instance;

  List<PlayingCard> _drawPile = <PlayingCard>[];
  final List<PlayingCard> _discardPile = <PlayingCard>[];
  final List<PlayingCard> _humanHand = <PlayingCard>[];
  final List<PlayingCard> _botHand = <PlayingCard>[];

  PlayerTurn _turn = PlayerTurn.human;
  String _status = '';
  bool _gameOver = false;
  bool _isResolvingTurn = false;
  bool _isInitialDealRunning = false;
  bool _isBotTurnRunning = false;

  int _forcedDrawCount = 0;
  PlayerTurn? _forcedDrawTarget;
  PlayerTurn? _forcedDrawSource;
  bool _humanMustAnswerAce = false;
  bool _botMustAnswerAce = false;
  Suit? _activeSuitConstraint;

  bool _isEightDemandOverlayVisible = false;
  Suit? _eightDemandOverlaySuit;
  String _eightDemandOverlayMessage = '';
  bool _humanDidVoluntaryDrawThisTurn = false;

  int _humanScore = 0;
  int _botScore = 0;
  final GlobalKey _discardPileKey = GlobalKey();
  static const Duration _uiTransitionDuration = Duration(milliseconds: 260);
  static const double _handCardWidth = 64;
  static const double _handCardHeight = 96;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    unawaited(_sfx.playShuffle());
    final PlayerTurn dealer =
        _random.nextBool() ? PlayerTurn.human : PlayerTurn.bot;
    final PlayerTurn startingPlayer = _opponentOf(dealer);

    _drawPile = _createDeck();
    _shuffleDeck(_drawPile);

    _discardPile.clear();

    final List<PlayingCard> humanInitialCards = _dealCards(_drawPile, 7);
    final List<PlayingCard> botInitialCards = _dealCards(_drawPile, 7);

    _humanHand.clear();
    _botHand.clear();

    final PlayingCard openingCard = _openFirstDiscardCard();

    setState(() {
      _turn = startingPlayer;
      _status = 'Distribution des cartes...';
      _gameOver = false;
      _isResolvingTurn = false;
      _isInitialDealRunning = true;
      _forcedDrawCount = 0;
      _forcedDrawTarget = null;
      _forcedDrawSource = null;
      _humanMustAnswerAce = false;
      _botMustAnswerAce = false;
      _activeSuitConstraint = null;
      _isEightDemandOverlayVisible = false;
      _eightDemandOverlaySuit = null;
      _eightDemandOverlayMessage = '';
      _humanDidVoluntaryDrawThisTurn = false;
      _humanHand.addAll(humanInitialCards);
      _botHand.addAll(botInitialCards);
    });

    setState(() {
      _isInitialDealRunning = false;
      _status = _turnStartText(startingPlayer);
    });

    _applyOpeningCardPenaltyIfNeeded(
      openingCard,
      startingPlayer: startingPlayer,
      dealer: dealer,
    );

    if (_turn == PlayerTurn.bot && !_gameOver) {
      _ensureBotTurnProgress();
    }
  }

  List<PlayingCard> _createDeck() {
    final List<PlayingCard> deck = <PlayingCard>[];

    for (final Suit suit in Suit.values) {
      for (int rank = 1; rank <= 13; rank++) {
        deck.add(PlayingCard.normal(suit: suit, rank: rank));
      }
    }

    deck.add(const PlayingCard.joker(kind: JokerKind.red));
    deck.add(const PlayingCard.joker(kind: JokerKind.black));

    return deck;
  }

  void _shuffleDeck(List<PlayingCard> deck) {
    deck.shuffle(_random);
  }

  PlayerTurn _opponentOf(PlayerTurn player) {
    return player == PlayerTurn.human ? PlayerTurn.bot : PlayerTurn.human;
  }

  String _turnLabel(PlayerTurn turn) {
    return turn == PlayerTurn.human ? 'Vous' : 'GINO';
  }

  String _turnStartText(PlayerTurn turn) {
    return turn == PlayerTurn.human ? 'Vous commencez' : 'GINO commence';
  }

  List<PlayingCard> _dealCards(List<PlayingCard> deck, int count) {
    final List<PlayingCard> dealt = <PlayingCard>[];
    for (int i = 0; i < count && deck.isNotEmpty; i++) {
      dealt.add(deck.removeLast());
    }
    return dealt;
  }

  PlayingCard _openFirstDiscardCard() {
    while (_drawPile.isNotEmpty) {
      final PlayingCard card = _drawPile.removeLast();
      if (card.rank == 8 || card.rank == 10 || card.rank == 11) {
        _drawPile.insert(0, card);
        _shuffleDeck(_drawPile);
      } else {
        _discardPile.add(card);
        return card;
      }
    }

    const PlayingCard fallback =
    PlayingCard.normal(suit: Suit.spades, rank: 3);
    _discardPile.add(fallback);
    return fallback;
  }

  PlayingCard get _topDiscard => _discardPile.last;

  void _applyOpeningCardPenaltyIfNeeded(
      PlayingCard openingCard, {
        required PlayerTurn startingPlayer,
        required PlayerTurn dealer,
      }) {
    if (openingCard.rank == 2) {
      _setForcedDraw(
        target: startingPlayer,
        source: dealer,
        count: 2,
        announcement: '${_turnStartText(startingPlayer)}, mais la carte d’ouverture est un 2.',
      );
      return;
    }

    if (openingCard.isJoker) {
      _setForcedDraw(
        target: startingPlayer,
        source: dealer,
        count: 9,
        announcement: '${_turnStartText(startingPlayer)}, mais la carte d’ouverture est un joker.',
      );
    }
  }

  bool _sameColor(PlayingCard a, PlayingCard b) {
    return a.isRed == b.isRed;
  }

  bool _isCardPlayableForHand(PlayingCard card, List<PlayingCard> hand) {
    if (_discardPile.isEmpty) {
      return false;
    }

    final bool isLastCard = hand.length == 1;
    if (isLastCard && !card.canFinishGame) {
      return false;
    }

    if (card.rank == 8) {
      return true;
    }

    if (_activeSuitConstraint != null) {
      return !card.isJoker && card.suit == _activeSuitConstraint;
    }

    final PlayingCard top = _topDiscard;

    if (card.isJoker) {
      return _sameColor(card, top);
    }

    if (top.isJoker) {
      return _sameColor(card, top);
    }

    return card.suit == top.suit || card.rank == top.rank;
  }

  bool _isCardPlayableForHuman(PlayingCard card) {
    if (_humanMustAnswerAce) {
      return _isValidAceResponse(card);
    }

    if (_forcedDrawCount > 0 && _forcedDrawTarget == PlayerTurn.human) {
      return false;
    }

    return _isCardPlayableForHand(card, _humanHand);
  }

  bool _isValidAceResponse(PlayingCard card) {
    if (_discardPile.isEmpty || _topDiscard.rank != 1) {
      return false;
    }

    if (!card.isJoker && card.rank == 1) {
      return true;
    }

    if (card.isJoker) {
      return card.isRed == _topDiscard.isRed;
    }

    return false;
  }

  void _setForcedDraw({
    required PlayerTurn target,
    required PlayerTurn source,
    required int count,
    required String announcement,
  }) {
    final String starter = count > 1 ? 'cartes' : 'carte';

    setState(() {
      _forcedDrawCount = count;
      _forcedDrawTarget = target;
      _forcedDrawSource = source;
      _status =
      '$announcement ${_turnLabel(target)} doit d’abord piocher $count $starter.';
    });
  }

  bool _isHumanForcedToDrawNow() {
    return _forcedDrawCount > 0 &&
        _forcedDrawTarget == PlayerTurn.human &&
        _turn == PlayerTurn.human;
  }

  String _forcedDrawRemainingText() {
    if (_forcedDrawCount <= 0 || _forcedDrawTarget == null) {
      return '';
    }

    final String unit = _forcedDrawCount > 1 ? 'cartes' : 'carte';
    return '${_turnLabel(_forcedDrawTarget!)} doit d’abord piocher $_forcedDrawCount $unit.';
  }

  Future<void> _onHumanTapCard(PlayingCard card) async {
    if (_turn != PlayerTurn.human ||
        _gameOver ||
        _isResolvingTurn ||
        _isInitialDealRunning ||
        _isHumanForcedToDrawNow()) {
      return;
    }

    if (!_isCardPlayableForHuman(card)) {
      return;
    }

    if (_humanMustAnswerAce) {
      setState(() {
        _humanMustAnswerAce = false;
      });
    }

    _isResolvingTurn = true;
    try {
      unawaited(_sfx.playCard());
      await _humanPlayCard(card);
    } finally {
      _isResolvingTurn = false;
      // Important: _endHumanTurn() can be called while _isResolvingTurn is true,
      // which prevents _scheduleBotTurn() from starting.
      // Re-check bot progression once the resolving lock is released.
      _ensureBotTurnProgress();
    }
  }

  Future<void> _humanPlayCard(PlayingCard card) async {
    setState(() {
      _humanDidVoluntaryDrawThisTurn = false;
    });
    await _playCard(
      hand: _humanHand,
      card: card,
      playerName: 'Vous',
    );

    final _PlayResolution result = await _applyCardEffects(
      card: card,
      currentTurn: PlayerTurn.human,
      sourceLabel: 'Vous',
    );

    if (_checkVictory(
      winner: PlayerTurn.human,
      hand: _humanHand,
      lastPlayed: card,
    )) {
      return;
    }

    if (result.extraTurn) {
      setState(() {
        _status = '$_status\nVous rejouez.';
      });
      return;
    }

    if (result.skipTurnSwitch) {
      return;
    }

    _endHumanTurn();
  }

  Future<void> _onHumanDraw() async {
    if (_turn != PlayerTurn.human ||
        _gameOver ||
        _isResolvingTurn ||
        _isInitialDealRunning) {
      return;
    }

    if (_isHumanForcedToDrawNow()) {
      final PlayingCard? card = _drawOneCard();
      if (card == null) {
        setState(() {
          _status = 'Pioche vide pendant la pioche forcée.';
          _forcedDrawCount = 0;
        });
        _finishForcedDrawIfNeeded();
        return;
      }

      setState(() {
        _humanHand.add(card);
        _forcedDrawCount--;
        final String unit = _forcedDrawCount > 1 ? 'cartes' : 'carte';
        _status = _forcedDrawCount > 0
            ? 'Vous devez d’abord piocher $_forcedDrawCount $unit.'
            : 'Pioche forcée terminée.';
      });
      unawaited(_sfx.playDraw());

      _finishForcedDrawIfNeeded();
      return;
    }

    if (_humanMustAnswerAce) {
      final int drawn = _drawCards(_humanHand, 1).length;
      setState(() {
        _humanMustAnswerAce = false;
        _humanDidVoluntaryDrawThisTurn = false;
        _status = drawn > 0
            ? 'Vous choisissez de piocher au lieu de répondre à l’As.'
            : 'Vous choisissez de piocher, mais la pioche est vide.';
      });
      if (drawn > 0) {
        unawaited(_sfx.playDraw());
      }
      _endHumanTurn();
      return;
    }

    if (_humanDidVoluntaryDrawThisTurn) {
      setState(() {
        _status = 'Vous passez après votre pioche volontaire.';
      });
      _endHumanTurn();
      return;
    }

    final PlayingCard? drawnCard = _drawOneCard();
    if (drawnCard == null) {
      setState(() {
        _status = 'La pioche est vide.';
      });
      _endHumanTurn();
      return;
    }

    setState(() {
      _humanHand.add(drawnCard);
      _humanDidVoluntaryDrawThisTurn = true;
      _status =
          'Vous piochez ${drawnCard.label}. Vous pouvez jouer une carte valide, ou retoucher la pioche pour passer.';
    });
    unawaited(_sfx.playDraw());
  }

  List<PlayingCard> _drawCards(List<PlayingCard> destination, int count) {
    final List<PlayingCard> drawn = <PlayingCard>[];

    for (int i = 0; i < count; i++) {
      final PlayingCard? card = _drawOneCard();
      if (card == null) {
        break;
      }
      destination.add(card);
      drawn.add(card);
    }

    return drawn;
  }

  PlayingCard? _drawOneCard() {
    if (_drawPile.isEmpty) {
      _rebuildDrawPileFromDiscard();
    }

    if (_drawPile.isEmpty) {
      return null;
    }

    return _drawPile.removeLast();
  }

  void _rebuildDrawPileFromDiscard() {
    if (_discardPile.length <= 1) {
      return;
    }

    final PlayingCard topCard = _discardPile.removeLast();
    _drawPile = List<PlayingCard>.from(_discardPile);
    _discardPile
      ..clear()
      ..add(topCard);

    _shuffleDeck(_drawPile);
  }

  Future<void> _playCard({
    required List<PlayingCard> hand,
    required PlayingCard card,
    required String playerName,
  }) async {
    setState(() {
      if (card.rank != 8) {
        _activeSuitConstraint = null;
      }
      _status = '$playerName joue ${card.label}.';
      hand.remove(card);
      _discardPile.add(card);
    });
  }

  Future<_PlayResolution> _applyCardEffects({
    required PlayingCard card,
    required PlayerTurn currentTurn,
    required String sourceLabel,
  }) async {
    if (card.rank == 1) {
      if (currentTurn == PlayerTurn.human) {
        setState(() {
          _botMustAnswerAce = true;
          _status =
          'Vous jouez un As : GINO doit répondre avec un As, un joker de même couleur, ou piocher.';
        });
        return const _PlayResolution(
          extraTurn: false,
          skipTurnSwitch: false,
        );
      }

      setState(() {
        _humanMustAnswerAce = true;
        _status =
        'GINO joue un As : répondez avec un As, un joker de même couleur, ou piochez.';
      });

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.rank == 2) {
      if (currentTurn == PlayerTurn.human) {
        _setForcedDraw(
          target: PlayerTurn.bot,
          source: PlayerTurn.human,
          count: 2,
          announcement: 'Vous jouez un 2 : GINO doit piocher 2 cartes.',
        );
        await _runForcedDrawForBot();
        return const _PlayResolution(
          extraTurn: true,
          skipTurnSwitch: false,
        );
      } else {
        _setForcedDraw(
          target: PlayerTurn.human,
          source: PlayerTurn.bot,
          count: 2,
          announcement: 'GINO joue un 2 : vous devez piocher 2 cartes.',
        );
      }

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.isJoker) {
      if (currentTurn == PlayerTurn.human) {
        _setForcedDraw(
          target: PlayerTurn.bot,
          source: PlayerTurn.human,
          count: 9,
          announcement: 'Vous jouez un joker : GINO doit piocher 9 cartes.',
        );
        await _runForcedDrawForBot();
        return const _PlayResolution(
          extraTurn: true,
          skipTurnSwitch: false,
        );
      } else {
        _setForcedDraw(
          target: PlayerTurn.human,
          source: PlayerTurn.bot,
          count: 9,
          announcement: 'GINO joue un joker : vous devez piocher 9 cartes.',
        );
      }

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.rank == 8) {
      final Suit askedSuit = await _getAskedSuit(currentTurn);
      if (_gameOver || !mounted) {
        return const _PlayResolution(
          extraTurn: false,
          skipTurnSwitch: false,
        );
      }

      final String demander = currentTurn == PlayerTurn.human
          ? 'Vous demandez ${_suitName(askedSuit)}.'
          : 'GINO demande ${_suitName(askedSuit)}.';

      setState(() {
        _activeSuitConstraint = askedSuit;
        _status = demander;
      });

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.rank == 10 || card.rank == 11) {
      setState(() {
        _status = card.rank == 11
            ? '$sourceLabel joue un Valet : tour adverse sauté, ${currentTurn == PlayerTurn.human ? 'vous' : 'GINO'} rejoue.'
            : '$sourceLabel joue un 10 : tour adverse sauté, ${currentTurn == PlayerTurn.human ? 'vous' : 'GINO'} rejoue.';
      });

      return const _PlayResolution(
        extraTurn: true,
        skipTurnSwitch: false,
      );
    }

    return const _PlayResolution(
      extraTurn: false,
      skipTurnSwitch: false,
    );
  }

  void _finishForcedDrawIfNeeded() {
    if (_forcedDrawCount > 0 || _forcedDrawSource == null) {
      return;
    }

    final PlayerTurn source = _forcedDrawSource!;
    final PlayerTurn? target = _forcedDrawTarget;

    setState(() {
      _status =
      '${target != null ? _turnLabel(target) : 'Le joueur pénalisé'} a terminé la pioche forcée. Le tour reste à ${_turnLabel(source)}.';
      _forcedDrawTarget = null;
      _forcedDrawSource = null;
      _turn = source;
    });

    if (_turn == PlayerTurn.bot && !_gameOver) {
      _ensureBotTurnProgress();
    }
  }

  Future<void> _runForcedDrawForBot() async {
    while (_forcedDrawCount > 0 &&
        _forcedDrawTarget == PlayerTurn.bot &&
        !_gameOver) {
      final PlayingCard? card = _drawOneCard();

      if (card == null) {
        setState(() {
          _status = 'Pioche vide pendant la pénalité de GINO.';
          _forcedDrawCount = 0;
        });
        break;
      }

      setState(() {
        _botHand.add(card);
        _forcedDrawCount--;
        final String unit = _forcedDrawCount > 1 ? 'cartes' : 'carte';
        _status = _forcedDrawCount > 0
            ? 'GINO doit encore piocher $_forcedDrawCount $unit.'
            : 'GINO a terminé sa pioche forcée.';
      });
      unawaited(_sfx.playDraw());
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    _finishForcedDrawIfNeeded();
  }

  Future<Suit> _getAskedSuit(PlayerTurn player) async {
    if (player == PlayerTurn.human) {
      return _showSuitChooserDialog();
    }

    final Suit bestSuit = _chooseRequestedSuitForBot(_botHand);
    await _showEightDemandOverlay(
      suit: bestSuit,
      message: 'GINO demande ${_suitName(bestSuit)}',
    );
    return bestSuit;
  }

  Future<void> _showEightDemandOverlay({
    required Suit suit,
    required String message,
  }) async {
    setState(() {
      _eightDemandOverlaySuit = suit;
      _eightDemandOverlayMessage = message;
      _isEightDemandOverlayVisible = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }

    setState(() {
      _isEightDemandOverlayVisible = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }

    setState(() {
      _eightDemandOverlaySuit = null;
      _eightDemandOverlayMessage = '';
    });
  }

  Future<Suit> _showSuitChooserDialog() async {
    final Suit? selected = await showDialog<Suit>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF9FAF8),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Choisis une enseigne',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1A3427),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 260,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: Suit.values
                  .map(
                    (Suit suit) => _SuitChoiceTile(
                      suit: suit,
                      onTap: () => Navigator.of(context).pop(suit),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );

    final Suit chosenSuit = selected ?? Suit.spades;

    await _showEightDemandOverlay(
      suit: chosenSuit,
      message: 'Vous demandez ${_suitName(chosenSuit)}',
    );

    return chosenSuit;
  }

  Suit _chooseRequestedSuitForBot(List<PlayingCard> hand) {
    final Map<Suit, int> counts = <Suit, int>{};

    for (final PlayingCard card in hand) {
      if (!card.isJoker) {
        counts[card.suit!] = (counts[card.suit!] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) {
      return Suit.values[_random.nextInt(Suit.values.length)];
    }

    Suit bestSuit = counts.keys.first;
    int bestCount = counts[bestSuit] ?? 0;

    counts.forEach((Suit suit, int count) {
      if (count > bestCount) {
        bestSuit = suit;
        bestCount = count;
      }
    });

    return bestSuit;
  }

  void _endHumanTurn() {
    if (_gameOver) {
      return;
    }

    setState(() {
      _humanDidVoluntaryDrawThisTurn = false;
      _turn = PlayerTurn.bot;
      _status = 'Tour de GINO...';
    });

    _ensureBotTurnProgress();
  }


  void _scheduleBotTurn() {
    if (_isBotTurnRunning ||
        _gameOver ||
        _turn != PlayerTurn.bot ||
        _isInitialDealRunning ||
        _isResolvingTurn) {
      return;
    }

    unawaited(_runBotTurn());
  }

  void _ensureBotTurnProgress() {
    if (!mounted || _gameOver) {
      return;
    }

    if (_turn != PlayerTurn.bot) {
      return;
    }

    if (_isInitialDealRunning || _isResolvingTurn) {
      return;
    }

    _scheduleBotTurn();
  }

  Future<void> _runBotTurn({bool chained = false}) async {
    if (!chained) {
      if (_isBotTurnRunning) {
        return;
      }
      _isBotTurnRunning = true;
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));

      if (!mounted || _gameOver || _turn != PlayerTurn.bot || _isInitialDealRunning) {
        return;
      }

      if (_forcedDrawCount > 0 && _forcedDrawTarget == PlayerTurn.bot) {
        await _runForcedDrawForBot();
        return;
      }

      if (_botMustAnswerAce) {
        final List<PlayingCard> aceResponses =
            _botHand.where(_isValidAceResponse).toList();

        final bool chooseToDraw = aceResponses.isEmpty || _random.nextBool();

        if (chooseToDraw) {
          final int drawn = _drawCards(_botHand, 1).length;
          if (drawn > 0) {
            unawaited(_sfx.playDraw());
          }
          setState(() {
            _botMustAnswerAce = false;
            _status = drawn > 0
                ? 'GINO choisit de piocher au lieu de répondre à l’As.'
                : 'GINO choisit de piocher, mais la pioche est vide.';
          });
          _switchToHuman();
          return;
        }

        final PlayingCard botAce = aceResponses.first;
        unawaited(_sfx.playCard());
        await _playCard(
          hand: _botHand,
          card: botAce,
          playerName: 'GINO',
        );

        setState(() {
          _botMustAnswerAce = false;
        });

        if (_checkVictory(
          winner: PlayerTurn.bot,
          hand: _botHand,
          lastPlayed: botAce,
        )) {
          return;
        }

        final _PlayResolution outcome = await _applyCardEffects(
          card: botAce,
          currentTurn: PlayerTurn.bot,
          sourceLabel: 'GINO',
        );

        if (outcome.extraTurn) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await _runBotTurn(chained: true);
          return;
        }

        if (outcome.skipTurnSwitch) {
          return;
        }

        _switchToHuman();
        return;
      }

      final List<PlayingCard> playable = _botHand.where((PlayingCard card) {
        return _isCardPlayableForHand(card, _botHand);
      }).toList();

      PlayingCard? chosen;

      if (playable.isNotEmpty) {
        final List<PlayingCard> nonEight =
            playable.where((PlayingCard card) => card.rank != 8).toList();
        chosen = nonEight.isNotEmpty ? nonEight.first : playable.first;
      }

      if (chosen == null) {
        final List<PlayingCard> drawn = _drawCards(_botHand, 1);
        if (drawn.isEmpty) {
          setState(() {
            _status = 'GINO ne peut pas piocher. Pioche vide.';
          });
          _switchToHuman();
          return;
        }

        setState(() {
          _status = 'GINO pioche une carte.';
        });
        unawaited(_sfx.playDraw());

        final PlayingCard drawnCard = drawn.first;
        if (_isCardPlayableForHand(drawnCard, _botHand)) {
          chosen = drawnCard;
        } else {
          _switchToHuman();
          return;
        }
      }

      unawaited(_sfx.playCard());
      await _playCard(
        hand: _botHand,
        card: chosen,
        playerName: 'GINO',
      );

      final _PlayResolution outcome = await _applyCardEffects(
        card: chosen,
        currentTurn: PlayerTurn.bot,
        sourceLabel: 'GINO',
      );

      if (_checkVictory(
        winner: PlayerTurn.bot,
        hand: _botHand,
        lastPlayed: chosen,
      )) {
        return;
      }

      if (outcome.extraTurn) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await _runBotTurn(chained: true);
        return;
      }

      if (outcome.skipTurnSwitch) {
        return;
      }

      _switchToHuman();
    } finally {
      if (!chained) {
        _isBotTurnRunning = false;
        _ensureBotTurnProgress();
      }
    }
  }

  bool _checkVictory({
    required PlayerTurn winner,
    required List<PlayingCard> hand,
    required PlayingCard lastPlayed,
  }) {
    if (hand.isNotEmpty) {
      return false;
    }

    if (!lastPlayed.canFinishGame) {
      return false;
    }

    setState(() {
      if (winner == PlayerTurn.human) {
        _humanScore++;
        unawaited(_sfx.playWin());
      } else {
        _botScore++;
        unawaited(_sfx.playLose());
      }
      _gameOver = true;
      _status = '${_turnLabel(winner)} a gagné !';
    });

    return true;
  }

  void _switchToHuman() {
    setState(() {
      _humanDidVoluntaryDrawThisTurn = false;
      _turn = PlayerTurn.human;
      if (!_gameOver) {
        _status =
        _isHumanForcedToDrawNow() ? _forcedDrawRemainingText() : 'À vous de jouer';
      }
    });
  }

  String _suitName(Suit suit) {
    switch (suit) {
      case Suit.spades:
        return 'pique';
      case Suit.hearts:
        return 'cœur';
      case Suit.diamonds:
        return 'carreau';
      case Suit.clubs:
        return 'trèfle';
    }
  }

  String _suitSymbol(Suit suit) {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  Color _suitColor(Suit suit) {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red.shade700;
      case Suit.spades:
      case Suit.clubs:
        return Colors.black87;
    }
  }

  Color _statusSuitColor(Suit suit) {
    if (suit == Suit.hearts || suit == Suit.diamonds) {
      return const Color(0xFFFF8383);
    }
    return const Color(0xFFF2FFF7);
  }

  bool _humanHasPlayableCard() {
    return _humanHand.any(_isCardPlayableForHuman);
  }

  bool _canHumanDrawNow() {
    if (_turn != PlayerTurn.human ||
        _gameOver ||
        _isResolvingTurn ||
        _isInitialDealRunning) {
      return false;
    }

    return true;
  }

  bool _shouldHighlightDrawPile() {
    if (!_canHumanDrawNow()) {
      return false;
    }

    if (_isHumanForcedToDrawNow()) {
      return true;
    }

    if (_humanMustAnswerAce) {
      return true;
    }

    return !_humanHasPlayableCard() || _humanDidVoluntaryDrawThisTurn;
  }

  @override
  Widget build(BuildContext context) {
    final bool canInteract = _turn == PlayerTurn.human &&
        !_gameOver &&
        !_isResolvingTurn &&
        !_isInitialDealRunning &&
        !_isHumanForcedToDrawNow();
    final double topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: GameModePalette.background,
      body: Stack(
        children: <Widget>[
          TableBackground(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 12, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () {
                              unawaited(_sfx.playClick());
                              Navigator.of(context).popUntil(
                                (Route<dynamic> route) => route.isFirst,
                              );
                            },
                            tooltip: 'Retour aux modes',
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: GameModePalette.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SOLO',
                            style: GoogleFonts.leagueSpartan(
                              color: GameModePalette.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              unawaited(_sfx.playClick());
                              _startNewGame();
                            },
                            tooltip: 'Nouvelle manche',
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: GameModePalette.white,
                            ),
                          ),
                        ],
                      ),
                      _scoreBar(),
                      const SizedBox(height: 10),
                      _statusBanner(),
                      const SizedBox(height: 10),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.center,
                          child: _botHandArea(),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.center,
                          child: _centerArea(),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _handMetaRow(count: _humanHand.length),
                            const SizedBox(height: 8),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                ) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          for (
                                            final PlayingCard card
                                                in _humanHand
                                          )
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: CardView(
                                                card: card,
                                                enabled:
                                                    canInteract &&
                                                    _isCardPlayableForHuman(
                                                      card,
                                                    ),
                                                onTap:
                                                    () => _onHumanTapCard(card),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_gameOver)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ElevatedButton(
                            onPressed: () {
                              unawaited(_sfx.playClick());
                              _startNewGame();
                            },
                            child: const Text('Prendre sa revanche'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isEightDemandOverlayVisible && _eightDemandOverlaySuit != null)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _isEightDemandOverlayVisible ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      tween: Tween<double>(begin: 0.85, end: 1),
                      builder:
                          (BuildContext context, double value, Widget? child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 240,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(color: Colors.black45, blurRadius: 18),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text(
                              'Nouvelle carte',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _EightSuitCard(suit: _eightDemandOverlaySuit!),
                            const SizedBox(height: 10),
                            Text(_eightDemandOverlayMessage),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _botHandArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _handMetaRow(count: _botHand.length),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: SizedBox(
                    height: _handCardHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (int i = 0; i < _botHand.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              right: i == _botHand.length - 1 ? 0 : 6,
                            ),
                            child: const CardBackView(
                              width: _handCardWidth,
                              height: _handCardHeight,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _centerArea() {
    final bool shouldHighlightDraw = _shouldHighlightDrawPile();
    final bool canDraw = _canHumanDrawNow();
    final bool hasDiscard = _discardPile.isNotEmpty;

    return SizedBox(
      height: 210,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double drawPileWidth = 52;
          const double drawPileHeight = 72;
          const double horizontalMargin = 12;
          const double topMargin = 10;
          const double idealHorizontalOffset = 96;
          const double idealVerticalOffset = 44;
          final double maxHorizontalOffset = max(
            0,
            (constraints.maxWidth / 2) -
                (drawPileWidth / 2) -
                horizontalMargin,
          );
          final double maxVerticalOffset = max(
            0,
            (constraints.maxHeight / 2) -
                (drawPileHeight / 2) -
                topMargin,
          );
          final double drawHorizontalOffset = min(
            idealHorizontalOffset,
            maxHorizontalOffset,
          );
          final double drawVerticalOffset = min(
            idealVerticalOffset,
            maxVerticalOffset,
          );

          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    if (hasDiscard)
                      Transform.scale(
                        scale: 1.08,
                        child: _DiscardPileView(
                          key: _discardPileKey,
                          cards: _discardPile,
                        ),
                      )
                    else
                      Transform.scale(
                        scale: 1.08,
                        child: const _EmptyCardSlot(label: 'Vide'),
                      ),
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(-drawHorizontalOffset, -drawVerticalOffset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: canDraw ? _onHumanDraw : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          _drawPile.isNotEmpty
                              ? _DrawPileView(highlight: shouldHighlightDraw)
                              : const _EmptyCardSlot(label: '0'),
                          Positioned(
                            right: -8,
                            top: -10,
                            child: _CountBadge(count: _drawPile.length),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scoreBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _ScorePill(label: 'VOUS', value: _humanScore),
        const SizedBox(width: 10),
        _ScorePill(label: 'GINO', value: _botScore),
      ],
    );
  }

  Widget _handMetaRow({required int count}) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.style_rounded,
          size: 18,
          color: Colors.white.withOpacity(0.95),
        ),
        const SizedBox(width: 6),
        _CountBadge(count: count),
      ],
    );
  }

  Widget _statusBanner() {
    return AnimatedSwitcher(
      duration: _uiTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Container(
        key: ValueKey<String>(
          '$_status-${_activeSuitConstraint?.name}-${_humanMustAnswerAce ? 1 : 0}',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_activeSuitConstraint != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Enseigne demandée : ${_suitName(_activeSuitConstraint!)} ${_suitSymbol(_activeSuitConstraint!)}',
                style: TextStyle(
                  color: _statusSuitColor(_activeSuitConstraint!),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (_humanMustAnswerAce) ...<Widget>[
              const SizedBox(height: 6),
              const Text(
                'Réponse à l’As : jouez un As, un joker de même couleur, ou piochez.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CardBackView extends StatelessWidget {
  const CardBackView({
    super.key,
    this.width = 52,
    this.height = 72,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: PremiumCardEffects.bevelBack(
        borderRadius: BorderRadius.circular(10),
        image: const DecorationImage(
          image: AssetImage('assets/img/card_back.jpeg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.18)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$label : $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DrawPileView extends StatefulWidget {
  const _DrawPileView({required this.highlight});

  final bool highlight;

  @override
  State<_DrawPileView> createState() => _DrawPileViewState();
}

class _DrawPileViewState extends State<_DrawPileView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.highlight) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _DrawPileView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.highlight && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.highlight && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (BuildContext context, Widget? child) {
        final double glow =
        widget.highlight ? (0.35 + (_pulseController.value * 0.55)) : 0.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              if (widget.highlight)
                BoxShadow(
                  color: Colors.amberAccent.withOpacity(glow),
                  blurRadius: 22,
                  spreadRadius: 1.5,
                ),
            ],
          ),
          child: child,
        );
      },
      child: const CardBackView(width: 70, height: 100),
    );
  }
}

class _EmptyCardSlot extends StatelessWidget {
  const _EmptyCardSlot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white38),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    this.enabled = false,
    this.onTap,
  });

  final PlayingCard card;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget cardWidget = Container(
      width: 64,
      height: 96,
      decoration: PremiumCardEffects.bevelFace(
        borderRadius: BorderRadius.circular(12),
        color: card.isJoker
            ? (card.isRed ? Colors.red.shade50 : Colors.grey.shade200)
            : Colors.white,
      ).copyWith(
        border: Border.all(
          color: enabled ? Colors.amber : Colors.black26,
          width: enabled ? 3 : 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: card.isJoker
          ? Center(
        child: Text(
          card.isRed ? 'Joker\nRouge' : 'Joker\nNoir',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: card.suitColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            card.rankLabel,
            style: TextStyle(
              color: card.suitColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              card.suitSymbol,
              style: TextStyle(
                color: card.suitColor,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: cardWidget,
    );
  }
}



class _DiscardPileView extends StatelessWidget {
  const _DiscardPileView({
    super.key,
    required this.cards,
  });

  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    final PlayingCard topCard = cards.last;

    return SizedBox(
      width: 86,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Simple and stable fake pile layers (visual only).
          Transform.translate(
            offset: const Offset(-4, -3),
            child: Container(
              width: 64,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(-2, -1),
            child: Container(
              width: 64,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
          // Only the top card is rendered as an actual card to avoid
          // complex stacking and repaint churn.
          CardView(card: topCard),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                '${cards.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuitChoiceTile extends StatelessWidget {
  const _SuitChoiceTile({
    required this.suit,
    required this.onTap,
  });

  final Suit suit;
  final VoidCallback onTap;

  String get _symbol {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  String get _name {
    switch (suit) {
      case Suit.spades:
        return 'pique';
      case Suit.hearts:
        return 'cœur';
      case Suit.diamonds:
        return 'carreau';
      case Suit.clubs:
        return 'trèfle';
    }
  }

  Color get _color {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red.shade700;
      case Suit.spades:
      case Suit.clubs:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 156,
        height: 124,
        decoration: PremiumCardEffects.bevelFace(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          borderColor: _color.withOpacity(0.45),
        ).copyWith(
          border: Border.all(
            color: _color.withOpacity(0.55),
            width: 1.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _symbol,
              style: TextStyle(
                color: _color,
                fontSize: 44,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _EightSuitCard extends StatelessWidget {
  const _EightSuitCard({required this.suit});

  final Suit suit;

  String get _symbol {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  Color get _color {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return Colors.red.shade700;
      case Suit.spades:
      case Suit.clubs:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 146,
      decoration: PremiumCardEffects.bevelFace(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        borderColor: Colors.blueGrey,
      ).copyWith(
        border: Border.all(color: Colors.blueGrey, width: 1.6),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '8',
            style: TextStyle(
              color: _color,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              _symbol,
              style: TextStyle(
                color: _color,
                fontSize: 44,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
