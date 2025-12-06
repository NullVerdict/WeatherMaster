import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/snack_util.dart';

class DataBackupService {
  static Future<void> exportData() async {
    final prefs = await SharedPreferences.getInstance();

    final sharedPrefsData = prefs.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
      map[key] = prefs.get(key);
      return map;
    });

    final cacheData = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('weather_cache_')) {
        cacheData[key] = prefs.get(key);
      }
    }

    final allData = {
      'app': 'WeatherMaster',
      'version': 1,
      'cache': cacheData,
      'sharedPreferences': sharedPrefsData,
    };

    final jsonString = jsonEncode(allData);
    final jsonBytes = utf8.encode(jsonString);

    try {
      final outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup file',
        fileName: 'WeatherMaster_data_export.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: jsonBytes,
      );

      if (outputFilePath != null) {
      } else {
      }
    } catch (e) {
      return;
    }
  }

  static Future<void> importAndReplaceAllData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select backup file to import',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('import_data'.tr()),
          content: Text(
            'import_data_sub'.tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      final pickedFile = result.files.single;
      final fileBytes = pickedFile.bytes;

      if (fileBytes == null) {
        return;
      }

      final jsonString = utf8.decode(fileBytes);
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (data['app'] != 'WeatherMaster' ||
          !data.containsKey('sharedPreferences')) {
        if (!context.mounted) return;
        SnackUtil.showSnackBar(context: context, message: "Invalid backup file format.");
        return;
      }

      await prefs.clear();

      final sharedPrefsData = Map<String, dynamic>.from(data['sharedPreferences'] ?? {});
      for (final entry in sharedPrefsData.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, List<String>.from(value));
        }
      }

      final cacheData = Map<String, dynamic>.from(data['cache'] ?? {});
      for (final entry in cacheData.entries) {
        if (entry.value is String) {
          await prefs.setString(entry.key, entry.value);
        }
      }

      if (!context.mounted) return;
      SnackUtil.showSnackBar(context: context, message: "Import complete");
    } catch (e) {
      if (!context.mounted) return;
      SnackUtil.showSnackBar(context: context, message: "Error during import");
    }
  }
}
