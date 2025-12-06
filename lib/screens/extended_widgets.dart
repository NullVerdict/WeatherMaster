import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../helper/locale_helper.dart';
import '../providers/app_providers.dart';
import '../notifiers/unit_settings_notifier.dart';
import '../utils/preferences_helper.dart';
import '../utils/unit_converter.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';

class ExtendWidget extends ConsumerStatefulWidget {
  final String widgetType;
  const ExtendWidget(this.widgetType, {super.key});

  @override
  ConsumerState<ExtendWidget> createState() => _ExtendWidgetState();
}

class _ExtendWidgetState extends ConsumerState<ExtendWidget> {
  late final Widget Function(Map<String, dynamic> raw, UnitSettingsNotifier units) builder;
  late final String extendedTitle;
  late final IconData? iconData;

  bool _showLoader = true;
  WeatherRequest? _request;

  @override
  void initState() {
    super.initState();
    if (widget.widgetType == 'humidity_widget') {
      builder = buildHumidityExtended;
      extendedTitle = 'humidity'.tr();
      iconData = Symbols.humidity_mid;
    } else if (widget.widgetType == 'sun_widget') {
      builder = buildSunExtended;
      extendedTitle = 'sun_tile_page'.tr();
      iconData = Symbols.wb_twilight;
    } else if (widget.widgetType == 'pressure_widget') {
      builder = buildPressureExtended;
      extendedTitle = 'pressure'.tr();
      iconData = Symbols.compress;
    } else if (widget.widgetType == 'visibility_widget') {
      builder = buildVisibilityExtended;
      extendedTitle = 'visibility'.tr();
      iconData = Symbols.visibility;
    } else if (widget.widgetType == 'winddirc_widget') {
      builder = buildWindExtended;
      extendedTitle = 'wind'.tr();
      iconData = Symbols.air;
    } else if (widget.widgetType == 'uv_widget') {
      builder = buildUVExtended;
      extendedTitle = 'uv_index'.tr();
      iconData = Symbols.flare;
    } else if (widget.widgetType == 'aqi_widget') {
      builder = buildAQIExtended;
      extendedTitle = 'air_quality'.tr();
      iconData = Symbols.airwave;
    } else if (widget.widgetType == 'precip_widget') {
      builder = buildPrecipExtended;
      extendedTitle = 'precipitation'.tr();
      iconData = Symbols.rainy_heavy;
    } else if (widget.widgetType == 'moon_widget') {
      builder = buildMoonExtended;
      extendedTitle = 'moon'.tr();
      iconData = Symbols.nightlight;
    } else {
      builder = (raw, units) => const Center(child: Text('Unknown widget type'));
      extendedTitle = 'Error';
      iconData = null;
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showLoader = false;
        });
      }
    });

    _initRequest();
  }

  Future<void> _initRequest() async {
    await PreferencesHelper.init();
    final currentLocation = PreferencesHelper.getJson('currentLocation');
    if (currentLocation == null) return;

    final cacheKey = currentLocation['cacheKey'];
    final lat = (currentLocation['lat'] as num?)?.toDouble();
    final lon = (currentLocation['lon'] as num?)?.toDouble();

    if (!mounted) return;
    setState(() {
      _request = WeatherRequest(cacheKey: cacheKey, lat: lat, lon: lon);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorTheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _buildBody(colorTheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorTheme) {
    if (_request == null || _showLoader) {
      return Center(
        key: const ValueKey('loader'),
        child: ExpressiveLoadingIndicator(
          color: colorTheme.primary,
          activeSize: 48,
        ),
      );
    }

    final asyncWeather = ref.watch(weatherProvider(_request!));
    final units = ref.watch(unitSettingsProvider);

    return asyncWeather.when(
      loading: () => Center(
        key: const ValueKey('loader'),
        child: ExpressiveLoadingIndicator(
          color: colorTheme.primary,
          activeSize: 48,
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (raw) {
        if (raw == null) {
          return Center(child: Text('no_data_available'.tr()));
        }
        return CustomScrollView(key: const ValueKey('content'), slivers: [
          SliverAppBar.large(
            titleSpacing: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                children: [
                  Icon(iconData),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      extendedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              expandedTitleScale: 1.25,
              titlePadding: const EdgeInsets.all(16),
            ),
            leadingWidth: 62,
            leading: IconButton.filledTonal(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Symbols.arrow_back, weight: 600),
            ),
            actions: [
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Symbols.close, weight: 600),
              ),
              const SizedBox(width: 5),
            ],
          ),
          SliverToBoxAdapter(child: builder(raw, units)),
        ]);
      },
    );
  }

  // --- Actual implemented card ---
  Widget buildHumidityExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final hourly = weather['hourly'] as Map<String, dynamic>;
    final hourlyTime = (hourly['time'] as List).cast<String>();
    final hourlyHumidity = (hourly['relative_humidity_2m'] as List).cast<num>();

    final offset = Duration(seconds: int.parse(weather['utc_offset_seconds'].toString()));
    final nowLocal = DateTime.now().toUtc().add(offset);
    final roundedNow = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, nowLocal.hour);

    int startIndex = hourlyTime.indexWhere((timeStr) => !DateTime.parse(timeStr).isBefore(roundedNow));
    if (startIndex == -1) startIndex = 0;

    final todayHumidities = <int>[];
    for (int i = 0; i < hourlyHumidity.length && i < 24; i++) {
      todayHumidities.add(hourlyHumidity[i].toInt());
    }
    final int avgHumidity = todayHumidities.isNotEmpty
        ? (todayHumidities.reduce((a, b) => a + b) ~/ todayHumidities.length)
        : 0;

    return Column(children: [
      Container(
        height: 360,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.only(top: 12),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("todays_avg".tr(),
                      style: TextStyle(
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      )),
                  Text(
                    "$avgHumidity%",
                    style: TextStyle(
                      fontFamily: "FlexFontEn",
                      fontSize: 50,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  )
                ],
              ),
            ),
            SizedBox(
              height: 225,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: (hourlyHumidity.length - startIndex).clamp(0, 24).toInt(),
                itemBuilder: (context, index) {
                  final dataIndex = startIndex + index;
                  if (dataIndex >= hourlyTime.length || dataIndex >= hourlyHumidity.length) {
                    return const SizedBox();
                  }

                  final forecastLocal = DateTime.parse(hourlyTime[dataIndex]);
                  final roundedDisplayTime = DateTime(
                    forecastLocal.year,
                    forecastLocal.month,
                    forecastLocal.day,
                    forecastLocal.hour,
                  );
                  final hour = units.timeUnit == '24 hr'
                      ? "${roundedDisplayTime.hour.toString().padLeft(2, '0')}:00"
                      : UnitConverter.formatTo12Hour(roundedDisplayTime);
                  final humidityPercentage = hourlyHumidity[dataIndex].toDouble();

                  final itemMargin = EdgeInsetsDirectional.only(start: index == 0 ? 10 : 6, end: 6);

                  return Container(
                    width: 53,
                    margin: itemMargin,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: ((humidityPercentage / 100) * 160).clamp(30, 160).toDouble(),
                          width: 36,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            humidityPercentage.toStringAsFixed(0),
                            style: TextStyle(
                              fontFamily: "FlexFontEn",
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(hour,
                            style: TextStyle(
                              fontFamily: "FlexFontEn",
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      Container(
        margin: EdgeInsets.fromLTRB(12, 20, 12, MediaQuery.of(context).padding.bottom + 26),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("humidity_info".tr(),
                style: TextStyle(
                  fontSize: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 12),
            Text("humidity_info_2".tr(),
                style: TextStyle(
                  fontSize: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      )
    ]);
  }

  Widget buildSunExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final daily = weather['daily'] as Map<String, dynamic>? ?? {};
    final sunriseStr = (daily['sunrise'] as List?)?.isNotEmpty == true ? daily['sunrise'][0] as String? : null;
    final sunsetStr = (daily['sunset'] as List?)?.isNotEmpty == true ? daily['sunset'][0] as String? : null;
    final daylightSeconds = (daily['daylight_duration'] as List?)?.isNotEmpty == true
        ? (daily['daylight_duration'][0] as num?)?.toDouble()
        : null;

    String formatTime(String? iso) {
      if (iso == null) return 'N/A';
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      return units.timeUnit == '24 hr'
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : UnitConverter.formatTo12Hour(dt);
    }

    final sunrise = formatTime(sunriseStr);
    final sunset = formatTime(sunsetStr);
    final daylightHours = daylightSeconds != null ? (daylightSeconds / 3600).toStringAsFixed(1) : 'N/A';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('sun_tile_page'.tr(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoChip('sunrise'.tr(), sunrise),
              _infoChip('sunset'.tr(), sunset),
              _infoChip('daylight'.tr(), '$daylightHours h'),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildPressureExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final hourly = weather['hourly'] as Map<String, dynamic>;
    final hourlyTime = (hourly['time'] as List).cast<String>();
    final pressures =
        (hourly['surface_pressure'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
    final idx = _getStartIndex(weather, hourlyTime);
    final pressureRaw = (idx < pressures.length ? pressures[idx] : null) ?? 0.0;

    double converted = pressureRaw;
    String unitLabel = units.pressureUnit;
    switch (units.pressureUnit.toLowerCase()) {
      case 'mmhg':
        converted = pressureRaw * 0.75006;
        unitLabel = 'mmHg';
        break;
      case 'inhg':
        converted = pressureRaw * 0.02953;
        unitLabel = 'inHg';
        break;
      default:
        unitLabel = 'hPa';
        break;
    }

    final localizedUnit = localizePressureUnit(unitLabel, context.locale);

    return _simpleStatCard(
      title: 'pressure'.tr(),
      value: converted.toStringAsFixed(1),
      unit: localizedUnit,
      subtitle: 'current_conditions'.tr(),
    );
  }

  Widget buildVisibilityExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final hourly = weather['hourly'] as Map<String, dynamic>;
    final hourlyTime = (hourly['time'] as List).cast<String>();
    final visibilityList =
        (hourly['visibility'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
    final idx = _getStartIndex(weather, hourlyTime);
    final visRaw = (idx < visibilityList.length ? visibilityList[idx] : null) ?? 0.0; // meters

    final isMiles = units.visibilityUnit == 'Mile';
    final converted = isMiles ? UnitConverter.mToMiles(visRaw) : UnitConverter.mToKm(visRaw);
    final unit = isMiles ? localizeVisibilityUnit('Mile', context.locale) : localizeVisibilityUnit('Km', context.locale);

    return _simpleStatCard(
      title: 'visibility'.tr(),
      value: converted.toStringAsFixed(1),
      unit: unit,
      subtitle: 'current_conditions'.tr(),
    );
  }

  Widget buildWindExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final hourly = weather['hourly'] as Map<String, dynamic>;
    final hourlyTime = (hourly['time'] as List).cast<String>();
    final speeds = (hourly['wind_speed_10m'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
    final directions = (hourly['wind_direction_10m'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
    final idx = _getStartIndex(weather, hourlyTime);
    final speed = (idx < speeds.length ? speeds[idx] : null) ?? 0.0;
    final dir = (idx < directions.length ? directions[idx] : null) ?? 0.0;

    double converted = speed;
    String unit = units.windUnit;
    switch (units.windUnit) {
      case 'Mph':
        converted = UnitConverter.kmhToMph(speed);
        break;
      case 'M/s':
        converted = UnitConverter.kmhToMs(speed);
        break;
      case 'Bft':
        converted = UnitConverter.kmhToBeaufort(speed).toDouble();
        break;
      case 'Kt':
        converted = UnitConverter.kmhToKt(speed);
        break;
      default:
        unit = 'Km/h';
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('wind'.tr(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoChip('speed'.tr(), '${converted.toStringAsFixed(1)} $unit'),
              _infoChip('direction'.tr(), '${dir.round()}°'),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildUVExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final hourly = weather['hourly'] as Map<String, dynamic>;
    final hourlyTime = (hourly['time'] as List).cast<String>();
    final uvs = (hourly['uv_index'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
    final idx = _getStartIndex(weather, hourlyTime);
    final uv = (idx < uvs.length ? uvs[idx] : null) ?? 0.0;

    String level;
    if (uv <= 2) {
      level = 'low'.tr();
    } else if (uv <= 5) {
      level = 'moderate'.tr();
    } else if (uv <= 7) {
      level = 'high'.tr();
    } else if (uv <= 10) {
      level = 'very_high'.tr();
    } else {
      level = 'extreme'.tr();
    }

    return _simpleStatCard(
      title: 'uv_index'.tr(),
      value: uv.toStringAsFixed(1),
      unit: level,
      subtitle: 'current_conditions'.tr(),
    );
  }

  Widget buildAQIExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final current = (weather['air_quality'] as Map?)?['current'] as Map<dynamic, dynamic>? ?? {};
    final us = (current['us_aqi'] as num?)?.toInt();
    final eu = (current['european_aqi'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('air_quality'.tr(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoChip('united_states_aqi'.tr(), us?.toString() ?? 'N/A'),
              _infoChip('european_aqi'.tr(), eu?.toString() ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildPrecipExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final hourly = weather['hourly'] as Map<String, dynamic>;
    final hourlyTime = (hourly['time'] as List).cast<String>();
    final precip = (hourly['precipitation'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
    final prob = (hourly['precipitation_probability'] as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];
    final idx = _getStartIndex(weather, hourlyTime);
    final amount = (idx < precip.length ? precip[idx] : null) ?? 0.0;
    final chance = (idx < prob.length ? prob[idx] : null) ?? 0;

    final unit = units.precipitationUnit;
    double converted = amount;
    if (unit == 'cm') {
      converted = UnitConverter.mmToCm(amount);
    } else if (unit == 'in') {
      converted = UnitConverter.mmToIn(amount);
    }

    final localizedUnit = localizePrecipUnit(unit, context.locale);

    return _simpleStatCard(
      title: 'precipitation'.tr(),
      value: converted.toStringAsFixed(1),
      unit: localizedUnit,
      subtitle: '${'chance_of_rain'.tr()}: $chance%',
    );
  }

  Widget buildMoonExtended(Map<String, dynamic> raw, UnitSettingsNotifier units) {
    final weather = raw['data'] as Map<String, dynamic>;
    final astro = (weather['astronomy'] as Map?)?['astronomy'] as Map? ?? {};
    final astroData = (astro['astro'] as Map?) ?? {};
    final moonrise = astroData['moonrise'] as String?;
    final moonset = astroData['moonset'] as String?;
    final phase = astroData['moon_phase'] as String? ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('moon'.tr(), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoChip('moonrise'.tr(), moonrise ?? 'N/A'),
              _infoChip('moonset'.tr(), moonset ?? 'N/A'),
              _infoChip('phase'.tr(), phase),
            ],
          ),
        ],
      ),
    );
  }

  Widget _simpleStatCard({required String title, required String value, required String unit, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'FlexFontEn',
                    fontSize: 44,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(unit, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  int _getStartIndex(Map<String, dynamic> weather, List<String> hourlyTime) {
    final offsetSeconds = int.tryParse(weather['utc_offset_seconds'].toString()) ?? 0;
    final offset = Duration(seconds: offsetSeconds);
    final nowLocal = DateTime.now().toUtc().add(offset);
    final roundedNow = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, nowLocal.hour);
    final idx = hourlyTime.indexWhere((t) {
      final dt = DateTime.tryParse(t);
      return dt != null && !dt.isBefore(roundedNow);
    });
    return idx == -1 ? 0 : idx;
  }
}
