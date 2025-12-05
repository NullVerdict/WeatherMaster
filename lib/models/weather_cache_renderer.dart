import 'dart:convert';
import 'package:hive_plus_secure/hive_plus_secure.dart';

class WeatherCacheRenderer {
  static const String _boxName = 'weatherMasterCache';

  static Future<Map<String, dynamic>?> renderData(String locationName) async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }

    final box = Hive.box(_boxName);
    final jsonStr = box.get(locationName);

    if (jsonStr != null) {
      return json.decode(jsonStr);
    }
    return null;
  }
}
