// lib/screens/maze_game_screen.dart - MAZE MADNESS LAST MAN STANDING - ULTIMATE TOURNAMENT COMPATIBLE
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../services/maze_bot_service.dart'; // ADDED: Import for bot service
import 'maze_results_screen.dart';

// Maze cell types
enum CellType { wall, path, start, goal, player }

// Game phases
enum GamePhase { study, memory, navigate, complete, failed }

// Maze cell class
class MazeCell {
  final int x, y;
  final CellType type;
  bool isVisited;
  bool isCorrectPath;

  MazeCell({
    required this.x,
    required this.y,
    required this.type,
    this.isVisited = false,
    this.isCorrectPath = false,
  });
}

class MazeGameScreen extends StatefulWidget {
  final bool isPractice;
  final String survivalId;
  final int round;
  final Function(Map<String, dynamic>)? onUltimateComplete;

  const MazeGameScreen({
    super.key,
    required this.isPractice,
    required this.survivalId,
    this.round = 1,
    this.onUltimateComplete,
  });

  @override
  State<MazeGameScreen> createState() => _MazeGameScreenState();
}

class _MazeGameScreenState extends State<MazeGameScreen>
    with TickerProviderStateMixin {
  // Game state
  List<List<MazeCell>> _maze = [];
  int _playerX = 1, _playerY = 1;
  int _goalX = 0, _goalY = 0;
  GamePhase _currentPhase = GamePhase.study;
  int _currentRound = 1;
  bool _hasSubmitted = false;

  // Timing
  late Timer _phaseTimer;
  int _studyTimeLeft = 5;
  int _navigateTimeLeft = 30;
  DateTime? _startTime;
  int _completionTimeMs = 0;
  int _wrongMoves = 0;

  // ULTIMATE TOURNAMENT VARIABLES
  bool _isUltimateTournament = false;
  DateTime? _ultimateStartTime;
  Timer? _ultimateTimer;
  int _ultimateTimeLeft = 60; // 60 seconds
  int _totalWrongMoves = 0; // Track across all rounds
  int _roundsCompleted = 0;

  // Maze generation
  late int _mazeSize;
  List<List<int>> _correctPath = [];

  // PSYCHEDELIC ANIMATIONS
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _rotationController;
  late AnimationController _flashController;
  late AnimationController _successController;
  late AnimationController _errorController;

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  // Database
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // FIXED: Bot result triggering method
  Future<void> _triggerBotResults() async {
    if (widget.isPractice) return;

    try {
      print('🧩 Triggering bot results submission for round $_currentRound');

      // Get all bots for this survival
      final bots = await MazeBotService.getBotsForSurvival(widget.survivalId);

      if (bots.isNotEmpty) {
        print('🧩 Found ${bots.length} bots, submitting their results');

        // Submit bot results for this round
        await MazeBotService.submitBotResults(widget.survivalId, _currentRound, bots);

        print('🧩 Bot results submission triggered successfully');
      } else {
        print('🧩 No bots found for survival ${widget.survivalId}');
      }
    } catch (e) {
      print('🧩 Error triggering bot results: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize psychedelic animations
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _backgroundController.forward(from: 0);
      }
    })..forward();

    _pulsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // CHECK IF THIS IS ULTIMATE TOURNAMENT
    _isUltimateTournament = widget.onUltimateComplete != null;

    if (_isUltimateTournament) {
      _ultimateStartTime = DateTime.now();
      _startUltimateTimer();
    }

    _currentRound = widget.round;
    _initializeRound();
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

    // SMART SCORING: Heavily penalize wrong moves
    final baseScore = _roundsCompleted * 1000;
    final errorPenalty = _totalWrongMoves * 100; // 100 points per wrong move
    final finalScore = math.max(0, baseScore - errorPenalty + timeBonus);

    // Rank based on final score (higher = better)
    int rank = math.max(1, 65 - (finalScore / 100).round());
    rank = math.min(64, rank);

    final result = {
      'score': finalScore,
      'rank': rank,
      'details': {
        'roundsCompleted': _roundsCompleted,
        'totalWrongMoves': _totalWrongMoves,
        'timeUsed': totalTime,
        'timeBonus': timeBonus,
      },
    };

    widget.onUltimateComplete!(result);
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    final mazeColors = [
      Colors.purple.shade800,
      Colors.pink.shade600,
      Colors.indigo.shade700,
      Colors.blue.shade700,
      Colors.cyan.shade500,
      Colors.teal.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.red.shade700,
      Colors.deepPurple.shade700,
    ];

    return List.generate(
        6, (_) => mazeColors[random.nextInt(mazeColors.length)]);
  }

  void _initializeRound() {
    // Calculate maze parameters based on round
    _mazeSize = _getMazeSizeForRound(_currentRound);
    _studyTimeLeft = _getStudyTimeForRound(_currentRound);
    _navigateTimeLeft = _getNavigateTimeForRound(_currentRound);

    // Generate new maze
    _generateMaze();

    // Reset game state
    _currentPhase = GamePhase.study;
    _wrongMoves = 0;
    _startTime = DateTime.now();

    setState(() {});

    // Start study phase timer
    _startPhaseTimer();
  }

  int _getMazeSizeForRound(int round) {
    switch (round) {
      case 1: return 7;   // 7x7 - easy start
      case 2: return 9;   // 9x9 - getting harder
      case 3: return 11;  // 11x11 - medium
      case 4: return 13;  // 13x13 - hard
      case 5: return 15;  // 15x15 - very hard
      case 6: return 17;  // 17x17 - ultimate
      default: return 7;
    }
  }

  int _getStudyTimeForRound(int round) {
    switch (round) {
      case 1: return 5;   // 5 seconds
      case 2: return 4;   // 4 seconds
      case 3: return 4;   // 4 seconds
      case 4: return 3;   // 3 seconds
      case 5: return 3;   // 3 seconds
      case 6: return 2;   // 2 seconds - brutal!
      default: return 5;
    }
  }

  int _getNavigateTimeForRound(int round) {
    switch (round) {
      case 1: return 45;  // 45 seconds
      case 2: return 40;  // 40 seconds
      case 3: return 35;  // 35 seconds
      case 4: return 30;  // 30 seconds
      case 5: return 25;  // 25 seconds
      case 6: return 20;  // 20 seconds - pressure!
      default: return 45;
    }
  }

  void _generateMaze() {
    // Initialize maze with walls
    _maze = List.generate(_mazeSize, (y) =>
        List.generate(_mazeSize, (x) =>
            MazeCell(x: x, y: y, type: CellType.wall)));

    // Simple maze generation - create a solvable path
    _carvePath(1, 1);

    // Set start and goal
    _maze[1][1] = MazeCell(x: 1, y: 1, type: CellType.start);
    _maze[_mazeSize - 2][_mazeSize - 2] = MazeCell(
        x: _mazeSize - 2, y: _mazeSize - 2, type: CellType.goal);

    _playerX = 1;
    _playerY = 1;
    _goalX = _mazeSize - 2;
    _goalY = _mazeSize - 2;

    // Find correct path for validation
    _findCorrectPath();
  }

  void _carvePath(int x, int y) {
    final random = math.Random();
    final directions = [[0, 2], [2, 0], [0, -2], [-2, 0]];
    directions.shuffle(random);

    _maze[y][x] = MazeCell(x: x, y: y, type: CellType.path);

    for (final dir in directions) {
      final newX = x + dir[0];
      final newY = y + dir[1];

      if (newX > 0 && newX < _mazeSize - 1 &&
          newY > 0 && newY < _mazeSize - 1 &&
          _maze[newY][newX].type == CellType.wall) {
        // Carve path between current and new cell
        _maze[y + dir[1] ~/ 2][x + dir[0] ~/ 2] =
            MazeCell(x: x + dir[0] ~/ 2, y: y + dir[1] ~/ 2, type: CellType.path);
        _carvePath(newX, newY);
      }
    }
  }

  void _findCorrectPath() {
    // Simple BFS to find path from start to goal
    _correctPath = [];
    final queue = [<int>[1, 1]]; // Start position
    final visited = <String>{};
    final parent = <String, List<int>>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final key = '${current[0]},${current[1]}';

      if (visited.contains(key)) continue;
      visited.add(key);

      if (current[0] == _goalX && current[1] == _goalY) {
        // Reconstruct path
        List<int>? pathPoint = current;
        while (pathPoint != null) {
          _correctPath.insert(0, pathPoint);
          pathPoint = parent['${pathPoint[0]},${pathPoint[1]}'];
        }
        break;
      }

      // Check neighbors
      for (final dir in [[0, 1], [1, 0], [0, -1], [-1, 0]]) {
        final newX = current[0] + dir[0];
        final newY = current[1] + dir[1];
        final newKey = '$newX,$newY';

        if (newX >= 0 && newX < _mazeSize &&
            newY >= 0 && newY < _mazeSize &&
            !visited.contains(newKey) &&
            (_maze[newY][newX].type == CellType.path ||
                _maze[newY][newX].type == CellType.goal)) {
          parent[newKey] = current;
          queue.add([newX, newY]);
        }
      }
    }

    // Mark correct path cells
    for (final point in _correctPath) {
      if (_maze[point[1]][point[0]].type == CellType.path) {
        _maze[point[1]][point[0]].isCorrectPath = true;
      }
    }
  }

  void _startPhaseTimer() {
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        switch (_currentPhase) {
          case GamePhase.study:
            _studyTimeLeft--;
            if (_studyTimeLeft <= 0) {
              _currentPhase = GamePhase.memory;
              timer.cancel();
              Timer(const Duration(seconds: 1), () {
                setState(() {
                  _currentPhase = GamePhase.navigate;
                });
                _startNavigationTimer();
              });
            }
            break;
          case GamePhase.navigate:
            _navigateTimeLeft--;
            if (_navigateTimeLeft <= 0) {
              timer.cancel();
              _failRound();
            }
            break;
          default:
            break;
        }
      });
    });
  }

  void _startNavigationTimer() {
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _navigateTimeLeft--;
        if (_navigateTimeLeft <= 0) {
          timer.cancel();
          _failRound();
        }
      });
    });
  }

  void _movePlayer(int deltaX, int deltaY) {
    if (_currentPhase != GamePhase.navigate) return;

    final newX = _playerX + deltaX;
    final newY = _playerY + deltaY;

    // Check bounds
    if (newX < 0 || newX >= _mazeSize || newY < 0 || newY >= _mazeSize) {
      return;
    }

    // Check if it's a valid move (not a wall)
    if (_maze[newY][newX].type == CellType.wall) {
      _wrongMoves++;
      _totalWrongMoves++; // Track total for Ultimate Tournament
      _triggerErrorEffect();
      HapticFeedback.mediumImpact();
      return;
    }

    // Check if it's a wrong path
    if (_maze[newY][newX].type == CellType.path && !_maze[newY][newX].isCorrectPath) {
      _wrongMoves++;
      _totalWrongMoves++; // Track total for Ultimate Tournament
      _triggerErrorEffect();
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }

    // Move player
    setState(() {
      _playerX = newX;
      _playerY = newY;
      _maze[newY][newX].isVisited = true;
    });

    // Check if reached goal
    if (newX == _goalX && newY == _goalY) {
      _completeRound();
    }
  }

  void _triggerErrorEffect() {
    _errorController.forward().then((_) => _errorController.reset());
  }

  void _triggerSuccessEffect() {
    _successController.forward().then((_) => _successController.reset());
  }

  void _completeRound() {
    _phaseTimer.cancel();
    final endTime = DateTime.now();
    _completionTimeMs = endTime.difference(_startTime!).inMilliseconds;

    setState(() {
      _currentPhase = GamePhase.complete;
    });

    _triggerSuccessEffect();
    HapticFeedback.heavyImpact();

    // INCREMENT ROUNDS COMPLETED
    _roundsCompleted++;

    // ULTIMATE TOURNAMENT: Continue to next round if time remaining
    if (_isUltimateTournament) {
      if (_ultimateTimeLeft <= 0) {
        _endUltimateTournament();
        return;
      }

      Timer(const Duration(seconds: 1), () {
        if (mounted && _ultimateTimeLeft > 10) { // Need at least 10 seconds for next round
          _currentRound++;
          _initializeRound(); // Start next round
        } else {
          _endUltimateTournament(); // Time almost up, end now
        }
      });
      return;
    }

    if (!widget.isPractice) {
      _submitRoundResult(true);
    }

    // Show success briefly, then proceed
    Timer(const Duration(seconds: 2), () {
      if (widget.isPractice) {
        _startNextRound();
      } else {
        _navigateToResults();
      }
    });
  }

  void _failRound() {
    _phaseTimer.cancel();
    final endTime = DateTime.now();
    _completionTimeMs = endTime.difference(_startTime!).inMilliseconds;

    setState(() {
      _currentPhase = GamePhase.failed;
    });

    _triggerErrorEffect();
    HapticFeedback.heavyImpact();

    // ULTIMATE TOURNAMENT: End immediately on failure
    if (_isUltimateTournament) {
      _endUltimateTournament();
      return;
    }

    if (!widget.isPractice) {
      _submitRoundResult(false);
    }

    Timer(const Duration(seconds: 2), () {
      if (widget.isPractice) {
        _initializeRound(); // Restart same round in practice
      } else {
        _navigateToResults();
      }
    });
  }

  void _startNextRound() {
    if (_currentRound < 6) {
      _currentRound++;
      _initializeRound();
    } else {
      // Completed all rounds in practice
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.purple.shade900.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.yellow, Colors.orange, Colors.red],
          ).createShader(bounds),
          child: Text(
            'Maze Master!',
            style: GoogleFonts.creepster(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Text(
          'You completed all 6 rounds!\n\nYour maze navigation skills are incredible!\n\nReady for the real survival challenge?',
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
                colors: [Colors.cyan.withOpacity(0.8), Colors.blue.withOpacity(0.8)],
              ),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: Text(
                'Challenge More Mazes',
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

  // FIXED: Submit round result with bot triggering
  Future<void> _submitRoundResult(bool completed) async {
    if (_hasSubmitted) return;
    _hasSubmitted = true;

    try {
      // Submit player result with unique ID per round
      await _db
          .collection('maze_survival')
          .doc(widget.survivalId)
          .collection('results')
          .doc('${_uid}_round_$_currentRound')
          .set({
        'uid': _uid,
        'round': _currentRound,
        'completed': completed,
        'completionTimeMs': _completionTimeMs,
        'wrongMoves': _wrongMoves,
        'submittedAt': FieldValue.serverTimestamp(),
        'isBot': false,
      });

      print('🧩 Player result submitted for round $_currentRound');

      // TRIGGER BOT RESULTS after player submits
      await _triggerBotResults();

    } catch (e) {
      print('Error submitting maze result: $e');
    }
  }

  void _navigateToResults() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MazeResultsScreen(
          survivalId: widget.survivalId,
          playerRound: _currentRound,
          completed: _currentPhase == GamePhase.complete,
          completionTime: _completionTimeMs,
          wrongMoves: _wrongMoves,
          isPractice: widget.isPractice,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phaseTimer.cancel();
    _ultimateTimer?.cancel(); // Cancel Ultimate Tournament timer
    _backgroundController.dispose();
    _pulsController.dispose();
    _rotationController.dispose();
    _flashController.dispose();
    _successController.dispose();
    _errorController.dispose();
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
                    stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // ROTATING OVERLAY
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.3),
                          Colors.transparent,
                          interpolatedColors[4].withOpacity(0.2),
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

              // ERROR FLASH
              if (_errorController.isAnimating)
                AnimatedBuilder(
                  animation: _errorController,
                  builder: (context, child) {
                    final flash = _errorController.value;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.red.withOpacity(0.6 * (1 - flash)),
                            Colors.orange.withOpacity(0.4 * (1 - flash)),
                            Colors.transparent,
                          ],
                          center: Alignment.center,
                          radius: flash * 2.0,
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
                    _buildPsychedelicHeader(interpolatedColors),

                    // PHASE INDICATOR
                    _buildPhaseIndicator(interpolatedColors),

                    const SizedBox(height: 10),

                    // MAZE
                    Expanded(
                      child: Center(
                        child: _buildPsychedelicMaze(interpolatedColors),
                      ),
                    ),

                    // CONTROLS (only during navigation)
                    if (_currentPhase == GamePhase.navigate)
                      _buildControls(interpolatedColors),

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

  Widget _buildPsychedelicHeader(List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Round indicator
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
                        colors[0].withOpacity(0.9),
                        colors[3].withOpacity(0.7),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
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
                      'Round $_currentRound/6',
                      style: GoogleFonts.creepster(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Timer and error display for Ultimate Tournament
          if (_isUltimateTournament)
            AnimatedBuilder(
              animation: _pulsController,
              builder: (context, child) {
                final intensity = _ultimateTimeLeft <= 10 ? 0.7 + (_pulsController.value * 0.3) : 0.7;
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
                        'Errors: $_totalWrongMoves',
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
          else if (_wrongMoves > 0)
          // Regular tournament wrong moves display
            AnimatedBuilder(
              animation: _pulsController,
              builder: (context, child) {
                final intensity = 0.7 + (_pulsController.value * 0.3);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(intensity),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Text(
                    'Wrong: $_wrongMoves',
                    style: GoogleFonts.chicle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator(List<Color> colors) {
    String phaseText;
    Color phaseColor;
    String timeText = '';

    switch (_currentPhase) {
      case GamePhase.study:
        phaseText = '👁️ Study the maze!';
        phaseColor = Colors.cyan;
        timeText = '${_studyTimeLeft}s';
        break;
      case GamePhase.memory:
        phaseText = '🌑 Memorizing...';
        phaseColor = Colors.purple;
        break;
      case GamePhase.navigate:
        phaseText = '🧭 Navigate to the goal!';
        phaseColor = Colors.orange;
        timeText = '${_navigateTimeLeft}s';
        break;
      case GamePhase.complete:
        phaseText = '🎉 Maze completed!';
        phaseColor = Colors.green;
        break;
      case GamePhase.failed:
        phaseText = '💥 Round failed!';
        phaseColor = Colors.red;
        break;
    }

    return AnimatedBuilder(
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
                  phaseColor.withOpacity(0.8),
                  colors[2].withOpacity(0.6),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, Colors.yellow, Colors.white],
                  ).createShader(bounds),
                  child: Text(
                    phaseText,
                    style: GoogleFonts.creepster(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (timeText.isNotEmpty)
                  Text(
                    timeText,
                    style: GoogleFonts.chicle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPsychedelicMaze(List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        // FIXED: Opaque background so maze colors are clearly visible
        color: Colors.black.withOpacity(0.9), // Dark opaque background
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
          // Add psychedelic glow around the maze border
          BoxShadow(
            color: colors[1].withOpacity(0.6),
            blurRadius: 30,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: colors[3].withOpacity(0.4),
            blurRadius: 40,
            spreadRadius: 12,
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / _mazeSize;

            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _mazeSize,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
              ),
              itemCount: _mazeSize * _mazeSize,
              itemBuilder: (context, index) {
                final x = index % _mazeSize;
                final y = index ~/ _mazeSize;
                final cell = _maze[y][x];

                return _buildMazeCell(cell, cellSize, colors);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMazeCell(MazeCell cell, double size, List<Color> colors) {
    Color cellColor;
    Widget? cellChild;

    // Determine cell appearance based on phase and type
    if (_currentPhase == GamePhase.study) {
      // During study phase, show everything with clear, distinct colors
      switch (cell.type) {
        case CellType.wall:
          cellColor = Colors.grey.shade800; // Dark grey walls
          break;
        case CellType.path:
        // FIXED: More distinct colors for correct vs wrong paths
          cellColor = cell.isCorrectPath
              ? Colors.green.shade600 // Bright green for correct path
              : Colors.grey.shade600; // Medium grey for other paths
          break;
        case CellType.start:
          cellColor = Colors.blue.shade600; // Blue start
          cellChild = const Icon(Icons.play_arrow, color: Colors.white, size: 16);
          break;
        case CellType.goal:
          cellColor = Colors.orange.shade600; // Orange goal
          cellChild = const Icon(Icons.flag, color: Colors.white, size: 16);
          break;
        default:
          cellColor = Colors.black;
      }
    } else if (_currentPhase == GamePhase.memory) {
      // During memory phase, everything is dark
      cellColor = Colors.grey.shade900;
    } else {
      // During navigation, show clear feedback
      if (cell.x == _playerX && cell.y == _playerY) {
        cellColor = Colors.yellow.shade400; // Bright yellow player
        cellChild = AnimatedBuilder(
          animation: _pulsController,
          builder: (context, child) {
            final scale = 1.0 + (_pulsController.value * 0.3);
            return Transform.scale(
              scale: scale,
              child: const Icon(Icons.person, color: Colors.black, size: 16),
            );
          },
        );
      } else if (cell.x == _goalX && cell.y == _goalY) {
        cellColor = Colors.orange.shade600;
        cellChild = const Icon(Icons.flag, color: Colors.white, size: 16);
      } else if (cell.isVisited) {
        // FIXED: Very clear feedback for visited paths
        cellColor = cell.isCorrectPath
            ? Colors.green.shade400  // Bright green for correct moves
            : Colors.red.shade400;   // Bright red for wrong moves
      } else {
        cellColor = Colors.grey.shade900; // Dark unvisited
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cellColor,
        border: Border.all(color: Colors.black, width: 0.5), // Black borders for definition
      ),
      child: cellChild,
    );
  }

  Widget _buildControls(List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Up
          _buildControlButton(Icons.keyboard_arrow_up, () => _movePlayer(0, -1), colors),
          const SizedBox(height: 10),
          // Left and Right
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(Icons.keyboard_arrow_left, () => _movePlayer(-1, 0), colors),
              const SizedBox(width: 20),
              _buildControlButton(Icons.keyboard_arrow_right, () => _movePlayer(1, 0), colors),
            ],
          ),
          const SizedBox(height: 10),
          // Down
          _buildControlButton(Icons.keyboard_arrow_down, () => _movePlayer(0, 1), colors),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed, List<Color> colors) {
    return AnimatedBuilder(
      animation: _pulsController,
      builder: (context, child) {
        final scale = 1.0 + (_pulsController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors[1].withOpacity(0.9),
                    colors[3].withOpacity(0.7),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}