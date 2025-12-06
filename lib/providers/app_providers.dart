import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_plus_secure/hive_plus_secure.dart';

import '../models/saved_location.dart';
import '../notifiers/unit_settings_notifier.dart';
import '../repositories/weather_repository.dart';
import '../utils/preferences_helper.dart';

class WeatherRequest {
  const WeatherRequest({
    required this.cacheKey,
    this.lat,
    this.lon,
  });

  final String cacheKey;
  final double? lat;
  final double? lon;
}

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final box = Hive.box(name: 'weatherMasterCache');
  return WeatherRepository(box: box);
});

final weatherProvider =
    FutureProvider.family<Map<String, dynamic>?, WeatherRequest>((ref, req) async {
  final repo = ref.watch(weatherRepositoryProvider);

  final cached = await repo.getCachedWeather(req.cacheKey);
  final stale = repo.isStale(req.cacheKey);

  // If nothing cached, try to fetch when coordinates are available.
  if (cached == null && req.lat != null && req.lon != null) {
    return await repo.refresh(
      lat: req.lat!,
      lon: req.lon!,
      cacheKey: req.cacheKey,
    );
  }

  // If cached but stale and coords known, refresh; otherwise return cached.
  if (stale && req.lat != null && req.lon != null) {
    final refreshed = await repo.refresh(
      lat: req.lat!,
      lon: req.lon!,
      cacheKey: req.cacheKey,
    );
    return refreshed ?? cached;
  }

  return cached;
});

final unitSettingsProvider =
    ChangeNotifierProvider<UnitSettingsNotifier>((ref) => UnitSettingsNotifier());

final temperatureUnitProvider = Provider<String>((ref) {
  return ref.watch(unitSettingsProvider.select((u) => u.tempUnit));
});

final timeUnitProvider = Provider<String>((ref) {
  return ref.watch(unitSettingsProvider.select((u) => u.timeUnit));
});

final savedLocationsProvider = FutureProvider<List<SavedLocation>>((ref) async {
  await PreferencesHelper.init();
  final jsonString = PreferencesHelper.getString('saved_locations');
  if (jsonString == null) return [];

  final decoded = jsonDecode(jsonString) as List;
  return decoded.map((e) => SavedLocation.fromJson(e)).toList();
});
