import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'dart:convert';
import 'dart:async';

import '../utils/gradient_cache.dart';
import '../widgets/scroll_gradient.dart';
import '../widgets/hourly_card.dart';
import '../widgets/daily_card.dart';
import '../widgets/top_weather_card.dart';
import '../models/weather_data_processor.dart';
import '../notifiers/weather_state_notifiers.dart';
import '../notifiers/unit_settings_notifier.dart';
import '../utils/preferences_helper.dart';
import '../services/fetch_data.dart';

class WeatherHome extends StatefulWidget {
  final String cacheKey;
  final String cityName;
  final String countryName;
  final bool isHomeLocation;
  final double? lat;
  final double? lon;

  const WeatherHome({
    super.key,
    required this.cacheKey,
    required this.cityName,
    required this.countryName,
    required this.isHomeLocation,
    required this.lat,
    required this.lon,
  });

  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  late final ValueNotifier<bool> _showHeaderNotifier;
  late final ScrollController _scrollController;
  late final WeatherStateNotifier _weatherNotifier;
  late final ThemeIndexNotifier _themeIndexNotifier;
  late final LocationStateNotifier _locationNotifier;
  late final AnimationStateNotifier _animationNotifier;
  late final FroggyIconNotifier _froggyIconNotifier;

  WeatherDataProcessor? _processor;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _showHeaderNotifier = ValueNotifier(false);
    _scrollController = ScrollController();
    _weatherNotifier = WeatherStateNotifier();
    _themeIndexNotifier = ThemeIndexNotifier();
    _locationNotifier = LocationStateNotifier();
    _animationNotifier = AnimationStateNotifier();
    _froggyIconNotifier = FroggyIconNotifier();

    _locationNotifier.updateLocation(
      cityName: widget.cityName,
      countryName: widget.countryName,
      cacheKey: widget.cacheKey,
      lat: widget.lat!,
      lon: widget.lon!,
    );

    _loadWeatherData();
  }

  @override
  void dispose() {
    _showHeaderNotifier.dispose();
    _scrollController.dispose();
    _weatherNotifier.dispose();
    _themeIndexNotifier.dispose();
    _locationNotifier.dispose();
    _animationNotifier.dispose();
    _froggyIconNotifier.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWeatherData() async {
    _weatherNotifier.setLoading(true);

    final box = await Hive.openBox('weatherMasterCache');
    var cached = box.get(_locationNotifier.cacheKey);

    if (cached == null) {
      final weatherService = WeatherService();
      await weatherService.fetchWeather(
        _locationNotifier.lat!,
        _locationNotifier.lon!,
        locationName: _locationNotifier.cacheKey,
        context: context,
      );
      cached = box.get(_locationNotifier.cacheKey);
    }

    if (cached != null) {
      final weatherData = json.decode(cached);
      _processor = WeatherDataProcessor(weatherData);
      _weatherNotifier.setWeatherData(weatherData);
    } else {
      _weatherNotifier.setError('No data available');
    }
  }

  Future<void> _refreshWeatherData() async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final weatherService = WeatherService();
      try {
        await weatherService.fetchWeather(
          _locationNotifier.lat!,
          _locationNotifier.lon!,
          locationName: _locationNotifier.cacheKey,
          context: context,
        );
        await _loadWeatherData();
      } catch (e) {
        _weatherNotifier.setError(e.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isShowFrog = context.select<UnitSettingsNotifier, bool>((n) => n.showFrog);
    final colorTheme = Theme.of(context).colorScheme;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: const Color(0x01000000),
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isLight ? const Color(0x01000000) : const Color.fromRGBO(0, 0, 0, 0.3),
      ),
    );

    final gradients = GradientCache.getGradients(
      isLight: isLight,
      isShowFrog: isShowFrog,
      isCurrentDay: true,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _weatherNotifier),
        ChangeNotifierProvider.value(value: _themeIndexNotifier),
        ChangeNotifierProvider.value(value: _locationNotifier),
        ChangeNotifierProvider.value(value: _animationNotifier),
        ChangeNotifierProvider.value(value: _froggyIconNotifier),
      ],
      child: Stack(
        children: [
          ScrollReactiveGradient(
            scrollController: _scrollController,
            baseGradient: gradients[2],
            scrolledGradient: gradients[2],
            headerVisibilityNotifier: _showHeaderNotifier,
          ),
          Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            body: _buildBody(colorTheme),
          ),
          _buildLoadingOverlay(colorTheme),
          _buildHeader(isLight),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorTheme) {
    return CustomRefreshIndicator(
      onRefresh: _refreshWeatherData,
      builder: (context, child, controller) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            child,
            _buildRefreshIndicator(controller, colorTheme),
          ],
        );
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 10),
            _buildWeatherContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherContent() {
    return Consumer<WeatherStateNotifier>(
      builder: (context, weatherState, _) {
        if (weatherState.isLoading) {
          return const SizedBox.shrink();
        }

        if (weatherState.error != null || weatherState.weatherData == null) {
          return Center(
            child: Text(weatherState.error ?? 'No data'),
          );
        }

        if (_processor == null) return const SizedBox.shrink();

        final processed = _processor!.processed;
        final tempUnit = context.select<UnitSettingsNotifier, String>((n) => n.tempUnit);
        final timeUnit = context.select<UnitSettingsNotifier, String>((n) => n.timeUnit);
        final isShowFrog = context.select<UnitSettingsNotifier, bool>((n) => n.showFrog);

        return RepaintBoundary(
          child: Column(
            children: [
              _buildLocationHeader(),
              const SizedBox(height: 10),
              WeatherTopCard(
                currentTemp: processed.currentTemp,
                currentFeelsLike: processed.currentFeelsLike,
                currentMaxTemp: weatherState.weatherData!['daily']['temperature_2m_max'][0].toDouble(),
                currentMinTemp: weatherState.weatherData!['daily']['temperature_2m_min'][0].toDouble(),
                currentWeatherIconCode: processed.weatherCode,
                currentisDay: processed.isDay ? 1 : 0,
                currentLastUpdated: 'just now',
                tempUnit: tempUnit,
                isShowFrog: isShowFrog,
              ),
              const SizedBox(height: 14),
              HourlyCard(
                hourlyTime: processed.filteredHourlyTime,
                hourlyTemps: processed.filteredHourlyTemps,
                hourlyWeatherCodes: processed.filteredHourlyWeatherCodes,
                isHourDuringDaylightOptimized: processed.isHourDuringDaylight,
                selectedContainerBgIndex: Theme.of(context).colorScheme.surfaceContainerLowest.value,
                timezone: processed.timezone,
                utcOffsetSeconds: processed.utcOffsetSeconds,
                hourlyPrecpProb: processed.filteredHourlyPrecpProb,
                tempUnit: tempUnit,
                timeUnit: timeUnit,
              ),
              const SizedBox(height: 12),
              DailyCard(
                dailyTime: processed.dailyDates,
                dailyTempsMin: processed.dailyTempsMin,
                dailyWeatherCodes: processed.dailyWeatherCodes,
                dailyTempsMax: processed.dailyTempsMax,
                dailyPrecProb: processed.dailyPrecProb,
                utcOffsetSeconds: processed.utcOffsetSeconds,
                selectedContainerBgIndex: Theme.of(context).colorScheme.surfaceContainerLowest.value,
                tempUnit: tempUnit,
                isDarkCards: PreferencesHelper.getBool("useDarkerBackground") ?? false,
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationHeader() {
    return Consumer<LocationStateNotifier>(
      builder: (context, location, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${location.cityName}, ${location.countryName}",
                  style: const TextStyle(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.settings_outlined),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay(ColorScheme colorTheme) {
    return Consumer<WeatherStateNotifier>(
      builder: (context, state, _) {
        if (!state.isLoading) return const SizedBox.shrink();

        return Positioned.fill(
          child: Container(
            color: colorTheme.surface,
            child: Center(
              child: ExpressiveLoadingIndicator(
                activeSize: 48,
                color: colorTheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRefreshIndicator(
    IndicatorController controller,
    ColorScheme colorTheme,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final val = controller.value.clamp(0.0, 1.0);
        final isVisible = val > 0.0;

        return isVisible
            ? Positioned(
                top: -30 + 120 * val,
                child: Opacity(
                  opacity: val,
                  child: RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: colorTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: ExpressiveLoadingIndicator(
                        color: colorTheme.primary,
                        activeSize: 40,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink();
      },
    );
  }

  Widget _buildHeader(bool isLight) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showHeaderNotifier,
      builder: (context, show, child) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: show ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: show ? 1 : 0,
              child: IgnorePointer(
                ignoring: !show,
                child: Container(
                  height: MediaQuery.of(context).padding.top,
                  color: isLight
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
