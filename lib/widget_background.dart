import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:home_widget/home_widget.dart';
import 'services/fetch_data.dart';
import 'utils/condition_label_map.dart';
import 'utils/preferences_helper.dart';
import 'utils/unit_converter.dart';

@pragma('vm:entry-point')
Future<void> updateHomeWidget(dynamic weather, {bool updatedFromHome = false}) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    await Future.wait([
      PreferencesHelper.init(),
      dotenv.load(fileName: ".env"),
    ]);

    final bool triggerFromWorker = PreferencesHelper.getBool("triggerfromWorker") ?? false;
    final String? lastUpdatedString = PreferencesHelper.getString('lastUpdatedFromHome');

    if (weather == null && !updatedFromHome) {
      if (!triggerFromWorker) {
        await PreferencesHelper.setBool('triggerfromWorker', true);
        return;
      }
      if (lastUpdatedString != null) {
        final lastUpdated = DateTime.parse(lastUpdatedString);
        if (DateTime.now().difference(lastUpdated).inMinutes < 45) return;
      }
    }

    final String localeString = PreferencesHelper.getString('locale') ?? 'en';
    
    Map<String, dynamic>? weatherData;
    Map<String, dynamic> translations;

    if (weather == null && !updatedFromHome) {
      final homeLocation = PreferencesHelper.getJson('homeLocation');
      if (homeLocation == null) return;

      final fetchFuture = WeatherService().fetchWeather(
        homeLocation['lat'], 
        homeLocation['lon'],
        locationName: homeLocation['cacheKey'],
        isBackground: true
      );
      
      final transFuture = _loadTranslations(localeString);
      
      final results = await Future.wait([fetchFuture, transFuture]);
      final fetchResultMap = results[0];
      translations = results[1] as Map<String, dynamic>;

      if (fetchResultMap == null) return;
      weatherData = fetchResultMap['data'];
    } else {
      translations = await _loadTranslations(localeString);
      weatherData = weather;
    }

    if (weatherData == null) return;

    final current = weatherData['current'];
    final daily = weatherData['daily'];
    final hourly = weatherData['hourly'] ?? const {};
    final int utcOffsetSeconds = _toInt(weatherData['utc_offset_seconds']);

    final double temp = _toDouble(current['temperature_2m']);
    final int code = _toInt(current['weather_code']);
    final int isDay = _toInt(current['is_day']);
    final double maxTemp = _toDouble(daily['temperature_2m_max']?[0]);
    final double minTemp = _toDouble(daily['temperature_2m_min']?[0]);

    final String tempUnit = PreferencesHelper.getString("selectedTempUnit") ?? "Celsius";
    final String timeUnit = PreferencesHelper.getString("selectedTimeUnit") ?? "12 hr";
    final bool isFahrenheit = tempUnit == 'Fahrenheit';
    final bool is24Hour = timeUnit == '24 hr';

    final List<Future<void>> widgetUpdates = [];
    
    String formatTemp(double t) => isFahrenheit 
        ? UnitConverter.celsiusToFahrenheit(t).round().toString() 
        : t.round().toString();

    final List<dynamic> hourlyTime = hourly['time'] ?? const [];
    final List<dynamic> hourlyTemps = hourly['temperature_2m'] ?? const [];
    final List<dynamic> hourlyCodes = hourly['weather_code'] ?? const [];
    
    final now = DateTime.now().toUtc().add(Duration(seconds: utcOffsetSeconds));
    final nowNormalized = DateTime(now.year, now.month, now.day, now.hour);
    
    int startIndex = 0;
    if (hourlyTime.isNotEmpty) {
      final firstTime = DateTime.parse(hourlyTime[0].toString());
      startIndex = nowNormalized.difference(firstTime).inHours;
      if (startIndex < 0) startIndex = 0;
    }

    final int maxHourly = hourlyTime.length;
    for (int i = 0; i < 4; i++) {
      final idx = startIndex + i;
      if (idx >= maxHourly) break;

      final tVal = _toDouble(hourlyTemps[idx]);
      final tDate = DateTime.parse(hourlyTime[idx].toString());
      final fTime = is24Hour 
          ? "${tDate.hour.toString().padLeft(2, '0')}:00" 
          : UnitConverter.formatTo12Hour(tDate);

      widgetUpdates.add(HomeWidget.saveWidgetData('hourly_temp_$i', formatTemp(tVal)));
      widgetUpdates.add(HomeWidget.saveWidgetData('hourly_time_$i', fTime));
      widgetUpdates.add(HomeWidget.saveWidgetData('hourly_code_$i', hourlyCodes[idx].toString()));
    }

    final List<dynamic> dailyMax = daily['temperature_2m_max'] ?? const [];
    final List<dynamic> dailyMin = daily['temperature_2m_min'] ?? const [];
    final List<dynamic> dailyCodes = daily['weather_code'] ?? const [];
    final List<dynamic> dailyTime = daily['time'] ?? const [];
    final int maxDaily = dailyTime.length;

    for (int i = 0; i < 4; i++) {
      if (i >= maxDaily) break;

      final dCode = dailyCodes[i];
      final condKey = WeatherConditionMapper.getConditionLabel(dCode, 1);
      final condName = translations[condKey] ?? condKey;
      final dDate = DateTime.parse(dailyTime[i].toString());

      widgetUpdates.add(HomeWidget.saveWidgetData('day${i + 1}Max', formatTemp(_toDouble(dailyMax[i]))));
      widgetUpdates.add(HomeWidget.saveWidgetData('day${i + 1}Min', formatTemp(_toDouble(dailyMin[i]))));
      widgetUpdates.add(HomeWidget.saveWidgetData('day${i + 1}Code', dCode.toString()));
      widgetUpdates.add(HomeWidget.saveWidgetData('day${i + 1}Date', "${dDate.month}/${dDate.day}"));
      widgetUpdates.add(HomeWidget.saveWidgetData('day${i + 1}_condition', condName));
    }

    final curCondKey = WeatherConditionMapper.getConditionLabel(code, isDay);
    final curCondName = translations[curCondKey] ?? curCondKey;
    final homeLoc = PreferencesHelper.getJson('homeLocation');
    final locName = homeLoc != null ? "${homeLoc['city']}, ${homeLoc['country']}" : "";

    widgetUpdates.addAll([
      HomeWidget.saveWidgetData('temperatureCurrentPill', isFahrenheit ? UnitConverter.celsiusToFahrenheit(temp).round().toString() : temp.round().toString()),
      HomeWidget.saveWidgetData('weather_codeCurrentPill', code.toString()),
      HomeWidget.saveWidgetData('todayMax', isFahrenheit ? UnitConverter.celsiusToFahrenheit(maxTemp).round().toString() : maxTemp.round().toString()),
      HomeWidget.saveWidgetData('todayMin', isFahrenheit ? UnitConverter.celsiusToFahrenheit(minTemp).round().toString() : minTemp.round().toString()),
      HomeWidget.saveWidgetData('locationNameWidget', locName),
      HomeWidget.saveWidgetData('locationCurrentConditon', curCondName),
      HomeWidget.saveWidgetData('isDayWidget', isDay.toString()),
    ]);

    await Future.wait(widgetUpdates);

    await Future.wait([
      HomeWidget.updateWidget(name: 'WeatherWidgetProvider'),
      HomeWidget.updateWidget(name: 'WeatherWidgetCastProvider'),
      HomeWidget.updateWidget(name: 'PillWidgetProvider'),
      HomeWidget.updateWidget(name: 'clockDateWidgetProvider'),
      HomeWidget.updateWidget(name: 'DateCurrentWidgetProvider'),
      HomeWidget.updateWidget(name: 'ClockHourlyWidgetProvider'),
    ]);

    debugPrint('[WidgetUpdate] Completed successfully');

  } catch (e, stack) {
    debugPrint('[WidgetUpdate][ERROR] $e');
    debugPrint(stack.toString());
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

Future<Map<String, dynamic>> _loadTranslations(String localeString) async {
  try {
    final parts = localeString.split(RegExp(r'[-_]'));
    final lang = parts[0];
    final country = parts.length > 1 ? parts[1].toUpperCase() : null;
    
    String path = 'assets/translations/$lang';
    if (country != null) path += '-$country';
    path += '.json';

    try {
      return jsonDecode(await rootBundle.loadString(path));
    } catch (_) {
      if (country != null) {
        try {
          return jsonDecode(await rootBundle.loadString('assets/translations/$lang.json'));
        } catch (_) {}
      }
      return jsonDecode(await rootBundle.loadString('assets/translations/en.json'));
    }
  } catch (_) {
    return {};
  }
}
