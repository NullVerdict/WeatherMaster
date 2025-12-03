import 'package:flutter/material.dart';

class WeatherDataProcessor {
  final Map<String, dynamic> weatherData;
  
  late final _ProcessedWeatherData _processed;
  
  WeatherDataProcessor(this.weatherData) {
    _processed = _preprocessAllData();
  }

  _ProcessedWeatherData _preprocessAllData() {
    final current = weatherData['current'];
    final hourly = weatherData['hourly'] ?? {};
    final daily = weatherData['daily'];
    
    final weatherCode = current['weather_code'] ?? 0;
    final isDay = current['is_day'] == 1;
    
    final filteredHourly = _filterHourlyData(hourly);
    
    final daylightMap = _buildDaylightMap(daily);
    
    final rainData = _computeRainData(hourly, weatherData['utc_offset_seconds'].toString());
    
    return _ProcessedWeatherData(
      weatherCode: weatherCode,
      isDay: isDay,
      currentTemp: current['temperature_2m'].toDouble(),
      currentFeelsLike: current['apparent_temperature'].toDouble(),
      currentHumidity: current['relative_humidity_2m'] ?? 0.0000001,
      currentPressure: current['pressure_msl'] ?? 0.0000001,
      currentWindSpeed: current['wind_speed_10m'] ?? 0.0000001,
      currentWindDirection: current['wind_direction_10m'] ?? 0.0000001,
      filteredHourlyTime: filteredHourly.time,
      filteredHourlyTemps: filteredHourly.temps,
      filteredHourlyWeatherCodes: filteredHourly.weatherCodes,
      filteredHourlyPrecpProb: filteredHourly.precpProb,
      dailyDates: daily['time'],
      dailyTempsMin: daily['temperature_2m_min'],
      dailyTempsMax: daily['temperature_2m_max'],
      dailyWeatherCodes: daily['weather_code'],
      dailyPrecProb: daily['precipitation_probability_max'],
      daylightMap: daylightMap,
      shouldShowRainBlock: rainData.shouldShow,
      utcOffsetSeconds: weatherData['utc_offset_seconds'].toString(),
      timezone: weatherData['timezone'].toString(),
    );
  }

  _FilteredHourlyData _filterHourlyData(Map<String, dynamic> hourly) {
    final List<dynamic> hourlyTimeNoFilter = hourly['time'];
    final List<dynamic> hourlyTempsNoFilter = hourly['temperature_2m'];
    final List<dynamic> hourlyWeatherCodesNoFilter = hourly['weather_code'];
    final List<dynamic> hourlyPrecpProbNoFilter = hourly['precipitation_probability'];

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final filteredIndices = <int>[];
    for (int i = 0; i < hourlyTimeNoFilter.length; i++) {
      final time = DateTime.parse(hourlyTimeNoFilter[i]);
      if (time.isAfter(todayMidnight) || time.isAtSameMomentAs(todayMidnight)) {
        filteredIndices.add(i);
      }
    }

    return _FilteredHourlyData(
      time: filteredIndices.map((i) => hourlyTimeNoFilter[i]).toList(),
      temps: filteredIndices.map((i) => hourlyTempsNoFilter[i]).toList(),
      weatherCodes: filteredIndices.map((i) => hourlyWeatherCodesNoFilter[i]).toList(),
      precpProb: filteredIndices.map((i) => hourlyPrecpProbNoFilter[i]).toList(),
    );
  }

  Map<String, (DateTime, DateTime)> _buildDaylightMap(Map<String, dynamic> daily) {
    final List<dynamic> dailyDates = daily['time'];
    final List<dynamic> sunriseTimes = daily['sunrise'];
    final List<dynamic> sunsetTimes = daily['sunset'];
    
    return {
      for (int i = 0; i < dailyDates.length; i++)
        dailyDates[i]: (
          DateTime.parse(sunriseTimes[i]),
          DateTime.parse(sunsetTimes[i])
        ),
    };
  }

  _RainData _computeRainData(Map<String, dynamic> hourly, String utcOffsetSeconds) {
    const double rainThreshold = 0.5;
    const int probThreshold = 40;
    
    int offsetSeconds = int.parse(utcOffsetSeconds);
    DateTime utcNow = DateTime.now().toUtc();
    DateTime nowPrecip = utcNow.add(Duration(seconds: offsetSeconds));

    nowPrecip = DateTime(
      nowPrecip.year,
      nowPrecip.month,
      nowPrecip.day,
      nowPrecip.hour,
      nowPrecip.minute,
      nowPrecip.second,
      nowPrecip.millisecond,
      nowPrecip.microsecond,
    );

    final List<String> allTimeStrings = (hourly['time'] as List?)?.cast<String>() ?? [];
    final List<double> allPrecip = (hourly['precipitation'] as List?)
            ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
            .toList() ??
        [];
    final List<int> allPrecipProb = (hourly['precipitation_probability'] as List?)
            ?.map((e) => (e as num?)?.toInt() ?? 0)
            .toList() ??
        [];

    final List<double> precpNext12h = [];
    final List<int> precipProbNext12h = [];

    for (int i = 0; i < allTimeStrings.length; i++) {
      if (i >= allPrecip.length || i >= allPrecipProb.length) break;

      final time = DateTime.parse(allTimeStrings[i]);
      if (time.isAfter(nowPrecip) && time.isBefore(nowPrecip.add(const Duration(hours: 12)))) {
        precpNext12h.add(allPrecip[i]);
        precipProbNext12h.add(allPrecipProb[i]);
      }
    }

    int? rainStart;
    int longestRainLength = 0;
    int? bestStart;
    int? bestEnd;

    for (int i = 0; i < precpNext12h.length; i++) {
      if (precpNext12h[i] >= rainThreshold && precipProbNext12h[i] >= probThreshold) {
        rainStart ??= i;
      } else {
        if (rainStart != null) {
          final length = i - rainStart;
          if (length >= 2 && length > longestRainLength) {
            longestRainLength = length;
            bestStart = rainStart;
            bestEnd = i - 1;
          }
          rainStart = null;
        }
      }
    }

    if (rainStart != null) {
      final length = precpNext12h.length - rainStart;
      if (length >= 2 && length > longestRainLength) {
        bestStart = rainStart;
        bestEnd = precpNext12h.length - 1;
      }
    }

    return _RainData(shouldShow: bestStart != null && bestEnd != null);
  }

  _ProcessedWeatherData get processed => _processed;
}

class _ProcessedWeatherData {
  final int weatherCode;
  final bool isDay;
  final double currentTemp;
  final double currentFeelsLike;
  final dynamic currentHumidity;
  final dynamic currentPressure;
  final dynamic currentWindSpeed;
  final dynamic currentWindDirection;
  final List<dynamic> filteredHourlyTime;
  final List<dynamic> filteredHourlyTemps;
  final List<dynamic> filteredHourlyWeatherCodes;
  final List<dynamic> filteredHourlyPrecpProb;
  final List<dynamic> dailyDates;
  final List<dynamic> dailyTempsMin;
  final List<dynamic> dailyTempsMax;
  final List<dynamic> dailyWeatherCodes;
  final List<dynamic> dailyPrecProb;
  final Map<String, (DateTime, DateTime)> daylightMap;
  final bool shouldShowRainBlock;
  final String utcOffsetSeconds;
  final String timezone;

  const _ProcessedWeatherData({
    required this.weatherCode,
    required this.isDay,
    required this.currentTemp,
    required this.currentFeelsLike,
    required this.currentHumidity,
    required this.currentPressure,
    required this.currentWindSpeed,
    required this.currentWindDirection,
    required this.filteredHourlyTime,
    required this.filteredHourlyTemps,
    required this.filteredHourlyWeatherCodes,
    required this.filteredHourlyPrecpProb,
    required this.dailyDates,
    required this.dailyTempsMin,
    required this.dailyTempsMax,
    required this.dailyWeatherCodes,
    required this.dailyPrecProb,
    required this.daylightMap,
    required this.shouldShowRainBlock,
    required this.utcOffsetSeconds,
    required this.timezone,
  });

  bool isHourDuringDaylight(DateTime hourTime) {
    final key =
        "${hourTime.year.toString().padLeft(4, '0')}-${hourTime.month.toString().padLeft(2, '0')}-${hourTime.day.toString().padLeft(2, '0')}";
    final times = daylightMap[key];
    if (times != null) {
      return hourTime.isAfter(times.$1) && hourTime.isBefore(times.$2);
    }
    return true;
  }
}

class _FilteredHourlyData {
  final List<dynamic> time;
  final List<dynamic> temps;
  final List<dynamic> weatherCodes;
  final List<dynamic> precpProb;

  const _FilteredHourlyData({
    required this.time,
    required this.temps,
    required this.weatherCodes,
    required this.precpProb,
  });
}

class _RainData {
  final bool shouldShow;

  const _RainData({required this.shouldShow});
}
