// lib/screens/match_game_screen.dart - COMPLETE FIXED VERSION
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show psychedelicPalette, backgroundSwapDuration;
import '../services/match_bot_service.dart';
import 'match_results_screen.dart';

// Psychedelic Tarot Card designs
enum TarotDesign {
  cosmicEye,
  infinitySpiral,
  crystallMoon,
  flamingPhoenix,
  voidPortal,
  lightningTree,
  mysticSerpent,
  starWave
}

class TarotCard {
  final int id;
  final TarotDesign design;
  bool isRevealed;
  bool isMatched;
  bool isSelected;

  TarotCard({
    required this.id,
    required this.design,
    this.isRevealed = false,
    this.isMatched = false,
    this.isSelected = false,
  });
}

class MatchGameScreen extends StatefulWidget {
  final bool isPractice;
  final String tourneyId;

  const MatchGameScreen({
    super.key,
    required this.isPractice,
    required this.tourneyId,
  });

  @override
  State<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends State<MatchGameScreen>
    with TickerProviderStateMixin {
  // Game state
  List<TarotCard> _cards = [];
  List<TarotCard> _selectedCards = [];
  bool _gameStarted = false;
  bool _showingCards = false;
  bool _gameComplete = false;
  bool _hasSubmitted = false;
  bool _hasSubmittedBots = false;

  // Timing
  DateTime? _gameStartTime;
  int _completionTimeMs = 0;
  int _penaltySeconds = 0;

  // UI feedback
  String _feedbackMessage = '';
  bool _showFeedbackMessage = false;
  bool _isPositiveFeedback = false;

  // Timers
  Timer? _revealTimer;
  Timer? _feedbackTimer;

  // OPTIMIZED: Reduced animation controllers for better performance
  late AnimationController _primaryController;      // Combined background + rotation
  late AnimationController _pulseController;       // Pulsing effects
  late AnimationController _cardFlipController;    // Card animations
  late AnimationController _successController;     // Success effects
  late AnimationController _errorController;       // Error effects
  late AnimationController _completionController;  // Completion effects

  late List<Color> _currentColors;
  late List<Color> _nextColors;

  // Database
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();

    // Initialize OPTIMIZED psychedelic animations
    _currentColors = _generateGradient();
    _nextColors = _generateGradient();

    // OPTIMIZED: Primary controller handles background AND rotation
    _primaryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentColors = List.from(_nextColors);
        _nextColors = _generateGradient();
        _primaryController.forward(from: 0);
      }
    })..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Initialize game
    _initializeCards();

    // Submit bot results for tournament mode
    if (!widget.isPractice) {
      _submitBotResults();
    }
  }

  List<Color> _generateGradient() {
    final random = math.Random();
    // OPTIMIZED: Reduced color count for better performance
    final matchColors = [
      Colors.purple.shade900,
      Colors.pink.shade700,
      Colors.indigo.shade800,
      Colors.blue.shade800,
      Colors.cyan.shade600,
      Colors.teal.shade700,
      Colors.green.shade700,
      Colors.orange.shade700,
    ];

    // OPTIMIZED: Reduced from 10 to 6 colors
    return List.generate(
        6, (_) => matchColors[random.nextInt(matchColors.length)]);
  }

  void _initializeCards() {
    _cards.clear();

    // Create pairs of each design
    int cardId = 0;
    for (final design in TarotDesign.values) {
      _cards.add(TarotCard(id: cardId++, design: design));
      _cards.add(TarotCard(id: cardId++, design: design));
    }

    // Shuffle the cards
    _cards.shuffle();
  }

  Future<void> _submitBotResults() async {
    if (_hasSubmittedBots) return;
    _hasSubmittedBots = true;

    try {
      final tourneyDoc = await _db
          .collection('match_tournaments')
          .doc(widget.tourneyId)
          .get();

      if (!tourneyDoc.exists) return;

      final data = tourneyDoc.data();
      if (data == null || !data.containsKey('bots')) return;

      final botsData = data['bots'] as Map<String, dynamic>?;
      if (botsData == null || botsData.isEmpty) return;

      final allBots = <MatchBotPlayer>[];

      for (final entry in botsData.entries) {
        try {
          final botData = entry.value as Map<String, dynamic>?;
          if (botData == null) continue;

          final name = botData['name'] as String?;
          final difficultyName = botData['difficulty'] as String?;

          if (name == null || difficultyName == null) continue;

          final difficulty = MatchBotDifficulty.values.where(
                (d) => d.name == difficultyName,
          ).firstOrNull;

          if (difficulty == null) continue;

          allBots.add(MatchBotPlayer(
            id: entry.key,
            name: name,
            difficulty: difficulty,
          ));
        } catch (e) {
          continue;
        }
      }

      if (allBots.isNotEmpty) {
        MatchBotService.submitBotResults(widget.tourneyId, allBots);
      }
    } catch (e) {
      print('Error submitting match bot results: $e');
    }
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _showingCards = true;
    });

    // Show all cards for 3 seconds
    for (var card in _cards) {
      card.isRevealed = true;
    }

    _revealTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _showingCards = false;
        for (var card in _cards) {
          card.isRevealed = false;
        }
      });

      // Start the actual game timer
      _gameStartTime = DateTime.now();
    });
  }

  void _onCardTap(TarotCard card) {
    // FIXED: Prevent interaction with matched cards completely
    if (!_gameStarted || _showingCards || card.isMatched || _gameComplete) return;
    if (_selectedCards.length >= 2) return;

    setState(() {
      card.isSelected = true;
      card.isRevealed = true;
      _selectedCards.add(card);
    });

    _cardFlipController.forward().then((_) => _cardFlipController.reset());

    if (_selectedCards.length == 2) {
      _checkMatch();
    }
  }

  void _checkMatch() {
    final card1 = _selectedCards[0];
    final card2 = _selectedCards[1];

    if (card1.design == card2.design) {
      // MATCH!
      _showFeedback('Yes!', true);
      _successController.forward().then((_) => _successController.reset());

      setState(() {
        card1.isMatched = true;
        card2.isMatched = true;
        // FIXED: Keep matched cards revealed and unselected
        card1.isRevealed = true;
        card2.isRevealed = true;
        card1.isSelected = false;
        card2.isSelected = false;
      });

      // Check if game complete
      if (_cards.every((card) => card.isMatched)) {
        _completeGame();
      }
    } else {
      // NO MATCH!
      _penaltySeconds++;
      _showFeedback('No! -1 second penalty', false);
      _errorController.forward().then((_) => _errorController.reset());
    }

    // Reset selection after delay
    Timer(const Duration(milliseconds: 500), () {
      setState(() {
        for (var card in _selectedCards) {
          if (!card.isMatched) {
            card.isSelected = false;
            card.isRevealed = false;
          }
        }
        _selectedCards.clear();
      });
    });
  }

  void _showFeedback(String message, bool isPositive) {
    setState(() {
      _feedbackMessage = message;
      _showFeedbackMessage = true;
      _isPositiveFeedback = isPositive;
    });

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1000), () {
      setState(() {
        _showFeedbackMessage = false;
      });
    });
  }

  void _completeGame() {
    if (_hasSubmitted || _gameComplete) return;

    final endTime = DateTime.now();
    final rawTime = endTime.difference(_gameStartTime!).inMilliseconds;
    _completionTimeMs = rawTime + (_penaltySeconds * 1000); // Add penalty time

    setState(() {
      _gameComplete = true;
    });

    _completionController.forward();

    // Use single results screen for both modes
    if (!widget.isPractice) {
      _submitResult();
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MatchResultsScreen(
                tourneyId: widget.tourneyId,
                playerTime: _completionTimeMs,
                isPractice: false, // Tournament mode
              ),
            ),
          );
        }
      });
    } else {
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MatchResultsScreen(
                tourneyId: widget.tourneyId,
                playerTime: _completionTimeMs,
                isPractice: true, // Practice mode
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _submitResult() async {
    if (_hasSubmitted) return;
    _hasSubmitted = true;

    try {
      await _db
          .collection('match_tournaments')
          .doc(widget.tourneyId)
          .collection('results')
          .doc(_uid)
          .set({
        'uid': _uid,
        'completionTimeMs': _completionTimeMs,
        'penaltySeconds': _penaltySeconds,
        'submittedAt': FieldValue.serverTimestamp(),
        'isBot': false,
      });
    } catch (e) {
      print('Error submitting match result: $e');
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _feedbackTimer?.cancel();
    _primaryController.dispose();
    _pulseController.dispose();
    _cardFlipController.dispose();
    _successController.dispose();
    _errorController.dispose();
    _completionController.dispose();
    super.dispose();
  }

// UPDATED: Just the build method section that needs to be replaced
// Replace the build method in your match_game_screen.dart with this version

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _primaryController,
        builder: (context, child) {
          final t = _primaryController.value;
          final interpolatedColors = <Color>[];

          for (int i = 0; i < _currentColors.length; i++) {
            interpolatedColors.add(
                Color.lerp(_currentColors[i], _nextColors[i], t) ?? _currentColors[i]
            );
          }

          return Stack(
            children: [
              // OPTIMIZED: Simplified psychedelic background
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

              // OPTIMIZED: Single rotating overlay using primary controller
              AnimatedBuilder(
                animation: _primaryController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          interpolatedColors[2].withOpacity(0.4),
                          Colors.transparent,
                          interpolatedColors[4].withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_primaryController.value * 6.28),
                      ),
                    ),
                  );
                },
              ),

              // MAIN CONTENT - MOVED ABOVE EFFECTS
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
                            animation: _pulseController,
                            builder: (context, child) {
                              final scale = 1.0 + (_pulseController.value * 0.1);
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
                                      'Match Madness',
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
                          if (_gameStarted && !_showingCards)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final intensity = 0.7 + (_pulseController.value * 0.3);
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
                                    'Penalties: $_penaltySeconds',
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

                    // GAME STATUS WITH PSYCHEDELIC STYLING
                    Stack(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulseController.value * 0.05);
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
                                      interpolatedColors[5].withOpacity(0.6),
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
                                    !_gameStarted ? '🔮 Ready to match the tarot cards?' :
                                    _showingCards ? '👁️ Memorize the cards!' :
                                    _gameComplete ? '🎉 All cards matched!' : '🧠 Find the matching pairs!',
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

                        // LOCALIZED SUCCESS EFFECT - ONLY AROUND GAME STATUS
                        if (_successController.isAnimating)
                          AnimatedBuilder(
                            animation: _successController,
                            builder: (context, child) {
                              final explosion = _successController.value;
                              return Positioned.fill(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.green.withOpacity(0.6 * (1 - explosion)),
                                        Colors.lime.withOpacity(0.4 * (1 - explosion)),
                                        Colors.transparent,
                                      ],
                                      center: Alignment.center,
                                      radius: explosion * 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // LOCALIZED ERROR EFFECT - ONLY AROUND GAME STATUS
                        if (_errorController.isAnimating)
                          AnimatedBuilder(
                            animation: _errorController,
                            builder: (context, child) {
                              final explosion = _errorController.value;
                              return Positioned.fill(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.red.withOpacity(0.6 * (1 - explosion)),
                                        Colors.orange.withOpacity(0.4 * (1 - explosion)),
                                        Colors.transparent,
                                      ],
                                      center: Alignment.center,
                                      radius: explosion * 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                    // Replace the feedback message section in your build method
// Find this part in your Column and replace it:

                    const SizedBox(height: 20),

// FIXED: Always reserve space for feedback message to prevent layout shifts
                    Container(
                      height: 60, // Fixed height - always reserves this space
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      child: _showFeedbackMessage
                          ? AnimatedBuilder(
                        animation: _isPositiveFeedback ? _successController : _errorController,
                        builder: (context, child) {
                          final animValue = _isPositiveFeedback ? _successController.value : _errorController.value;
                          final scale = 1.0 + (animValue * 0.2);

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: LinearGradient(
                                  colors: _isPositiveFeedback
                                      ? [Colors.green.withOpacity(0.9), Colors.lime.withOpacity(0.7)]
                                      : [Colors.red.withOpacity(0.9), Colors.orange.withOpacity(0.7)],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isPositiveFeedback ? Colors.green : Colors.red).withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _feedbackMessage,
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
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                          : const SizedBox.shrink(), // Empty but maintains the Container's height
                    ),

                    const SizedBox(height: 20),

                    // CARD GRID - STABLE POSITIONING
                    Expanded(
                      child: _gameStarted ? _buildCardGrid() : _buildStartButton(),
                    ),
                  ],
                ),
              ),

              // COMPLETION EFFECT - ONLY FOR GAME END
              if (_completionController.isAnimating)
                AnimatedBuilder(
                  animation: _completionController,
                  builder: (context, child) {
                    final explosion = _completionController.value;
                    final rotation = explosion * 6.28;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: SweepGradient(
                          colors: [
                            Colors.red.withOpacity(0.4 * (1 - explosion)),
                            Colors.orange.withOpacity(0.4 * (1 - explosion)),
                            Colors.yellow.withOpacity(0.4 * (1 - explosion)),
                            Colors.green.withOpacity(0.4 * (1 - explosion)),
                            Colors.blue.withOpacity(0.4 * (1 - explosion)),
                            Colors.purple.withOpacity(0.4 * (1 - explosion)),
                            Colors.pink.withOpacity(0.4 * (1 - explosion)),
                            Colors.red.withOpacity(0.4 * (1 - explosion)),
                          ],
                          center: Alignment.center,
                          transform: GradientRotation(rotation),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + (_pulseController.value * 0.1);
          final glow = 0.5 + (_pulseController.value * 0.5);

          return Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: _startGame,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withOpacity(0.9),
                      Colors.pink.withOpacity(0.8),
                      Colors.cyan.withOpacity(0.7),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(glow),
                      blurRadius: 25,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.6),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, Colors.yellow, Colors.white],
                    ).createShader(bounds),
                    child: Text(
                      'START',
                      style: GoogleFonts.creepster(
                        fontSize: 28,
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
      ),
    );
  }

  Widget _buildCardGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.7,
        ),
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final card = _cards[index];
          return _buildTarotCard(card);
        },
      ),
    );
  }

  Widget _buildTarotCard(TarotCard card) {
    return AnimatedBuilder(
      animation: _cardFlipController,
      builder: (context, child) {
        final flipAnimation = card.isSelected ? _cardFlipController.value : 0.0;

        return GestureDetector(
          onTap: () => _onCardTap(card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(flipAnimation * math.pi),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: card.isRevealed ? _getTarotGradient(card.design) : _getCardBackGradient(),
              border: Border.all(
                color: card.isSelected
                    ? Colors.yellow.withOpacity(0.8)
                    : card.isMatched
                    ? Colors.green.withOpacity(0.8) // FIXED: Different border for matched cards
                    : Colors.white.withOpacity(0.3),
                width: card.isSelected || card.isMatched ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: card.isSelected
                      ? Colors.yellow.withOpacity(0.5)
                      : card.isMatched
                      ? Colors.green.withOpacity(0.5) // FIXED: Green glow for matched cards
                      : Colors.black.withOpacity(0.3),
                  blurRadius: card.isSelected || card.isMatched ? 15 : 8,
                  spreadRadius: card.isSelected || card.isMatched ? 3 : 1,
                ),
              ],
            ),
            child: card.isRevealed ? _buildTarotDesign(card.design) : _buildCardBack(),
          ),
        );
      },
    );
  }

  LinearGradient _getCardBackGradient() {
    return LinearGradient(
      colors: [
        Colors.indigo.shade900,
        Colors.purple.shade800,
        Colors.pink.shade700,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  LinearGradient _getTarotGradient(TarotDesign design) {
    switch (design) {
      case TarotDesign.cosmicEye:
        return LinearGradient(colors: [Colors.purple.shade800, Colors.pink.shade600]);
      case TarotDesign.infinitySpiral:
        return LinearGradient(colors: [Colors.blue.shade800, Colors.cyan.shade500]);
      case TarotDesign.crystallMoon:
        return LinearGradient(colors: [Colors.indigo.shade800, Colors.blue.shade600]);
      case TarotDesign.flamingPhoenix:
        return LinearGradient(colors: [Colors.red.shade800, Colors.orange.shade600]);
      case TarotDesign.voidPortal:
        return LinearGradient(colors: [Colors.black, Colors.purple.shade900]);
      case TarotDesign.lightningTree:
        return LinearGradient(colors: [Colors.green.shade800, Colors.lime.shade600]);
      case TarotDesign.mysticSerpent:
        return LinearGradient(colors: [Colors.teal.shade800, Colors.green.shade600]);
      case TarotDesign.starWave:
        return LinearGradient(colors: [Colors.yellow.shade600, Colors.amber.shade500]);
    }
  }

  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade900,
            Colors.purple.shade800,
            Colors.pink.shade700,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          size: 30,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildTarotDesign(TarotDesign design) {
    IconData icon;
    switch (design) {
      case TarotDesign.cosmicEye:
        icon = Icons.visibility;
        break;
      case TarotDesign.infinitySpiral:
        icon = Icons.all_inclusive;
        break;
      case TarotDesign.crystallMoon:
        icon = Icons.brightness_2;
        break;
      case TarotDesign.flamingPhoenix:
        icon = Icons.local_fire_department;
        break;
      case TarotDesign.voidPortal:
        icon = Icons.fiber_manual_record;
        break;
      case TarotDesign.lightningTree:
        icon = Icons.flash_on;
        break;
      case TarotDesign.mysticSerpent:
        icon = Icons.waves;
        break;
      case TarotDesign.starWave:
        icon = Icons.star;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: _getTarotGradient(design),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 40,
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
    );
  }
}