import 'dart:math';

class WeatherDataProcessor {
  final Map<String, dynamic> rawData;

  late final Map<String, dynamic> current;
  late final Map<String, dynamic> hourly;
  late final Map<String, dynamic> daily;
  late final Map<String, dynamic> airQuality;
  
  // Processed Data
  late final List<dynamic> filteredHourlyTime;
  late final List<dynamic> filteredHourlyTemps;
  late final List<dynamic> filteredHourlyWeatherCodes;
  late final List<dynamic> filteredHourlyPrecpProb;
  
  late final Map<String, (DateTime, DateTime)> daylightMap;
  
  // Rain Logic
  late final bool shouldShowRainBlock;
  late final int? rainStart;
  late final int? rainEnd;

  WeatherDataProcessor(this.rawData) {
    _processData();
  }

  void _processData() {
    final data = rawData['data'];
    current = data['current'];
    hourly = data['hourly'] ?? {};
    daily = data['daily'] ?? {};
    airQuality = data['air_quality'] ?? {};

    _processHourlyData();
    _processDaylightMap();
    _processRainLogic();
  }

  void _processHourlyData() {
    final List<dynamic> time = hourly['time'] ?? [];
    final List<dynamic> temps = hourly['temperature_2m'] ?? [];
    final List<dynamic> codes = hourly['weather_code'] ?? [];
    final List<dynamic> probs = hourly['precipitation_probability'] ?? [];

    filteredHourlyTime = [];
    filteredHourlyTemps = [];
    filteredHourlyWeatherCodes = [];
    filteredHourlyPrecpProb = [];

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    for (int i = 0; i < time.length; i++) {
      final t = DateTime.parse(time[i]);
      if (t.millisecondsSinceEpoch >= todayMidnight) {
        filteredHourlyTime.add(time[i]);
        filteredHourlyTemps.add(temps[i]);
        filteredHourlyWeatherCodes.add(codes[i]);
        filteredHourlyPrecpProb.add(probs[i]);
      }
    }
  }

  void _processDaylightMap() {
    daylightMap = {};
    final List<dynamic> dates = daily['time'] ?? [];
    final List<dynamic> sunrise = daily['sunrise'] ?? [];
    final List<dynamic> sunset = daily['sunset'] ?? [];

    for (int i = 0; i < dates.length; i++) {
      daylightMap[dates[i]] = (
        DateTime.parse(sunrise[i]),
        DateTime.parse(sunset[i])
      );
    }
  }

  bool isHourDuringDaylight(DateTime hourTime) {
    final key = "${hourTime.year.toString().padLeft(4, '0')}-${hourTime.month.toString().padLeft(2, '0')}-${hourTime.day.toString().padLeft(2, '0')}";
    final times = daylightMap[key];
    if (times != null) {
      return hourTime.isAfter(times.$1) && hourTime.isBefore(times.$2);
    }
    return true;
  }

  void _processRainLogic() {
    const double rainThreshold = 0.5;
    const int probThreshold = 40;
    
    final int offsetSeconds = int.parse(rawData['utc_offset_seconds'].toString());
    final DateTime utcNow = DateTime.now().toUtc();
    final DateTime nowPrecip = utcNow.add(Duration(seconds: offsetSeconds));
    
    // Normalize to minute precision to match original logic if needed, 
    // but original logic just used DateTime constructor to strip sub-second?
    // Actually original logic: DateTime(y,m,d,h,m,s,ms,us) - wait, it didn't strip anything?
    // "nowPrecip = DateTime(..., nowPrecip.microsecond)" -> it just copied it. Redundant.
    
    final List<String> allTimeStrings = (hourly['time'] as List?)?.cast<String>() ?? [];
    final List<double> allPrecip = (hourly['precipitation'] as List?)
            ?.map((e) => (e as num?)?.toDouble() ?? 0.0)
            .toList() ?? [];
    final List<int> allPrecipProb = (hourly['precipitation_probability'] as List?)
            ?.map((e) => (e as num?)?.toInt() ?? 0)
            .toList() ?? [];

    final List<double> precpNext12h = [];
    final List<int> precipProbNext12h = [];
    
    final limit = nowPrecip.add(const Duration(hours: 12));

    for (int i = 0; i < allTimeStrings.length; i++) {
      if (i >= allPrecip.length || i >= allPrecipProb.length) break;

      final time = DateTime.parse(allTimeStrings[i]);
      if (time.isAfter(nowPrecip) && time.isBefore(limit)) {
        precpNext12h.add(allPrecip[i]);
        precipProbNext12h.add(allPrecipProb[i]);
      }
    }

    int? start;
    int longestRainLength = 0;
    int? bestStart;
    int? bestEnd;

    for (int i = 0; i < precpNext12h.length; i++) {
      if (precpNext12h[i] >= rainThreshold && precipProbNext12h[i] >= probThreshold) {
        start ??= i;
      } else {
        if (start != null) {
          final length = i - start;
          if (length >= 2 && length > longestRainLength) {
            longestRainLength = length;
            bestStart = start;
            bestEnd = i - 1;
          }
          start = null;
        }
      }
    }

    if (start != null) {
      final length = precpNext12h.length - start;
      if (length >= 2 && length > longestRainLength) {
        bestStart = start;
        bestEnd = precpNext12h.length - 1;
      }
    }

    shouldShowRainBlock = bestStart != null && bestEnd != null;
    rainStart = bestStart;
    rainEnd = bestEnd;
    
    this.timeNext12h = timeNext12h;
    this.precpNext12h = precpNext12h;
    this.precipProbNext12h = precipProbNext12h;
  }
  
  late final List<String> timeNext12h;
  late final List<double> precpNext12h;
  late final List<int> precipProbNext12h;
}
