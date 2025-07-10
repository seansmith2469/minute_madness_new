// lib/screens/momentum_game_screen.dart - FIXED 10-SPIN SINGLE TOURNAMENT
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import 'momentum_results_screen.dart';

class MomentumGameScreen extends StatefulWidget {
  final bool isPractice;
  final String tourneyId;
  final Function(Map<String, dynamic>)? onUltimateComplete;

  const MomentumGameScreen({
    super.key,
    required this.isPractice,
    required this.tourneyId,
    this.onUltimateComplete,
  });

  @override
  State<MomentumGameScreen> createState() => _MomentumGameScreenState();
}

class _MomentumGameScreenState extends State<MomentumGameScreen>
    with TickerProviderStateMixin {

  // Game state - FIXED: 10 spins total for single tournament
  int _currentSpin = 1;
  static const int TOTAL_SPINS = 10; // 10 spins total
  bool _hasSubmitted = false;

  // Wheel state - OPTIMIZED: Instant stop, progressive speed
  bool _isSpinning = false;
  double _wheelPosition = 0.0; // 0.0 to 1.0 representing full rotation
  double _currentSpinSpeed = 1.0; // Speed for current spin only
  Timer? _wheelTimer;

  // PROGRESSIVE SPEED SYSTEM
  List<int> _spinScores = [];
  double _accuracyMultiplier = 1.0; // Speed multiplier based on accuracy
  double _progressiveMultiplier = 1.0; // Speed multiplier based on spin number

  // ENHANCED TARGET SYSTEM for bigger wheel
  static const double TARGET_PERFECT = 0.75; // Perfect target at 75%
  static const double TARGET_SIZE = 0.08; // Larger target zone (8% of wheel)
  double get _targetStart => TARGET_PERFECT - (TARGET_SIZE / 2);
  double get _targetEnd => TARGET_PERFECT + (TARGET_SIZE / 2);

  // UI state
  String _statusMessage = 'Spin 1/10 - Tap to start!';
  bool _showResult = false;
  int _lastSpinScore = 0;

  // Check if ultimate tournament
  bool get _isUltimateTournament => widget.onUltimateComplete != null;

  // ENHANCED ANIMATIONS
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _wheelController;
  late AnimationController _successController;
  late AnimationController _perfectController;
  late AnimationController _speedController;
  late AnimationController _particleController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;
  List<Particle> _particles = [];

  // Database
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();

    // Initialize enhanced psychedelic animations
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (2000 / math.max(1.0, _getCurrentSpeedMultiplier())).round()),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.duration = Duration(
            milliseconds: (2000 / math.max(1.0, _getCurrentSpeedMultiplier())).round()
        );
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _perfectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _speedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    final speedMultiplier = _getCurrentSpeedMultiplier();

    // Colors become more intense with higher speed
    List<Color> baseColors = speedMultiplier > 10.0
        ? [Colors.red.shade900, Colors.orange.shade900, Colors.yellow.shade700, Colors.pink.shade900]
        : speedMultiplier > 5.0
        ? [Colors.red.shade800, Colors.orange.shade700, Colors.yellow.shade600, Colors.purple.shade800]
        : speedMultiplier > 2.0
        ? [Colors.blue.shade800, Colors.purple.shade700, Colors.cyan.shade600, Colors.indigo.shade700]
        : [Colors.blue.shade700, Colors.indigo.shade600, Colors.purple.shade600, Colors.cyan.shade600];

    return List.generate(
        8, (_) => baseColors[random.nextInt(baseColors.length)]);
  }

  // PROGRESSIVE SPEED CALCULATION
  double _getCurrentSpeedMultiplier() {
    // Progressive multiplier: starts at 1x, goes to 5x by spin 10
    _progressiveMultiplier = 1.0 + ((_currentSpin - 1) / (TOTAL_SPINS - 1)) * 4.0;

    // Total speed = progressive * accuracy multiplier
    return _progressiveMultiplier * _accuracyMultiplier;
  }

  void _startSpinning() {
    if (_isSpinning || _currentSpin > TOTAL_SPINS) return;

    // Calculate speed ONCE at start of spin and keep it consistent
    final speedMultiplier = _getCurrentSpeedMultiplier();
    _currentSpinSpeed = 2.0 * speedMultiplier; // Lock in speed for this entire spin

    setState(() {
      _isSpinning = true;
      _showResult = false;
      _statusMessage = 'Spinning at ${speedMultiplier.toStringAsFixed(1)}x speed - TAP TO STOP!';
    });

    // Immediate haptic feedback
    HapticFeedback.lightImpact();

    // ULTRA HIGH FPS for completely smooth, instant response
    const int fps = 240; // Maximum possible FPS
    const double frameTime = 1.0 / fps;

    _wheelTimer = Timer.periodic(Duration(microseconds: (frameTime * 1000000).round()), (timer) {
      if (!_isSpinning) {
        timer.cancel();
        return;
      }

      setState(() {
        // Use locked-in speed for entire spin duration
        _wheelPosition += (_currentSpinSpeed * frameTime);
        if (_wheelPosition >= 1.0) {
          _wheelPosition -= 1.0;
        }
      });
    });
  }

  void _stopWheel() {
    if (!_isSpinning) {
      _startSpinning();
      return;
    }

    // INSTANT STOP - no delay whatsoever
    _wheelTimer?.cancel();
    setState(() {
      _isSpinning = false;
    });

    final score = _calculateScore(_wheelPosition);

    // Immediate haptic feedback based on accuracy
    if (score >= 950) {
      HapticFeedback.heavyImpact();
    } else if (score >= 800) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }

    _lastSpinScore = score;
    _spinScores.add(score);

    // Update accuracy multiplier for next spin
    _updateAccuracyMultiplier(score);

    // Create particles for good shots
    if (score >= 700) {
      _createParticles(score);
    }

    // Show result
    _showSpinResult(score);

    // Prepare for next spin or finish
    if (_currentSpin < TOTAL_SPINS) {
      Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() {
            _currentSpin++;
            // Show NEXT spin's speed, not current
            final nextSpeed = _getCurrentSpeedMultiplier();
            _statusMessage = 'Spin $_currentSpin/$TOTAL_SPINS - Next Speed: ${nextSpeed.toStringAsFixed(1)}x - Tap to spin!';
            _showResult = false;
          });

          // Update animation speeds for next spin
          _updateAnimationSpeeds();
        }
      });
    } else {
      Timer(const Duration(milliseconds: 1200), () {
        _finishGame();
      });
    }
  }

  void _updateAccuracyMultiplier(int score) {
    // Only update for NEXT spin, not current spin
    // Exponential speed increase based on accuracy
    double accuracyPercent = score / 1000.0;

    if (accuracyPercent >= 0.95) {
      // Perfect shots make it MUCH faster
      _accuracyMultiplier *= 1.8;
    } else if (accuracyPercent >= 0.9) {
      // Near perfect
      _accuracyMultiplier *= 1.5;
    } else if (accuracyPercent >= 0.8) {
      // Good shots
      _accuracyMultiplier *= 1.3;
    } else if (accuracyPercent >= 0.7) {
      // OK shots
      _accuracyMultiplier *= 1.1;
    } else if (accuracyPercent >= 0.5) {
      // Poor shots slow it down a bit
      _accuracyMultiplier *= 0.95;
    } else {
      // Really bad shots provide some relief
      _accuracyMultiplier *= 0.8;
    }

    // Cap the multiplier to prevent impossible speeds
    _accuracyMultiplier = math.min(_accuracyMultiplier, 20.0);
    _accuracyMultiplier = math.max(_accuracyMultiplier, 0.5);

    // Note: Speed changes will take effect on NEXT spin only
  }

  int _calculateScore(double wheelPosition) {
    double distanceFromPerfect = (wheelPosition - TARGET_PERFECT).abs();

    // Handle wrap-around (if target is near 0.0 or 1.0)
    if (distanceFromPerfect > 0.5) {
      distanceFromPerfect = 1.0 - distanceFromPerfect;
    }

    // Check if in target zone
    if (distanceFromPerfect <= TARGET_SIZE / 2) {
      final accuracy = 1.0 - (distanceFromPerfect / (TARGET_SIZE / 2));
      final baseScore = (accuracy * 1000).round();

      // Use speed from when spin started, not current multiplier
      final speedBonus = (_currentSpinSpeed > 10.0 ?
      (_currentSpinSpeed - 2.0) * 10 : 0).round();

      return math.min(1000, baseScore + speedBonus);
    } else {
      // Outside target zone - distance-based scoring
      final maxDistance = 0.5;
      final accuracy = math.max(0.0, 1.0 - (distanceFromPerfect / maxDistance));
      return (accuracy * 600).round(); // Max 600 points outside target
    }
  }

  void _updateAnimationSpeeds() {
    final speedMultiplier = _getCurrentSpeedMultiplier();
    final newBgDuration = (2000 / math.max(1.0, speedMultiplier)).round();

    _backgroundController.duration = Duration(milliseconds: newBgDuration);
  }

  void _createParticles(int score) {
    final random = math.Random();
    final particleCount = score >= 950 ? 30 : score >= 800 ? 20 : 10;

    _particles.clear();
    for (int i = 0; i < particleCount; i++) {
      _particles.add(Particle(
        x: 200 + random.nextDouble() * 100, // Around wheel center
        y: 200 + random.nextDouble() * 100,
        dx: (random.nextDouble() - 0.5) * 6,
        dy: (random.nextDouble() - 0.5) * 6,
        color: score >= 950 ? Colors.yellow : score >= 800 ? Colors.orange : Colors.cyan,
        life: 1.0,
      ));
    }

    _particleController.forward(from: 0);
  }

  void _showSpinResult(int score) {
    setState(() {
      _showResult = true;

      String baseMessage = '';
      if (score >= 1000) {
        baseMessage = 'IMPOSSIBLE PERFECT! 🎯 +${score} points';
        _perfectController.forward().then((_) => _perfectController.reset());
      } else if (score >= 950) {
        baseMessage = 'PERFECT! 🎯 +${score} points';
        _perfectController.forward().then((_) => _perfectController.reset());
      } else if (score >= 800) {
        baseMessage = 'EXCELLENT! ⭐ +${score} points';
        _successController.forward().then((_) => _successController.reset());
      } else if (score >= 700) {
        baseMessage = 'GOOD! ✓ +${score} points';
      } else if (score >= 500) {
        baseMessage = 'OK... +${score} points';
      } else {
        baseMessage = 'MISS! +${score} points';
      }

      // Add speed indicators
      final speedMultiplier = _getCurrentSpeedMultiplier();
      if (speedMultiplier > 15.0) {
        baseMessage += ' [INSANE SPEED!]';
      } else if (speedMultiplier > 10.0) {
        baseMessage += ' [EXTREME SPEED!]';
      } else if (speedMultiplier > 5.0) {
        baseMessage += ' [HIGH SPEED]';
      }

      _statusMessage = baseMessage;
    });
  }

  void _finishGame() {
    final totalScore = _spinScores.fold<int>(0, (sum, score) => sum + score);

    if (widget.onUltimateComplete != null) {
      // Calculate rank based on score (1-64, higher score = better rank)
      int rank = math.max(1, 65 - (totalScore / 100).round());
      rank = math.min(64, rank);

      final result = {
        'score': totalScore,
        'rank': rank,
        'details': {
          'totalScore': totalScore,
          'spins': TOTAL_SPINS,
          'maxSpeed': _getCurrentSpeedMultiplier(),
        },
      };

      widget.onUltimateComplete!(result);
      return; // Don't navigate, let Ultimate Tournament handle it
    }

    if (!widget.isPractice && !_isUltimateTournament) {
      _submitResult(totalScore);
    }

    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MomentumResultsScreen(
              tourneyId: widget.tourneyId,
              playerScore: totalScore,
              spinScores: _spinScores,
              isPractice: widget.isPractice,
              achievements: [], // Single tournament, no complex achievements
              momentumMultiplier: _getCurrentSpeedMultiplier(),
              comebackBonuses: 0,
            ),
          ),
        );
      }
    });
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
        'maxSpeed': _getCurrentSpeedMultiplier(), // FIXED: Store as maxSpeed
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
    _speedController.dispose();
    _particleController.dispose();
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
              // ENHANCED PSYCHEDELIC BACKGROUND
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.0 + (_getCurrentSpeedMultiplier() * 0.1),
                    stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.85, 1.0],
                  ),
                ),
              ),

              // SPEED-RESPONSIVE ROTATING OVERLAY
              AnimatedBuilder(
                animation: _wheelController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.2 + _getCurrentSpeedMultiplier() * 0.05),
                          Colors.transparent,
                          interpolatedColors[5].withOpacity(0.1 + _getCurrentSpeedMultiplier() * 0.03),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_wheelController.value * 6.28 * _getCurrentSpeedMultiplier()),
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
                          radius: explosion * (4.0 + _getCurrentSpeedMultiplier()),
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
                          radius: explosion * 3.0,
                        ),
                      ),
                    );
                  },
                ),

              // PARTICLE SYSTEM
              if (_particles.isNotEmpty)
                AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ParticlePainter(_particles, _particleController.value),
                      size: Size.infinite,
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
                          // Spin counter
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
                                      'Spin $_currentSpin/$TOTAL_SPINS',
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

                          // SPEED INDICATOR
                          _buildSpeedIndicator(interpolatedColors),
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

                    // THE BIG SPINNING WHEEL
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: _stopWheel,
                          child: _buildBigSpinningWheel(interpolatedColors),
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
                        child: Column(
                          children: [
                            // Score display optimized for 10 spins
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: _spinScores.asMap().entries.map((entry) {
                                final spinNum = entry.key + 1;
                                final score = entry.value;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: score >= 800 ? Colors.green.withOpacity(0.3) :
                                    score >= 600 ? Colors.orange.withOpacity(0.3) :
                                    Colors.red.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: score >= 800 ? Colors.green :
                                      score >= 600 ? Colors.orange : Colors.red,
                                    ),
                                  ),
                                  child: Text(
                                    '$spinNum:$score',
                                    style: GoogleFonts.chicle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 10),

                            // Total score
                            Text(
                              'Total: ${_spinScores.fold<int>(0, (sum, score) => sum + score)}',
                              style: GoogleFonts.chicle(
                                fontSize: 18,
                                color: Colors.yellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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

  Widget _buildSpeedIndicator(List<Color> colors) {
    final speedMultiplier = _getCurrentSpeedMultiplier();
    Color speedColor = speedMultiplier > 15.0 ? Colors.red.shade900 :
    speedMultiplier > 10.0 ? Colors.red :
    speedMultiplier > 5.0 ? Colors.orange :
    speedMultiplier > 2.0 ? Colors.yellow : Colors.green;

    return AnimatedBuilder(
      animation: _speedController,
      builder: (context, child) {
        final intensity = 0.7 + (_speedController.value * 0.3);
        final scale = 1.0 + (_speedController.value * 0.1 * speedMultiplier / 20.0);

        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: speedColor.withOpacity(intensity),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: speedColor.withOpacity(0.5),
                  blurRadius: 15 + (speedMultiplier * 2),
                  spreadRadius: 3 + speedMultiplier,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SPEED',
                  style: GoogleFonts.chicle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${speedMultiplier.toStringAsFixed(1)}x',
                  style: GoogleFonts.creepster(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Speed bar
                Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.yellow, Colors.orange, Colors.red, Colors.red.shade900],
                      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: math.min(1.0, speedMultiplier / 20.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: speedColor.withOpacity(0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBigSpinningWheel(List<Color> colors) {
    return AnimatedBuilder(
      animation: _pulsController,
      builder: (context, child) {
        // Remove pulsing scale during spinning to maintain consistent visual speed
        final pulseScale = _isSpinning ? 1.0 : 1.0 + (_pulsController.value * 0.03);
        final glowIntensity = 0.6 + (_pulsController.value * 0.4) + (_getCurrentSpeedMultiplier() * 0.05);

        return Transform.scale(
          scale: pulseScale,
          child: Container(
            width: 350, // BIGGER WHEEL
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(glowIntensity * 0.6),
                  blurRadius: 30 + (_getCurrentSpeedMultiplier() * 5),
                  spreadRadius: 10 + (_getCurrentSpeedMultiplier() * 2),
                ),
                BoxShadow(
                  color: colors[1].withOpacity(0.8),
                  blurRadius: 50 + (_getCurrentSpeedMultiplier() * 8),
                  spreadRadius: 5 + (_getCurrentSpeedMultiplier() * 1.5),
                ),
              ],
            ),
            child: CustomPaint(
              painter: BigSpinningWheelPainter(
                wheelPosition: _wheelPosition,
                isSpinning: _isSpinning,
                colors: colors,
                targetStart: _targetStart,
                targetEnd: _targetEnd,
                targetPerfect: TARGET_PERFECT,
                speedMultiplier: _getCurrentSpeedMultiplier(),
              ),
              size: const Size(350, 350),
            ),
          ),
        );
      },
    );
  }
}

class BigSpinningWheelPainter extends CustomPainter {
  final double wheelPosition;
  final bool isSpinning;
  final List<Color> colors;
  final double targetStart;
  final double targetEnd;
  final double targetPerfect;
  final double speedMultiplier;

  BigSpinningWheelPainter({
    required this.wheelPosition,
    required this.isSpinning,
    required this.colors,
    required this.targetStart,
    required this.targetEnd,
    required this.targetPerfect,
    required this.speedMultiplier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw wheel segments - MORE SEGMENTS for bigger wheel
    const int segments = 40; // Doubled from 20 to 40 segments
    for (int i = 0; i < segments; i++) {
      final startAngle = (i / segments) * 2 * math.pi;
      final sweepAngle = (2 * math.pi) / segments;

      // Enhanced colors based on speed
      Color segmentColor = colors[i % colors.length];
      if (speedMultiplier > 10.0) {
        segmentColor = segmentColor.withOpacity(0.95);
      } else if (speedMultiplier > 5.0) {
        segmentColor = segmentColor.withOpacity(0.85);
      } else {
        segmentColor = segmentColor.withOpacity(0.75);
      }

      final paint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Enhanced segment borders
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3 + speedMultiplier * 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + (speedMultiplier * 0.3);

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
      ..color = Colors.yellow.withOpacity(0.8)
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
      ..strokeWidth = 5 + speedMultiplier;

    final perfectStart = Offset(
      center.dx + (radius - 30) * math.cos(perfectAngle),
      center.dy + (radius - 30) * math.sin(perfectAngle),
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
      ..strokeWidth = 5 + speedMultiplier;

    canvas.drawCircle(center, radius, borderPaint);

    // Draw pointer
    final pointerAngle = wheelPosition * 2 * math.pi;
    final pointerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pointerPath = Path();
    final pointerLength = radius - 30;

    pointerPath.moveTo(center.dx, center.dy);
    pointerPath.lineTo(
      center.dx + pointerLength * math.cos(pointerAngle - 0.1),
      center.dy + pointerLength * math.sin(pointerAngle - 0.1),
    );
    pointerPath.lineTo(
      center.dx + (pointerLength + 15) * math.cos(pointerAngle),
      center.dy + (pointerLength + 15) * math.sin(pointerAngle),
    );
    pointerPath.lineTo(
      center.dx + pointerLength * math.cos(pointerAngle + 0.1),
      center.dy + pointerLength * math.sin(pointerAngle + 0.1),
    );
    pointerPath.close();

    canvas.drawPath(pointerPath, pointerPaint);

    // Draw center circle
    final centerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 25, centerPaint);

    final centerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, 25, centerBorderPaint);

    // Speed indicator ring
    if (speedMultiplier > 5.0) {
      final speedRingPaint = Paint()
        ..color = Colors.cyan.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;

      canvas.drawCircle(center, radius + 20, speedRingPaint);
    }
  }

  @override
  bool shouldRepaint(BigSpinningWheelPainter oldDelegate) {
    return oldDelegate.wheelPosition != wheelPosition ||
        oldDelegate.isSpinning != isSpinning ||
        oldDelegate.speedMultiplier != speedMultiplier;
  }
}

class Particle {
  double x, y, dx, dy, life;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.color,
    required this.life,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animation;

  ParticlePainter(this.particles, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final currentLife = particle.life * (1 - animation);
      if (currentLife <= 0) continue;

      final paint = Paint()
        ..color = particle.color.withOpacity(currentLife)
        ..style = PaintingStyle.fill;

      final currentX = particle.x + (particle.dx * animation * 100);
      final currentY = particle.y + (particle.dy * animation * 100);

      canvas.drawCircle(
        Offset(currentX, currentY),
        4 * currentLife,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}