import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/widgets.dart';

import 'app_logo.dart';
import 'app_sfx_service.dart';
import 'auth_service.dart';
import 'firebase_config.dart';
import 'duel_mode.dart';
import 'leaderboard_page.dart';
import 'admin_dashboard.dart';
import 'player_side_panel.dart';
import 'premium_ui.dart';
import 'player_profile.dart';
import 'game_card_avatar.dart';
import 'game_popup_ui.dart';
import 'game_history_page.dart';
import 'user_profile_service.dart';
import 'widgets/bouncy_card_entry.dart';
import 'widgets/funny_game_toast.dart';
import 'widgets/gino_popups.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
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
  }
  await _initializeFirebaseIfConfigured();
  runApp(const MyApp());
}

Future<void> _initializeFirebaseIfConfigured() async {
  if (Firebase.apps.isNotEmpty) {
    final FirebaseApp app = Firebase.app();
    debugPrint(
      '[Firebase] already initialized: app=${app.name}, projectId=${app.options.projectId}, appId=${app.options.appId}',
    );
    return;
  }

  try {
    final FirebaseOptions? options = FirebaseConfig.optionsForCurrentPlatform();
    if (options != null) {
      await Firebase.initializeApp(options: options);
      final FirebaseApp app = Firebase.app();
      debugPrint(
        '[Firebase] initialized: app=${app.name}, projectId=${app.options.projectId}, appId=${app.options.appId}',
      );
    } else {
      debugPrint('[Firebase] skipped initialization: missing options for platform.');
    }
  } catch (e, stackTrace) {
    debugPrint('[Firebase] initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => AudioService.instance.registerUserGesture(),
      child: MaterialApp(
        title: 'GINO',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: PremiumColors.tableGreenMid,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: GoogleFonts.poppins().fontFamily,
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
                fontWeight: FontWeight.w500,
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
              fontWeight: FontWeight.w500,
            ),
            contentTextStyle: const TextStyle(
              color: PremiumColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        routes: <String, WidgetBuilder>{
          GameModeRoutes.solo: (BuildContext context) {
            unawaited(AudioService.instance.preloadGameSounds());
            final Object? args = ModalRoute.of(context)?.settings.arguments;
            return CrazyEightsPage(
              launchOptions: args is GameLaunchOptions ? args : const GameLaunchOptions(),
            );
          },
          GameModeRoutes.duel: (BuildContext context) {
            unawaited(AudioService.instance.preloadGameSounds());
            final Object? args = ModalRoute.of(context)?.settings.arguments;
            final bool specialBonusesEnabled = args is GameLaunchOptions
                ? args.specialBonusesEnabled
                : true;
            return DuelLobbyPage(specialBonusesEnabled: specialBonusesEnabled);
          },
          GameModeRoutes.credits: (BuildContext context) {
            unawaited(AudioService.instance.preloadGameSounds());
            final Object? args = ModalRoute.of(context)?.settings.arguments;
            final bool specialBonusesEnabled = args is GameLaunchOptions
                ? args.specialBonusesEnabled
                : false;
            return DuelLobbyPage(
              mode: DuelRoomMode.credits,
              specialBonusesEnabled: specialBonusesEnabled,
            );
          },
          GameModeRoutes.leaderboard: (_) => const LeaderboardPage(),
          GameModeRoutes.history: (_) => const GameHistoryPage(),
          GameModeRoutes.adminLogin: (_) => const LoginAdminPage(),
          GameModeRoutes.adminDashboard: (_) => const AdminDashboardPage(),
        },
        home: const AppBootstrapPage(),
      ),
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  @override
  void initState() {
    super.initState();
    unawaited(AudioService.instance.initialize(strict: false));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AudioService.instance.startProgressivePreload());
      unawaited(AudioService.instance.playDefaultBackgroundMusic());
    });
  }

  @override
  Widget build(BuildContext context) {
    return const IntroLandingPage();
  }
}

class _AudioWarmupErrorPage extends StatelessWidget {
  const _AudioWarmupErrorPage({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameModePalette.background,
      endDrawer: PlayerSidePanel(
        onOpenLeaderboard: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(GameModeRoutes.leaderboard);
        },
        onOpenHistory: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(GameModeRoutes.history);
        },
      ),
      body: Stack(
        children: <Widget>[
          const BackgroundDecoration(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Audio initialization failed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioWarmupPage extends StatefulWidget {
  const _AudioWarmupPage();

  @override
  State<_AudioWarmupPage> createState() => _AudioWarmupPageState();
}

class _AudioWarmupPageState extends State<_AudioWarmupPage> {
  static const List<String> _loadingSuits = <String>['♦', '♥', '♠', '♣'];
  static const Duration _symbolStep = Duration(milliseconds: 620);
  int _symbolIndex = 0;
  Timer? _symbolTimer;

  @override
  void initState() {
    super.initState();
    _symbolTimer = Timer.periodic(_symbolStep, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _symbolIndex = (_symbolIndex + 1) % _loadingSuits.length;
      });
    });
  }

  @override
  void dispose() {
    _symbolTimer?.cancel();
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
                      const AppLogo(size: 190),
                      const SizedBox(height: 28),
                      ListenableBuilder(
                        listenable: AudioService.instance,
                        builder: (BuildContext context, _) {
                          final double progress = AudioService.instance.initializationProgress;
                          final int percent = (progress * 100).round().clamp(0, 100);
                          return Column(
                            children: <Widget>[
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 340),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder:
                                    (Widget child, Animation<double> animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween<double>(begin: 0.9, end: 1).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                          child: child,
                                        ),
                                      );
                                    },
                                child: Text(
                                  _loadingSuits[_symbolIndex],
                                  key: ValueKey<int>(_symbolIndex),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.88),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: progress),
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOutCubic,
                                  builder: (BuildContext context, double animatedValue, _) {
                                    return LinearProgressIndicator(
                                      minHeight: 8,
                                      value: animatedValue,
                                      color: GameModePalette.accentGreen,
                                      backgroundColor: Colors.white24,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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



enum GameMode { solo, duel, credits }

class GameModeRoutes {
  static const String solo = '/solo';
  static const String duel = '/duel';
  static const String credits = '/credits';
  static const String leaderboard = '/leaderboard';
  static const String history = '/history';
  static const String adminLogin = '/admin-login';
  static const String adminDashboard = '/admin-dashboard';
}

class GameLaunchOptions {
  const GameLaunchOptions({this.specialBonusesEnabled = true});

  final bool specialBonusesEnabled;
}

class SpecialFinishBonus {
  const SpecialFinishBonus({
    required this.cardName,
    required this.amount,
  });

  final String cardName;
  final int amount;

  String get winnerLine => 'Bonus $cardName : +$amount';
  String get loserLine => 'Malus adverse : −$amount';
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

class _IntroLandingPageState extends State<IntroLandingPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService.instance;
  final UserProfileService _profileService = UserProfileService.instance;
  bool _hasShownStartupAd = false;
  bool _hasAskedStartupLogin = false;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showStartupDialogs());
    });
  }

  Future<void> _showStartupDialogs() async {
    if (!mounted) {
      return;
    }
    if (!_hasShownStartupAd) {
      _hasShownStartupAd = true;
      await showStartupAdPopup(context);
    }
    if (!mounted || _hasAskedStartupLogin || _authService.currentUser != null) {
      return;
    }
    _hasAskedStartupLogin = true;
    final bool shouldLogin = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return ConnectionPopup(
              onGooglePressed: () => Navigator.of(context).pop(true),
              onContinueWithoutAccount: () => Navigator.of(context).pop(false),
            );
          },
        ) ??
        false;
    if (!mounted || !shouldLogin) {
      return;
    }
    final GoogleAuthResult result = await _authService.signInWithGoogle();
    if (!mounted) {
      return;
    }
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Connexion Google impossible.')),
      );
      return;
    }
    try {
      await _profileService.createOrUpdateFromGoogleUser(result.user!);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion réussie, profil indisponible: $e')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ambientController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF022817),
      endDrawer: PlayerSidePanel(
        onOpenLeaderboard: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(GameModeRoutes.leaderboard);
        },
        onOpenHistory: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(GameModeRoutes.history);
        },
      ),
      body: Stack(
        children: <Widget>[
          PremiumHomeBackgroundDecoration(animation: _ambientController),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: GlobalMusicToggleButton(premiumSurface: true),
            ),
          ),
          SafeArea(
            child: Builder(
              builder: (BuildContext context) =>
                  const PlayerSidePanelButton(premiumSurface: true),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: PremiumHomeLogoGlow(
                          animation: _ambientController,
                          child: const AppLogo(size: 280),
                        ),
                      ),
                      const SizedBox(height: 34),
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

class StartupAdPopup extends StatelessWidget {
  const StartupAdPopup({super.key});

  static const String _adAssetPath = 'assets/img/ADS1.jpeg';

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double maxPopupWidth = (screenSize.width * 0.9).clamp(260, 560).toDouble();
    final double maxPopupHeight = (screenSize.height * 0.8).clamp(220, 680).toDouble();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxPopupWidth,
              maxHeight: maxPopupHeight,
            ),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    GinoPopupStyle.premiumDeepGreen.withOpacity(0.96),
                    GinoPopupStyle.popupGreen.withOpacity(0.92),
                    const Color(0xFF001D13).withOpacity(0.97),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: GinoPopupStyle.casinoGold.withOpacity(0.72),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.42),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: GinoPopupStyle.premiumNeonGreen.withOpacity(0.16),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.asset(
                  _adAssetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: -10,
            right: -10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        GinoPopupStyle.casinoGold,
                        GinoPopupStyle.accentGreen,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
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

Future<void> showStartupAdPopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => const StartupAdPopup(),
  );
}

class GameModePage extends StatefulWidget {
  const GameModePage({super.key});

  @override
  State<GameModePage> createState() => _GameModePageState();
}

class _GameModePageState extends State<GameModePage>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService.instance;
  final UserProfileService _profileService = UserProfileService.instance;
  static const double _designWidth = 393;
  static const double _designHeight = 852;
  static const double _frameHorizontalPadding = 18;
  static const double _frameVerticalPadding = 14;
  static const double _logoTopSpacing = 10;
  static const double _modeCardsTopSpacing = 16;
  static const double _controlsTopSpacing = 24;
  static const double _centerBlockVerticalOffset = -10;
  static const double _modeLabelFontSize = 22;
  static const double _playLabelFontSize = 20;
  static const double _versionFontSize = 14;
  static const double _modeCardWidth = 116;
  static const double _modeCardHeight = 178;

  late final AnimationController _introController;
  late final AnimationController _ambientController;
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
  late final SelectionCardModel _duelFrontCard;
  late final SelectionCardModel _duelBackCard;
  GameMode? _selectedMode;
  bool _specialBonusesEnabled = true;

  @override
  void initState() {
    super.initState();
    final Random random = Random();
    _duelFrontCard = SelectionCardGenerator.randomCard(random);
    _duelBackCard = SelectionCardGenerator.randomCard(random);
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);
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
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02160E),
      endDrawer: PlayerSidePanel(
        onOpenLeaderboard: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(GameModeRoutes.leaderboard);
        },
        onOpenHistory: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(GameModeRoutes.history);
        },
      ),
      body: Stack(
        children: <Widget>[
          PremiumHomeBackgroundDecoration(animation: _ambientController),
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
                            PremiumHomeLogoGlow(
                              animation: _ambientController,
                              child: const AppLogo(size: 170),
                            ),
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
                                                  child: GameModeCard(
                                                    mode: _ModeCardVariant.solo,
                                                    width: _modeCardWidth,
                                                    height: _modeCardHeight,
                                                    primaryCard:
                                                        const SelectionCardModel(
                                                      rank: '9',
                                                      suit: SelectionSuit.club,
                                                    ),
                                                    labelFontSize:
                                                        _modeLabelFontSize,
                                                    appearDelay:
                                                        const Duration(
                                                          milliseconds: 60,
                                                        ),
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
                                                  child: GameModeCard(
                                                    mode: _ModeCardVariant.duel,
                                                    width: _modeCardWidth,
                                                    height: _modeCardHeight,
                                                    primaryCard:
                                                        _duelFrontCard,
                                                    secondaryCard:
                                                        _duelBackCard,
                                                    labelFontSize:
                                                        _modeLabelFontSize,
                                                    appearDelay:
                                                        const Duration(
                                                          milliseconds: 140,
                                                        ),
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
                                                  child: GameModeCard(
                                                    mode: _ModeCardVariant.paris,
                                                    width: _modeCardWidth,
                                                    height: _modeCardHeight,
                                                    primaryCard:
                                                        const SelectionCardModel(
                                                      rank: 'A',
                                                      suit: SelectionSuit.heart,
                                                    ),
                                                    labelFontSize:
                                                        _modeLabelFontSize,
                                                    appearDelay:
                                                        const Duration(
                                                          milliseconds: 220,
                                                        ),
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
                                      const SizedBox(height: 16),
                                      _SpecialBonusOptionCard(
                                        enabled: _specialBonusesEnabled,
                                        selectedMode: _selectedMode,
                                        onChanged: (bool value) {
                                          unawaited(AppSfxService.instance.playClick());
                                          setState(() {
                                            _specialBonusesEnabled = value;
                                          });
                                        },
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
                                  'v2.9',
                                  style: GoogleFonts.poppins(
                                    color: GameModePalette.white.withOpacity(
                                      0.9,
                                    ),
                                    fontSize: _versionFontSize,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  ' DESIGNED BY AKENOO',
                                  style: GoogleFonts.poppins(
                                    color: GameModePalette.white.withOpacity(
                                      0.85,
                                    ),
                                    fontSize: _versionFontSize,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.5,
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
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: GlobalMusicToggleButton(premiumSurface: true),
            ),
          ),
          SafeArea(
            child: Builder(
              builder: (BuildContext context) =>
                  const PlayerSidePanelButton(premiumSurface: true),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: IconButton(
                  tooltip: 'Classement',
                  onPressed: () {
                    unawaited(AppSfxService.instance.playClick());
                    Navigator.of(context).pushNamed(GameModeRoutes.leaderboard);
                  },
                  icon: const Icon(Icons.leaderboard_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: GestureDetector(
                  onLongPress: () {
                    unawaited(AppSfxService.instance.playClick());
                    Navigator.of(context).pushNamed(GameModeRoutes.adminLogin);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF003B22).withOpacity(0.85),
                      border: Border.all(color: const Color(0x667CC79A), width: 1),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 17,
                      color: Colors.white,
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
    unawaited(_startSelectedModeInternal());
  }

  Future<void> _startSelectedModeInternal() async {
    final GameMode? mode = _selectedMode;
    if (mode == null) {
      return;
    }
    if ((mode == GameMode.duel || mode == GameMode.credits) && _authService.currentUser == null) {
      final bool shouldLogin = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: GinoDecisionPopup(
                  title: 'Connexion',
                  message: 'Connecte-toi avec Google pour continuer.',
                  primaryLabel: 'Google',
                  secondaryLabel: 'Annuler',
                  onPrimary: () => Navigator.of(context).pop(true),
                  onSecondary: () => Navigator.of(context).pop(false),
                ),
              );
            },
          ) ??
          false;
      if (!shouldLogin) {
        return;
      }
      final GoogleAuthResult result = await _authService.signInWithGoogle();
      if (!mounted) {
        return;
      }
      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ??
                  (mode == GameMode.duel
                      ? 'Connectez-vous avec Google pour jouer en duel simple.'
                      : 'Connectez-vous avec Google pour jouer en mode pari.'),
            ),
          ),
        );
        return;
      }
      await _profileService.createOrUpdateFromGoogleUser(result.user!);
    }
    if (mode == GameMode.credits) {
      final String? uid = _authService.currentUser?.uid;
      if (uid == null) {
        return;
      }
      final DocumentSnapshot<Map<String, dynamic>> profileSnap =
          await FirebaseFirestore.instance.collection('user_profiles').doc(uid).get();
      final int credits = (profileSnap.data()?['credits'] as num?)?.toInt() ?? 0;
      if (credits <= 0) {
        if (!mounted) {
          return;
        }
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: GinoPopupStyle.premiumDeepGreen.withOpacity(0.96),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: GinoPopupStyle.casinoGold.withOpacity(0.72)),
              ),
              shadowColor: GinoPopupStyle.premiumNeonGreen.withOpacity(0.28),
              title: const Text(
                'Crédit insuffisant',
                style: TextStyle(color: GinoPopupStyle.textWhite, fontWeight: FontWeight.w300),
              ),
              content: const Text(
                'Votre solde est insuffisant pour accéder au mode Pari. Veuillez contacter le service client ou l’administrateur afin de recharger votre compte.',
                style: TextStyle(color: GinoPopupStyle.textWhite, fontWeight: FontWeight.w300),
              ),
              actions: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GinoPopupStyle.premiumNeonGreen.withOpacity(0.82),
                    foregroundColor: GinoPopupStyle.textWhite,
                    shadowColor: GinoPopupStyle.premiumNeonGreen.withOpacity(0.28),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Retour à l’accueil'),
                ),
              ],
            );
          },
        );
        return;
      }
    }
    unawaited(AppSfxService.instance.playClick());
    Navigator.of(context).pushNamed(
      switch (mode) {
        GameMode.solo => GameModeRoutes.solo,
        GameMode.duel => GameModeRoutes.duel,
        GameMode.credits => GameModeRoutes.credits,
      },
      arguments: GameLaunchOptions(
        specialBonusesEnabled: mode == GameMode.credits ? false : _specialBonusesEnabled,
      ),
    );
  }
}


class _SpecialBonusOptionCard extends StatelessWidget {
  const _SpecialBonusOptionCard({
    required this.enabled,
    required this.selectedMode,
    required this.onChanged,
  });

  final bool enabled;
  final GameMode? selectedMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool forcedOff = selectedMode == GameMode.credits;
    final bool displayedEnabled = !forcedOff && enabled;
    final String status = displayedEnabled
        ? 'Bonus spéciaux activés'
        : 'Bonus spéciaux désactivés';
    final String detail = forcedOff
        ? 'Mode Paris/Mises : bonus sécurisés désactivés pour ne pas perturber les mises.'
        : 'Cartes concernées : 8, As, 2 et Joker.';
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: selectedMode == null ? 0.74 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Colors.white.withOpacity(0.10),
              const Color(0xFF07351F).withOpacity(0.76),
              Colors.black.withOpacity(0.18),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF73F38A).withOpacity(0.46),
            width: 1.1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.24),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF72FF9E).withOpacity(0.10),
              blurRadius: 16,
              ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Icon(
              displayedEnabled ? Icons.auto_awesome_rounded : Icons.block_rounded,
              color: displayedEnabled
                  ? const Color(0xFFE8C45A)
                  : Colors.white.withOpacity(0.62),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    detail,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: displayedEnabled,
              onChanged: forcedOff ? null : onChanged,
              activeColor: const Color(0xFF91FFA8),
              activeTrackColor: const Color(0xFF0E6F3B),
              inactiveThumbColor: const Color(0xFFDCECDF),
              inactiveTrackColor: Colors.white.withOpacity(0.16),
              ),
          ],
        ),
      ),
    );
  }
}


class PremiumHomeLogoGlow extends StatelessWidget {
  const PremiumHomeLogoGlow({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double glow = 0.56 + (animation.value * 0.24);
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF58FF91).withOpacity(0.20 * glow),
                blurRadius: 72 + (animation.value * 18),
                spreadRadius: 8 + (animation.value * 6),
              ),
              BoxShadow(
                color: const Color(0xFFE4B853).withOpacity(0.08 * glow),
                blurRadius: 38,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

class PremiumHomeBackgroundDecoration extends StatelessWidget {
  const PremiumHomeBackgroundDecoration({
    super.key,
    required this.animation,
  });

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF031E13),
                Color(0xFF064427),
                Color(0xFF02160E),
              ],
              stops: <double>[0, 0.48, 1],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.18),
                      radius: 0.86,
                      colors: <Color>[
                        const Color(0xFF0DBB61).withOpacity(0.24),
                        Colors.transparent,
                      ],
                      stops: const <double>[0, 1],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, _) {
                    return CustomPaint(
                      painter: _PremiumHomeParticlePainter(animation.value),
                    );
                  },
                ),
              ),
              Positioned(
                top: -120,
                left: -70,
                child: Transform.rotate(
                  angle: -0.48,
                  child: _premiumDecorCard(260, 400, 0.075),
                ),
              ),
              Positioned(
                right: -110,
                bottom: -130,
                child: Transform.rotate(
                  angle: -0.33,
                  child: _premiumDecorCard(290, 410, 0.065),
                ),
              ),
              Positioned(
                top: 118,
                right: -52,
                child: Transform.rotate(
                  angle: 0.18,
                  child: _premiumDecorCard(150, 224, 0.045),
                ),
              ),
              Positioned(
                top: 70,
                left: -34,
                child: Text(
                  '♠',
                  style: TextStyle(
                    fontSize: 156,
                    color: Colors.white.withOpacity(0.045),
                    height: 1,
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 42,
                child: Text(
                  '♣',
                  style: TextStyle(
                    fontSize: 136,
                    color: const Color(0xFF9CFFB7).withOpacity(0.045),
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _premiumDecorCard(double width, double height, double opacity) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withOpacity(opacity * 0.35),
        border: Border.all(
          color: const Color(0xFF9EFFBA).withOpacity(opacity),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
    );
  }
}

class _PremiumHomeParticlePainter extends CustomPainter {
  const _PremiumHomeParticlePainter(this.phase);

  final double phase;

  static const List<Offset> _positions = <Offset>[
    Offset(0.16, 0.18),
    Offset(0.78, 0.16),
    Offset(0.62, 0.32),
    Offset(0.24, 0.58),
    Offset(0.84, 0.64),
    Offset(0.42, 0.78),
    Offset(0.12, 0.86),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _positions.length; i++) {
      final Offset base = _positions[i];
      final double drift = sin((phase * pi * 2) + i) * 7;
      final Offset center = Offset(
        (base.dx * size.width) + drift,
        (base.dy * size.height) - (phase * 9) + (i.isEven ? 4 : -4),
      );
      final double sparkle =
          0.38 + (sin((phase * pi * 2) + (i * 0.9)) * 0.18);
      final Paint paint = Paint()
        ..color = (i.isEven ? const Color(0xFFE8C45A) : const Color(0xFF72FF9E))
            .withOpacity(0.10 + (sparkle * 0.08));
      canvas.drawCircle(center, 1.4 + (i % 3 * 0.45), paint);
    }
  }

  @override
  bool shouldRepaint(_PremiumHomeParticlePainter oldDelegate) {
    return oldDelegate.phase != phase;
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

enum _ModeCardVariant { solo, duel, paris }

enum SelectionSuit { spade, heart, diamond, club }

class SelectionCardModel {
  const SelectionCardModel({
    required this.rank,
    required this.suit,
  });

  final String rank;
  final SelectionSuit suit;
  bool get isRedSuit => suit == SelectionSuit.heart || suit == SelectionSuit.diamond;

  String get suitSymbol => switch (suit) {
    SelectionSuit.spade => '♠',
    SelectionSuit.heart => '♥',
    SelectionSuit.diamond => '♦',
    SelectionSuit.club => '♣',
  };
}

class SelectionCardGenerator {
  SelectionCardGenerator._();

  static const List<String> _ranks = <String>['A', 'K', 'Q', 'J', '10', '9', '8'];

  static SelectionCardModel randomCard(Random random) {
    return SelectionCardModel(
      rank: _ranks[random.nextInt(_ranks.length)],
      suit: SelectionSuit.values[random.nextInt(SelectionSuit.values.length)],
    );
  }
}

class GameModeCard extends StatelessWidget {
  const GameModeCard({
    super.key,
    required this.mode,
    required this.width,
    required this.height,
    required this.labelFontSize,
    required this.appearDelay,
    required this.isSelected,
    required this.onTap,
    this.primaryCard,
    this.secondaryCard,
  });

  final _ModeCardVariant mode;
  final double width;
  final double height;
  final double labelFontSize;
  final Duration appearDelay;
  final bool isSelected;
  final VoidCallback onTap;
  final SelectionCardModel? primaryCard;
  final SelectionCardModel? secondaryCard;

  @override
  Widget build(BuildContext context) {
    return _PressableModeCard(
      onTap: onTap,
      isSelected: isSelected,
      label: _label,
      labelFontSize: labelFontSize,
      appearDelay: appearDelay,
      child: _GameModeCardFace(
        width: width,
        height: height,
        mode: mode,
        primaryCard: primaryCard,
        secondaryCard: secondaryCard,
      ),
    );
  }

  String get _label => switch (mode) {
    _ModeCardVariant.solo => 'Solo',
    _ModeCardVariant.duel => 'Duel',
    _ModeCardVariant.paris => 'Pari',
  };
}

class _GameModeCardFace extends StatelessWidget {
  const _GameModeCardFace({
    required this.width,
    required this.height,
    required this.mode,
    this.primaryCard,
    this.secondaryCard,
  });

  final double width;
  final double height;
  final _ModeCardVariant mode;
  final SelectionCardModel? primaryCard;
  final SelectionCardModel? secondaryCard;

  @override
  Widget build(BuildContext context) {
    final SelectionCardModel fallback = SelectionCardGenerator.randomCard(Random(99));
    return switch (mode) {
      _ModeCardVariant.solo => SelectionPlayingCard(
        model: primaryCard ?? fallback,
        width: width,
        height: height,
      ),
      _ModeCardVariant.duel => DuelSelectionCard(
        width: width,
        height: height,
        backCard: secondaryCard ?? fallback,
        frontCard: primaryCard ?? fallback,
      ),
      _ModeCardVariant.paris => SelectionPlayingCard(
        model: primaryCard ?? fallback,
        width: width,
        height: height,
      ),
    };
  }
}

class SelectionPlayingCard extends StatelessWidget {
  const SelectionPlayingCard({
    super.key,
    required this.model,
    required this.width,
    required this.height,
  });

  final SelectionCardModel model;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color suitColor = model.isRedSuit
        ? const Color(0xFFD83B47)
        : const Color(0xFF087D45);
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFFFFF),
              Color(0xFFF5FFF8),
              Color(0xFFE7F4EA),
            ],
          ),
          border: Border.all(color: const Color(0xFFE4B853).withOpacity(0.58)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.26),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF6CFF99).withOpacity(0.12),
              blurRadius: 16,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.25, -0.4),
                      radius: 0.86,
                      colors: <Color>[
                        const Color(0xFF68FF9A).withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _CardCorner(
                  rank: model.rank,
                  suit: model.suitSymbol,
                  color: suitColor,
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Transform.rotate(
                  angle: pi,
                  child: _CardCorner(
                    rank: model.rank,
                    suit: model.suitSymbol,
                    color: suitColor,
                  ),
                ),
              ),
              Center(
                child: Text(
                  model.suitSymbol,
                  style: TextStyle(
                    color: suitColor,
                    fontSize: height * 0.46,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    shadows: <Shadow>[
                      Shadow(
                        color: suitColor.withOpacity(0.22),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.58),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DuelSelectionCard extends StatelessWidget {
  const DuelSelectionCard({
    super.key,
    required this.width,
    required this.height,
    required this.backCard,
    required this.frontCard,
  });

  final double width;
  final double height;
  final SelectionCardModel backCard;
  final SelectionCardModel frontCard;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            top: 13,
            left: 6,
            child: Transform.rotate(
              angle: -0.11,
              child: SelectionPlayingCard(
                model: backCard,
                width: width * 0.74,
                height: height * 0.74,
              ),
            ),
            ),
            Positioned(
            right: 3,
            bottom: 6,
            child: Transform.rotate(
              angle: 0.08,
              child: SelectionPlayingCard(
                model: frontCard,
                width: width * 0.74,
                height: height * 0.74,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardCorner extends StatelessWidget {
  const _CardCorner({
    required this.rank,
    required this.suit,
    required this.color,
  });

  final String rank;
  final String suit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          rank,
          style: GoogleFonts.notoSerif(
            color: color,
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          suit,
          style: TextStyle(
            color: color,
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CardAppearWrapper extends StatefulWidget {
  const _CardAppearWrapper({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_CardAppearWrapper> createState() => _CardAppearWrapperState();
}

class _CardAppearWrapperState extends State<_CardAppearWrapper> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) {
        return;
      }
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutQuart,
      offset: _visible ? Offset.zero : const Offset(0, 0.03),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutQuart,
        scale: _visible ? 1 : 0.985,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 560),
          curve: Curves.easeOutQuart,
          opacity: _visible ? 1 : 0,
          child: widget.child,
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
    required this.appearDelay,
    required this.isSelected,
    required this.onTap,
  });

  final Widget child;
  final String label;
  final double labelFontSize;
  final Duration appearDelay;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_PressableModeCard> createState() => _PressableModeCardState();
}

class _PressableModeCardState extends State<_PressableModeCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _isHovered = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool emphasized = widget.isSelected || _isHovered;
    return _CardAppearWrapper(
      delay: widget.appearDelay,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.962 : emphasized ? 1.018 : 1,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (BuildContext context, Widget? child) {
                final double pulse = 0.55 + (_pulseController.value * 0.45);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Colors.white.withOpacity(emphasized ? 0.16 : 0.10),
                        const Color(0xFF0B3C27).withOpacity(0.72),
                        Colors.black.withOpacity(0.24),
                      ],
                      stops: const <double>[0, 0.5, 1],
                    ),
                    border: Border.all(
                      color: Color.lerp(
                        const Color(0xFF57FF91).withOpacity(0.46),
                        const Color(0xFFE4B853).withOpacity(0.44),
                        emphasized ? pulse : 0.22,
                      )!,
                      width: emphasized ? 1.45 : 1.05,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.34),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: const Color(0xFF60FF92)
                            .withOpacity(emphasized ? 0.18 : 0.08),
                        blurRadius: emphasized ? 26 : 18,
                        spreadRadius: emphasized ? 1 : 0,
                      ),
                      BoxShadow(
                        color: const Color(0xFFE2B857)
                            .withOpacity(emphasized ? 0.08 : 0.035),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 0.9,
                        colors: <Color>[
                          const Color(0xFF69FF97).withOpacity(0.16),
                          Colors.white.withOpacity(0.035),
                          Colors.transparent,
                        ],
                        stops: const <double>[0, 0.54, 1],
                      ),
                    ),
                    child: widget.child,
                  ),
                  const SizedBox(height: 11),
                  Text(
                    widget.label,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8AF5A3),
                      fontSize: widget.labelFontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.45,
                      shadows: <Shadow>[
                        Shadow(
                          color: const Color(0xFF58FF91).withOpacity(0.32),
                          blurRadius: emphasized ? 12 : 7,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
              "Let's go",
              style: GoogleFonts.poppins(
                color: GameModePalette.backgroundShade,
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.0,
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

class _IntroPlayButtonState extends State<_IntroPlayButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (BuildContext context, Widget? child) {
          final double pulse = 1 + (_pulseController.value * 0.018);
          return AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            scale: _isPressed ? 0.97 : pulse,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 58, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFFE7FFE7).withOpacity(0.52),
                const Color(0xFF80FFA0).withOpacity(0.34),
                const Color(0xFF31DC66).withOpacity(0.90),
              ],
              stops: const <double>[0, 0.34, 1],
            ),
            border: Border.all(
              color: const Color(0xFF8BFFAA).withOpacity(0.92),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF62FF8E).withOpacity(0.30),
                blurRadius: 28,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.16),
                blurRadius: 6,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Text(
            'Jouer',
            style: GoogleFonts.poppins(
              color: GameModePalette.backgroundShade,
              fontSize: 24,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.0,
            ),
          ),
        ),
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

  String get displayLabel => label;

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
  const CrazyEightsPage({
    super.key,
    this.launchOptions = const GameLaunchOptions(),
  });

  final GameLaunchOptions launchOptions;

  @override
  State<CrazyEightsPage> createState() => _CrazyEightsPageState();
}

class _CrazyEightsPageState extends State<CrazyEightsPage>
{
  static const String _botName = 'Ordi';
  static const String _botNameLower = 'l’ordi';
  final Random _random = Random();
  final AppSfxService _sfx = AppSfxService.instance;
  final AuthService _authService = AuthService.instance;
  final UserProfileService _profileService = UserProfileService.instance;

  List<PlayingCard> _drawPile = <PlayingCard>[];
  final List<PlayingCard> _discardPile = <PlayingCard>[];
  final List<PlayingCard> _humanHand = <PlayingCard>[];
  final List<PlayingCard> _botHand = <PlayingCard>[];
  List<int> _previousHumanCardRefs = <int>[];
  List<int> _previousBotCardRefs = <int>[];
  Set<int> _newHumanCardRefs = <int>{};
  Set<int> _newBotCardRefs = <int>{};

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

  bool _humanDidVoluntaryDrawThisTurn = false;
  bool _forcedDrawWitchPlayed = false;

  int _humanScore = 0;
  int _botScore = 0;
  final GlobalKey _discardPileKey = GlobalKey();
  static const Duration _uiTransitionDuration = Duration(milliseconds: 260);
  static const double _handCardWidth = 64;
  static const double _handCardHeight = 92;
  static const int _maxCardsPerRow = 5;
  bool _funnyMessagesEnabled = true;
  DateTime? _lastFunnyMessageAt;
  bool _isImportantPopupOpen = false;
  int _roundNumber = 0;
  int _lastRoundCreditDelta = 0;
  String _humanDisplayName = 'Vous';
  int _humanWins = 0;
  int _humanLosses = 0;
  GameCardAvatarData _humanAvatar = GameCardAvatarPalette.fromSeed('solo-human');
  final GameCardAvatarData _botAvatar = GameCardAvatarPalette.fromSelection(rank: 'K', suit: 'spades');

  @override
  void initState() {
    super.initState();
    unawaited(_loadHumanProfile());
    _startNewGame();
  }

  Future<void> _loadHumanProfile() async {
    final user = _authService.currentUser;
    if (user == null) {
      return;
    }
    try {
      final PlayerProfile? profile = await _profileService.getProfile(user.uid);
      if (!mounted || profile == null) {
        return;
      }
      setState(() {
        _humanDisplayName = profile.publicDisplayName;
        _humanWins = profile.wins;
        _humanLosses = profile.losses;
        _humanAvatar = profile.selectedCardAvatar;
      });
    } catch (_) {
      // Keep defaults if profile is unavailable.
    }
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
      _roundNumber++;
      _turn = startingPlayer;
      _status = 'Distribution';
      _gameOver = false;
      _isResolvingTurn = false;
      _isInitialDealRunning = true;
      _forcedDrawCount = 0;
      _forcedDrawTarget = null;
      _forcedDrawSource = null;
      _humanMustAnswerAce = false;
      _botMustAnswerAce = false;
      _activeSuitConstraint = null;
      _humanDidVoluntaryDrawThisTurn = false;
      _forcedDrawWitchPlayed = false;
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
      unawaited(_ensureBotTurnProgress());
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

  String _turnLabel(PlayerTurn turn) => turn == PlayerTurn.human ? 'Vous' : _botName;

  String _turnStartText(PlayerTurn turn) => turn == PlayerTurn.human ? 'À votre tour' : 'Tour de l’ordi';

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
    return _evaluateHumanCardPlayability(card).canPlay;
  }

  ({bool canPlay, String? rejectionMessage}) _evaluateHumanCardPlayability(
    PlayingCard card,
  ) {
    if (_humanMustAnswerAce) {
      return _isValidAceResponse(card)
          ? (canPlay: true, rejectionMessage: null)
          : (canPlay: false, rejectionMessage: 'Vous devez répondre à l’As.');
    }

    if (_forcedDrawCount > 0 && _forcedDrawTarget == PlayerTurn.human) {
      return (
        canPlay: false,
        rejectionMessage: 'Vous devez d’abord piocher.',
      );
    }

    if (_activeSuitConstraint != null &&
        (card.isJoker || card.suit != _activeSuitConstraint)) {
      return (
        canPlay: false,
        rejectionMessage: 'Vous devez respecter la couleur.',
      );
    }

    if (_discardPile.isNotEmpty &&
        _topDiscard.isJoker &&
        !_sameColor(card, _topDiscard)) {
      final String colorMessage = _topDiscard.isRed
          ? 'Vous devez jouer une carte rouge.'
          : 'Vous devez jouer une carte noire.';
      return (
        canPlay: false,
        rejectionMessage: colorMessage,
      );
    }

    if (!_isCardPlayableForHand(card, _humanHand)) {
      return (canPlay: false, rejectionMessage: 'Carte non jouable.');
    }

    return (canPlay: true, rejectionMessage: null);
  }

  bool _isValidAceResponse(PlayingCard card) {
    if (_discardPile.isEmpty || _topDiscard.rank != 1) {
      return false;
    }

    return !card.isJoker && card.rank == 1;
  }

  void _setForcedDraw({
    required PlayerTurn target,
    required PlayerTurn source,
    required int count,
    required String announcement,
  }) {
    setState(() {
      _forcedDrawCount = count;
      _forcedDrawTarget = target;
      _forcedDrawSource = source;
      _forcedDrawWitchPlayed = false;
      _status = announcement;
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
    return _forcedDrawCount > 1
        ? 'Vous piochez • encore $_forcedDrawCount cartes'
        : 'Vous piochez • encore 1 carte';
  }

  void _playDrawnCardSfx(PlayingCard card) {
    if (card.isJoker) {
      unawaited(_sfx.playJokerDrawn());
    } else {
      unawaited(_sfx.playDraw());
    }
  }

  void _playHeavyDrawSfxOnce() {
    if (_forcedDrawWitchPlayed || _forcedDrawCount < 4) {
      return;
    }
    _forcedDrawWitchPlayed = true;
    unawaited(_sfx.playHeavyDraw());
  }

  void _playBotOneCardLeftSfxIfNeeded() {
    if (_botHand.length == 1) {
      unawaited(_sfx.playOneCardLeft());
    }
  }

  Future<void> _onHumanTapCard(PlayingCard card) async {
    if (_turn != PlayerTurn.human ||
        _gameOver ||
        _isResolvingTurn ||
        _isInitialDealRunning ||
        _isHumanForcedToDrawNow()) {
      return;
    }

    final ({bool canPlay, String? rejectionMessage}) playability =
        _evaluateHumanCardPlayability(card);
    if (!playability.canPlay) {
      _showShortHumanMessage(playability.rejectionMessage ?? 'Carte non jouable.');
      return;
    }

    final bool wasAceResponse = _humanMustAnswerAce;
    if (_humanMustAnswerAce) {
      setState(() {
        _humanMustAnswerAce = false;
      });
    }

    _isResolvingTurn = true;
    try {
      unawaited(_sfx.playCard());
      await _humanPlayCard(card, wasAceResponse: wasAceResponse);
    } finally {
      _isResolvingTurn = false;
      // Important: _endHumanTurn() can be called while _isResolvingTurn is true,
      // which prevents _scheduleBotTurn() from starting.
      // Re-check bot progression once the resolving lock is released.
      unawaited(_ensureBotTurnProgress());
    }
  }

  void _showShortHumanMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.trim()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _humanPlayCard(
    PlayingCard card, {
    required bool wasAceResponse,
  }) async {
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
      wasAceResponse: wasAceResponse,
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
        _status = 'Vous rejouez';
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
          _status = 'Pioche vide';
          _forcedDrawCount = 0;
        });
        _finishForcedDrawIfNeeded();
        return;
      }

      _playHeavyDrawSfxOnce();
      setState(() {
        _humanHand.add(card);
        _forcedDrawCount--;
        _status = _forcedDrawCount > 0 ? 'Vous piochez' : 'Pioche terminée';
      });
      _playDrawnCardSfx(card);

      _finishForcedDrawIfNeeded();
      return;
    }

    if (_humanMustAnswerAce) {
      final int drawn = _drawCards(_humanHand, 1).length;
      setState(() {
        _humanMustAnswerAce = false;
        _humanDidVoluntaryDrawThisTurn = false;
        _status = drawn > 0
            ? 'Vous piochez.'
            : 'Pioche vide';
      });
      if (drawn > 0) {
        _playDrawnCardSfx(_humanHand.last);
      }
      _endHumanTurn();
      return;
    }

    if (_humanDidVoluntaryDrawThisTurn) {
      setState(() {
        _status = 'Vous passez.';
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
      _status = 'Vous piochez';
    });
    _playDrawnCardSfx(drawnCard);

    // After drawing voluntarily, turn always passes to the bot
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!_gameOver && _turn == PlayerTurn.human) {
      _endHumanTurn();
    }
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
      _status = playerName == 'Vous'
          ? 'Vous jouez ${card.label}'
          : 'Ordi joue ${card.label}';
      hand.remove(card);
      _discardPile.add(card);
    });
  }

  Future<_PlayResolution> _applyCardEffects({
    required PlayingCard card,
    required PlayerTurn currentTurn,
    bool wasAceResponse = false,
  }) async {
    if (card.rank == 1) {
      if (wasAceResponse) {
        setState(() {
          _status = currentTurn == PlayerTurn.human
              ? 'Vous répondez à l’As'
              : 'L’ordi répond à l’As';
        });
        return const _PlayResolution(extraTurn: false, skipTurnSwitch: false);
      }
      if (currentTurn == PlayerTurn.human) {
        setState(() {
          _botMustAnswerAce = true;
          _status = '$_botName doit répondre à l’As.';
        });
        return const _PlayResolution(
          extraTurn: false,
          skipTurnSwitch: false,
        );
      }

      setState(() {
        _humanMustAnswerAce = true;
        _status = 'Vous devez répondre à l’As';
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
          announcement: 'Ordi pioche 2 cartes',
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
          announcement: '$_botName joue un 2.',
        );
        _showFunnyGameMessage(playerName: 'Vous', message: 'Petit cadeau du quartier.');
        return const _PlayResolution(
          extraTurn: false,
          skipTurnSwitch: false,
        );
      }
    }

    if (card.isJoker) {
      if (currentTurn == PlayerTurn.human) {
        _setForcedDraw(
          target: PlayerTurn.bot,
          source: PlayerTurn.human,
          count: 9,
          announcement: 'Ordi pioche 9 cartes',
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
          announcement: '$_botName joue un joker.',
        );
        unawaited(_sfx.playJokerEffect());
        _showFunnyGameMessage(playerName: 'Vous', message: 'Le joker a parlé.');
        return const _PlayResolution(
          extraTurn: false,
          skipTurnSwitch: false,
        );
      }
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
          ? 'Vous demandez ${_suitName(askedSuit)}'
          : 'Ordi demande ${_suitName(askedSuit)}';

      setState(() {
        _activeSuitConstraint = askedSuit;
        _status = demander;
      });
      _showFunnyGameMessage(
        playerName: currentTurn == PlayerTurn.human ? _botName : 'Vous',
        message: 'Commande lancée.',
      );

      return const _PlayResolution(
        extraTurn: false,
        skipTurnSwitch: false,
      );
    }

    if (card.rank == 10 || card.rank == 11) {
      setState(() {
        _status = currentTurn == PlayerTurn.human ? 'Vous rejouez' : 'Tour de l’ordi';
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

    setState(() {
      _status = source == PlayerTurn.human ? 'À votre tour' : 'Tour de l’ordi';
      _forcedDrawTarget = null;
      _forcedDrawSource = null;
      _turn = source;
    });

    if (_turn == PlayerTurn.bot && !_gameOver) {
      unawaited(_ensureBotTurnProgress());
    }
  }

  Future<void> _runForcedDrawForBot() async {
    _playHeavyDrawSfxOnce();
    while (_forcedDrawCount > 0 &&
        _forcedDrawTarget == PlayerTurn.bot &&
        !_gameOver) {
      final PlayingCard? card = _drawOneCard();

      if (card == null) {
        setState(() {
          _status = 'Pioche vide';
          _forcedDrawCount = 0;
        });
        break;
      }

      setState(() {
        _botHand.add(card);
        _forcedDrawCount--;
        final String unit = _forcedDrawCount > 1 ? 'cartes' : 'carte';
        _status = _forcedDrawCount > 0
            ? 'Ordi pioche encore $_forcedDrawCount $unit'
            : 'Ordi a fini de piocher';
      });
      _playDrawnCardSfx(card);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    _finishForcedDrawIfNeeded();
  }

  Future<Suit> _getAskedSuit(PlayerTurn player) async {
    if (player == PlayerTurn.human) {
      return _showSuitChooserDialog();
    }

    final Suit bestSuit = _chooseRequestedSuitForBot(_botHand);
    await _showBotCommandPopup(bestSuit);
    return bestSuit;
  }

  Future<void> _showBotCommandPopup(Suit suit) async {
    if (!mounted) {
      return;
    }
    bool commandPopupClosed = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (BuildContext dialogContext) {
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 1700), () {
            if (!commandPopupClosed && Navigator.of(dialogContext).canPop()) {
              commandPopupClosed = true;
              Navigator.of(dialogContext).pop();
            }
          }),
        );
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: GinoOpponentCommandPopup(
            playerName: _botName,
            suit: _suitSymbol(suit),
            onClose: () {
              if (!commandPopupClosed && Navigator.of(dialogContext).canPop()) {
                commandPopupClosed = true;
                Navigator.of(dialogContext).pop();
              }
            },
          ),
        );
      },
    );
  }

  Future<Suit> _showSuitChooserDialog() async {
    final String? selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: GinoChooseSuitPopup(
            onSuitSelected: (String suit) => Navigator.of(context).pop(suit),
          ),
        );
      },
    );

    final Suit chosenSuit = switch (selected) {
      '♥' => Suit.hearts,
      '♣' => Suit.clubs,
      '♦' => Suit.diamonds,
      _ => Suit.spades,
    };

    return chosenSuit;
  }

  Suit _chooseRequestedSuitForBot(List<PlayingCard> hand) {
    final Map<Suit, int> counts = <Suit, int>{for (final Suit suit in Suit.values) suit: 0};
    for (final PlayingCard card in hand) {
      if (!card.isJoker && card.suit != null) {
        counts[card.suit!] = (counts[card.suit!] ?? 0) + 1;
      }
    }
    final List<Suit> available = counts.entries.where((MapEntry<Suit, int> e) => e.value > 0).map((e) => e.key).toList();
    if (available.isEmpty) {
      return Suit.hearts;
    }
    int scoreForSuit(Suit suit) {
      final int baseCount = counts[suit] ?? 0;
      int playableNow = 0;
      for (final PlayingCard card in hand) {
        if (card.isJoker) continue;
        if (card.suit == suit || card.rank == _topDiscard.rank || card.rank == 8) {
          playableNow++;
        }
      }
      return (baseCount * 100) + playableNow;
    }
    available.sort((Suit a, Suit b) => scoreForSuit(b).compareTo(scoreForSuit(a)));
    return available.first;
  }

  void _endHumanTurn() {
    if (_gameOver) {
      return;
    }

    setState(() {
      _humanDidVoluntaryDrawThisTurn = false;
      _turn = PlayerTurn.bot;
      _status = 'Tour de l’ordi';
    });

    unawaited(_ensureBotTurnProgress());
  }


  Future<void> _scheduleBotTurn() async {
    if (_isBotTurnRunning ||
        _gameOver ||
        _turn != PlayerTurn.bot ||
        _isInitialDealRunning ||
        _isResolvingTurn) {
      return;
    }

    await _runBotTurn();
  }

  Future<void> _ensureBotTurnProgress() async {
    if (!mounted || _gameOver) {
      return;
    }

    if (_turn != PlayerTurn.bot) {
      return;
    }

    if (_isInitialDealRunning || _isResolvingTurn) {
      return;
    }

    final int before = _botTurnStateFingerprint();
    await _scheduleBotTurn();

    if (!mounted || _gameOver || _turn != PlayerTurn.bot || _isBotTurnRunning) {
      return;
    }

    final int after = _botTurnStateFingerprint();
    if (before == after) {
      debugPrint('[SoloBot] warning: no state progress detected');
      final List<PlayingCard> fallbackDraw = _drawCards(_botHand, 1);
      if (fallbackDraw.isNotEmpty) {
        _playDrawnCardSfx(fallbackDraw.first);
        setState(() {
          _status = 'Ordi pioche (sécurité)';
        });
      }
      _switchToHuman();
    }
  }

  int _botTurnStateFingerprint() {
    final PlayingCard? topCard = _discardPile.isEmpty ? null : _topDiscard;
    return Object.hashAll(<Object?>[
      _turn,
      _status,
      _botHand.length,
      _humanHand.length,
      _drawPile.length,
      _discardPile.length,
      topCard?.displayLabel,
      topCard?.suit?.name,
      topCard?.jokerKind?.name,
      _forcedDrawCount,
      _forcedDrawTarget,
      _forcedDrawSource,
      _botMustAnswerAce,
      _activeSuitConstraint,
    ]);
  }

  Future<void> _runBotTurn({bool chained = false}) async {
    if (!chained) {
      if (_isBotTurnRunning) {
        return;
      }
      _isBotTurnRunning = true;
    }

    try {
      await Future<void>.delayed(
        Duration(milliseconds: 900 + _random.nextInt(1200)),
      );

      if (!mounted || _gameOver || _turn != PlayerTurn.bot || _isInitialDealRunning) {
        return;
      }

      debugPrint('[SoloBot] turn start');
      debugPrint('[SoloBot] pending draw count=$_forcedDrawCount');

      if (_forcedDrawCount > 0 && _forcedDrawTarget == PlayerTurn.bot) {
        await _runForcedDrawForBot();
        debugPrint('[SoloBot] action completed');
        return;
      }

      if (_botMustAnswerAce) {
        final List<PlayingCard> aceResponses =
            _botHand.where(_isValidAceResponse).toList();
        debugPrint('[SoloBot] playable cards=${aceResponses.length}');

        final bool chooseToDraw = aceResponses.isEmpty;

        if (chooseToDraw) {
          debugPrint('[SoloBot] no playable card, drawing');
          final int drawn = _drawCards(_botHand, 1).length;
          if (drawn > 0) {
            _playDrawnCardSfx(_botHand.last);
          }
          setState(() {
            _botMustAnswerAce = false;
            _status = drawn > 0
                ? 'Ordi pioche'
                : 'Pioche vide';
          });
          _switchToHuman();
          debugPrint('[SoloBot] action completed');
          return;
        }

        final PlayingCard botAce = aceResponses.first;
        debugPrint('[SoloBot] plays card=$botAce');
        unawaited(_sfx.playCard());
        await _playCard(
          hand: _botHand,
          card: botAce,
          playerName: _botName,
        );
        _playBotOneCardLeftSfxIfNeeded();

        final bool wasAceResponse = _botMustAnswerAce;
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
          wasAceResponse: wasAceResponse,
        );

        if (outcome.extraTurn) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await _runBotTurn(chained: true);
          return;
        }

        if (outcome.skipTurnSwitch) {
          debugPrint('[SoloBot] action completed');
          return;
        }

        _switchToHuman();
        debugPrint('[SoloBot] action completed');
        return;
      }

      final List<PlayingCard> playable = _botHand.where((PlayingCard card) {
        return _isCardPlayableForHand(card, _botHand);
      }).toList();
      debugPrint('[SoloBot] playable cards=${playable.length}');

      PlayingCard? chosen;

      if (playable.isNotEmpty) {
        chosen = _chooseBestBotCard(playable);
      }

      if (chosen == null) {
        debugPrint('[SoloBot] no playable card, drawing');
        final List<PlayingCard> drawn = _drawCards(_botHand, 1);
        if (drawn.isEmpty) {
          setState(() {
            _status = 'Pioche vide';
          });
          _switchToHuman();
          debugPrint('[SoloBot] action completed');
          return;
        }

        setState(() {
          _status = 'Ordi pioche';
        });
        final PlayingCard drawnCard = drawn.first;
        _playDrawnCardSfx(drawnCard);
        if (_isCardPlayableForHand(drawnCard, _botHand)) {
          chosen = drawnCard;
        } else {
          _switchToHuman();
          debugPrint('[SoloBot] action completed');
          return;
        }
      }

      debugPrint('[SoloBot] plays card=$chosen');
      unawaited(_sfx.playCard());
      await _playCard(
        hand: _botHand,
        card: chosen,
        playerName: _botName,
      );
      _playBotOneCardLeftSfxIfNeeded();

      final _PlayResolution outcome = await _applyCardEffects(
        card: chosen,
        currentTurn: PlayerTurn.bot,
      );

      if (_checkVictory(
        winner: PlayerTurn.bot,
        hand: _botHand,
        lastPlayed: chosen,
      )) {
        return;
      }

      if (outcome.extraTurn) {
        await Future<void>.delayed(
          Duration(milliseconds: 500 + _random.nextInt(700)),
        );
        await _runBotTurn(chained: true);
        return;
      }

      if (outcome.skipTurnSwitch) {
        debugPrint('[SoloBot] action completed');
        return;
      }

      _switchToHuman();
      debugPrint('[SoloBot] action completed');
    } finally {
      if (!chained) {
        _isBotTurnRunning = false;
        unawaited(_ensureBotTurnProgress());
      }
    }
  }

  SpecialFinishBonus? _specialFinishBonusFor(PlayingCard card) {
    if (card.isJoker) {
      return const SpecialFinishBonus(cardName: 'Joker', amount: 300);
    }
    switch (card.rank) {
      case 1:
        return const SpecialFinishBonus(cardName: 'As', amount: 150);
      case 2:
        return const SpecialFinishBonus(cardName: '2', amount: 200);
      case 8:
        return const SpecialFinishBonus(cardName: '8', amount: 100);
    }
    return null;
  }

  int _computeRoundCreditDelta({
    required PlayerTurn winner,
    required PlayingCard lastPlayed,
  }) {
    final int baseDelta = winner == PlayerTurn.human ? 100 : -100;
    if (!widget.launchOptions.specialBonusesEnabled) {
      return baseDelta;
    }
    final SpecialFinishBonus? bonus = _specialFinishBonusFor(lastPlayed);
    if (bonus == null) {
      return baseDelta;
    }
    return winner == PlayerTurn.human
        ? baseDelta + bonus.amount
        : baseDelta - bonus.amount;
  }

  Future<void> _applyRoundCredits(int delta) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .update(<String, dynamic>{
        'credits': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Solo] credit update failed: $e');
    }
  }

  PlayingCard _chooseBestBotCard(List<PlayingCard> playable) {
    int score(PlayingCard card) {
      int value = 0;
      final int handSize = _botHand.length;
      if (handSize <= 2 && card.canFinishGame) value += 2000;
      if (card.isJoker) value += handSize <= 3 ? 900 : 250;
      if (card.rank == 2) value += handSize <= 3 ? 700 : 180;
      if (card.rank == 1) value += handSize <= 3 ? 550 : 140;
      if (card.rank == 11) value += 110;
      if (card.rank == 8) value += handSize <= 3 ? 300 : -120;
      if (!card.isJoker && card.suit != null) {
        final int sameSuit = _botHand.where((PlayingCard c) => !c.isJoker && c.suit == card.suit).length;
        value += sameSuit * 35;
      }
      if (card.rank == _topDiscard.rank) value += 55;
      return value;
    }
    playable.sort((PlayingCard a, PlayingCard b) => score(b).compareTo(score(a)));
    return playable.first;
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

    final int creditDelta = _computeRoundCreditDelta(
      winner: winner,
      lastPlayed: lastPlayed,
    );
    unawaited(_applyRoundCredits(creditDelta));

    setState(() {
      if (winner == PlayerTurn.human) {
        _humanScore++;
        unawaited(_sfx.playWin());
      } else {
        _botScore++;
        unawaited(_sfx.playLose());
      }
      _gameOver = true;
      _lastRoundCreditDelta = creditDelta;
      _status = '${_turnLabel(winner)} a gagné !';
    });
    unawaited(_showRoundResultPopup(winner: winner, creditDelta: creditDelta, lastPlayed: lastPlayed));

    _showFunnyGameMessage(
      playerName: _turnLabel(winner),
      message: 'Propre, net, sans bavure.',
    );

    return true;
  }

  void _showFunnyGameMessage({
    required String playerName,
    required String message,
  }) {
    if (!_funnyMessagesEnabled || !mounted || _isInitialDealRunning) {
      return;
    }
    final DateTime now = DateTime.now();
    if (_isImportantPopupOpen) {
      return;
    }
    if (_lastFunnyMessageAt != null &&
        now.difference(_lastFunnyMessageAt!) < const Duration(seconds: 8)) {
      return;
    }
    _lastFunnyMessageAt = now;
    FunnyGameToast.show(
      context,
      playerName: playerName,
      message: message,
      alignment: Alignment.topCenter,
    );
  }

  Future<void> _showRoundResultPopup({
    required PlayerTurn winner,
    required int creditDelta,
    required PlayingCard lastPlayed,
  }) async {
    if (!mounted) {
      return;
    }
    _isImportantPopupOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final bool humanWon = winner == PlayerTurn.human;
        final bool isConnected = AuthService.instance.currentUser != null;
        final String creditLabel = creditDelta >= 0
            ? '+$creditDelta crédits'
            : '$creditDelta crédits';
        final Color creditColor =
            creditDelta >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

        final SpecialFinishBonus? specialBonus = _specialFinishBonusFor(lastPlayed);
        final bool bonusesEnabled = widget.launchOptions.specialBonusesEnabled;
        final SpecialFinishBonus? appliedBonus = bonusesEnabled ? specialBonus : null;
        final bool isSpecialCard = appliedBonus != null;
        final String bonusReason = appliedBonus != null
            ? '${humanWon ? 'Victoire' : 'Défaite'} · base ${humanWon ? '+100' : '−100'}\n${appliedBonus.winnerLine} / ${appliedBonus.loserLine}'
            : (humanWon ? 'Victoire · +100 crédits' : 'Défaite · −100 crédits');

        if (appliedBonus != null) {
          final String cardName = appliedBonus.cardName;
          final String specialMessage = humanWon
              ? 'Vous avez terminé avec un $cardName'
              : 'Votre adversaire a terminé avec un $cardName';
          final String label = lastPlayed.isJoker ? 'JOKER' : cardName;
          final String suit = lastPlayed.isJoker ? '🃏' : _suitSymbol(lastPlayed.suit!);
          return Dialog(
            backgroundColor: Colors.transparent,
            child: GinoSpecialFinishBonusPopup(
              title: humanWon ? 'Fin de manche' : 'Défaite',
              message: specialMessage,
              cardLabel: label,
              cardSuitSymbol: suit,
              deltaLabel: creditLabel,
              detailLines: <String>[
                'Carte spéciale : $cardName',
                'Bonus gagnant : +${appliedBonus.amount}',
                'Malus adversaire : −${appliedBonus.amount}',
                'Impact total : $creditLabel',
              ],
              isPositive: creditDelta >= 0,
              onContinue: () => _closeRoundPopupAndExit(context),
              secondaryActionLabel: 'Rematch',
              onSecondaryAction: () => _closeRoundPopupAndStartRematch(context),
            ),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          child: GinoPopupFrame(
            titleTag: humanWon ? 'Vous avez gagné' : 'Vous avez perdu',
            isPremium: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Manche n°$_roundNumber',
                  textAlign: TextAlign.center,
                  style: GinoPopupStyle.baseText(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  humanWon
                      ? 'Belle manche, ${_humanDisplayName.isEmpty ? 'joueur' : _humanDisplayName}.'
                      : '$_botName remporte cette manche.',
                  textAlign: TextAlign.center,
                  style: GinoPopupStyle.baseText(fontSize: 16),
                ),
                if (isConnected) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: creditColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: creditColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // Card visual — shown only for special cards
                        if (isSpecialCard) ...<Widget>[
                          Transform.rotate(
                            angle: -0.08,
                            child: SizedBox(
                              width: 52,
                              height: 74,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: CardView(card: lastPlayed),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        // Amount + reason
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isSpecialCard
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    creditDelta >= 0
                                        ? Icons.monetization_on_rounded
                                        : Icons.money_off_rounded,
                                    color: creditColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    creditLabel,
                                    style: TextStyle(
                                      color: creditColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                bonusReason,
                                style: TextStyle(
                                  color: creditColor.withOpacity(0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: GinoPopupButton(
                        label: 'Quitter',
                        isPrimary: false,
                        isPremium: true,
                        onPressed: () => _closeRoundPopupAndExit(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GinoPopupButton(
                        label: 'Rematch',
                        isPremium: true,
                        onPressed: () => _closeRoundPopupAndStartRematch(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    _isImportantPopupOpen = false;
  }

  void _closeRoundPopupAndExit(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    if (mounted) {
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    }
  }

  void _closeRoundPopupAndStartRematch(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    if (mounted) {
      _startNewGame();
    }
  }

  void _switchToHuman() {
    setState(() {
      _humanDidVoluntaryDrawThisTurn = false;
      _turn = PlayerTurn.human;
      if (!_gameOver) {
        _status = _isHumanForcedToDrawNow() ? _forcedDrawRemainingText() : 'À votre tour';
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
        _isInitialDealRunning ||
        _humanDidVoluntaryDrawThisTurn) {
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

    // Highlight draw pile only when no card is playable (not after drawing, turn auto-passes)
    return !_humanHasPlayableCard() && !_humanDidVoluntaryDrawThisTurn;
  }

  void _refreshHandEntryAnimations() {
    final List<int> currentHumanRefs = _humanHand.map<int>(identityHashCode).toList();
    final Set<int> previousHumanRefs = _previousHumanCardRefs.toSet();
    _newHumanCardRefs = currentHumanRefs.where((int ref) => !previousHumanRefs.contains(ref)).toSet();
    _previousHumanCardRefs = currentHumanRefs;

    final List<int> currentBotRefs = _botHand.map<int>(identityHashCode).toList();
    final Set<int> previousBotRefs = _previousBotCardRefs.toSet();
    _newBotCardRefs = currentBotRefs.where((int ref) => !previousBotRefs.contains(ref)).toSet();
    _previousBotCardRefs = currentBotRefs;
  }

  @override
  Widget build(BuildContext context) {
    _refreshHandEntryAnimations();
    final bool canInteract = _turn == PlayerTurn.human &&
        !_gameOver &&
        !_isResolvingTurn &&
        !_isInitialDealRunning &&
        !_isHumanForcedToDrawNow();
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool compact = screenSize.height < 760;
    final double topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: GameModePalette.background,
      endDrawer: PlayerSidePanel(
        onOpenLeaderboard: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(GameModeRoutes.leaderboard);
        },
        onOpenHistory: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed(GameModeRoutes.history);
        },
      ),
      body: Stack(
        children: <Widget>[
          TableBackground(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 4, 12, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _topBar(),
                      const SizedBox(height: 6),
                      _statusBanner(),
                      const SizedBox(height: 6),
                      Expanded(
                        flex: compact ? 3 : 2,
                        child: Align(
                          alignment: Alignment.center,
                          child: _botHandArea(),
                        ),
                      ),
                      Expanded(
                        flex: compact ? 2 : 2,
                        child: Align(
                          alignment: Alignment.center,
                          child: _centerArea(),
                        ),
                      ),
                      Expanded(
                        flex: compact ? 5 : 6,
                        child: _playerPanel(canInteract: canInteract),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: GlobalMusicToggleButton(),
            ),
          ),
          if (_isHumanForcedToDrawNow())
            Positioned(
              top: topInset + 118,
              left: 22,
              right: 22,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: PremiumGameDecorations.glassPanel(
                      radius: 12,
                      golden: true,
                      opacity: 0.58,
                    ),
                    child: Text(
                      _forcedDrawCount > 1
                          ? 'Vous piochez • encore $_forcedDrawCount cartes'
                          : 'Vous piochez • encore 1 carte',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double sideWidth = min(
          constraints.maxWidth * 0.38,
          176.0,
        );

        return SizedBox(
          height: 112,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const Positioned(
                left: 0,
                top: 40,
                child: AppLogo(size: 52),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: PremiumIconButtonShell(
                  child: IconButton(
                    onPressed: () {
                      unawaited(_sfx.playClick());
                      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
                    },
                    tooltip: 'Retour aux modes',
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 0,
                child: SizedBox(
                  width: sideWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PremiumIconButtonShell(
                          golden: true,
                          child: IconButton(
                            onPressed: () {
                              unawaited(_sfx.playClick());
                              _startNewGame();
                            },
                            tooltip: 'Nouvelle manche',
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const PlayerSidePanelButton(
                          padding: EdgeInsets.zero,
                          wrapInAlign: false,
                          showCredits: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 64,
                right: 64,
                bottom: 0,
                child: Center(child: _scoreBar()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _playerHeader({
    required bool isHuman,
    required String name,
    required int count,
    required int wins,
    required int losses,
    required GameCardAvatarData avatar,
    bool showCountBadge = true,
  }) {
    return Row(
      children: <Widget>[
        GameCardAvatar(data: avatar, size: 34),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name.isEmpty ? (isHuman ? 'Vous' : _botName) : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
              ),
              Text(
                'V $wins   D $losses',
                style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w400, fontSize: 10.5),
              ),
            ],
          ),
        ),
        if (showCountBadge) _CountBadge(count: count),
      ],
    );
  }

  Widget _playerPanel({required bool canInteract}) {
    return PremiumGamePanel(
      padding: const EdgeInsets.all(12),
      radius: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _playerHeader(
                isHuman: true,
                name: _humanDisplayName,
                count: _humanHand.length,
                wins: _humanWins,
                losses: _humanLosses,
                avatar: _humanAvatar,
                showCountBadge: false,
              ),
              const PremiumDividerLine(verticalPadding: 8),
              Expanded(child: _playerHandArea(canInteract: canInteract)),
            ],
          ),
          Positioned(
            top: -6,
            right: -6,
            child: _CountBadge(count: _humanHand.length),
          ),
        ],
      ),
    );
  }

  Widget _playerHandArea({required bool canInteract}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxRowWidth =
            (_handCardWidth * _maxCardsPerRow) + (6 * (_maxCardsPerRow - 1));
        final double wrapWidth = min(maxRowWidth, constraints.maxWidth - 4);
        return SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: wrapWidth,
              child: Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: List<Widget>.generate(_humanHand.length, (int index) {
                  final PlayingCard card = _humanHand[index];
                  final int cardRef = identityHashCode(card);
                  final bool isNew = _newHumanCardRefs.contains(cardRef);
                  final ({bool canPlay, String? rejectionMessage}) playability =
                      _evaluateHumanCardPlayability(card);
                  return BouncyCardEntry(
                    key: ValueKey<int>(cardRef),
                    animate: isNew,
                    delay: Duration(milliseconds: isNew ? index * 36 : 0),
                    child: CardView(
                      card: card,
                      enabled: canInteract && playability.canPlay,
                      opacity: canInteract && !playability.canPlay ? 0.45 : 1,
                      onTap: canInteract ? () => _onHumanTapCard(card) : null,
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _botHandArea() {
    return PremiumGamePanel(
      padding: const EdgeInsets.all(12),
      radius: 20,
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Column(
              children: <Widget>[
                _playerHeader(
                  isHuman: false,
                  name: _botName,
                  count: _botHand.length,
                  wins: 0,
                  losses: 0,
                  avatar: _botAvatar,
                  showCountBadge: false,
                ),
                const PremiumDividerLine(verticalPadding: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(
                        _botHand.length,
                        (int index) {
                          final PlayingCard card = _botHand[index];
                          final int cardRef = identityHashCode(card);
                          final bool isNew = _newBotCardRefs.contains(cardRef);
                          return Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: BouncyCardEntry(
                              key: ValueKey<int>(cardRef),
                              animate: isNew,
                              delay: Duration(milliseconds: isNew ? index * 32 : 0),
                              child: const CardBackView(width: 28, height: 40),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: -6,
              right: -6,
              child: _CountBadge(count: _botHand.length),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerArea() {
    final bool shouldHighlightDraw = _shouldHighlightDrawPile();
    final bool canDraw = _canHumanDrawNow();
    final bool hasDiscard = _discardPile.isNotEmpty;

    return SizedBox(
      height: 168,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double drawPileWidth = 64;
          const double drawPileHeight = 92;
          const double horizontalMargin = 12;
          const double topMargin = 4;
          const double idealHorizontalOffset = 82;
          const double idealVerticalOffset = 30;
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
                    const SizedBox(height: 8),
                    if (hasDiscard)
                      Transform.scale(
                        scale: 1.0,
                        child: _DiscardPileView(
                          key: _discardPileKey,
                          cards: _discardPile,
                        ),
                      )
                    else
                      Transform.scale(
                        scale: 1.0,
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
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: canDraw ? _onHumanDraw : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          _drawPile.isNotEmpty
                              ? _DrawPileView(
                                  highlight: shouldHighlightDraw,
                                  count: _drawPile.length,
                                )
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
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _ScorePill(label: 'Vous', value: _humanScore),
            const SizedBox(width: 8),
            _ScorePill(label: _botName, value: _botScore),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Manche n°$_roundNumber',
          style: TextStyle(
            color: Colors.white.withOpacity(0.84),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: PremiumGameDecorations.glassPanel(
          radius: 16,
          golden: _activeSuitConstraint != null || _humanMustAnswerAce,
          opacity: 0.42,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (_activeSuitConstraint != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Couleur demandée : ${_suitName(_activeSuitConstraint!)} ${_suitSymbol(_activeSuitConstraint!)}',
                textAlign: TextAlign.center,
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
                textAlign: TextAlign.center,
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
        borderRadius: BorderRadius.circular(6),
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
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD50000),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          height: 1,
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
      decoration: PremiumGameDecorations.goldPill(),
      child: Text(
        '$label : $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DrawPileView extends StatefulWidget {
  const _DrawPileView({required this.highlight, required this.count});

  final bool highlight;
  final int count;

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
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          if (widget.count > 1)
            Transform.translate(
              offset: const Offset(-2, 1),
              child: Transform.rotate(
                angle: -0.02,
                child: Opacity(
                  opacity: 0.6,
                  child: const CardBackView(width: 64, height: 92),
                ),
              ),
            ),
          const CardBackView(width: 64, height: 92),
        ],
      ),
    );
  }
}

class _EmptyCardSlot extends StatelessWidget {
  const _EmptyCardSlot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 92,
      decoration: PremiumGameDecorations.glassPanel(radius: 12, opacity: 0.28),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w400,
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
    this.opacity = 1,
    this.onTap,
  });

  final PlayingCard card;
  final bool enabled;
  final double opacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = card.suitColor;
    final String rank = card.isJoker ? 'JK' : card.rankLabel;
    final Widget cardWidget = Container(
      width: _CrazyEightsPageState._handCardWidth,
      height: _CrazyEightsPageState._handCardHeight,
      decoration: PremiumCardEffects.bevelFace(
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ).copyWith(
        border: Border.all(color: PremiumColors.accent.withOpacity(0.28), width: 1),
        boxShadow: <BoxShadow>[
          ...PremiumCardEffects.bevelShadow,
          BoxShadow(
            color: PremiumColors.accent.withOpacity(0.08),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(7),
      child: card.isJoker
          ? Center(
              child: Text(
                'JOKER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(rank, style: TextStyle(color: ink, fontWeight: FontWeight.w500, fontSize: 16, height: 1)),
                Text(card.suitSymbol, style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w500, height: 1)),
                const Spacer(),
                Center(
                  child: Text(
                    card.suitSymbol,
                    style: TextStyle(color: ink, fontSize: 32, fontWeight: FontWeight.w500, height: 1),
                  ),
                ),
              ],
            ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: cardWidget,
      ),
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
    final int cardCount = cards.length;
    final List<PlayingCard> underCards = cardCount <= 1
        ? const <PlayingCard>[]
        : cardCount == 2
            ? <PlayingCard>[cards[cardCount - 2]]
            : <PlayingCard>[cards[cardCount - 3], cards[cardCount - 2]];

    return SizedBox(
      width: 86,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (int index = 0; index < underCards.length; index++)
            Transform.translate(
              offset: Offset(-2.0 + (index * 2), -1.0 + (index * 1)),
              child: Transform.rotate(
                angle: index == 0 ? -0.02 : 0.02,
                child: Opacity(
                  opacity: 0.65 - (index * 0.15),
                  child: CardView(card: underCards[index]),
                ),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<String>('${topCard.label}-$cardCount'),
              child: CardView(card: topCard),
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
                fontWeight: FontWeight.w500,
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
              fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
