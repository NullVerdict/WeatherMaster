import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_location.dart';
import '../services/fetch_data.dart';
import '../utils/preferences_helper.dart';
import '../utils/app_storage.dart';

Future<void> handleSaveLocationView({
  required BuildContext context,
  required VoidCallback updateUIState,
}) async {
    final saved = SavedLocation(
      latitude: PreferencesHelper.getJson(PrefKeys.selectedViewLocation)?['lat'],
      longitude: PreferencesHelper.getJson(PrefKeys.selectedViewLocation)?['lon'],
      city: PreferencesHelper.getJson(PrefKeys.selectedViewLocation)?['city'] ?? '',
      country: PreferencesHelper.getJson(PrefKeys.selectedViewLocation)?['country'] ?? '',
    );
  
  final cacheKeyViewing = "${saved.city}_${saved.country}".toLowerCase().replaceAll(' ', '_');
    final weatherService = WeatherService();
  weatherService.fetchWeather(
      PreferencesHelper.getJson(PrefKeys.selectedViewLocation)?['lat'],
      PreferencesHelper.getJson(PrefKeys.selectedViewLocation)?['lon'],
      locationName: cacheKeyViewing,
      context: context);

  await _saveLocationView(saved);

  updateUIState();
}


Future<void> _saveLocationView(SavedLocation newLocation) async {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(PrefKeys.savedLocations);
      List<SavedLocation> current = [];

      if (existing != null) {
        final decoded = jsonDecode(existing) as List;
        current = decoded.map((e) => SavedLocation.fromJson(e)).toList();
      }

      bool alreadyExists = current.any((loc) =>
          loc.city == newLocation.city && loc.country == newLocation.country);

      if (!alreadyExists) {
        current.add(newLocation);
        await prefs.setString(
            PrefKeys.savedLocations,
            jsonEncode(current.map((e) => e.toJson()).toList()));
      }
}
