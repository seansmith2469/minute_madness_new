// lib/screens/memory_game_screen.dart - ENHANCED WITH PSYCHEDELIC ARROWS - ULTIMATE TOURNAMENT COMPATIBLE
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../services/memory_bot_service.dart';
import 'memory_results_screen.dart';

enum ArrowDirection { up, down, left, right }
enum PatternColor { red, blue, green, yellow, purple, orange }

class PatternElement {
  final ArrowDirection direction;
  final PatternColor? color;

  PatternElement(this.direction, [this.color]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PatternElement &&
              runtimeType == other.runtimeType &&
              direction == other.direction &&
              color == other.color;

  @override
  int get hashCode => direction.hashCode ^ color.hashCode;
}

class MemoryGameScreen extends StatefulWidget {
  final bool isPractice;
  final String tourneyId;
  final Function(Map<String, dynamic>)? onUltimateComplete;

  const MemoryGameScreen({
    super.key,
    required this.isPractice,
    required this.tourneyId,
    this.onUltimateComplete,
  });

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen>
    with TickerProviderStateMixin {
  // Game state
  List<PatternElement> _currentPattern = [];
  List<PatternElement> _playerInput = [];
  int _currentLevel = 1;
  bool _isShowingPattern = false;
  bool _isInputMode = false;
  bool _gameOver = false;
  bool _hasSubmitted = false;
  bool _hasSubmittedBots = false;

  // Track completion time for tiebreakers
  DateTime? _gameStartTime;
  DateTime? _levelStartTime;
  int _totalCompletionTimeMs = 0;

  // ULTIMATE TOURNAMENT VARIABLES
  bool _isUltimateTournament = false;
  DateTime? _ultimateStartTime;
  Timer? _ultimateTimer;
  int _ultimateTimeLeft = 60; // 60 seconds
  int _totalWrongAttempts = 0; // Track across all levels
  int _levelsCompleted = 0;

  // Timers
  Timer? _patternTimer;
  Timer? _inputTimer;
  int _timeRemaining = 5;

  // PSYCHEDELIC ANIMATION CONTROLLERS - MAXIMUM INTENSITY!
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _waveController;
  late AnimationController _arrowFlashController;
  late AnimationController _successController;
  late AnimationController _errorController;
  late AnimationController _levelUpController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  // Database
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // Perfect pattern effects
  bool _showSuccessEffect = false;
  bool _showErrorEffect = false;
  bool _showLevelUpEffect = false;

  // Selected color for color levels
  PatternColor? _selectedColor;

  @override
  void initState() {
    super.initState();

    // Initialize ULTRA PSYCHEDELIC animations
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // SUPER FAST for intensity
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _arrowFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // CHECK IF THIS IS ULTIMATE TOURNAMENT
    _isUltimateTournament = widget.onUltimateComplete != null;

    if (_isUltimateTournament) {
      _ultimateStartTime = DateTime.now();
      _startUltimateTimer();
    }

    // Submit bot results for tournament mode
    if (!widget.isPractice) {
      _submitBotResults();
    }

    _gameStartTime = DateTime.now();
    _startLevel();
  }

  void _startUltimateTimer() {
    _ultimateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _ultimateTimeLeft--;
      });

      if (_ultimateTimeLeft <= 0) {
        timer.cancel();
        _endUltimateTournament();
      }
    });
  }

  void _endUltimateTournament() {
    if (widget.onUltimateComplete == null) return;

    final totalTime = 60 - _ultimateTimeLeft;
    final timeBonus = math.max(0, _ultimateTimeLeft * 5); // 5 points per second remaining

    // SMART SCORING: Heavily penalize wrong attempts
    final baseScore = _levelsCompleted * 200;
    final errorPenalty = _totalWrongAttempts * 50; // 50 points per wrong attempt
    final finalScore = math.max(0, baseScore - errorPenalty + timeBonus);

    // Rank based on final score (higher = better)
    int rank = math.max(1, 65 - (finalScore / 50).round());
    rank = math.min(64, rank);

    final result = {
      'score': finalScore,
      'rank': rank,
      'details': {
        'levelsCompleted': _levelsCompleted,
        'totalWrongAttempts': _totalWrongAttempts,
        'timeUsed': totalTime,
        'timeBonus': timeBonus,
      },
    };

    widget.onUltimateComplete!(result);
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    // ULTRA VIBRANT memory-themed colors
    final memoryColors = [
      Colors.purple.shade900,
      Colors.pink.shade700,
      Colors.indigo.shade800,
      Colors.blue.shade800,
      Colors.cyan.shade600,
      Colors.teal.shade700,
      Colors.green.shade700,
      Colors.lime.shade600,
      Colors.yellow.shade600,
      Colors.orange.shade700,
      Colors.red.shade800,
      Colors.deepPurple.shade900,
      Colors.deepOrange.shade800,
      Colors.amber.shade700,
    ];

    return List.generate(
        10, (_) => memoryColors[random.nextInt(memoryColors.length)]); // MAXIMUM colors
  }

  Future<void> _submitBotResults() async {
    if (_hasSubmittedBots) return;
    _hasSubmittedBots = true;

    try {
      final tourneyDoc = await _db
          .collection('memory_tournaments')
          .doc(widget.tourneyId)
          .get();

      if (!tourneyDoc.exists) return;

      final data = tourneyDoc.data();
      if (data == null || !data.containsKey('bots')) return;

      final botsData = data['bots'] as Map<String, dynamic>?;
      if (botsData == null || botsData.isEmpty) return;

      final allBots = <MemoryBotPlayer>[];

      for (final entry in botsData.entries) {
        try {
          final botData = entry.value as Map<String, dynamic>?;
          if (botData == null) continue;

          final name = botData['name'] as String?;
          final difficultyName = botData['difficulty'] as String?;

          if (name == null || difficultyName == null) continue;

          final difficulty = MemoryBotDifficulty.values.where(
                (d) => d.name == difficultyName,
          ).firstOrNull;

          if (difficulty == null) continue;

          allBots.add(MemoryBotPlayer(
            id: entry.key,
            name: name,
            difficulty: difficulty,
          ));
        } catch (e) {
          continue;
        }
      }

      if (allBots.isNotEmpty) {
        MemoryBotService.submitBotResults(widget.tourneyId, allBots);
      }
    } catch (e) {
      print('Error submitting memory bot results: $e');
    }
  }

  void _startLevel() {
    setState(() {
      _playerInput.clear();
      _isShowingPattern = true;
      _isInputMode = false;
      _showSuccessEffect = false;
      _showErrorEffect = false;
      _showLevelUpEffect = false;
    });

    _levelStartTime = DateTime.now();
    _generatePattern();
    _showPattern();
  }

  void _generatePattern() {
    final random = math.Random();
    final length = _getPatternLength();
    final useColors = _shouldUseColors();

    _currentPattern = List.generate(length, (index) {
      final direction = ArrowDirection.values[random.nextInt(4)];
      PatternColor? color;

      if (useColors) {
        color = PatternColor.values[random.nextInt(PatternColor.values.length)];
      }

      return PatternElement(direction, color);
    });
  }

  int _getPatternLength() {
    if (_currentLevel <= 3) return 2 + _currentLevel; // 3, 4, 5
    if (_currentLevel <= 6) return 3 + _currentLevel; // 7, 8, 9
    if (_currentLevel <= 10) return 4 + _currentLevel; // 11, 12, 13, 14
    return 15 + (_currentLevel - 10); // 15+
  }

  bool _shouldUseColors() {
    return _currentLevel >= 7; // Colors start at level 7
  }

  void _showPattern() {
    int index = 0;
    _patternTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (index >= _currentPattern.length) {
        timer.cancel();
        _startInputPhase();
        return;
      }
      index++;
    });
  }

  void _startInputPhase() {
    setState(() {
      _isShowingPattern = false;
      _isInputMode = true;
      _timeRemaining = 5;
    });

    _inputTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
      });

      if (_timeRemaining <= 0) {
        timer.cancel();
        _triggerErrorEffect();
        _endGame(false);
      }
    });
  }

  void _onArrowTap(ArrowDirection direction, PatternColor? color) {
    if (_gameOver || _hasSubmitted || !_isInputMode) return;
    if (_playerInput.length >= _currentPattern.length) return;

    final expectedElement = _currentPattern[_playerInput.length];
    final useColors = _shouldUseColors();

    PatternColor? finalColor;
    if (useColors) {
      if (_selectedColor == null) {
        _showColorRequiredFeedback();
        return;
      }
      finalColor = _selectedColor;
    }

    final inputElement = PatternElement(direction, finalColor);
    final isCorrect = inputElement == expectedElement;

    if (!isCorrect) {
      _totalWrongAttempts++; // Track for Ultimate Tournament
      _triggerErrorEffect();
      _endGame(false);
      return;
    }

    // CORRECT INPUT - TRIGGER SUCCESS EFFECT!
    _triggerSuccessEffect();
    _arrowFlashController.forward().then((_) => _arrowFlashController.reset());

    _playerInput.add(inputElement);

    if (mounted) {
      setState(() {});
    }

    // Check if pattern complete
    if (_playerInput.length >= _currentPattern.length) {
      if (_levelStartTime != null) {
        final levelTime = DateTime.now().difference(_levelStartTime!).inMilliseconds;
        _totalCompletionTimeMs += levelTime;
      }

      _inputTimer?.cancel();
      _triggerLevelUpEffect();
      _nextLevel();
    }
  }

  void _triggerSuccessEffect() {
    setState(() {
      _showSuccessEffect = true;
    });
    _successController.forward().then((_) {
      _successController.reset();
      setState(() {
        _showSuccessEffect = false;
      });
    });
  }

  void _triggerErrorEffect() {
    setState(() {
      _showErrorEffect = true;
    });
    _errorController.forward().then((_) {
      _errorController.reset();
      setState(() {
        _showErrorEffect = false;
      });
    });
  }

  void _triggerLevelUpEffect() {
    setState(() {
      _showLevelUpEffect = true;
    });
    _levelUpController.forward().then((_) {
      _levelUpController.reset();
      setState(() {
        _showLevelUpEffect = false;
      });
    });
  }

  void _showColorRequiredFeedback() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select a color first!',
            style: GoogleFonts.chicle(color: Colors.white),
          ),
          duration: const Duration(milliseconds: 800),
          backgroundColor: Colors.orange.withOpacity(0.9),
        ),
      );
    }
  }

  void _nextLevel() {
    _levelsCompleted++; // Track for Ultimate Tournament

    if (_isUltimateTournament && _ultimateTimeLeft <= 5) {
      _endUltimateTournament();
      return;
    }

    setState(() {
      _currentLevel++;
    });

    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _startLevel();
      }
    });
  }

  // UPDATED: _endGame method with timeout detection
  void _endGame(bool won) {
    if (_hasSubmitted) return;
    _hasSubmitted = true;

    _inputTimer?.cancel();
    _patternTimer?.cancel();

    setState(() {
      _gameOver = true;
    });

    final finalLevel = _currentLevel;
    final isCompleteFailure = finalLevel == 1 && _playerInput.isEmpty;

    // ULTIMATE TOURNAMENT: End immediately
    if (_isUltimateTournament) {
      _endUltimateTournament();
      return;
    }

    // FIXED: Check if player didn't complete even level 1
    if (!widget.isPractice) {
      // Submit result with special handling for complete failures
      if (isCompleteFailure) {
        _submitWorstPossibleResult(); // New method for last place
      } else {
        _submitResult();
      }

      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MemoryResultsScreen(
                tourneyId: widget.tourneyId,
                playerLevel: finalLevel,
              ),
            ),
          );
        }
      });
    } else {
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _showGameOverDialog(won, isCompleteFailure);
        }
      });
    }
  }

  // Enhanced psychedelic arrow element with colorful directions
  Widget _buildPsychedelicArrowElement(PatternElement element, int index, double size, bool isPattern) {
    // Get colorful arrow color instead of just white
    final arrowColor = element.color != null
        ? _getColorFromEnum(element.color!)
        : _getArrowDirectionColor(element.direction); // New method for colorful arrows

    return AnimatedBuilder(
      animation: _arrowFlashController,
      builder: (context, child) {
        final flash = isPattern ? 0.0 : _arrowFlashController.value;
        final glowIntensity = 0.7 + (flash * 0.3);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                arrowColor.withOpacity(0.9),
                arrowColor.withOpacity(0.6),
                arrowColor.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: arrowColor.withOpacity(0.8 + (flash * 0.2)),
              width: 2 + (flash * 2),
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: arrowColor.withOpacity(glowIntensity),
                blurRadius: 12 + (flash * 8),
                spreadRadius: 3 + (flash * 2),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(glowIntensity * 0.5),
                blurRadius: 6 + (flash * 4),
                spreadRadius: 1 + flash,
              ),
            ],
          ),
          child: Icon(
            _getIconFromDirection(element.direction),
            color: Colors.white,
            size: size * 0.6,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 4,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        );
      },
    );
  }

  // NEW: Get colorful colors for arrow directions when no specific color is set
  Color _getArrowDirectionColor(ArrowDirection direction) {
    switch (direction) {
      case ArrowDirection.up:
        return Colors.cyan.shade400;
      case ArrowDirection.down:
        return Colors.orange.shade400;
      case ArrowDirection.left:
        return Colors.green.shade400;
      case ArrowDirection.right:
        return Colors.purple.shade400;
    }
  }

  // Enhanced psychedelic arrow button with colorful direction-based styling
  Widget _buildPsychedelicArrowButton(ArrowDirection direction) {
    final directionColor = _getArrowDirectionColor(direction);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = 1.0 + (_pulseController.value * 0.1);
        final glow = 0.4 + (_pulseController.value * 0.4);

        return Transform.scale(
          scale: pulse,
          child: GestureDetector(
            onTap: () {
              final useColors = _shouldUseColors();
              final colorToUse = useColors ? _selectedColor : null;
              _onArrowTap(direction, colorToUse);
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    directionColor.withOpacity(0.9),
                    directionColor.withOpacity(0.7),
                    directionColor.withOpacity(0.5),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: directionColor.withOpacity(glow),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(glow * 0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _getIconFromDirection(direction),
                color: Colors.white,
                size: 40,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Enhanced color grid with enhanced visual effects
  Widget _buildPsychedelicColorGrid() {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Wrap(
          spacing: 12, // Increased spacing
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: PatternColor.values.map((color) {
            final isSelected = _selectedColor == color;
            final colorValue = _getColorFromEnum(color);

            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = isSelected ? 1.0 + (_pulseController.value * 0.3) : 1.0;
                final glow = isSelected ? 0.8 + (_pulseController.value * 0.4) : 0.4;

                return Transform.scale(
                  scale: pulse,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 55, // Slightly larger
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            colorValue.withOpacity(0.95),
                            colorValue.withOpacity(0.8),
                            colorValue.withOpacity(0.6),
                          ],
                        ),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                          width: isSelected ? 4 : 2,
                        ),
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: [
                          BoxShadow(
                            color: colorValue.withOpacity(glow),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                          if (isSelected)
                            BoxShadow(
                              color: Colors.white.withOpacity(0.9),
                              blurRadius: 25,
                              spreadRadius: 6,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 2,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      )
                          : null,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _submitResult() async {
    try {
      await _db
          .collection('memory_tournaments')
          .doc(widget.tourneyId)
          .collection('results')
          .doc(_uid)
          .set({
        'uid': _uid,
        'level': _currentLevel,
        'completionTimeMs': _totalCompletionTimeMs,
        'submittedAt': FieldValue.serverTimestamp(),
        'isBot': false,
      });
    } catch (e) {
      print('Error submitting memory result: $e');
    }
  }

  // NEW METHOD: Submit worst possible result for timeouts
  Future<void> _submitWorstPossibleResult() async {
    try {
      await _db
          .collection('memory_tournaments')
          .doc(widget.tourneyId)
          .collection('results')
          .doc(_uid)
          .set({
        'uid': _uid,
        'level': 0, // SPECIAL: Level 0 = complete failure/timeout
        'completionTimeMs': 999999, // Worst possible time
        'submittedAt': FieldValue.serverTimestamp(),
        'isBot': false,
        'timedOut': true, // Flag for complete failure
      });

      print('Submitted timeout result: level 0 (automatic last place)');
    } catch (e) {
      print('Error submitting timeout result: $e');
    }
  }

  // UPDATED: Enhanced dialog for practice mode
  void _showGameOverDialog(bool won, bool isCompleteFailure) {
    String title;
    String message;

    if (isCompleteFailure) {
      title = '⏰ Time\'s Up!';
      message = 'You didn\'t complete even the first pattern!\n\n'
          'The first level only has 3 arrows - anyone can do it!\n\n'
          'Try focusing and tapping faster next time.';
    } else {
      title = won ? '🎉 Victory!' : '💥 Game Over';
      message = 'You reached Level $_currentLevel!\n\n'
          '${won ? 'Incredible memory skills!' : 'Better luck next time!'}';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.purple.shade900.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isCompleteFailure
                ? [Colors.red, Colors.orange, Colors.yellow]
                : won
                ? [Colors.yellow, Colors.orange, Colors.red]
                : [Colors.red, Colors.orange, Colors.purple],
          ).createShader(bounds),
          child: Text(
            title,
            style: GoogleFonts.creepster(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.chicle(
            fontSize: 16,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: isCompleteFailure
                    ? [Colors.red.withOpacity(0.8), Colors.orange.withOpacity(0.8)]
                    : [Colors.cyan.withOpacity(0.8), Colors.blue.withOpacity(0.8)],
              ),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(
                isCompleteFailure ? 'Try Again!' : (widget.isPractice ? 'Try Again' : 'Return to Lobby'),
                style: GoogleFonts.chicle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _patternTimer?.cancel();
    _inputTimer?.cancel();
    _ultimateTimer?.cancel(); // Cancel Ultimate Tournament timer
    _backgroundController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    _waveController.dispose();
    _arrowFlashController.dispose();
    _successController.dispose();
    _errorController.dispose();
    _levelUpController.dispose();
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
              // PSYCHEDELIC BACKGROUND - ULTRA INTENSE!
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: interpolatedColors,
                    center: Alignment.center,
                    radius: 2.0,
                    stops: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0],
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
                          interpolatedColors[3].withOpacity(0.4),
                          Colors.transparent,
                          interpolatedColors[7].withOpacity(0.3),
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

              // WAVE OVERLAY
              AnimatedBuilder(
                animation: _waveController,
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
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        transform: GradientRotation(_waveController.value * -4.28),
                      ),
                    ),
                  );
                },
              ),

              // SUCCESS EFFECT - GREEN EXPLOSION!
              if (_showSuccessEffect)
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

              // ERROR EFFECT - RED EXPLOSION!
              if (_showErrorEffect)
                AnimatedBuilder(
                  animation: _errorController,
                  builder: (context, child) {
                    final explosion = _errorController.value;
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
                          radius: explosion * 3.0,
                        ),
                      ),
                    );
                  },
                ),

              // LEVEL UP EFFECT - RAINBOW EXPLOSION!
              if (_showLevelUpEffect)
                AnimatedBuilder(
                  animation: _levelUpController,
                  builder: (context, child) {
                    final explosion = _levelUpController.value;
                    final rotation = explosion * 6.28;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: SweepGradient(
                          colors: [
                            Colors.red.withOpacity(0.8 * (1 - explosion)),
                            Colors.orange.withOpacity(0.8 * (1 - explosion)),
                            Colors.yellow.withOpacity(0.8 * (1 - explosion)),
                            Colors.green.withOpacity(0.8 * (1 - explosion)),
                            Colors.blue.withOpacity(0.8 * (1 - explosion)),
                            Colors.purple.withOpacity(0.8 * (1 - explosion)),
                            Colors.pink.withOpacity(0.8 * (1 - explosion)),
                            Colors.red.withOpacity(0.8 * (1 - explosion)),
                          ],
                          center: Alignment.center,
                          transform: GradientRotation(rotation),
                        ),
                      ),
                    );
                  },
                ),

              // MAIN CONTENT WITH FIXED LAYOUT
              SafeArea(
                child: Column(
                  children: [
                    // PSYCHEDELIC HEADER
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedBuilder(
                            animation: _scaleController,
                            builder: (context, child) {
                              final scale = 1.0 + (_scaleController.value * 0.1);
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
                                      'Level $_currentLevel',
                                      style: GoogleFonts.creepster(
                                        fontSize: 24,
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
                          // Ultimate Tournament timer or regular input timer
                          if (_isUltimateTournament)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final intensity = _ultimateTimeLeft <= 10 ? 0.7 + (_pulseController.value * 0.3) : 0.7;
                                final timerColor = _ultimateTimeLeft <= 10 ? Colors.red : Colors.orange;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: timerColor.withOpacity(intensity),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: timerColor.withOpacity(0.5),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Time: ${_ultimateTimeLeft}s',
                                        style: GoogleFonts.chicle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Errors: $_totalWrongAttempts',
                                        style: GoogleFonts.chicle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else if (_isInputMode)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final intensity = 0.7 + (_pulseController.value * 0.3);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(intensity),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.8),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Time: ${_timeRemaining}s',
                                    style: GoogleFonts.chicle(
                                      fontSize: 18,
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

                    // GAME STATUS WITH PSYCHEDELIC STYLING
                    AnimatedBuilder(
                      animation: _scaleController,
                      builder: (context, child) {
                        final scale = 1.0 + (_scaleController.value * 0.05);
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
                                _isShowingPattern ? '👁️ Watch the Pattern!' :
                                _isInputMode ? '🧠 Reproduce the Pattern!' : '⚡ Get Ready...',
                                style: GoogleFonts.creepster(
                                  fontSize: 20,
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

                    const SizedBox(height: 20),

                    // PATTERN DISPLAY AREA - FIXED SIZE
                    SizedBox(
                      height: 180, // Fixed height for pattern area
                      child: _isShowingPattern
                          ? _buildPsychedelicPatternDisplay()
                          : AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final glow = 0.3 + (_pulseController.value * 0.4);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(glow),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: interpolatedColors[4].withOpacity(glow),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Center(
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [Colors.yellow, Colors.orange, Colors.red],
                                ).createShader(bounds),
                                child: Text(
                                  '🎯 Now repeat the pattern!',
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
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // INPUT AREA - EXPANDED TO FILL REMAINING SPACE
                    Expanded(
                      child: SingleChildScrollView( // ADDED: ScrollView for overflow protection
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 40), // ADDED: Bottom padding to prevent cutoff
                          child: _buildPsychedelicInputArea(),
                        ),
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

  Widget _buildPsychedelicPatternDisplay() {
    if (_currentPattern.isEmpty) return const SizedBox();

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.5 + (_pulseController.value * 0.5);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: RadialGradient(
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.purple.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(glow),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(glow * 0.5),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Colors.cyan, Colors.purple, Colors.pink],
                ).createShader(bounds),
                child: Text(
                  'Pattern: (${_currentPattern.length} arrows)',
                  style: GoogleFonts.creepster(
                    fontSize: 16,
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
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: _buildPsychedelicArrowGrid(_currentPattern, true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPsychedelicArrowGrid(List<PatternElement> elements, bool isPattern) {
    if (elements.isEmpty) return const SizedBox();

    double arrowSize;
    int itemsPerRow;

    if (elements.length <= 6) {
      arrowSize = 50;
      itemsPerRow = 6;
    } else if (elements.length <= 12) {
      arrowSize = 40;
      itemsPerRow = 6;
    } else if (elements.length <= 18) {
      arrowSize = 35;
      itemsPerRow = 6;
    } else {
      arrowSize = 30;
      itemsPerRow = 8;
    }

    final rows = <List<PatternElement>>[];
    for (int i = 0; i < elements.length; i += itemsPerRow) {
      final end = (i + itemsPerRow < elements.length) ? i + itemsPerRow : elements.length;
      rows.add(elements.sublist(i, end));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.asMap().entries.map((rowEntry) {
        final rowIndex = rowEntry.key;
        final row = rowEntry.value;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.asMap().entries.map((entry) {
              final colIndex = entry.key;
              final element = entry.value;
              final globalIndex = (rowIndex * itemsPerRow) + colIndex;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildPsychedelicArrowElement(element, globalIndex, arrowSize, isPattern),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPsychedelicInputArea() {
    final useColors = _shouldUseColors();

    return Column(
      children: [
        // YOUR INPUT HEADER
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
                      _currentColors[1].withOpacity(0.8),
                      _currentColors[4].withOpacity(0.6),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, Colors.yellow, Colors.cyan],
                  ).createShader(bounds),
                  child: Text(
                    'Your Input: (${_playerInput.length}/${_currentPattern.length})',
                    style: GoogleFonts.creepster(
                      fontSize: 16,
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
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        // PLAYER INPUT DISPLAY
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(10),
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
          child: _playerInput.isEmpty
              ? Container(
            height: 60,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final opacity = 0.3 + (_pulseController.value * 0.4);
                  return Text(
                    '✨ Your arrows will appear here ✨',
                    style: GoogleFonts.chicle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(opacity),
                      shadows: [
                        Shadow(
                          color: Colors.purple.withOpacity(0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          )
              : _buildPsychedelicArrowGrid(_playerInput, false),
        ),

        const SizedBox(height: 30),

        // INPUT CONTROLS
        if (_isInputMode) ...[
          _buildPsychedelicArrowControls(),

          if (useColors) ...[
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) {
                final scale = 1.0 + (_scaleController.value * 0.03);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        colors: [
                          _currentColors[3].withOpacity(0.7),
                          _currentColors[7].withOpacity(0.5),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '🎨 Select Color:',
                      style: GoogleFonts.chicle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 3,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildPsychedelicColorGrid(),
            const SizedBox(height: 20), // ADDED: Extra spacing at bottom
          ],
        ],
      ],
    );
  }

  Widget _buildPsychedelicArrowControls() {
    return Column(
      children: [
        // Up arrow
        _buildPsychedelicArrowButton(ArrowDirection.up),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPsychedelicArrowButton(ArrowDirection.left),
            const SizedBox(width: 20),
            _buildPsychedelicArrowButton(ArrowDirection.right),
          ],
        ),
        const SizedBox(height: 10),
        _buildPsychedelicArrowButton(ArrowDirection.down),
      ],
    );
  }

  IconData _getIconFromDirection(ArrowDirection direction) {
    switch (direction) {
      case ArrowDirection.up:
        return Icons.keyboard_arrow_up;
      case ArrowDirection.down:
        return Icons.keyboard_arrow_down;
      case ArrowDirection.left:
        return Icons.keyboard_arrow_left;
      case ArrowDirection.right:
        return Icons.keyboard_arrow_right;
    }
  }

  Color _getColorFromEnum(PatternColor color) {
    switch (color) {
      case PatternColor.red:
        return Colors.red;
      case PatternColor.blue:
        return Colors.blue;
      case PatternColor.green:
        return Colors.green;
      case PatternColor.yellow:
        return Colors.yellow;
      case PatternColor.purple:
        return Colors.purple;
      case PatternColor.orange:
        return Colors.orange;
    }
  }
}