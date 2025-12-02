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
      final fetchResultMap = results[0] as Map<String, dynamic>?;
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

    // Pre-compute formatting functions
    final String Function(double) formatTemp = isFahrenheit 
        ? (t) => UnitConverter.celsiusToFahrenheit(t).round().toString() 
        : (t) => t.round().toString();

    final List<dynamic> hourlyTime = hourly['time'] ?? const [];
    final List<dynamic> hourlyTemps = hourly['temperature_2m'] ?? const [];
    final List<dynamic> hourlyCodes = hourly['weather_code'] ?? const [];
    
    final now = DateTime.now().toUtc().add(Duration(seconds: utcOffsetSeconds));
    final nowNormalized = DateTime(now.year, now.month, now.day, now.hour);
    
    int startIndex = 0;
    if (hourlyTime.isNotEmpty) {
      final firstTime = DateTime.parse(hourlyTime[0].toString());
      startIndex = nowNormalized.difference(firstTime).inHours.clamp(0, hourlyTime.length - 1);
    }

    final int maxHourly = hourlyTime.length;
    final int hourlyCount = (maxHourly - startIndex).clamp(0, 4);
    
    // Pre-compute all data to minimize allocations
    final hourlyData = List.generate(hourlyCount, (i) {
      final idx = startIndex + i;
      final tDate = DateTime.parse(hourlyTime[idx].toString());
      return (
        temp: formatTemp(_toDouble(hourlyTemps[idx])),
        time: is24Hour 
            ? "${tDate.hour.toString().padLeft(2, '0')}:00" 
            : UnitConverter.formatTo12Hour(tDate),
        code: hourlyCodes[idx].toString(),
      );
    });

    final List<dynamic> dailyMax = daily['temperature_2m_max'] ?? const [];
    final List<dynamic> dailyMin = daily['temperature_2m_min'] ?? const [];
    final List<dynamic> dailyCodes = daily['weather_code'] ?? const [];
    final List<dynamic> dailyTime = daily['time'] ?? const [];
    final int dailyCount = dailyTime.length.clamp(0, 4);

    // Pre-compute all daily data
    final dailyData = List.generate(dailyCount, (i) {
      final dCode = dailyCodes[i];
      final condKey = WeatherConditionMapper.getConditionLabel(dCode, 1);
      final dDate = DateTime.parse(dailyTime[i].toString());
      return (
        max: formatTemp(_toDouble(dailyMax[i])),
        min: formatTemp(_toDouble(dailyMin[i])),
        code: dCode.toString(),
        date: "${dDate.month}/${dDate.day}",
        condition: translations[condKey] ?? condKey,
      );
    });

    final curCondKey = WeatherConditionMapper.getConditionLabel(code, isDay);
    final curCondName = translations[curCondKey] ?? curCondKey;
    final homeLoc = PreferencesHelper.getJson('homeLocation');
    final locName = homeLoc != null ? "${homeLoc['city']}, ${homeLoc['country']}" : "";

    // Batch all widget updates into single parallel Future.wait
    await Future.wait([
      // Hourly updates
      ...hourlyData.expand((h) => [
        HomeWidget.saveWidgetData('hourly_temp_${hourlyData.indexOf(h)}', h.temp),
        HomeWidget.saveWidgetData('hourly_time_${hourlyData.indexOf(h)}', h.time),
        HomeWidget.saveWidgetData('hourly_code_${hourlyData.indexOf(h)}', h.code),
      ]),
      
      // Daily updates
      ...dailyData.expand((d) sync* {
        final idx = dailyData.indexOf(d) + 1;
        yield HomeWidget.saveWidgetData('day${idx}Max', d.max);
        yield HomeWidget.saveWidgetData('day${idx}Min', d.min);
        yield HomeWidget.saveWidgetData('day${idx}Code', d.code);
        yield HomeWidget.saveWidgetData('day${idx}Date', d.date);
        yield HomeWidget.saveWidgetData('day${idx}_condition', d.condition);
      }),

      // Current data
      HomeWidget.saveWidgetData('temperatureCurrentPill', formatTemp(temp)),
      HomeWidget.saveWidgetData('weather_codeCurrentPill', code.toString()),
      HomeWidget.saveWidgetData('todayMax', formatTemp(maxTemp)),
      HomeWidget.saveWidgetData('todayMin', formatTemp(minTemp)),
      HomeWidget.saveWidgetData('locationNameWidget', locName),
      HomeWidget.saveWidgetData('locationCurrentConditon', curCondName),
      HomeWidget.saveWidgetData('isDayWidget', isDay.toString()),
      
      // Widget updates
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
