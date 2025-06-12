// lib/screens/momentum_game_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../services/momentum_bot_service.dart';
import 'momentum_results_screen.dart';

class MomentumGameScreen extends StatefulWidget {
  final bool isPractice;
  final String tourneyId;

  const MomentumGameScreen({
    super.key,
    required this.isPractice,
    required this.tourneyId,
  });

  @override
  State<MomentumGameScreen> createState() => _MomentumGameScreenState();
}

class _MomentumGameScreenState extends State<MomentumGameScreen>
    with TickerProviderStateMixin {

  // Game state
  int _currentSpin = 1;
  static const int SPINS_PER_ROUND = 3;
  bool _hasSubmitted = false;
  bool _hasSubmittedBots = false;

  // Wheel state
  bool _isSpinning = false;
  double _wheelPosition = 0.0; // 0.0 to 1.0 representing full rotation
  double _baseSpeed = 2.0; // Base rotations per second
  double _currentSpeed = 2.0; // Current speed (affected by momentum)
  Timer? _wheelTimer;

  // Momentum system
  List<int> _spinScores = []; // Scores for each spin (0-1000 points)
  double _momentumMultiplier = 1.0; // Speed multiplier based on performance

  // Target zone (perfect stop zone)
  static const double TARGET_START = 0.85; // 85% around the wheel
  static const double TARGET_END = 0.95;   // 95% around the wheel
  static const double TARGET_PERFECT = 0.9; // Perfect center at 90%

  // UI state
  String _statusMessage = 'Tap the wheel to start spinning!';
  bool _showResult = false;
  int _lastSpinScore = 0;

  // PSYCHEDELIC ANIMATION CONTROLLERS
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _wheelController;
  late AnimationController _successController;
  late AnimationController _perfectController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  // Database
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();

    // Initialize INTENSE psychedelic animations
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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

    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Long duration for smooth wheel animation
    )..repeat();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _perfectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Submit bot results for tournament mode
    if (!widget.isPractice) {
      _submitBotResults();
    }
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    final momentumColors = [
      Colors.red.shade800,
      Colors.orange.shade700,
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
    ];

    return List.generate(
        8, (_) => momentumColors[random.nextInt(momentumColors.length)]);
  }

  Future<void> _submitBotResults() async {
    if (_hasSubmittedBots) return;
    _hasSubmittedBots = true;

    try {
      final tourneyDoc = await _db
          .collection('momentum_tournaments')
          .doc(widget.tourneyId)
          .get();

      if (!tourneyDoc.exists) return;

      final data = tourneyDoc.data();
      if (data == null || !data.containsKey('bots')) return;

      final botsData = data['bots'] as Map<String, dynamic>?;
      if (botsData == null || botsData.isEmpty) return;

      final allBots = <MomentumBotPlayer>[];

      for (final entry in botsData.entries) {
        try {
          final botData = entry.value as Map<String, dynamic>?;
          if (botData == null) continue;

          final name = botData['name'] as String?;
          final difficultyName = botData['difficulty'] as String?;

          if (name == null || difficultyName == null) continue;

          final difficulty = MomentumBotDifficulty.values.where(
                (d) => d.name == difficultyName,
          ).firstOrNull;

          if (difficulty == null) continue;

          allBots.add(MomentumBotPlayer(
            id: entry.key,
            name: name,
            difficulty: difficulty,
          ));
        } catch (e) {
          continue;
        }
      }

      if (allBots.isNotEmpty) {
        MomentumBotService.submitBotResults(widget.tourneyId, allBots);
      }
    } catch (e) {
      print('Error submitting momentum bot results: $e');
    }
  }

  void _startSpinning() {
    if (_isSpinning || _currentSpin > SPINS_PER_ROUND) return;

    setState(() {
      _isSpinning = true;
      _showResult = false;
      _statusMessage = 'Wheel is spinning... Tap to STOP!';
      _currentSpeed = _baseSpeed * _momentumMultiplier;
    });

    // Start wheel animation
    const int fps = 60;
    const double frameTime = 1.0 / fps;

    _wheelTimer = Timer.periodic(Duration(milliseconds: (frameTime * 1000).round()), (timer) {
      if (!_isSpinning) {
        timer.cancel();
        return;
      }

      setState(() {
        _wheelPosition += (_currentSpeed * frameTime);
        if (_wheelPosition >= 1.0) {
          _wheelPosition -= 1.0; // Keep in 0-1 range
        }
      });
    });
  }

  void _stopWheel() {
    if (!_isSpinning) {
      _startSpinning();
      return;
    }

    _wheelTimer?.cancel();
    setState(() {
      _isSpinning = false;
    });

    // Calculate score based on accuracy
    final score = _calculateScore(_wheelPosition);
    _lastSpinScore = score;
    _spinScores.add(score);

    // Update momentum based on performance
    _updateMomentum(score);

    // Show result
    _showSpinResult(score);

    // Prepare for next spin or finish
    if (_currentSpin < SPINS_PER_ROUND) {
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _currentSpin++;
            _statusMessage = 'Spin ${_currentSpin} of $SPINS_PER_ROUND - Tap to spin!';
            _showResult = false;
          });
        }
      });
    } else {
      // All spins complete
      Timer(const Duration(seconds: 2), () {
        _finishRound();
      });
    }
  }

  int _calculateScore(double wheelPosition) {
    // Calculate distance from perfect target
    double distanceFromPerfect = (wheelPosition - TARGET_PERFECT).abs();

    // Handle wrap-around (wheel is circular)
    if (distanceFromPerfect > 0.5) {
      distanceFromPerfect = 1.0 - distanceFromPerfect;
    }

    // Convert to score (1000 = perfect, 0 = worst)
    if (distanceFromPerfect <= (TARGET_END - TARGET_START) / 2) {
      // Within target zone
      final accuracy = 1.0 - (distanceFromPerfect / ((TARGET_END - TARGET_START) / 2));
      return (accuracy * 1000).round();
    } else {
      // Outside target zone
      final maxDistance = 0.5; // Maximum possible distance
      final accuracy = math.max(0.0, 1.0 - (distanceFromPerfect / maxDistance));
      return (accuracy * 500).round(); // Max 500 points outside target
    }
  }

  void _updateMomentum(int score) {
    // Momentum builds based on consistent good performance
    if (score >= 800) {
      _momentumMultiplier += 0.3; // Excellent spin
    } else if (score >= 600) {
      _momentumMultiplier += 0.1; // Good spin
    } else if (score >= 400) {
      // Average spin - no change
    } else {
      _momentumMultiplier = math.max(1.0, _momentumMultiplier - 0.2); // Poor spin
    }

    // Cap momentum
    _momentumMultiplier = math.min(_momentumMultiplier, 4.0);
  }

  void _showSpinResult(int score) {
    setState(() {
      _showResult = true;

      if (score >= 950) {
        _statusMessage = 'PERFECT! 🎯 +${score} points';
        _perfectController.forward().then((_) => _perfectController.reset());
      } else if (score >= 800) {
        _statusMessage = 'EXCELLENT! ⭐ +${score} points';
        _successController.forward().then((_) => _successController.reset());
      } else if (score >= 600) {
        _statusMessage = 'GOOD! ✓ +${score} points';
      } else if (score >= 400) {
        _statusMessage = 'OKAY... +${score} points';
      } else {
        _statusMessage = 'MISS! +${score} points';
      }
    });
  }

  void _finishRound() {
    final totalScore = _spinScores.fold<int>(0, (sum, score) => sum + score);

    if (!widget.isPractice) {
      _submitResult(totalScore);

      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MomentumResultsScreen(
                tourneyId: widget.tourneyId,
                playerScore: totalScore,
                spinScores: _spinScores,
                isPractice: false,
              ),
            ),
          );
        }
      });
    } else {
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MomentumResultsScreen(
                tourneyId: widget.tourneyId,
                playerScore: totalScore,
                spinScores: _spinScores,
                isPractice: true,
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _submitResult(int totalScore) async {
    if (_hasSubmitted) return;
    _hasSubmitted = true;

    try {
      await _db
          .collection('momentum_tournaments')
          .doc(widget.tourneyId)
          .collection('results')
          .doc(_uid)
          .set({
        'uid': _uid,
        'totalScore': totalScore,
        'spinScores': _spinScores,
        'momentum': _momentumMultiplier,
        'submittedAt': FieldValue.serverTimestamp(),
        'isBot': false,
      });
    } catch (e) {
      print('Error submitting momentum result: $e');
    }
  }

  @override
  void dispose() {
    _wheelTimer?.cancel();
    _backgroundController.dispose();
    _pulsController.dispose();
    _wheelController.dispose();
    _successController.dispose();
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
            children: [
              // PSYCHEDELIC BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.0,
                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.85, 1.0],
                  ),
                ),
              ),

              // ROTATING OVERLAY
              AnimatedBuilder(
                animation: _wheelController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.3),
                          Colors.transparent,
                          interpolatedColors[5].withOpacity(0.2),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_wheelController.value * 6.28),
                      ),
                    ),
                  );
                },
              ),

              // PERFECT HIT EXPLOSION
              if (_perfectController.isAnimating)
                AnimatedBuilder(
                  animation: _perfectController,
                  builder: (context, child) {
                    final explosion = _perfectController.value;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.9 * (1 - explosion)),
                            Colors.yellow.withOpacity(0.7 * (1 - explosion)),
                            Colors.orange.withOpacity(0.5 * (1 - explosion)),
                            Colors.transparent,
                          ],
                          center: Alignment.center,
                          radius: explosion * 3.0,
                        ),
                      ),
                    );
                  },
                ),

              // SUCCESS EXPLOSION
              if (_successController.isAnimating)
                AnimatedBuilder(
                  animation: _successController,
                  builder: (context, child) {
                    final explosion = _successController.value;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.green.withOpacity(0.8 * (1 - explosion)),
                            Colors.lime.withOpacity(0.6 * (1 - explosion)),
                            Colors.cyan.withOpacity(0.4 * (1 - explosion)),
                            Colors.transparent,
                          ],
                          center: Alignment.center,
                          radius: explosion * 2.5,
                        ),
                      ),
                    );
                  },
                ),

              // MAIN CONTENT
              SafeArea(
                child: Column(
                  children: [
                    // HEADER
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedBuilder(
                            animation: _pulsController,
                            builder: (context, child) {
                              final scale = 1.0 + (_pulsController.value * 0.1);
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: RadialGradient(
                                      colors: [
                                        interpolatedColors[0].withOpacity(0.9),
                                        interpolatedColors[3].withOpacity(0.7),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.6),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [Colors.white, Colors.yellow, Colors.white],
                                    ).createShader(bounds),
                                    child: Text(
                                      'Spin $_currentSpin/$SPINS_PER_ROUND',
                                      style: GoogleFonts.creepster(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.8),
                                            blurRadius: 6,
                                            offset: const Offset(2, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Momentum indicator
                          AnimatedBuilder(
                            animation: _pulsController,
                            builder: (context, child) {
                              final intensity = 0.7 + (_pulsController.value * 0.3);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(intensity),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.8),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.purple.withOpacity(0.5),
                                      blurRadius: 15,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Speed: ${_momentumMultiplier.toStringAsFixed(1)}x',
                                  style: GoogleFonts.chicle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.8),
                                        blurRadius: 4,
                                        offset: const Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // STATUS MESSAGE
                    AnimatedBuilder(
                      animation: _pulsController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulsController.value * 0.05);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  interpolatedColors[2].withOpacity(0.8),
                                  interpolatedColors[6].withOpacity(0.6),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [Colors.white, Colors.cyan, Colors.purple],
                              ).createShader(bounds),
                              child: Text(
                                _statusMessage,
                                style: GoogleFonts.creepster(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.8),
                                      blurRadius: 6,
                                      offset: const Offset(2, 2),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // THE SPINNING WHEEL
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: _stopWheel,
                          child: _buildSpinningWheel(interpolatedColors),
                        ),
                      ),
                    ),

                    // SCORE DISPLAY
                    if (_spinScores.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: RadialGradient(
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.purple.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _spinScores.asMap().entries.map((entry) {
                            final spinNum = entry.key + 1;
                            final score = entry.value;
                            return Column(
                              children: [
                                Text(
                                  'Spin $spinNum',
                                  style: GoogleFonts.chicle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '$score',
                                  style: GoogleFonts.chicle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpinningWheel(List<Color> colors) {
    return AnimatedBuilder(
      animation: _pulsController,
      builder: (context, child) {
        final pulseScale = 1.0 + (_pulsController.value * 0.05);
        final glowIntensity = 0.6 + (_pulsController.value * 0.4);

        return Transform.scale(
          scale: pulseScale,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(glowIntensity * 0.6),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: colors[1].withOpacity(0.8),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CustomPaint(
              painter: SpinningWheelPainter(
                wheelPosition: _wheelPosition,
                isSpinning: _isSpinning,
                colors: colors,
                targetStart: TARGET_START,
                targetEnd: TARGET_END,
                targetPerfect: TARGET_PERFECT,
              ),
              size: const Size(300, 300),
            ),
          ),
        );
      },
    );
  }
}

class SpinningWheelPainter extends CustomPainter {
  final double wheelPosition;
  final bool isSpinning;
  final List<Color> colors;
  final double targetStart;
  final double targetEnd;
  final double targetPerfect;

  SpinningWheelPainter({
    required this.wheelPosition,
    required this.isSpinning,
    required this.colors,
    required this.targetStart,
    required this.targetEnd,
    required this.targetPerfect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw wheel segments
    const int segments = 20;
    for (int i = 0; i < segments; i++) {
      final startAngle = (i / segments) * 2 * math.pi;
      final sweepAngle = (2 * math.pi) / segments;

      final paint = Paint()
        ..color = colors[i % colors.length].withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw segment borders
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );
    }

    // Draw target zone
    final targetStartAngle = targetStart * 2 * math.pi;
    final targetSweepAngle = (targetEnd - targetStart) * 2 * math.pi;

    final targetPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      targetStartAngle,
      targetSweepAngle,
      true,
      targetPaint,
    );

    // Draw perfect target line
    final perfectAngle = targetPerfect * 2 * math.pi;
    final perfectPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final perfectStart = Offset(
      center.dx + (radius - 20) * math.cos(perfectAngle),
      center.dy + (radius - 20) * math.sin(perfectAngle),
    );
    final perfectEnd = Offset(
      center.dx + radius * math.cos(perfectAngle),
      center.dy + radius * math.sin(perfectAngle),
    );

    canvas.drawLine(perfectStart, perfectEnd, perfectPaint);

    // Draw wheel border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius, borderPaint);

    // Draw pointer (current position)
    final pointerAngle = wheelPosition * 2 * math.pi;
    final pointerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pointerStart = center;
    final pointerEnd = Offset(
      center.dx + (radius - 30) * math.cos(pointerAngle),
      center.dy + (radius - 30) * math.sin(pointerAngle),
    );

    // Draw pointer as triangle
    final pointerPath = Path();
    pointerPath.moveTo(center.dx, center.dy);
    pointerPath.lineTo(
      center.dx + (radius - 30) * math.cos(pointerAngle - 0.1),
      center.dy + (radius - 30) * math.sin(pointerAngle - 0.1),
    );
    pointerPath.lineTo(
      center.dx + (radius - 30) * math.cos(pointerAngle + 0.1),
      center.dy + (radius - 30) * math.sin(pointerAngle + 0.1),
    );
    pointerPath.close();

    canvas.drawPath(pointerPath, pointerPaint);

    // Draw center circle
    final centerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 15, centerPaint);

    final centerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, 15, centerBorderPaint);
  }

  @override
  bool shouldRepaint(SpinningWheelPainter oldDelegate) {
    return oldDelegate.wheelPosition != wheelPosition ||
        oldDelegate.isSpinning != isSpinning;
  }
}