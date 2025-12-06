import 'dart:convert';
import 'package:hive_plus_secure/hive_plus_secure.dart';

class WeatherCacheRenderer {
  static const String _boxName = 'weatherMasterCache';

  static Future<Map<String, dynamic>?> renderData(String locationName) async {
    final box = Hive.box(name: _boxName);
    final jsonStr = box.get(locationName);

    if (jsonStr != null) {
      return json.decode(jsonStr);
    }
    return null;
  }
}
