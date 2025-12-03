import 'package:flutter/material.dart';

class WeatherStateNotifier extends ChangeNotifier {
  Map<String, dynamic>? _weatherData;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setWeatherData(Map<String, dynamic>? data) {
    if (_weatherData != data) {
      _weatherData = data;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void setError(String? error) {
    if (_error != error) {
      _error = error;
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() => setError(null);
}

class ThemeIndexNotifier extends ChangeNotifier {
  int _gradientIndex = 2;
  int _searchBgIndex = 2;
  int _containerBgIndex = 2;
  int _conditionColorIndex = 2;

  int get gradientIndex => _gradientIndex;
  int get searchBgIndex => _searchBgIndex;
  int get containerBgIndex => _containerBgIndex;
  int get conditionColorIndex => _conditionColorIndex;

  void updateIndices(int newIndex) {
    if (_gradientIndex != newIndex ||
        _searchBgIndex != newIndex ||
        _containerBgIndex != newIndex ||
        _conditionColorIndex != newIndex) {
      _gradientIndex = newIndex;
      _searchBgIndex = newIndex;
      _containerBgIndex = newIndex;
      _conditionColorIndex = newIndex;
      notifyListeners();
    }
  }
}

class LocationStateNotifier extends ChangeNotifier {
  String _cityName = '';
  String _countryName = '';
  String _cacheKey = '';
  double? _lat;
  double? _lon;
  bool _isViewLocation = false;

  String get cityName => _cityName;
  String get countryName => _countryName;
  String get cacheKey => _cacheKey;
  double? get lat => _lat;
  double? get lon => _lon;
  bool get isViewLocation => _isViewLocation;

  void updateLocation({
    required String cityName,
    required String countryName,
    required String cacheKey,
    required double lat,
    required double lon,
    bool isViewLocation = false,
  }) {
    bool changed = _cityName != cityName ||
        _countryName != countryName ||
        _cacheKey != cacheKey ||
        _lat != lat ||
        _lon != lon ||
        _isViewLocation != isViewLocation;

    if (changed) {
      _cityName = cityName;
      _countryName = countryName;
      _cacheKey = cacheKey;
      _lat = lat;
      _lon = lon;
      _isViewLocation = isViewLocation;
      notifyListeners();
    }
  }

  void setViewLocation(bool isView) {
    if (_isViewLocation != isView) {
      _isViewLocation = isView;
      notifyListeners();
    }
  }
}

class AnimationStateNotifier extends ChangeNotifier {
  Widget? _weatherAnimationWidget;
  int? _cachedWeatherCode;
  int? _cachedIsDay;
  bool? _cachedIsShowFrog;

  Widget? get weatherAnimationWidget => _weatherAnimationWidget;

  void updateAnimation({
    required Widget? widget,
    required int? weatherCode,
    required int? isDay,
    required bool? isShowFrog,
  }) {
    if (_weatherAnimationWidget != widget ||
        _cachedWeatherCode != weatherCode ||
        _cachedIsDay != isDay ||
        _cachedIsShowFrog != isShowFrog) {
      _weatherAnimationWidget = widget;
      _cachedWeatherCode = weatherCode;
      _cachedIsDay = isDay;
      _cachedIsShowFrog = isShowFrog;
      notifyListeners();
    }
  }

  bool shouldUpdate(int weatherCode, int isDay, bool isShowFrog) {
    return _cachedWeatherCode != weatherCode ||
        _cachedIsDay != isDay ||
        _cachedIsShowFrog != isShowFrog;
  }
}

class FroggyIconNotifier extends ChangeNotifier {
  String? _iconUrl;
  bool _isLoading = true;

  String? get iconUrl => _iconUrl;
  bool get isLoading => _isLoading;

  void setIcon(String? url) {
    if (_iconUrl != url) {
      _iconUrl = url;
      _isLoading = false;
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }
}
