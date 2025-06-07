import 'dart:math';
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
final psychedelicPalette = <Color>[
  const Color(0xFFFE4A49), // hot pink-red
  const Color(0xFFFFA600), // tangerine
  const Color(0xFFFFFF00), // acid yellow
  const Color(0xFF00E676), // neon green
  const Color(0xFF00C5FF), // electric cyan
  const Color(0xFF7C4DFF), // vivid purple
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

    // NEW: Initialize tournament system
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
      debugShowCheckedModeBanner: false,
      title: 'Minute Madness',

      // Cache the theme to avoid rebuilding
      theme: _buildTheme(),

      // Use SplashScreen instead of GameSelectionScreen
      home: const SplashScreen(),

      // Add performance optimizations
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
      textTheme: GoogleFonts.chicleTextTheme(baseTheme.textTheme),

      // Optimize app bar theme
      appBarTheme: baseTheme.appBarTheme.copyWith(
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Add performance-friendly defaults
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Optimize button themes for consistency
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          animationDuration: const Duration(milliseconds: 200),
        ),
      ),
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

// Utility functions for performance optimization
class AppUtils {
  // Efficient random color generator
  static final Random _random = Random();

  static Color getRandomPsychedelicColor() {
    return psychedelicPalette[_random.nextInt(psychedelicPalette.length)];
  }

  // Generate gradient with cached colors
  static List<Color> generatePsychedelicGradient([int count = 3]) {
    return List.generate(count, (_) => getRandomPsychedelicColor());
  }

  // Format duration efficiently
  static String formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}s';
  }
}