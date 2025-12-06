import 'dart:convert';

import 'package:hive_plus_secure/hive_plus_secure.dart';

import '../services/fetch_data.dart';

class WeatherRepository {
  WeatherRepository({
    required Box box,
    WeatherService? weatherService,
  })  : _box = box,
        _weatherService = weatherService ?? WeatherService();

  final Box _box;
  final WeatherService _weatherService;

  Future<Map<String, dynamic>?> getCachedWeather(String cacheKey) async {
    final cached = _box.get(cacheKey);
    if (cached == null) return null;
    return json.decode(cached) as Map<String, dynamic>;
  }

  bool isStale(String cacheKey, {Duration maxAge = const Duration(minutes: 45)}) {
    final cached = _box.get(cacheKey);
    if (cached == null) return true;
    final map = json.decode(cached) as Map<String, dynamic>;
    final lastUpdatedStr = map['last_updated'] as String?;
    final lastUpdated = DateTime.tryParse(lastUpdatedStr ?? '');
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated) > maxAge;
  }

  Future<Map<String, dynamic>?> refresh({
    required double lat,
    required double lon,
    required String cacheKey,
    bool isOnlyView = false,
    bool isBackground = false,
  }) {
    return _weatherService.fetchWeather(
      lat,
      lon,
      locationName: cacheKey,
      isOnlyView: isOnlyView,
      isBackground: isBackground,
    );
  }
}
