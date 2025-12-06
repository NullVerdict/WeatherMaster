import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

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
    final weather = raw['data'];
    final hourly = weather['hourly'];
    final List<dynamic> hourlyTime = hourly['time'];
    final List<dynamic> hourlyHumidity = hourly['relative_humidity_2m'];

    final offset = Duration(seconds: int.parse(weather['utc_offset_seconds'].toString()));
    final nowLocal = DateTime.now().toUtc().add(offset);
    final roundedNow = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, nowLocal.hour);

    int startIndex = hourlyTime.indexWhere((timeStr) => !DateTime.parse(timeStr).isBefore(roundedNow));
    if (startIndex == -1) startIndex = 0;

    final todayHumidities = <int>[];
    for (int i = 1; i <= 23 && i < hourlyHumidity.length; i++) {
      final humidity = hourlyHumidity[i];
      if (humidity is int) todayHumidities.add(humidity);
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
                itemCount: 24 + 24 - startIndex,
                itemBuilder: (context, index) {
                  final dataIndex = startIndex + index;
                  if (dataIndex >= hourlyTime.length) return const SizedBox();

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
                  final humidityPercentage = hourlyHumidity[dataIndex];

                  final itemMargin = EdgeInsetsDirectional.only(
                    start: index == 0 ? 10 : 0,
                    end: index == 24 + 24 - startIndex - 1 ? 10 : 0,
                  );

                  return Container(
                    width: 53,
                    margin: itemMargin,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          alignment: Alignment.bottomCenter,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 20,
                              height: 160,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: math.max((humidityPercentage / 100) * 160, 45),
                              ),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                              builder: (context, value, child) {
                                return Container(
                                  width: 43,
                                  height: value,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: child,
                                );
                              },
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned(
                                        top: 0,
                                        child: SvgPicture.string(
                                          '''<svg width="48" height="48" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M20.3091 8.60363C20.4924 8.454 20.584 8.37919 20.6677 8.31603C22.6389 6.82799 25.3611 6.82799 27.3323 8.31603C27.416 8.37919 27.5076 8.454 27.6909 8.60363C27.7727 8.67042 27.8136 8.70381 27.8541 8.7356C28.7818 9.46445 29.9191 9.87748 31.0993 9.91409C31.1508 9.91569 31.2037 9.91634 31.3094 9.91765C31.5462 9.92059 31.6646 9.92206 31.7694 9.92733C34.2381 10.0516 36.3234 11.7974 36.8747 14.2015C36.8982 14.3036 36.9202 14.4197 36.9642 14.6518C36.9838 14.7555 36.9937 14.8073 37.0042 14.8576C37.2452 16.0109 37.8504 17.0567 38.7309 17.8416C38.7693 17.8759 38.8094 17.9103 38.8895 17.9791C39.069 18.1332 39.1588 18.2102 39.2357 18.2815C41.0467 19.96 41.5194 22.6347 40.393 24.8299C40.3451 24.9231 40.2872 25.0262 40.1714 25.2322C40.1196 25.3242 40.0938 25.3702 40.0694 25.4155C39.5111 26.4536 39.3009 27.6429 39.4697 28.8088C39.4771 28.8597 39.4856 28.9117 39.5027 29.0158C39.5409 29.249 39.56 29.3656 39.573 29.4695C39.879 31.9168 38.5179 34.2689 36.2407 35.2281C36.1441 35.2688 36.0333 35.3106 35.8118 35.3942C35.7129 35.4315 35.6635 35.4501 35.6156 35.4692C34.5192 35.9063 33.592 36.6826 32.9701 37.684C32.943 37.7277 32.916 37.7731 32.862 37.8637C32.741 38.0669 32.6806 38.1685 32.6236 38.2564C31.2814 40.3273 28.7233 41.2563 26.3609 40.5306C26.2606 40.4998 26.1489 40.4608 25.9253 40.3827C25.8256 40.3479 25.7757 40.3305 25.7268 40.3144C24.6052 39.9461 23.3948 39.9461 22.2732 40.3144C22.2243 40.3305 22.1744 40.3479 22.0747 40.3827C21.8511 40.4608 21.7394 40.4998 21.6391 40.5306C19.2767 41.2563 16.7186 40.3273 15.3764 38.2564C15.3194 38.1685 15.259 38.0669 15.138 37.8637C15.084 37.7731 15.057 37.7277 15.0299 37.684C14.408 36.6826 13.4808 35.9063 12.3844 35.4692C12.3365 35.4501 12.2871 35.4315 12.1882 35.3942C11.9667 35.3106 11.8559 35.2688 11.7593 35.2281C9.48205 34.2689 8.12097 31.9168 8.42698 29.4695C8.43997 29.3656 8.45908 29.249 8.4973 29.0158C8.51436 28.9117 8.52289 28.8597 8.53026 28.8088C8.69906 27.6429 8.48889 26.4536 7.93056 25.4155C7.90621 25.319 7.85828 25.2182 7.81535 25.1203C7.71201 24.8834 7.60224 24.6516 7.48641 24.4252C6.74949 22.9812 5.38657 21.923 3.76801 21.5425C3.50187 21.4777 3.22752 21.4408 2.95843 21.4095C2.66472 21.3749 2.37511 21.3417 2.10979 21.2754C0.181815 20.7977 -1.3771 19.3176 -1.83585 17.3362C-1.89582 17.0741 -1.92761 16.8014 -1.95909 16.5246C-1.99365 16.233 -2.02881 15.9374 -2.0906 15.6602C-2.523 13.74 -1.82022 11.7317 -0.276727 10.3639C-0.0700202 10.1749 0.157878 9.98649 0.391258 9.80344C0.664212 9.59036 0.941672 9.38235 1.19698 9.15673C1.72097 8.68888 2.0458 8.0168 2.0458 7.30112C2.0458 6.3896 1.68087 5.52665 1.09055 4.88168C0.914462 4.69392 0.724324 4.50665 0.523034 4.33846C0.230363 4.09133 -0.063909 3.85061 -0.32332 3.57869C-1.63636 2.19655 -1.96787 0.15804 -1.14976 -1.51982C-0.983554 -1.8446 -0.759531 -2.14465 -0.543051 -2.44035C-0.333019 -2.72675 -0.137171 -3.00292 0.0372804 -3.27441C0.302051 -3.69119 0.452628 -4.14652 0.452628 -4.62243C0.452628 -5.35075 0.21391 -6.03443 -0.196417 -6.61069C-0.4246 -6.9264 -0.68477 -7.21629 -0.950326 -7.5179C-1.16741 -7.76334 -1.38515 -8.01045 -1.58114 -8.27983C-2.6805 -9.74086 -2.39589 -11.7975 -0.961616 -12.9931C-0.570742 -13.3239 -0.10287 -13.5839 0.371176 -13.8319C0.701277 -14.0005 1.04001 -14.164 1.3731 -14.3393C1.99319 -14.6651 2.45287 -15.2419 2.61039 -15.9292C2.72121 -16.4026 2.69221 -16.8944 2.58887 -17.3631C2.47198 -17.8907 2.23491 -18.4068 2.01248 -18.9076C1.75842 -19.4734 1.51561 -20.0131 1.51561 -20.5987C1.51561 -22.4868 3.20581 -24 5.14323 -24H5.25187C6.23578 -24 7.06196 -24.688 7.31093 -25.6408C7.3856 -25.9401 7.41402 -26.2518 7.44244 -26.5714C7.47334 -26.9244 7.50466 -27.279 7.57146 -27.6215C7.81726 -28.9224 8.73476 -30 10.1359 -30H10.2445C11.2284 -30 12.0546 -30.688 12.3036 -31.6408C12.4505 -32.2129 12.5436 -32.8063 12.6368 -33.4059C12.7896 -34.3872 13.6036 -35.1459 14.5893 -35.1459H14.6979C15.563 -35.1459 16.359 -35.6388 16.7395 -36.4208C16.897 -36.7446 17.0085 -37.1027 17.1336 -37.484C17.327 -38.0806 17.5204 -38.6806 17.8926 -39.1814C19.0013 -40.6718 21.0606 -40.9618 22.5639 -39.8419L22.6423 -39.7848C23.4722 -39.1647 24.5587 -39.1647 25.3886 -39.7848L25.467 -39.8419C26.9703 -40.9618 29.0296 -40.6718 30.1384 -39.1814C30.5106 -38.6806 30.7039 -38.0806 30.8973 -37.484C31.0224 -37.1027 31.134 -36.7446 31.2914 -36.4208C31.672 -35.6388 32.468 -35.1459 33.3331 -35.1459H33.4417C34.4274 -35.1459 35.2414 -34.3872 35.3942 -33.4059C35.4874 -32.8063 35.5805 -32.2129 35.7274 -31.6408C35.9764 -30.688 36.8026 -30 37.7865 -30H37.8952C39.2963 -30 40.2138 -28.9224 40.4596 -27.6215C40.5264 -27.279 40.5577 -26.9244 40.5886 -26.5714C40.617 -26.2518 40.6455 -25.9401 40.7201 -25.6408C40.9691 -24.688 41.7953 -24 42.7792 -24H42.8879C44.8253 -24 46.5155 -22.4868 46.5155 -20.5987C46.5155 -20.0131 46.2727 -19.4734 46.0186 -18.9076C45.7962 -18.4068 45.5591 -17.8907 45.4422 -17.3631C45.3388 -16.8944 45.3098 -16.4026 45.4206 -15.9292C45.5781 -15.2419 46.0378 -14.6651 46.6579 -14.3393C46.991 -14.164 47.3297 -14.0005 47.6598 -13.8319C48.1338 -13.5839 48.6017 -13.3239 48.9926 -12.9931C50.4268 -11.7975 50.7114 -9.74086 49.612 -8.27983C49.416 -8.01045 49.1983 -7.76334 48.9812 -7.5179C48.7156 -7.21629 48.4555 -6.9264 48.2273 -6.61069C47.817 -6.03443 47.5783 -5.35075 47.5783 -4.62243C47.5783 -4.14652 47.7289 -3.69119 47.9937 -3.27441C48.1681 -3.00292 48.364 -2.72675 48.574 -2.44035C48.7905 -2.14465 49.0145 -1.8446 49.1807 -1.51982C49.9988 0.15804 49.6672 2.19655 48.3542 3.57869C48.0948 3.85061 47.8006 4.09133 47.5079 4.33846C47.3066 4.50665 47.1165 4.69392 46.9404 4.88168C46.3501 5.52665 45.9851 6.3896 45.9851 7.30112C45.9851 8.0168 46.3099 8.68888 46.8339 9.15673C47.0892 9.38235 47.3667 9.59036 47.6396 9.80344C47.873 9.98649 48.1009 10.1749 48.3076 10.3639C49.8511 11.7317 50.5538 13.74 50.1214 15.6602C50.0596 15.9374 50.0245 16.233 49.9899 16.5246C49.9584 16.8014 49.9266 17.0741 49.8666 17.3362C49.4078 19.3176 47.8489 20.7977 45.9209 21.2754C45.6556 21.3417 45.366 21.3749 45.0723 21.4095C44.8032 21.4408 44.5288 21.4777 44.2627 21.5425C42.6441 21.923 41.2812 22.9812 40.5443 24.4252C40.4284 24.6516 40.3187 24.8834 40.2154 25.1203C40.1724 25.2182 40.1245 25.319 40.0645 25.4155C39.5062 26.4536 39.296 27.6429 39.4648 28.8088C39.4778 28.9023 39.4892 28.9768 39.5006 29.0493C39.5164 29.1476 39.532 29.2431 39.5481 29.3431C39.9562 31.9202 38.5493 34.2944 36.2349 35.2397C36.0401 35.3208 35.8144 35.4083 35.5305 35.5229C35.4309 35.5634 35.3351 35.6025 35.2514 35.6368C34.1666 36.0826 33.2521 36.8661 32.6295 37.8743C32.4929 38.0989 32.3767 38.3252 32.2691 38.5408C31.1342 40.7755 28.4249 41.646 26.1574 40.8037C26.0839 40.7766 26.009 40.7461 25.9065 40.7063C25.6801 40.6185 25.433 40.5223 25.1718 40.4358C24.13 40.0965 23.07 40.0965 22.0282 40.4358C21.767 40.5223 21.5199 40.6185 21.2935 40.7063C21.1909 40.7461 21.116 40.7766 21.0426 40.8037C18.775 41.646 16.0658 40.7755 14.9309 38.5408C14.8233 38.3252 14.7071 38.0989 14.5705 37.8743C13.9479 36.8661 13.0334 36.0826 11.9486 35.6368C11.8649 35.6025 11.7691 35.5634 11.6695 35.5229C11.3856 35.4083 11.1599 35.3208 10.9651 35.2397C8.65065 34.2944 7.24379 31.9202 7.65186 29.3431C7.66797 29.2431 7.68356 29.1476 7.69941 29.0493C7.7108 28.9768 7.72224 28.9023 7.73523 28.8088C7.90403 27.6429 7.69385 26.4536 7.13552 25.4155C7.07555 25.319 7.02762 25.2182 6.98469 25.1203C6.88135 24.8834 6.77158 24.6516 6.65575 24.4252C5.91883 22.9812 4.55591 21.923 2.93735 21.5425C2.67121 21.4777 2.39686 21.4408 2.12777 21.4095C1.83406 21.3749 1.54445 21.3417 1.27913 21.2754C-0.648846 20.7977 -2.20776 19.3176 -2.6665 17.3362C-2.72647 17.0741 -2.75826 16.8014 -2.78975 16.5246C-2.8243 16.233 -2.85947 15.9374 -2.92126 15.6602C-3.35366 13.74 -2.65088 11.7317 -1.10739 10.3639C-0.900684 10.1749 -0.672786 9.98649 -0.439406 9.80344C-0.166453 9.59036 0.110999 9.38235 0.366307 9.15673C0.890294 8.68888 1.21512 8.0168 1.21512 7.30112C1.21512 6.3896 0.850189 5.52665 0.259868 4.88168C0.0837798 4.69392 -0.106358 4.50665 -0.307648 4.33846C-0.600319 4.09133 -0.894591 3.85061 -1.153 3.57869C-2.46604 2.19655 -2.79755 0.15804 -1.97944 -1.51982C-1.81324 -1.8446 -1.58921 -2.14465 -1.37273 -2.44035C-1.1627 -2.72675 -0.966852 -3.00292 -0.792401 -3.27441C-0.52763 -3.69119 -0.377053 -4.14652 -0.377053 -4.62243C-0.377053 -5.35075 -0.615771 -6.03443 -1.0261 -6.61069C-1.25428 -6.9264 -1.51445 -7.21629 -1.78001 -7.5179C-1.9971 -7.76334 -2.21484 -8.01045 -2.41083 -8.27983C-3.5102 -9.74086 -3.22558 -11.7975 -1.79131 -12.9931C-1.40044 -13.3239 -0.932569 -13.5839 -0.458523 -13.8319C-0.128422 -14.0005 0.210319 -14.164 0.54341 -14.3393C1.1635 -14.6651 1.62318 -15.2419 1.7807 -15.9292C1.89152 -16.4026 1.86252 -16.8944 1.75918 -17.3631C1.64229 -17.8907 1.40522 -18.4068 1.18279 -18.9076C0.928735 -19.4734 0.685923 -20.0131 0.685923 -20.5987C0.685923 -22.4868 2.37612 -24 4.31355 -24H4.42219C5.4061 -24 6.23228 -24.688 6.48125 -25.6408C6.55592 -25.9401 6.58434 -26.2518 6.61275 -26.5714C6.64365 -26.9244 6.675 -27.279 6.7418 -27.6215C6.9876 -28.9224 7.9051 -30 9.30621 -30H9.41485C10.3988 -30 11.225 -30.688 11.474 -31.6408C11.6209 -32.2129 11.714 -32.8063 11.8071 -33.4059C11.9599 -34.3872 12.7739 -35.1459 13.7596 -35.1459H13.8682C14.7333 -35.1459 15.5293 -35.6388 15.9098 -36.4208C16.0673 -36.7446 16.1789 -37.1027 16.304 -37.484C16.4974 -38.0806 16.6907 -38.6806 17.063 -39.1814C18.1716 -40.6718 20.231 -40.9618 21.7343 -39.8419L21.8126 -39.7848C22.6425 -39.1647 23.729 -39.1647 24.5589 -39.7848L24.6373 -39.8419C26.1406 -40.9618 28.1999 -40.6718 29.3087 -39.1814C29.681 -38.6806 29.8743 -38.0806 30.0677 -37.484C30.1928 -37.1027 30.3043 -36.7446 30.4618 -36.4208C30.8423 -35.6388 31.6383 -35.1459 32.5034 -35.1459H32.612C33.5977 -35.1459 34.4117 -34.3872 34.5645 -33.4059C34.6577 -32.8063 34.7508 -32.2129 34.8977 -31.6408C35.1467 -30.688 35.9729 -30 36.9568 -30H37.0655C38.4666 -30 39.3841 -28.9224 39.6299 -27.6215C39.6967 -27.279 39.728 -26.9244 39.7589 -26.5714C39.7873 -26.2518 39.8158 -25.9401 39.8904 -25.6408C40.1394 -24.688 40.9656 -24 41.9495 -24H42.0582C43.9956 -24 45.6858 -22.4868 45.6858 -20.5987C45.6858 -20.0131 45.443 -19.4734 45.1889 -18.9076C44.9665 -18.4068 44.7294 -17.8907 44.6125 -17.3631C44.5092 -16.8944 44.4802 -16.4026 44.591 -15.9292C44.7485 -15.2419 45.2082 -14.6651 45.8283 -14.3393C46.1613 -14.164 46.5001 -14.0005 46.8302 -13.8319C47.3042 -13.5839 47.7721 -13.3239 48.163 -12.9931C49.5973 -11.7975 49.8819 -9.74086 48.7825 -8.27983C48.5865 -8.01045 48.3687 -7.76334 48.1517 -7.5179C47.8861 -7.21629 47.626 -6.9264 47.3978 -6.61069C46.9875 -6.03443 46.7488 -5.35075 46.7488 -4.62243C46.7488 -4.14652 46.8994 -3.69119 47.1642 -3.27441C47.3386 -3.00292 47.5345 -2.72675 47.7445 -2.44035C47.961 -2.14465 48.1849 -1.8446 48.3512 -1.51982C49.1693 0.15804 48.8378 2.19655 47.5247 3.57869C47.2653 3.85061 46.9711 4.09133 46.6784 4.33846C46.4771 4.50665 46.287 4.69392 46.111 4.88168C45.5207 5.52665 45.1557 6.3896 45.1557 7.30112C45.1557 8.0168 45.4806 8.68888 46.0046 9.15673C46.2599 9.38235 46.5373 9.59036 46.8103 9.80344C47.0437 9.98649 47.2715 10.1749 47.4782 10.3639C49.0217 11.7317 49.7244 13.74 49.292 15.6602C49.2302 15.9374 49.1951 16.233 49.1605 16.5246C49.129 16.8014 49.0972 17.0741 49.0372 17.3362C48.5784 19.3176 47.0195 20.7977 45.0915 21.2754C44.8262 21.3417 44.5366 21.3749 44.2429 21.4095C43.9738 21.4408 43.6995 21.4777 43.4333 21.5425C41.8148 21.923 40.4519 22.9812 39.715 24.4252C39.5991 24.6516 39.4894 24.8834 39.386 25.1203C39.3431 25.2182 39.2951 25.319 39.2351 25.4155C38.6768 26.4536 38.4666 27.6429 38.6354 28.8088C38.6484 28.9023 38.6598 28.9768 38.6712 29.0493C38.687 29.1476 38.7026 29.2431 38.7187 29.3431C39.1268 31.9202 37.7199 34.2944 35.4055 35.2397C35.2107 35.3208 34.985 35.4083 34.7011 35.5229C34.6015 35.5634 34.5057 35.6025 34.422 35.6368C33.3372 36.0826 32.4227 36.8661 31.8001 37.8743C31.6635 38.0989 31.5473 38.3252 31.4397 38.5408C30.3048 40.7755 27.5955 41.646 25.328 40.8037C25.2545 40.7766 25.1796 40.7461 25.0771 40.7063C24.8507 40.6185 24.6036 40.5223 24.3424 40.4358C23.3006 40.0965 22.2406 40.0965 21.1988 40.4358C20.9376 40.5223 20.6905 40.6185 20.4641 40.7063C20.3615 40.7461 20.2866 40.7766 20.2132 40.8037C17.9456 41.646 15.2364 40.7755 14.1015 38.5408C13.994 38.3252 13.8777 38.0989 13.7411 37.8743C13.1185 36.8661 12.204 36.0826 11.1192 35.6368C11.0355 35.6025 10.9397 35.5634 10.8401 35.5229C10.5562 35.4083 10.3305 35.3208 10.1357 35.2397C7.82121 34.2944 6.41435 31.9202 6.82242 29.3431C6.83702 29.2431 6.85313 29.1476 6.86872 29.0493C6.88011 28.9768 6.89155 28.9023 6.90454 28.8088C7.07334 27.6429 6.86316 26.4536 6.30483 25.4155C6.24486 25.319 6.19693 25.2182 6.15399 25.1203C6.05066 24.8834 5.94089 24.6516 5.82506 24.4252C5.08814 22.9812 3.72522 21.923 2.10666 21.5425C1.84052 21.4777 1.56617 21.4408 1.29708 21.4095C1.00337 21.3749 0.713764 21.3417 0.448447 21.2754C-1.47953 20.7977 -3.03844 19.3176 -3.49718 17.3362C-3.55715 17.0741 -3.58894 16.8014 -3.62042 16.5246C-3.65498 16.233 -3.69014 15.9374 -3.75193 15.6602C-4.18433 13.74 -3.48155 11.7317 -1.93806 10.3639C-1.73135 10.1749 -1.50345 9.98649 -1.27007 9.80344C-0.997112 9.59036 -0.719661 9.38235 -0.464353 9.15673C0.0596335 8.68888 0.384459 8.0168 0.384459 7.30112C0.384459 6.3896 0.0195264 5.52665 -0.570795 4.88168C-0.746883 4.69392 -0.937021 4.50665 -1.13831 4.33846C-1.43098 4.09133 -1.72525 3.85061 -1.98366 3.57869C-3.29669 2.19655 -3.6282 0.15804 -2.81009 -1.51982C-2.64389 -1.8446 -2.41986 -2.14465 -2.20338 -2.44035C-1.99335 -2.72675 -1.7975 -3.00292 -1.62305 -3.27441C-1.35828 -3.69119 -1.2077 -4.14652 -1.2077 -4.62243C-1.2077 -5.35075 -1.44642 -6.03443 -1.85675 -6.61069C-2.08493 -6.9264 -2.3451 -7.21629 -2.61065 -7.5179C-2.82774 -7.76334 -3.04548 -8.01045 -3.24147 -8.27983C-4.34084 -9.74086 -4.05622 -11.7975 -2.62195 -12.9931C-2.23108 -13.3239 -1.76321 -13.5839 -1.28916 -13.8319C-0.959053 -14.0005 -0.620318 -14.164 -0.287228 -14.3393C0.332862 -14.6651 0.792539 -15.2419 0.950058 -15.9292C1.06088 -16.4026 1.03188 -16.8944 0.92854 -17.3631C0.81165 -17.8907 0.574576 -18.4068 0.352147 -18.9076C0.0980917 -19.4734 -0.144719 -20.0131 -0.144719 -20.5987C-0.144719 -22.4868 1.54548 -24 3.4829 -24H3.59154C4.57545 -24 5.40163 -24.688 5.6506 -25.6408C5.72527 -25.9401 5.75369 -26.2518 5.7821 -26.5714C5.813 -26.9244 5.84435 -27.279 5.91115 -27.6215C6.15695 -28.9224 7.07445 -30 8.47556 -30H8.5842C9.56811 -30 10.3943 -30.688 10.6433 -31.6408C10.7902 -32.2129 10.8833 -32.8063 10.9764 -33.4059C11.1292 -34.3872 11.9432 -35.1459 12.9289 -35.1459H13.0375C13.9026 -35.1459 14.6986 -35.6388 15.0791 -36.4208C15.2366 -36.7446 15.3481 -37.1027 15.4732 -37.484C15.6666 -38.0806 15.86 -38.6806 16.2322 -39.1814C17.3409 -40.6718 19.4002 -40.9618 20.9035 -39.8419L20.9819 -39.7848C21.8118 -39.1647 22.8983 -39.1647 23.7282 -39.7848L23.8066 -39.8419C25.3099 -40.9618 27.3692 -40.6718 28.478 -39.1814C28.8502 -38.6806 29.0436 -38.0806 29.237 -37.484C29.3621 -37.1027 29.4736 -36.7446 29.631 -36.4208C30.0116 -35.6388 30.8076 -35.1459 31.6727 -35.1459H31.7813C32.767 -35.1459 33.581 -34.3872 33.7338 -33.4059C33.827 -32.8063 33.9201 -32.2129 34.067 -31.6408C34.316 -30.688 35.1422 -30 36.1261 -30H36.2348C37.6359 -30 38.5534 -28.9224 38.7992 -27.6215C38.866 -27.279 38.8973 -26.9244 38.9282 -26.5714C38.9566 -26.2518 38.9851 -25.9401 39.0597 -25.6408C39.3087 -24.688 40.1349 -24 41.1188 -24H41.2275C43.1649 -24 44.8551 -22.4868 44.8551 -20.5987C44.8551 -20.0131 44.6123 -19.4734 44.3582 -18.9076C44.1358 -18.4068 43.8987 -17.8907 43.7818 -17.3631C43.6784 -16.8944 43.6494 -16.4026 43.7602 -15.9292C43.9177 -15.2419 44.3774 -14.6651 44.9975 -14.3393Z" fill="#cddde8"/>
                        </svg>''',
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        child: SizedBox(
                                          height: 48,
                                          child: Center(
                                            child: Text(
                                              "$humidityPercentage",
                                              style: TextStyle(
                                                fontFamily: "FlexFontEn",
                                                fontSize: 16,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
          spacing: 20,
          children: [
            Text("humidity_info".tr(),
                style: TextStyle(
                  fontSize: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
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

    String _formatTime(String? iso) {
      if (iso == null) return 'N/A';
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      return units.timeUnit == '24 hr' ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : UnitConverter.formatTo12Hour(dt);
    }

    final sunrise = _formatTime(sunriseStr);
    final sunset = _formatTime(sunsetStr);
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
    final pressures = (hourly['surface_pressure'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? <double>[];
    final idx = _getStartIndex(weather, hourlyTime);
    final pressureRaw = (idx < pressures.length ? pressures[idx] : null) ?? 0.0;

    double converted = pressureRaw;
    String unitLabel = units.pressureUnit;
    if (units.pressureUnit.toLowerCase() == 'mmhg') {
      converted = pressureRaw * 0.75006;
      unitLabel = 'mmHg';
    } else if (units.pressureUnit.toLowerCase() == 'inhg') {
      converted = pressureRaw * 0.02953;
      unitLabel = 'inHg';
    } else {
      unitLabel = 'hPa';
    }

    return _simpleStatCard(
      title: 'pressure'.tr(),
      value: converted.toStringAsFixed(1),
      unit: unitLabel,
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

    return _simpleStatCard(
      title: 'precipitation'.tr(),
      value: converted.toStringAsFixed(1),
      unit: unit,
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
