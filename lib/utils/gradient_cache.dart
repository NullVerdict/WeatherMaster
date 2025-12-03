import 'package:flutter/material.dart';

class GradientCache {
  static final Map<String, List<LinearGradient>> _cache = {};

  static List<LinearGradient> getGradients({
    required bool isLight,
    required bool isShowFrog,
    required bool? isCurrentDay,
  }) {
    final key = '$isLight-$isShowFrog-$isCurrentDay';
    return _cache.putIfAbsent(key, () => _buildGradients(isLight, isShowFrog, isCurrentDay));
  }

  static List<LinearGradient> _buildGradients(bool isLight, bool isShowFrog, bool? isCurrentDay) {
    if (!isShowFrog || isCurrentDay == false) {
      return [
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
        const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
      ];
    }

    if (isLight) {
      return [
        const LinearGradient(colors: [Color(0xFFe3f0ff), Color(0xFFe3f0ff)]),
        const LinearGradient(colors: [Color(0xFFe8f2ff), Color(0xFFe8f2ff)]),
        const LinearGradient(colors: [Color(0xFFe8f2ff), Color(0xFFe8f2ff)]),
        const LinearGradient(colors: [Color(0xFFf0f3f7), Color(0xFFf0f3f7)]),
        const LinearGradient(colors: [Color(0xFFffefd9), Color(0xFFffefd9)]),
        const LinearGradient(colors: [Color(0xFFe8f2ff), Color(0xFFe8f2ff)]),
        const LinearGradient(colors: [Color(0xFFf7e8ff), Color(0xFFf7e8ff)]),
        const LinearGradient(colors: [Color(0xFFe8feff), Color(0xFFe8feff)]),
      ];
    } else {
      return [
        LinearGradient(
          colors: [const Color(0xFF0a1828).withValues(alpha: 0.9), const Color(0xFF0a1828).withValues(alpha: 0.9)],
        ),
        LinearGradient(
          colors: [const Color(0xFF001f3f).withValues(alpha: 0.85), const Color(0xFF001f3f).withValues(alpha: 0.85)],
        ),
        LinearGradient(
          colors: [const Color(0xFF002244).withValues(alpha: 0.82), const Color(0xFF002244).withValues(alpha: 0.82)],
        ),
        LinearGradient(
          colors: [const Color(0xFF0d1b2a).withValues(alpha: 0.88), const Color(0xFF0d1b2a).withValues(alpha: 0.88)],
        ),
        LinearGradient(
          colors: [const Color(0xFF1a0f00).withValues(alpha: 0.80), const Color(0xFF1a0f00).withValues(alpha: 0.80)],
        ),
        LinearGradient(
          colors: [const Color(0xFF001f3f).withValues(alpha: 0.85), const Color(0xFF001f3f).withValues(alpha: 0.85)],
        ),
        LinearGradient(
          colors: [const Color(0xFF1a0033).withValues(alpha: 0.82), const Color(0xFF1a0033).withValues(alpha: 0.82)],
        ),
        LinearGradient(
          colors: [const Color(0xFF00121f).withValues(alpha: 0.87), const Color(0xFF00121f).withValues(alpha: 0.87)],
        ),
      ];
    }
  }

  static void clearCache() {
    _cache.clear();
  }
}

class ColorSchemeCache {
  static final Map<String, List<Color>> _weatherConditionColorsCache = {};
  static final Map<String, List<Color>> _searchBgColorsCache = {};
  static final Map<String, List<int>> _containerColorsCache = {};

  static List<Color> getWeatherConditionColors() {
    return _weatherConditionColorsCache.putIfAbsent('default', () => [
      const Color.fromARGB(255, 3, 88, 216),
      Colors.blueAccent,
      Colors.blueAccent,
      const Color.fromARGB(255, 58, 66, 183),
      Colors.orange,
      Colors.blueAccent,
      const Color.fromARGB(255, 180, 68, 255),
      Colors.cyan,
    ]);
  }

  static void clearCache() {
    _weatherConditionColorsCache.clear();
    _searchBgColorsCache.clear();
    _containerColorsCache.clear();
  }
}
