import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/game_selection_screen.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';
import 'repositories/tournament_repository.dart';

// ---------------- CONFIG ----------------
const backgroundSwapDuration = Duration(seconds: 4);

// FIXED: Remove problematic const declaration and use regular list
// Change this line in main.dart:
const psychedelicPalette = <Color>[
  Color(0xFFFE4A49), // Remove 'const' from individual colors
  Color(0xFFFFA600),
  Color(0xFFFFFF00),
  Color(0xFF00E676),
  Color(0xFF00C5FF),
  Color(0xFF7C4DFF),
];

// Group related constants
const gif3s = 'assets/anim/psychedelic_tunnel_3s.gif';
const targetDuration = Duration(seconds: 3);

// Support multiple target durations for flexibility
const targetDurations = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 3),
  Duration(seconds: 5),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for better performance
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Optimize system UI for better performance
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  try {
    // Initialize Firebase with error handling
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Anonymous sign-in with error handling
    await FirebaseAuth.instance.signInAnonymously();

    // Initialize tournament system
    print('🎮 Tournament system initialized!');
    TournamentService.instance; // This triggers initialization

    runApp(const MinuteMadnessApp());
  } catch (e) {
    // Handle initialization errors gracefully
    runApp(ErrorApp(error: e.toString()));
  }
}

class MinuteMadnessApp extends StatelessWidget {
  const MinuteMadnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ✅ ALREADY HAVE THIS - GREAT! This removes the debug banner
      debugShowCheckedModeBanner: false,
      title: 'Minute Madness',

      // Cache the theme to avoid rebuilding
      theme: _buildTheme(),

      // Use SplashScreen instead of GameSelectionScreen
      home: const SplashScreen(),

      // Add performance optimizations for Momentum Madness
      builder: (context, child) {
        return MediaQuery(
          // Disable animations for better performance on low-end devices
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), // FIXED: Updated deprecated textScaleFactor
          ),
          child: child!,
        );
      },
    );
  }

  // Extract theme building to avoid rebuilding
  static ThemeData _buildTheme() {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    return baseTheme.copyWith(
      // ENHANCED: Better font support for Momentum Madness
      textTheme: GoogleFonts.chicleTextTheme(baseTheme.textTheme),

      // Optimize app bar theme
      appBarTheme: baseTheme.appBarTheme.copyWith(
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Add performance-friendly defaults
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // ENHANCED: Optimize button themes for better Momentum Madness experience
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          animationDuration: const Duration(milliseconds: 200), // Faster animations
        ),
      ),

      // ENHANCED: Add better haptic feedback support
      splashFactory: InkRipple.splashFactory,
    );
  }
}

// Error fallback app for initialization failures
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'App Initialization Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  error,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ENHANCED: Utility functions for performance optimization and Momentum Madness
class AppUtils {
  // Efficient random color generator
  static final math.Random _random = math.Random();

  static Color getRandomPsychedelicColor() {
    return psychedelicPalette[_random.nextInt(psychedelicPalette.length)];
  }

  // Generate gradient with cached colors
  static List<Color> generatePsychedelicGradient([int count = 3]) {
    return List.generate(count, (_) => getRandomPsychedelicColor());
  }

  // ENHANCED: Generate momentum-specific gradients
  static List<Color> generateMomentumGradient(double momentumMultiplier) {
    final intensity = (momentumMultiplier / 5.0).clamp(0.0, 1.0);

    if (intensity > 0.8) {
      // Extreme momentum - intense reds and oranges
      return [
        Colors.red.shade900,
        Colors.orange.shade700,
        Colors.yellow.shade600,
        Colors.pink.shade700,
      ];
    } else if (intensity > 0.6) {
      // High momentum - vibrant colors
      return [
        Colors.orange.shade700,
        Colors.red.shade600,
        Colors.purple.shade700,
        Colors.cyan.shade600,
      ];
    } else if (intensity > 0.4) {
      // Medium momentum - balanced colors
      return [
        Colors.blue.shade700,
        Colors.purple.shade600,
        Colors.cyan.shade600,
        Colors.indigo.shade700,
      ];
    } else {
      // Low momentum - cooler colors
      return [
        Colors.blue.shade800,
        Colors.indigo.shade700,
        Colors.purple.shade800,
        Colors.cyan.shade700,
      ];
    }
  }

  // Format duration efficiently
  static String formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}s';
  }

  // ENHANCED: Momentum-specific formatting
  static String formatMomentum(double momentum) {
    return '${momentum.toStringAsFixed(1)}x';
  }

  // ENHANCED: Score formatting for Momentum Madness
  static String formatScore(int score) {
    if (score >= 1000000) {
      return '${(score / 1000000).toStringAsFixed(1)}M';
    } else if (score >= 1000) {
      return '${(score / 1000).toStringAsFixed(1)}K';
    } else {
      return score.toString();
    }
  }

  // ENHANCED: Tournament round naming
  static String getTournamentRoundName(int round, int totalPlayers) {
    switch (round) {
      case 1:
        return totalPlayers >= 128 ? 'Round of 128' : 'Round of $totalPlayers';
      case 2:
        return 'Round of 64';
      case 3:
        return 'Round of 32';
      case 4:
        return 'Round of 16';
      case 5:
        return 'Quarterfinals';
      case 6:
        return 'Semifinals';
      case 7:
        return 'Finals';
      default:
        return 'Round $round';
    }
  }

  // ENHANCED: Haptic feedback helper for Momentum Madness
  static void provideMomentumHaptic(double momentum, int score) {
    if (score >= 950 && momentum > 3.0) {
      // Perfect shot at high momentum - strongest feedback
      HapticFeedback.heavyImpact();
    } else if (score >= 800) {
      // Good shot - medium feedback
      HapticFeedback.mediumImpact();
    } else if (score >= 600) {
      // OK shot - light feedback
      HapticFeedback.lightImpact();
    } else {
      // Poor shot - selection click
      HapticFeedback.selectionClick();
    }
  }

  // ENHANCED: Performance monitoring for animations
  static bool shouldUseReducedAnimations() {
    // You could check device performance or user preferences here
    return false; // For now, always use full animations
  }

  // ENHANCED: Calculate optimal animation duration based on momentum
  static Duration getAnimationDuration(double momentum, Duration baseDuration) {
    final speedMultiplier = 1.0 + (momentum - 1.0) * 0.5;
    final adjustedDuration = Duration(
      milliseconds: (baseDuration.inMilliseconds / speedMultiplier).round(),
    );

    // Ensure minimum duration for visibility
    return Duration(
      milliseconds: math.max(adjustedDuration.inMilliseconds, 100),
    );
  }
}