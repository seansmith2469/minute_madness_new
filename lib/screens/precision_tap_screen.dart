// lib/screens/precision_tap_screen.dart - FIXED VERSION
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/match_result.dart';
import '../main.dart' show gif3s, targetDurations;
import '../config/gradient_config.dart';
import '../services/bot_service.dart';
import 'tournament_results_screen.dart';

class PrecisionTapScreen extends StatefulWidget {
  final Duration target;
  final String tourneyId;
  final int round;
  final Function(Map<String, dynamic>)? onUltimateComplete;

  const PrecisionTapScreen({
    super.key,
    required this.target,
    required this.tourneyId,
    required this.round,
    this.onUltimateComplete,
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
  bool _timedOut = false;

  Timer? _countdownTimer;
  int _remainingSeconds = 20; // 20 seconds after ready is clicked (HIDDEN FROM USER)

  // ULTIMATE TOURNAMENT VARIABLES
  bool _isUltimateTournament = false;
  int _currentRound = 1; // Current round (1, 2, or 3)
  List<int> _roundErrors = []; // Store error in ms for each round
  Timer? _ultimateTimer;
  int _ultimateTimeLeft = 30; // 30 seconds total for 3 rounds
  DateTime? _ultimateStartTime;
  bool _showInstructions = true;
  bool _gameComplete = false;

  // PSYCHEDELIC ANIMATION CONTROLLERS
  late AnimationController _backgroundController;
  late AnimationController _pulsController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _buttonController;
  late AnimationController _explosionController;
  late AnimationController _perfectController;
  late AnimationController _instructionController;

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

  // ADDED: Ready screen states
  bool _showReadyScreen = true;
  bool _hasClickedReady = false;

  @override
  void initState() {
    super.initState();

    // Check if this is Ultimate Tournament
    _isUltimateTournament = widget.onUltimateComplete != null;

    // FIXED: Only show instructions for Ultimate Tournament
    _showInstructions = _isUltimateTournament; // Changed from true to conditional

    // Initialize INTENSE psychedelic controllers using gradient config
    _currentColors = PsychedelicGradient.generateStableGradient(6);
    _nextColors = PsychedelicGradient.generateGradient(6);

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = PsychedelicGradient.generateGradient(6);
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

    _instructionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Initialize cached target text once
    _cachedTargetText = 'Aim for ${widget.target.inSeconds == 0 ? widget.target.inMilliseconds : widget.target.inSeconds}s';

    // Initialize stream once (only for regular tournament)
    if (!_isUltimateTournament) {
      _resultsStream = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tourneyId)
          .collection('rounds')
          .doc('round_${widget.round}')
          .collection('results')
          .snapshots();
    }

    // Ultimate Tournament: Show instructions initially
    if (_isUltimateTournament) {
      _showInstructions = true;
      _showReadyScreen = false; // Ultimate mode has its own instructions
      // Auto-hide instructions after 4 seconds
      Timer(const Duration(seconds: 4), () {
        if (mounted) {
          _hideInstructions();
        }
      });
    } else {
      // Regular tournament: Show ready screen first
      if (!_isPracticeMode) {
        // For rounds 2-6, submit bot results
        if (widget.round > 1) {
          print('🤖 Round ${widget.round} starting - submitting bot results...');
          Future.delayed(const Duration(milliseconds: 500), () {
            _submitBotResultsForCurrentRound();
          });
        }
        _checkIfBotsSubmitted();
      } else {
        // Practice mode: skip ready screen
        _showReadyScreen = false;
        _hasClickedReady = true;
      }
    }
  }

  // ADDED: Submit bot results for current round
  Future<void> _submitBotResultsForCurrentRound() async {
    if (_isPracticeMode || _isUltimateTournament) return;

    try {
      print('🤖 Submitting bot results for round ${widget.round}...');

      // Get tournament data
      final tourneyDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tourneyId)
          .get();

      if (!tourneyDoc.exists) {
        print('❌ Tournament not found');
        return;
      }

      final tourneyData = tourneyDoc.data()!;
      final players = List<String>.from(tourneyData['players'] ?? []);
      final botsData = tourneyData['bots'] as Map<String, dynamic>? ?? {};

      // Find which bots are still in the tournament
      final botsInRound = <BotPlayer>[];
      for (final playerId in players) {
        if (botsData.containsKey(playerId)) {
          final botData = botsData[playerId] as Map<String, dynamic>;
          final bot = BotPlayer(
            id: playerId,
            name: botData['name'] as String,
            difficulty: BotDifficulty.values.firstWhere(
                  (d) => d.name == botData['difficulty'],
            ),
          );
          botsInRound.add(bot);
        }
      }

      if (botsInRound.isEmpty) {
        print('✅ No bots in round ${widget.round}');
        return;
      }

      print('🤖 Submitting results for ${botsInRound.length} bots...');
      await BotService.submitBotResults(
          widget.tourneyId,
          widget.round,
          botsInRound,
          widget.target
      );
      print('✅ Bot results submitted for round ${widget.round}');

    } catch (e) {
      print('❌ Error submitting bot results: $e');
    }
  }

  // FIXED: Check if bots are already submitted instead of submitting them
  Future<void> _checkIfBotsSubmitted() async {
    try {
      final tourneyDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tourneyId)
          .get();

      if (!tourneyDoc.exists) {
        print('❌ Tournament document not found');
        return;
      }

      final data = tourneyDoc.data();
      final botsSubmitted = data?['botsSubmitted'] as bool? ?? false;

      if (botsSubmitted) {
        print('✅ Bots already submitted in lobby - skipping duplicate submission');
      } else {
        print('⚠️ Bots not yet submitted - submitting now as fallback');
        await _submitBotResultsForRound();
      }
    } catch (e) {
      print('❌ Error checking bot submission status: $e');
      // Fallback: try to submit bots
      await _submitBotResultsForRound();
    }
  }

  void _hideInstructions() {
    _instructionController.forward().then((_) {
      if (mounted) {
        setState(() {
          _showInstructions = false;
        });
        _startUltimateTimer();
      }
    });
  }

  void _startUltimateTimer() {
    _ultimateStartTime = DateTime.now();
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
        _endUltimateGame();
      }
    });
  }

  void _endUltimateGame() {
    if (_gameComplete || widget.onUltimateComplete == null) return;

    setState(() {
      _gameComplete = true;
      _isRunning = false;
      _showButton = false;
    });

    // Calculate total error across all completed rounds
    final totalError = _roundErrors.fold(0, (sum, error) => sum + error);

    // If player didn't complete 3 rounds, add penalty for incomplete rounds
    final missedRounds = 3 - _roundErrors.length;
    final penaltyError = missedRounds * 5000; // 5 second penalty per missed round
    final finalError = totalError + penaltyError;

    // Calculate rank based on total error (lower = better)
    int rank;
    if (finalError <= 150) rank = 1; // Amazing performance
    else if (finalError <= 300) rank = math.min(5, 2 + ((finalError - 150) / 30).round());
    else if (finalError <= 600) rank = math.min(15, 6 + ((finalError - 300) / 30).round());
    else if (finalError <= 1000) rank = math.min(30, 16 + ((finalError - 600) / 25).round());
    else if (finalError <= 2000) rank = math.min(50, 31 + ((finalError - 1000) / 50).round());
    else rank = math.min(64, 51 + ((finalError - 2000) / 200).round());

    final result = {
      'score': math.max(0, 5000 - finalError), // Higher score for lower error
      'rank': rank,
      'details': {
        'totalErrorMs': finalError,
        'roundsCompleted': _roundErrors.length,
        'roundErrors': _roundErrors,
        'penaltyMs': penaltyError,
      },
    };

    // Show final result before calling completion
    setState(() {
      _cachedResultText = 'GAME COMPLETE!\n'
          'Rounds: ${_roundErrors.length}/3\n'
          'Total Error: ${finalError}ms\n'
          'Rank: #$rank';
    });

    // CHANGED: Use post frame callback instead of Timer
    if (widget.onUltimateComplete != null && mounted) {
      print('🏆 Calling onUltimateComplete with result: $result');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUltimateComplete!(result);
      });
    }
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
        print('🤖 Fallback: Submitting results for ${allBots.length} bots...');
        await BotService.submitBotResults(widget.tourneyId, widget.round, allBots, widget.target);
        print('✅ Fallback bot submission complete');
      }
    } catch (e) {
      print('Error submitting bot results: $e');
    }
  }

  void _startHiddenCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _remainingSeconds--;

      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (!_hasSubmitted && !_timedOut) {
          _handleTimeout();
        }
      }
    });
  }

  // ADDED: Handle ready button click
  void _handleReadyClick() {
    setState(() {
      _hasClickedReady = true;
      _showReadyScreen = false;
    });

    // Start the hidden countdown timer after ready is clicked
    if (!_isPracticeMode && !_isUltimateTournament) {
      _startHiddenCountdown();
    }
  }

  void _handleTimeout() {
    if (_hasSubmitted || _timedOut) return;

    setState(() {
      _timedOut = true;
      _isRunning = false;
      _showButton = false;
      _cachedResultText = "⏰ TIME RAN OUT!\nLast place this round";
    });

    _explosionController.forward();
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

    // ULTIMATE TOURNAMENT: Handle 3-round format
    if (_isUltimateTournament) {
      // Add this round's error
      _roundErrors.add(error.inMilliseconds.abs());

      if (_currentRound < 3 && !_gameComplete && _ultimateTimeLeft > 0) {
        // Move to next round
        setState(() {
          _currentRound++;
          _hasSubmitted = false;
          _showButton = true;
          _cachedResultText = null;
          _isPerfectHit = false;
          _showPerfectEffect = false;
        });

        // Reset animations for next round
        _explosionController.reset();
        _perfectController.reset();
        return;
      } else {
        // All 3 rounds complete or time ran out
        _endUltimateGame();
        return;
      }
    }

    // Regular tournament logic
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
      // Practice mode reset
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _hasSubmitted = false;
          _showButton = true;
          _cachedResultText = null;
          _isPerfectHit = false;
          _showPerfectEffect = false;
          _timedOut = false;
        });

        _explosionController.reset();
        _perfectController.reset();
      }
    }
  }

  void _handleTap() {
    if (_timedOut || _gameComplete || _showInstructions) return;

    if (!_isRunning) {
      // START BUTTON PRESSED
      setState(() {
        _startTime = DateTime.now();
        _elapsed = null;
        _error = null;
        _isRunning = true;
        _cachedResultText = null;
        _isPerfectHit = false;
        _showPerfectEffect = false;
      });

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

      // Show result with round info for Ultimate Tournament
      if (_isUltimateTournament) {
        final roundInfo = 'Round $_currentRound/3';
        _cachedResultText = '$roundInfo\n${_formatResult(elapsed, error)}';
      } else {
        _cachedResultText = _formatResult(elapsed, error);
      }

      setState(() {
        _elapsed = elapsed;
        _error = error;
        _isRunning = false;
        _showButton = false;
        _showPerfectEffect = _isPerfectHit;
      });

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
    _ultimateTimer?.cancel();
    _backgroundController.dispose();
    _pulsController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    _buttonController.dispose();
    _explosionController.dispose();
    _perfectController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🔴 PRECISION TAP BUILD');
    print('🔴 showReadyScreen: $_showReadyScreen');
    print('🔴 hasClickedReady: $_hasClickedReady');
    print('🔴 isPracticeMode: $_isPracticeMode');
    print('🔴 isUltimateTournament: $_isUltimateTournament');
    print('🔴 showButton: $_showButton');
    print('🔴 showInstructions: $_showInstructions');
    print('🔴 timedOut: $_timedOut');
    print('🔴 gameComplete: $_gameComplete');

    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          final t = _backgroundController.value;
          // Ensure we always have exactly 6 colors for interpolation
          final interpolatedColors = <Color>[];
          for (int i = 0; i < _currentColors.length; i++) {
            interpolatedColors.add(
                Color.lerp(_currentColors[i], _nextColors[i], t) ?? _currentColors[i]
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // PSYCHEDELIC BACKGROUND - Base layer
              Container(
                decoration: BoxDecoration(
                  gradient: PsychedelicGradient.getRadialGradient(
                    interpolatedColors,
                    radius: _isRunning ? 2.0 : 1.0,
                  ),
                ),
              ),

              // SUBTLE ROTATING OVERLAY - Reduced opacity
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: PsychedelicGradient.getOverlayGradient(
                        interpolatedColors,
                        _rotationController.value * 6.28,
                      ),
                    ),
                  );
                },
              ),

              // PULSING OVERLAY - Reduced opacity
              AnimatedBuilder(
                animation: _pulsController,
                builder: (context, child) {
                  final intensity = _isRunning ? 0.3 : 0.15; // Reduced from 0.6/0.3
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

              // PERFECT HIT EXPLOSION EFFECT
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
                          radius: explosion * 3.0,
                        ),
                      ),
                    );
                  },
                ),

              // TIMEOUT EXPLOSION EFFECT
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
                          radius: explosion * 3.5,
                        ),
                      ),
                    );
                  },
                ),

              // MAIN GAME CONTENT - Above all gradient layers
              Positioned.fill(
                child: SafeArea(
                  child: Stack(
                    children: [
                      // READY SCREEN (for regular tournament)
                      if (!_isUltimateTournament && _showReadyScreen && !_isPracticeMode)
                        Container(
                          color: Colors.black.withOpacity(0.7),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.orange.withOpacity(0.9),
                                        Colors.red.withOpacity(0.7),
                                        Colors.yellow.withOpacity(0.5),
                                      ],
                                    ),
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.5),
                                        blurRadius: 30,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '🎯 PRECISION TAP 🎯',
                                        style: GoogleFonts.creepster(
                                          fontSize: 32,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Round ${widget.round}',
                                        style: GoogleFonts.chicle(
                                          fontSize: 24,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.info_outline,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            const SizedBox(height: 15),
                                            Text(
                                              'HOW TO PLAY:',
                                              style: GoogleFonts.chicle(
                                                fontSize: 20,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '1. Click READY to begin\n'
                                                  '2. Click START to start the timer\n'
                                                  '3. Click STOP at exactly 3 seconds\n'
                                                  '4. Get as close as possible!',
                                              style: GoogleFonts.chicle(
                                                fontSize: 16,
                                                color: Colors.white.withOpacity(0.9),
                                                height: 1.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            // REMOVED: No countdown display
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      AnimatedBuilder(
                                        animation: _pulsController,
                                        builder: (context, child) {
                                          final scale = 1.0 + (_pulsController.value * 0.1);
                                          return Transform.scale(
                                            scale: scale,
                                            child: ElevatedButton(
                                              onPressed: _handleReadyClick,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 50,
                                                  vertical: 20,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(30),
                                                ),
                                                elevation: 10,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.play_arrow,
                                                    size: 30,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'READY!',
                                                    style: GoogleFonts.creepster(
                                                      fontSize: 24,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 2.0,
                                                    ),
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
                              ],
                            ),
                          ),
                        ),

                      // ULTIMATE TOURNAMENT INSTRUCTIONS OVERLAY
                      if (_isUltimateTournament && _showInstructions)
                        AnimatedBuilder(
                          animation: _instructionController,
                          builder: (context, child) {
                            final fade = _instructionController.value;
                            return Container(
                              color: Colors.black.withOpacity(0.8 * (1 - fade)),
                              child: Center(
                                child: Transform.scale(
                                  scale: 1.0 - (fade * 0.3),
                                  child: Container(
                                    margin: const EdgeInsets.all(20),
                                    padding: const EdgeInsets.all(30),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.purple.withOpacity(0.9),
                                          Colors.blue.withOpacity(0.7),
                                          Colors.cyan.withOpacity(0.5),
                                        ],
                                      ),
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '⚡ MINUTE MADNESS ⚡',
                                          style: GoogleFonts.creepster(
                                            fontSize: 32,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          '🎯 Complete 3 rounds\n'
                                              '⏱️ 30 seconds total time\n'
                                              '🏆 Lowest total error wins\n'
                                              '🎮 Stop timer at exactly 3 seconds',
                                          style: GoogleFonts.chicle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        Container(
                                          padding: const EdgeInsets.all(15),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          child: Text(
                                            'Starting in a few seconds...',
                                            style: GoogleFonts.chicle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                      // MAIN GAME UI
                      if (!_showReadyScreen || _isPracticeMode || _isUltimateTournament)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ULTIMATE TOURNAMENT HEADER (NO TIMER DISPLAY)
                              if (_isUltimateTournament && !_showInstructions) ...[
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
                                              Colors.purple.withOpacity(0.8),
                                              Colors.blue.withOpacity(0.6),
                                            ],
                                          ),
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              'Round $_currentRound/3',
                                              style: GoogleFonts.chicle(
                                                fontSize: 18,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (_roundErrors.isNotEmpty)
                                              Text(
                                                'Errors: ${_roundErrors.join(', ')}ms',
                                                style: GoogleFonts.chicle(
                                                  fontSize: 14,
                                                  color: Colors.white.withOpacity(0.9),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],

                              // PERFECT HIT TEXT EFFECT
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
                                          colors: PsychedelicGradient.getPsychedelicPalette(),
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
                              if (_cachedResultText != null && !_showInstructions) ...[
                                AnimatedBuilder(
                                  animation: _explosionController,
                                  builder: (context, child) {
                                    final scale = 1.0 + (_explosionController.value * 0.3);
                                    final colorShift = _explosionController.value;

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

                              // THE PSYCHEDELIC BUTTON
                              if (_showButton && !_timedOut && !_showInstructions && !_gameComplete && (_hasClickedReady || _isPracticeMode || _isUltimateTournament))
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
                                                  stops: const [0.0, 0.3, 0.7, 1.0],
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
                                                  shaderCallback: (bounds) => const LinearGradient(
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
                              if (_isRunning && !_timedOut && !_showInstructions) ...[
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
                                              interpolatedColors[5].withOpacity(0.5),
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

                      // Results counter (only show for regular tournament)
                      if (!_isPracticeMode && !_timedOut && !_isUltimateTournament && !_showReadyScreen)
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
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}