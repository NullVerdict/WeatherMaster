import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';

/// Service for precaching SVG assets to improve rendering performance.
///
/// Call [precacheAssets] during app initialization to preload frequently used
/// SVG files into memory. This reduces first-render latency for SVG widgets.
class SvgCacheService {
  /// List of SVG asset paths to precache.
  /// Add paths for SVGs that are used frequently or on critical screens.
  static const _svgAssets = <String>[
    'assets/weather-icons/showers_rain.svg',
    // Add other frequently used SVG assets here
  ];

  /// Precaches all registered SVG assets.
  ///
  /// Call this during app startup (e.g., in main() after ensureInitialized)
  /// to preload SVGs before they're displayed.
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await SvgCacheService.precacheAssets();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> precacheAssets() async {
    for (final path in _svgAssets) {
      try {
        final loader = SvgAssetLoader(path);
        await svg.cache.putIfAbsent(
          loader.cacheKey(null),
          () => loader.loadBytes(null),
        );
      } catch (e) {
        debugPrint('Failed to precache SVG $path: $e');
      }
    }
  }

  /// Precaches a single SVG asset.
  ///
  /// Use for dynamic SVG paths that aren't in the static list.
  static Future<void> precacheAsset(String path) async {
    try {
      final loader = SvgAssetLoader(path);
      await svg.cache.putIfAbsent(
        loader.cacheKey(null),
        () => loader.loadBytes(null),
      );
    } catch (e) {
      debugPrint('Failed to precache SVG $path: $e');
    }
  }
}
