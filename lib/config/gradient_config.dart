// lib/config/gradient_config.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class PsychedelicGradient {
  // Core psychedelic colors - vibrant and consistent across screens
  static const List<Color> baseColors = [
    Color(0xFFFF006E), // Hot Pink
    Color(0xFFFFBE0B), // Bright Yellow
    Color(0xFF8338EC), // Purple
    Color(0xFF3A86FF), // Blue
    Color(0xFFFB5607), // Orange
    Color(0xFF06FFA5), // Mint Green
    Color(0xFFE91E63), // Pink
    Color(0xFF00BCD4), // Cyan
  ];

  // Generate a gradient with specified number of colors
  static List<Color> generateGradient([int colorCount = 6]) {
    final random = math.Random();
    final colors = <Color>[];

    // Pick random colors from our palette
    for (int i = 0; i < colorCount; i++) {
      colors.add(baseColors[random.nextInt(baseColors.length)]);
    }

    return colors;
  }

  // Generate stable gradient (for screens that need consistency)
  static List<Color> generateStableGradient(int colorCount) {
    // Use a predictable pattern for stable gradients
    final colors = <Color>[];
    for (int i = 0; i < colorCount; i++) {
      colors.add(baseColors[i % baseColors.length]);
    }
    return colors;
  }

  // Dynamic gradient stops based on color count
  static List<double> getGradientStops(int colorCount) {
    if (colorCount <= 1) return [1.0];
    return List.generate(colorCount, (i) => i / (colorCount - 1));
  }

  // Background gradient that adapts to color count
  static RadialGradient getBackgroundGradient(List<Color> colors) {
    return RadialGradient(
      colors: colors,
      stops: getGradientStops(colors.length),
      center: Alignment.center,
      radius: 1.5,
    );
  }

  // Get radial gradient with custom settings
  static RadialGradient getRadialGradient(List<Color> colors, {
    double radius = 1.5,
    Alignment center = Alignment.center,
    List<double>? stops,
  }) {
    return RadialGradient(
      colors: colors,
      stops: stops ?? getGradientStops(colors.length),
      center: center,
      radius: radius,
    );
  }

  // Overlay gradient for depth
  static LinearGradient getOverlayGradient(List<Color> colors, double rotation) {
    // Ensure we have enough colors
    final overlayColors = <Color>[];
    if (colors.isEmpty) {
      overlayColors.addAll([
        Colors.transparent,
        baseColors[0].withOpacity(0.2),
        Colors.transparent,
      ]);
    } else if (colors.length == 1) {
      overlayColors.addAll([
        Colors.transparent,
        colors[0].withOpacity(0.2),
        Colors.transparent,
      ]);
    } else {
      overlayColors.addAll([
        Colors.transparent,
        colors[0].withOpacity(0.2),
        Colors.transparent,
        colors[colors.length > 2 ? 2 : 1].withOpacity(0.1),
        Colors.transparent,
      ]);
    }

    return LinearGradient(
      colors: overlayColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(rotation),
    );
  }

  // Intense gradient for special effects
  static RadialGradient getIntenseGradient(List<Color> colors) {
    return RadialGradient(
      colors: colors,
      stops: getGradientStops(colors.length),
      center: Alignment.center,
      radius: 2.0, // Larger radius for more intensity
    );
  }

  // Helper to get psychedelic colors for consistency
  static List<Color> getPsychedelicPalette() {
    return List.from(baseColors);
  }
}