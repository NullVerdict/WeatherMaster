import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import '../utils/preferences_helper.dart';
import 'package:flutter/material.dart';
import '../screens/meteo_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class WeatherService {
  static const String _boxName = 'weatherMasterCache';

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<Map<String, dynamic>?> fetchWeather(double lat, double lon,
      {String? locationName,
      BuildContext? context,
      bool isOnlyView = false,
      bool isBackground = false}) async {
    final timezone = tzmap.latLngToTimezoneString(lat, lon);
    final key = locationName ?? 'loc_${lat}_${lon}';
    final box = await _openBox();

    final selectedModel =
        PreferencesHelper.getString("selectedWeatherModel") ?? "best_match";

    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast')
        .replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current':
          'temperature_2m,is_day,apparent_temperature,pressure_msl,relative_humidity_2m,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m',
      'hourly':
          'wind_speed_10m,wind_direction_10m,relative_humidity_2m,pressure_msl,cloud_cover,temperature_2m,dew_point_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,visibility,uv_index',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,daylight_duration,uv_index_max,precipitation_sum,precipitation_probability_max,precipitation_hours,wind_speed_10m_max,wind_gusts_10m_max',
      'timezone': timezone,
      'forecast_days': '7',
      'models': selectedModel,
      'past_days': '1'
    });

    final airQualityUri =
        Uri.parse('https://air-quality-api.open-meteo.com/v1/air-quality')
            .replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current':
          'us_aqi,european_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen',
      'timezone': timezone,
      'forecast_hours': '1',
    });

    Uri? astronomyUri;
    if (!isBackground) {
      astronomyUri = Uri.parse(
          'https://api.weatherapi.com/v1/astronomy.json?key=${dotenv.env['API_KEY_WEATHERAPI'].toString()}&q=$lat,$lon');
    }

    try {
      final requests = <Future<http.Response>>[
        http.get(uri).timeout(const Duration(seconds: 15)),
        http.get(airQualityUri).timeout(const Duration(seconds: 15)),
        if (astronomyUri != null)
          http.get(astronomyUri).timeout(const Duration(seconds: 15)),
      ];

      final responses = await Future.wait(requests);

      for (var response in responses) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
              'HTTP request failed with status: ${response.statusCode}');
        }
      }

      final weatherBody = responses[0].body;
      final airQualityBody = responses[1].body;
      final astronomyBody = astronomyUri != null ? responses[2].body : null;
      final cachedJson = isOnlyView ? null : box.get(key) as String?;

      var processingResult = await compute(_processWeatherData, {
        'weatherBody': weatherBody,
        'airQualityBody': airQualityBody,
        'astronomyBody': astronomyBody,
        'cachedJson': cachedJson,
        'selectedModel': selectedModel,
        'isOnlyView': isOnlyView,
        'checkIncomplete': true,
      });

      if (processingResult['status'] == 'incomplete') {
        log("Data incomplete, fetching fallback...");
        final fallbackUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'models': 'best_match',
        });

        final fallbackResponse = await http.get(fallbackUri);
        final fallbackBody = fallbackResponse.body;

        processingResult = await compute(_processWeatherData, {
          'weatherBody': weatherBody,
          'airQualityBody': airQualityBody,
          'astronomyBody': astronomyBody,
          'fallbackBody': fallbackBody,
          'cachedJson': cachedJson,
          'selectedModel': selectedModel,
          'isOnlyView': isOnlyView,
          'checkIncomplete': false,
        });
      }

      if (processingResult['status'] == 'error') {
        final reason = processingResult['reason'] ?? 'Unknown error';
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 10),
              content: Text("$reason. Please change your model"),
              action: SnackBarAction(
                label: 'Change model',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MeteoModelsPage()),
                  );
                },
              ),
            ),
          );
        }
        return null;
      }

      final resultData = processingResult['data'] as Map<String, dynamic>;
      final fromCache = processingResult['from_cache'] as bool;
      final dataToCache = processingResult['data_to_cache'] as String?;

      if (fromCache) {
        log("Hive: No update needed for $key");
        return resultData;
      }

      if (dataToCache != null && !isOnlyView) {
        await box.put(key, dataToCache);
        log("Hive: Updated cache for $key");
      }

      return resultData;

    } on TimeoutException catch (_) {
      throw Exception("Request timed out after 15 seconds");
    } catch (e) {
      throw Exception('WeatherService.fetchWeather failed: $e');
    }
  }
}

Future<Map<String, dynamic>> _processWeatherData(Map<String, dynamic> args) async {
  final weatherBody = args['weatherBody'] as String;
  final airQualityBody = args['airQualityBody'] as String;
  final astronomyBody = args['astronomyBody'] as String?;
  final fallbackBody = args['fallbackBody'] as String?;
  final cachedJson = args['cachedJson'] as String?;
  final selectedModel = args['selectedModel'] as String;
  final checkIncomplete = args['checkIncomplete'] as bool;
  final isOnlyView = args['isOnlyView'] as bool;

  try {
    final weatherData = json.decode(weatherBody) as Map<String, dynamic>;
    final airQualityData = json.decode(airQualityBody) as Map<String, dynamic>;
    final astronomyData = astronomyBody != null
        ? json.decode(astronomyBody) as Map<String, dynamic>
        : <String, dynamic>{};

    if (weatherData['error'] == true ||
        airQualityData['error'] == true ||
        astronomyData['error'] == true) {
      return {
        'status': 'error',
        'reason': weatherData['reason'] ??
            airQualityData['reason'] ??
            astronomyData['reason']
      };
    }

    if (checkIncomplete && selectedModel != "best_match") {
      if (_hasIncompleteData(weatherData)) {
        return {'status': 'incomplete'};
      }
    }

    Map<String, dynamic> finalWeatherData = weatherData;
    if (fallbackBody != null) {
      final fallbackData = json.decode(fallbackBody) as Map<String, dynamic>;
      if (fallbackData['error'] != true) {
        finalWeatherData = _mergeWeatherData(weatherData, fallbackData);
      }
    }

    finalWeatherData['current'] = _sanitizeCurrent(finalWeatherData['current']);
    finalWeatherData['hourly'] = _sanitizeHourly(finalWeatherData['hourly']);
    finalWeatherData['daily'] = _sanitizeDaily(finalWeatherData['daily']);

    final combinedData = {
      ...finalWeatherData,
      'air_quality': airQualityData,
      'astronomy': astronomyData,
    };

    final now = DateTime.now().toIso8601String();

    if (cachedJson != null && !isOnlyView) {
      final cachedMap = json.decode(cachedJson);
      final cachedData = cachedMap['data'];
      final lastUpdated = cachedMap['last_updated'];

      if (_fastDeepEquals(finalWeatherData['current'], cachedData['current']) &&
          _fastDeepEquals(airQualityData, cachedData['air_quality']) &&
          _fastDeepEquals(astronomyData, cachedData['astronomy'])) {
        return {
          'status': 'success',
          'data': {'data': cachedData, 'last_updated': lastUpdated, 'from_cache': true},
          'from_cache': true,
        };
      }
    }

    final result = {
      'data': combinedData,
      'last_updated': now,
      'from_cache': false,
    };

    String? dataToCache;
    if (!isOnlyView) {
      dataToCache = json.encode({
        'data': combinedData,
        'last_updated': now,
      });
    }

    return {
      'status': 'success',
      'data': result,
      'from_cache': false,
      'data_to_cache': dataToCache,
    };

  } catch (e) {
    return {'status': 'error', 'reason': e.toString()};
  }
}

bool _hasIncompleteData(Map<String, dynamic> weatherData) {
  final current = weatherData['current'] as Map<String, dynamic>?;
  if (current == null) return true;
  
  if (current.values.any((v) => v == null)) return true;

  final hourly = weatherData['hourly'] as Map<String, dynamic>?;
  if (hourly == null) return true;
  
  final hourlyTemps = hourly['temperature_2m'] as List?;
  if (hourlyTemps == null || hourlyTemps.isEmpty || hourlyTemps.contains(null)) return true;

  final daily = weatherData['daily'] as Map<String, dynamic>?;
  if (daily == null) return true;
  
  final dailyMax = daily['temperature_2m_max'] as List?;
  if (dailyMax == null || dailyMax.isEmpty || dailyMax.contains(null)) return true;

  return false;
}

Map<String, dynamic> _mergeWeatherData(
    Map<String, dynamic> primary, Map<String, dynamic> fallback) {
  final merged = Map<String, dynamic>.from(primary);
  
  void mergeSection(String section) {
    merged[section] = _mergeMap(
      primary[section] as Map<String, dynamic>?,
      fallback[section] as Map<String, dynamic>?
    );
  }

  mergeSection('current');
  mergeSection('hourly');
  mergeSection('daily');

  for (final key in fallback.keys) {
    if (merged[key] == null) {
      merged[key] = fallback[key];
    }
  }
  return merged;
}

Map<String, dynamic> _mergeMap(Map<String, dynamic>? primary, Map<String, dynamic>? fallback) {
  if (primary == null) return fallback != null ? Map.from(fallback) : {};
  if (fallback == null) return Map.from(primary);

  final merged = Map<String, dynamic>.from(primary);
  for (final key in fallback.keys) {
    final pVal = merged[key];
    final fVal = fallback[key];

    if (pVal == null) {
      merged[key] = fVal;
    } else if (pVal is List && fVal is List) {
      final len = pVal.length > fVal.length ? pVal.length : fVal.length;
      merged[key] = List.generate(len, (i) {
        final p = i < pVal.length ? pVal[i] : null;
        final f = i < fVal.length ? fVal[i] : null;
        return p ?? f;
      });
    }
  }
  return merged;
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

Map<String, dynamic> _sanitizeCurrent(Map? current) {
  if (current == null) return {};
  return {
    'temperature_2m': _toDouble(current['temperature_2m']),
    'apparent_temperature': _toDouble(current['apparent_temperature']),
    'pressure_msl': _toDouble(current['pressure_msl']),
    'relative_humidity_2m': _toInt(current['relative_humidity_2m']),
    'precipitation': _toDouble(current['precipitation']),
    'weather_code': _toInt(current['weather_code']),
    'cloud_cover': _toInt(current['cloud_cover']),
    'wind_speed_10m': _toDouble(current['wind_speed_10m']),
    'wind_direction_10m': _toInt(current['wind_direction_10m']),
    'wind_gusts_10m': _toDouble(current['wind_gusts_10m']),
    'is_day': _toInt(current['is_day']),
  };
}

Map<String, dynamic> _sanitizeHourly(Map? hourly) {
  if (hourly == null) return {};
  final time = (hourly['time'] as List?) ?? [];
  final len = time.length;

  List<T> mapList<T>(String key, T Function(dynamic) mapper) {
    final list = hourly![key] as List?;
    if (list == null) return [];
    final effectiveLen = list.length < len ? list.length : len;
    final result = List<T>.filled(effectiveLen, mapper(null)); 
    for (int i = 0; i < effectiveLen; i++) {
      result[i] = mapper(list[i]);
    }
    return result;
  }

  return {
    'time': time,
    'wind_speed_10m': mapList('wind_speed_10m', _toDouble),
    'wind_direction_10m': mapList('wind_direction_10m', _toInt),
    'relative_humidity_2m': mapList('relative_humidity_2m', _toInt),
    'pressure_msl': mapList('pressure_msl', _toDouble),
    'cloud_cover': mapList('cloud_cover', _toInt),
    'temperature_2m': mapList('temperature_2m', _toDouble),
    'dew_point_2m': mapList('dew_point_2m', _toDouble),
    'apparent_temperature': mapList('apparent_temperature', _toDouble),
    'precipitation_probability': mapList('precipitation_probability', _toInt),
    'precipitation': mapList('precipitation', _toDouble),
    'weather_code': mapList('weather_code', _toInt),
    'visibility': mapList('visibility', _toDouble),
    'uv_index': mapList('uv_index', _toDouble),
  };
}

Map<String, dynamic> _sanitizeDaily(Map? daily) {
  if (daily == null) return {};
  final time = (daily['time'] as List?) ?? [];
  final len = time.length;

  List<T> mapList<T>(String key, T Function(dynamic) mapper) {
    final list = daily![key] as List?;
    if (list == null) return [];
    final effectiveLen = list.length < len ? list.length : len;
    final result = List<T>.filled(effectiveLen, mapper(null));
    for (int i = 0; i < effectiveLen; i++) {
      result[i] = mapper(list[i]);
    }
    return result;
  }

  return {
    'time': time,
    'weather_code': mapList('weather_code', _toInt),
    'temperature_2m_max': mapList('temperature_2m_max', _toDouble),
    'temperature_2m_min': mapList('temperature_2m_min', _toDouble),
    'sunrise': (daily['sunrise'] as List?) ?? [],
    'sunset': (daily['sunset'] as List?) ?? [],
    'daylight_duration': mapList('daylight_duration', _toDouble),
    'uv_index_max': mapList('uv_index_max', _toDouble),
    'precipitation_sum': mapList('precipitation_sum', _toDouble),
    'precipitation_probability_max': mapList('precipitation_probability_max', _toInt),
    'precipitation_hours': mapList('precipitation_hours', _toDouble),
    'wind_speed_10m_max': mapList('wind_speed_10m_max', _toDouble),
    'wind_gusts_10m_max': mapList('wind_gusts_10m_max', _toDouble),
  };
}

bool _fastDeepEquals(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;

  if (a is List && b is List) {
    if (a.length != b.length) return false;
    if (a.isNotEmpty) {
      if (!_fastDeepEquals(a.first, b.first)) return false;
      if (!_fastDeepEquals(a.last, b.last)) return false;
    }
    for (int i = 1; i < a.length - 1; i++) {
      if (!_fastDeepEquals(a[i], b[i])) return false;
    }
    return true;
  }

  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_fastDeepEquals(a[key], b[key])) return false;
    }
    return true;
  }

  return a == b;
}