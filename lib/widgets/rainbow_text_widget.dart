// lib/widgets/rainbow_text_widget.dart - REUSABLE RAINBOW TEXT COMPONENT
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RainbowText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final TextAlign textAlign;
  final List<Shadow>? shadows;

  const RainbowText({
    super.key,
    required this.text,
    this.fontSize = 42,
    this.fontWeight = FontWeight.bold,
    this.letterSpacing = 3.0,
    this.textAlign = TextAlign.center,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.indigo,
          Colors.purple,
          Colors.pink,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        style: GoogleFonts.creepster(
          fontSize: fontSize,
          color: Colors.white,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          shadows: shadows ?? [
            Shadow(
              color: Colors.black.withOpacity(0.9),
              blurRadius: 12,
              offset: const Offset(4, 4),
            ),
            Shadow(
              color: Colors.red.withOpacity(0.7),
              blurRadius: 16,
              offset: const Offset(-3, -3),
            ),
            Shadow(
              color: Colors.purple.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        textAlign: textAlign,
      ),
    );
  }
}

// Animated version for special effects
class AnimatedRainbowText extends StatefulWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final TextAlign textAlign;
  final List<Shadow>? shadows;
  final Duration animationDuration;

  const AnimatedRainbowText({
    super.key,
    required this.text,
    this.fontSize = 42,
    this.fontWeight = FontWeight.bold,
    this.letterSpacing = 3.0,
    this.textAlign = TextAlign.center,
    this.shadows,
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  State<AnimatedRainbowText> createState() => _AnimatedRainbowTextState();
}

class _AnimatedRainbowTextState extends State<AnimatedRainbowText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.indigo,
              Colors.purple,
              Colors.pink,
              Colors.red, // Loop back for smooth animation
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            transform: GradientRotation(_controller.value * 6.28),
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: GoogleFonts.creepster(
              fontSize: widget.fontSize,
              color: Colors.white,
              fontWeight: widget.fontWeight,
              letterSpacing: widget.letterSpacing,
              shadows: widget.shadows ?? [
                Shadow(
                  color: Colors.black.withOpacity(0.9),
                  blurRadius: 12,
                  offset: const Offset(4, 4),
                ),
                Shadow(
                  color: Colors.red.withOpacity(0.7),
                  blurRadius: 16,
                  offset: const Offset(-3, -3),
                ),
                Shadow(
                  color: Colors.purple.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            textAlign: widget.textAlign,
          ),
        );
      },
    );
  }
}