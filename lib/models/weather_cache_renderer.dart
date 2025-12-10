import 'dart:convert';
import 'package:hive/hive.dart';

class WeatherCacheRenderer {
  static const String _boxName = 'weatherMasterCache';
  static Box? _cachedBox;

  static Future<Box> _getBox() async {
    _cachedBox ??= await Hive.openBox(_boxName);
    return _cachedBox!;
  }

  static Future<Map<String, dynamic>?> renderData(String locationName) async {
    final box = await _getBox();
    final jsonStr = box.get(locationName);

    if (jsonStr != null) {
      return json.decode(jsonStr);
    }
    return null;
  }

  static void dispose() {
    _cachedBox?.close();
    _cachedBox = null;
  }
}
