// lib/screens/precision_tap_screen.dart - HIDDEN TIMER WITH TIMEOUT HANDLING
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show gif3s, targetDurations;
import 'tournament_results_screen.dart';
import '../services/bot_service.dart';

class PrecisionTapScreen extends StatefulWidget {
  final Duration target;
  final String tourneyId;
  final int round;

  const PrecisionTapScreen({
    super.key,
    required this.target,
    required this.tourneyId,
    required this.round,
  });

  @override
  State<PrecisionTapScreen> createState() => _PrecisionTapScreenState();
}

class _PrecisionTapScreenState extends State<PrecisionTapScreen>
    with TickerProviderStateMixin {
  DateTime? _startTime;
  Duration? _elapsed;
  Duration? _error;
  bool _isRunning = false;
  bool _showButton = true;
  bool _hasSubmitted = false;
  bool _timedOut = false; // NEW: Track if user timed out

  Timer? _countdownTimer;
  int _remainingSeconds = 10; // HIDDEN - user doesn't see this anymore

  // PSYCHEDELIC ANIMATION CONTROLLERS
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _buttonController;
  late AnimationController _explosionController;
  late AnimationController _perfectController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  // Practice mode detection
  bool get _isPracticeMode => widget.tourneyId == 'practice_mode';

  // Cache the StreamBuilder reference
  late final Stream<QuerySnapshot> _resultsStream;

  // Cache formatted strings
  String? _cachedResultText;
  String? _cachedTargetText;

  // Perfect hit detection
  bool _isPerfectHit = false;
  bool _showPerfectEffect = false;

  @override
  void initState() {
    super.initState();

    // Initialize INTENSE psychedelic controllers
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // SUPER FAST for intensity
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _perfectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Initialize cached target text once
    _cachedTargetText = 'Aim for ${widget.target.inSeconds == 0 ? widget.target.inMilliseconds : widget.target.inSeconds}s';

    // Initialize stream once
    _resultsStream = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tourneyId)
        .collection('rounds')
        .doc('round_${widget.round}')
        .collection('results')
        .snapshots();

    // Only start countdown for tournament mode
    if (!_isPracticeMode) {
      _startHiddenCountdown(); // RENAMED: Hidden countdown
      _submitBotResultsForRound();
    }
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    // SUPER VIBRANT colors for gameplay intensity
    final ultraVibrantColors = [
      Colors.red.shade900,
      Colors.orange.shade800,
      Colors.yellow.shade600,
      Colors.green.shade700,
      Colors.blue.shade800,
      Colors.indigo.shade700,
      Colors.purple.shade800,
      Colors.pink.shade700,
      Colors.cyan.shade600,
      Colors.lime.shade700,
      Colors.deepOrange.shade800,
      Colors.deepPurple.shade800,
      Colors.teal.shade700,
      Colors.amber.shade700,
    ];

    return List.generate(
        8, (_) => ultraVibrantColors[random.nextInt(ultraVibrantColors.length)]); // EVEN MORE colors
  }

  Future<void> _submitBotResultsForRound() async {
    try {
      final tourneyDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tourneyId)
          .get();

      if (!tourneyDoc.exists) return;

      final data = tourneyDoc.data();
      if (data == null || !data.containsKey('bots')) return;

      final botsData = data['bots'] as Map<String, dynamic>?;
      if (botsData == null || botsData.isEmpty) return;

      final allBots = <BotPlayer>[];

      for (final entry in botsData.entries) {
        try {
          final botData = entry.value as Map<String, dynamic>?;
          if (botData == null) continue;

          final name = botData['name'] as String?;
          final difficultyName = botData['difficulty'] as String?;

          if (name == null || difficultyName == null) continue;

          final difficulty = BotDifficulty.values.where(
                (d) => d.name == difficultyName,
          ).firstOrNull;

          if (difficulty == null) continue;

          allBots.add(BotPlayer(
            id: entry.key,
            name: name,
            difficulty: difficulty,
          ));
        } catch (e) {
          continue;
        }
      }

      if (allBots.isNotEmpty) {
        BotService.submitBotResults(widget.tourneyId, widget.round, allBots, widget.target);
      }
    } catch (e) {
      print('Error submitting bot results: $e');
    }
  }

  // RENAMED: Hidden countdown - user doesn't see the timer
  void _startHiddenCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _remainingSeconds--;

      // NO setState here - user doesn't see the countdown!

      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (!_hasSubmitted && !_timedOut) {
          _handleTimeout(); // NEW: Handle timeout properly
        }
      }
    });
  }

  // NEW: Handle timeout scenario
  void _handleTimeout() {
    if (_hasSubmitted || _timedOut) return;

    setState(() {
      _timedOut = true;
      _isRunning = false;
      _showButton = false;
      _cachedResultText = "⏰ TIME RAN OUT!\nLast place this round";
    });

    // Trigger timeout explosion effect
    _explosionController.forward();

    // Submit worst possible score (maximum error)
    _submitAndExit(const Duration(milliseconds: 99999));
  }

  Future<void> _submitResult(Duration error, String tourneyId, int round) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final errorMs = error.inMilliseconds;

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tourneyId)
          .collection('rounds')
          .doc('round_$round')
          .collection('results')
          .doc(uid)
          .set({
        'uid': uid,
        'errorMs': errorMs,
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error submitting result: $e');
    }
  }

  void _submitAndExit(Duration error) async {
    if (_hasSubmitted) return;
    _hasSubmitted = true;

    // Only submit to Firebase in tournament mode
    if (!_isPracticeMode) {
      await _submitResult(error, widget.tourneyId, widget.round);

      await Future.delayed(const Duration(seconds: 2));
      if (mounted && (_elapsed != null || _timedOut)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentResultsScreen(
              tourneyId: widget.tourneyId,
              round: widget.round,
              playerTime: _elapsed ?? Duration.zero,
              playerError: error,
            ),
          ),
        );
      }
    } else {
      // In practice mode, reset for another attempt
      await Future.delayed(const Duration(seconds: 3)); // Longer to see effects
      if (mounted) {
        setState(() {
          _hasSubmitted = false;
          _showButton = true;
          _cachedResultText = null;
          _isPerfectHit = false;
          _showPerfectEffect = false;
          _timedOut = false; // Reset timeout state
        });

        // Reset animations
        _explosionController.reset();
        _perfectController.reset();
      }
    }
  }

  void _handleTap() {
    // PREVENT any action if timed out
    if (_timedOut) return;

    if (!_isRunning) {
      // START BUTTON PRESSED - PSYCHEDELIC EXPLOSION!
      setState(() {
        _startTime = DateTime.now();
        _elapsed = null;
        _error = null;
        _isRunning = true;
        _cachedResultText = null;
        _isPerfectHit = false;
        _showPerfectEffect = false;
      });

      // Button press animation
      _buttonController.forward().then((_) => _buttonController.reverse());

    } else {
      // STOP BUTTON PRESSED
      if (_startTime == null) return;

      final stop = DateTime.now();
      final elapsed = stop.difference(_startTime!);
      final error = elapsed - widget.target;

      // Check for PERFECT hit (within 50ms)
      final errorMs = error.inMilliseconds.abs();
      _isPerfectHit = errorMs <= 50;

      _cachedResultText = _formatResult(elapsed, error);

      setState(() {
        _elapsed = elapsed;
        _error = error;
        _isRunning = false;
        _showButton = false;
        _showPerfectEffect = _isPerfectHit;
      });

      // TRIGGER PSYCHEDELIC EFFECTS!
      _explosionController.forward();

      if (_isPerfectHit) {
        _perfectController.forward();
      }

      _submitAndExit(error);
    }
  }

  String _formatResult(Duration elapsed, Duration error) {
    final sec = elapsed.inSeconds;
    final ms = elapsed.inMilliseconds % 1000;
    final total = '${sec.toString().padLeft(2, '0')} sec ${ms.toString().padLeft(3, '0')} ms';
    final errMs = error.inMilliseconds;
    final offset = errMs >= 0 ? '+${errMs} ms' : '${errMs} ms';
    return '$total\n$offset';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _backgroundController.dispose();
    _pulsController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    _buttonController.dispose();
    _explosionController.dispose();
    _perfectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          final t = _backgroundController.value;
          final interpolatedColors = <Color>[];

          for (int i = 0; i < _currentColors.length; i++) {
            interpolatedColors.add(
                Color.lerp(_currentColors[i], _nextColors[i], t) ?? _currentColors[i]
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // PSYCHEDELIC BACKGROUND - INTENSE!
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: _isRunning ? 2.0 : 1.0, // Expands when running!
                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.85, 1.0],
                  ),
                ),
              ),

              // ROTATING OVERLAY 1
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.4),
                          Colors.transparent,
                          interpolatedColors[5].withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_rotationController.value * 6.28),
                      ),
                    ),
                  );
                },
              ),

              // PULSING OVERLAY
              AnimatedBuilder(
                animation: _pulsController,
                builder: (context, child) {
                  final intensity = _isRunning ? 0.6 : 0.3; // More intense when running
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          interpolatedColors[1].withOpacity(intensity * _pulsController.value),
                          Colors.transparent,
                          interpolatedColors[4].withOpacity(intensity * (1 - _pulsController.value)),
                        ],
                        center: Alignment.center,
                        radius: 1.5,
                      ),
                    ),
                  );
                },
              ),

              // PERFECT HIT EXPLOSION EFFECT!
              if (_showPerfectEffect)
                AnimatedBuilder(
                  animation: _perfectController,
                  builder: (context, child) {
                    final explosion = _perfectController.value;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.8 * (1 - explosion)),
                            Colors.yellow.withOpacity(0.6 * (1 - explosion)),
                            Colors.orange.withOpacity(0.4 * (1 - explosion)),
                            Colors.transparent,
                          ],
                          center: Alignment.center,
                          radius: explosion * 3.0, // Expanding explosion
                        ),
                      ),
                    );
                  },
                ),

              // TIMEOUT EXPLOSION EFFECT (red/orange for timeout)
              if (_timedOut)
                AnimatedBuilder(
                  animation: _explosionController,
                  builder: (context, child) {
                    final explosion = _explosionController.value;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.red.withOpacity(0.9 * (1 - explosion)),
                            Colors.orange.withOpacity(0.7 * (1 - explosion)),
                            Colors.yellow.withOpacity(0.5 * (1 - explosion)),
                            Colors.transparent,
                          ],
                          center: Alignment.center,
                          radius: explosion * 3.5, // Bigger explosion for timeout
                        ),
                      ),
                    );
                  },
                ),

              // MAIN CONTENT
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // REMOVED: Tournament countdown timer - now hidden!
                    // NO MORE visible countdown timer for user

                    // PERFECT HIT TEXT EFFECT!
                    if (_showPerfectEffect)
                      AnimatedBuilder(
                        animation: _perfectController,
                        builder: (context, child) {
                          final bounce = math.sin(_perfectController.value * math.pi * 4) * 0.3;
                          final scale = 1.0 + bounce;
                          final opacity = 1.0 - _perfectController.value;

                          return Transform.scale(
                            scale: scale,
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.yellow,
                                  Colors.orange,
                                  Colors.red,
                                  Colors.pink,
                                  Colors.purple,
                                  Colors.cyan,
                                ],
                              ).createShader(bounds),
                              child: Text(
                                '🎯 PERFECT! 🎯',
                                style: GoogleFonts.creepster(
                                  fontSize: 48,
                                  color: Colors.white.withOpacity(opacity),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.9),
                                      blurRadius: 15,
                                      offset: const Offset(4, 4),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),

                    // Result display
                    if (_cachedResultText != null) ...[
                      AnimatedBuilder(
                        animation: _explosionController,
                        builder: (context, child) {
                          final scale = 1.0 + (_explosionController.value * 0.3);
                          final colorShift = _explosionController.value;

                          // Different colors for timeout vs normal result
                          final gradientColors = _timedOut ? [
                            Color.lerp(Colors.red, Colors.white, colorShift * 0.5)!.withOpacity(0.9),
                            Color.lerp(Colors.orange, Colors.yellow, colorShift * 0.3)!.withOpacity(0.7),
                            Colors.red.withOpacity(0.5),
                          ] : [
                            Color.lerp(interpolatedColors[0], Colors.white, colorShift * 0.5)!.withOpacity(0.9),
                            Color.lerp(interpolatedColors[2], Colors.yellow, colorShift * 0.3)!.withOpacity(0.7),
                            interpolatedColors[4].withOpacity(0.5),
                          ];

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                gradient: RadialGradient(
                                  colors: gradientColors,
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: (_timedOut ? Colors.red : interpolatedColors[1]).withOpacity(0.7),
                                    blurRadius: 30,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: Text(
                                _cachedResultText!,
                                style: GoogleFonts.chicle(
                                  fontSize: _timedOut ? 28 : 32,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.9),
                                      blurRadius: 8,
                                      offset: const Offset(3, 3),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],

                    // THE PSYCHEDELIC BUTTON!
                    if (_showButton && !_timedOut) // HIDE button if timed out
                      AnimatedBuilder(
                        animation: _buttonController,
                        builder: (context, child) {
                          return AnimatedBuilder(
                            animation: _pulsController,
                            builder: (context, child) {
                              final buttonScale = 1.0 + (_pulsController.value * 0.1) + (_buttonController.value * 0.2);
                              final glowIntensity = 0.5 + (_pulsController.value * 0.5);

                              return Transform.scale(
                                scale: buttonScale,
                                child: GestureDetector(
                                  onTap: _handleTap,
                                  child: Container(
                                    width: 250,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: _isRunning ? [
                                          Colors.red.withOpacity(0.9),
                                          Colors.orange.withOpacity(0.8),
                                          Colors.yellow.withOpacity(0.7),
                                          Colors.red.withOpacity(0.9),
                                        ] : [
                                          Colors.green.withOpacity(0.9),
                                          Colors.lime.withOpacity(0.8),
                                          Colors.cyan.withOpacity(0.7),
                                          Colors.green.withOpacity(0.9),
                                        ],
                                        stops: [0.0, 0.3, 0.7, 1.0],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.8),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(glowIntensity),
                                          blurRadius: 25,
                                          spreadRadius: 8,
                                        ),
                                        BoxShadow(
                                          color: (_isRunning ? Colors.red : Colors.green).withOpacity(0.6),
                                          blurRadius: 40,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Colors.yellow,
                                            Colors.white,
                                          ],
                                        ).createShader(bounds),
                                        child: Text(
                                          _isRunning ? 'STOP' : 'START',
                                          style: GoogleFonts.creepster(
                                            fontSize: 36,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 3.0,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withOpacity(0.9),
                                                blurRadius: 10,
                                                offset: const Offset(3, 3),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                    // Target instruction
                    if (_isRunning && !_timedOut) ...[
                      const SizedBox(height: 30),
                      AnimatedBuilder(
                        animation: _scaleController,
                        builder: (context, child) {
                          final scale = 1.0 + (_scaleController.value * 0.05);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [
                                    interpolatedColors[3].withOpacity(0.7),
                                    interpolatedColors[6].withOpacity(0.5),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                _cachedTargetText!,
                                style: GoogleFonts.chicle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.8),
                                      blurRadius: 4,
                                      offset: const Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              // Results counter (only show if not timed out)
              if (!_isPracticeMode && !_timedOut)
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _resultsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final count = snapshot.data!.docs.length;
                        return AnimatedBuilder(
                          animation: _scaleController,
                          builder: (context, child) {
                            final scale = 1.0 + (_scaleController.value * 0.05);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: LinearGradient(
                                    colors: [
                                      interpolatedColors[0].withOpacity(0.8),
                                      interpolatedColors[4].withOpacity(0.6),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$count players finished this round...',
                                  style: GoogleFonts.chicle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.7),
                                        blurRadius: 3,
                                        offset: const Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}