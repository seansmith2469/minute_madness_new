import 'dart:math';
import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/match_result.dart';
import 'precision_tap_screen.dart';
import '../main.dart' show targetDuration;

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  late List<Player> _players;
  int _round = 1;
  bool _isProcessingRound = false;
  final Random _random = Random(); // Cache Random instance

  @override
  void initState() {
    super.initState();
    // Create 64 players with more efficient generation
    _players = List.generate(64, (i) => Player('Player ${i + 1}'), growable: true);
  }

  /// Simulate a whole round: shuffle, take the top half as winners.
  void _playRound() {
    if (_isProcessingRound || _players.length <= 1) return;

    setState(() {
      _isProcessingRound = true;
    });

    // Use a more efficient shuffle and selection
    _players.shuffle(_random);
    final winnersCount = _players.length ~/ 2;
    _players = _players.take(winnersCount).toList();

    setState(() {
      _round++;
      _isProcessingRound = false;
    });

    // Check for winner after state update
    if (_players.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWinnerDialog(_players.first.name);
      });
    }
  }

  void _showWinnerDialog(String winner) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (_) => AlertDialog(
        title: const Text('🏆 Champion'),
        content: Text('$winner is the champion!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleMatchResult(MatchResult result, Player p1, Player p2, int matchIndex) {
    if (!mounted) return;

    // Simulate opponent with random ±200 ms absolute error
    final opponentError = Duration(milliseconds: 100 + _random.nextInt(300));

    final winner = result.error <= opponentError ? p1 : p2;
    final loser = result.error > opponentError ? p1 : p2;

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${winner.name} wins this match!'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Update players list efficiently
    setState(() {
      _players.remove(loser);
    });

    // Check for tournament winner
    if (_players.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWinnerDialog(winner.name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tournament • Round $_round'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // Tournament status card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${_players.length} players remaining',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Round $_round of ${_calculateMaxRounds()}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Play round button
          ElevatedButton(
            onPressed: (_players.length > 1 && !_isProcessingRound) ? _playRound : null,
            child: _isProcessingRound
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Play Round'),
          ),

          const SizedBox(height: 16),

          // Matches list
          Expanded(
            child: _players.length > 1
                ? _MatchesList(
              players: _players,
              onMatchTap: _handleMatchResult,
              targetDuration: targetDuration,
              round: _round,
            )
                : const Center(
              child: Text(
                'Tournament Complete!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateMaxRounds() {
    return (64 / 2).ceil().toString().length + 5; // Rough estimate
  }
}

// Separate widget for matches list to optimize rebuilds
class _MatchesList extends StatelessWidget {
  final List<Player> players;
  final Function(MatchResult, Player, Player, int) onMatchTap;
  final Duration targetDuration;
  final int round;

  const _MatchesList({
    required this.players,
    required this.onMatchTap,
    required this.targetDuration,
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    final matchCount = players.length ~/ 2;

    if (matchCount == 0) {
      return const Center(
        child: Text('No matches available'),
      );
    }

    return ListView.builder(
      itemCount: matchCount,
      itemBuilder: (context, index) {
        final p1 = players[index * 2];
        final p2 = players[index * 2 + 1];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text('${p1.name} vs ${p2.name}'),
            subtitle: Text('Match ${index + 1}'),
            trailing: const Icon(Icons.play_arrow),
            onTap: () async {
              try {
                final result = await Navigator.push<MatchResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrecisionTapScreen(
                      target: targetDuration,
                      tourneyId: 'tournament_${DateTime.now().millisecondsSinceEpoch}',
                      round: round,
                    ),
                  ),
                );

                if (result != null) {
                  onMatchTap(result, p1, p2, index);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error playing match: $e')),
                );
              }
            },
          ),
        );
      },
    );
  }
}