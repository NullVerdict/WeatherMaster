import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/icon_map.dart';
import '../utils/condition_label_map.dart';
import '../utils/preferences_helper.dart';
import '../utils/unit_converter.dart';
import 'package:easy_localization/easy_localization.dart';

class WeatherTopCard extends StatelessWidget {
  final num currentTemp;
  final int currentWeatherIconCode;
  final int currentisDay;
  final num currentFeelsLike;
  final num currentMaxTemp;
  final num currentMinTemp;
  final String currentLastUpdated;
  final String tempUnit;
  final bool isShowFrog;

  const WeatherTopCard({
    super.key,
    required this.currentTemp,
    required this.currentWeatherIconCode,
    required this.currentisDay,
    required this.currentFeelsLike,
    required this.currentMaxTemp,
    required this.currentMinTemp,
    required this.currentLastUpdated,
    required this.tempUnit,
    required this.isShowFrog,
  });

  @override
  Widget build(BuildContext context) {
    final isFahrenheit = tempUnit == "Fahrenheit";
    final convertedTemp = _convert(currentTemp, isFahrenheit);
    final convertedMaxTemp = _convert(currentMaxTemp, isFahrenheit);
    final convertedMinTemp = _convert(currentMinTemp, isFahrenheit);
    final convertedFeelsLike = _convert(currentFeelsLike, isFahrenheit);

    return RepaintBoundary(
      child: isShowFrog
          ? _WeatherTopCardHorizontal(
              convertedTemp: convertedTemp,
              convertedMaxTemp: convertedMaxTemp,
              convertedMinTemp: convertedMinTemp,
              convertedFeelsLike: convertedFeelsLike,
              currentWeatherIconCode: currentWeatherIconCode,
              currentisDay: currentisDay,
              currentFeelsLike: currentFeelsLike,
              currentLastUpdated: currentLastUpdated,
            )
          : _WeatherTopCardVertical(
              convertedTemp: convertedTemp,
              convertedMaxTemp: convertedMaxTemp,
              convertedMinTemp: convertedMinTemp,
              convertedFeelsLike: convertedFeelsLike,
              currentWeatherIconCode: currentWeatherIconCode,
              currentisDay: currentisDay,
              currentFeelsLike: currentFeelsLike,
            ),
    );
  }

  static int _convert(num celsius, bool isFahrenheit) => isFahrenheit
      ? UnitConverter.celsiusToFahrenheit(celsius.toDouble()).round()
      : celsius.round();
}

class _WeatherTopCardHorizontal extends StatelessWidget {
  final int convertedTemp;
  final int convertedMaxTemp;
  final int convertedMinTemp;
  final int convertedFeelsLike;
  final int currentWeatherIconCode;
  final int currentisDay;
  final num currentFeelsLike;
  final String currentLastUpdated;

  const _WeatherTopCardHorizontal({
    required this.convertedTemp,
    required this.convertedMaxTemp,
    required this.convertedMinTemp,
    required this.convertedFeelsLike,
    required this.currentWeatherIconCode,
    required this.currentisDay,
    required this.currentFeelsLike,
    required this.currentLastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final useTempAnimation = PreferencesHelper.getBool("useTempAnimation") != false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("now".tr(), style: TextStyle(color: scheme.secondary, fontSize: 18)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  useTempAnimation
                      ? _AnimatedTemperature(
                          targetTemp: convertedTemp.toDouble(),
                          brightness: brightness,
                          scheme: scheme,
                        )
                      : Text(
                          "$convertedTemp°",
                          style: TextStyle(
                            fontFamily: "FlexFontEn",
                            color: isLight ? scheme.inverseSurface : scheme.primary,
                            fontSize: 65,
                            height: 1.3,
                          ),
                        ),
                  SvgPicture.asset(
                    WeatherIconMapper.getIcon(currentWeatherIconCode, currentisDay),
                    width: 50,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward, size: 16, color: scheme.onSurfaceVariant),
                  Text(
                    "$convertedMaxTemp°",
                    style: TextStyle(fontFamily: "FlexFontEn", color: scheme.onSurfaceVariant, fontSize: 16),
                  ),
                  Icon(Icons.arrow_downward, size: 16, color: scheme.onSurfaceVariant),
                  Text(
                    "$convertedMinTemp°",
                    style: TextStyle(fontFamily: "FlexFontEn", color: scheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  WeatherConditionMapper.getConditionLabel(currentWeatherIconCode, currentisDay).tr(),
                  style: TextStyle(color: scheme.onSurface, fontSize: 18),
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  "${'feels_like'.tr()} ${currentFeelsLike == 0000 ? '--' : '\u200E$convertedFeelsLike°'} ",
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(height: 60),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.update, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    currentLastUpdated,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherTopCardVertical extends StatelessWidget {
  final int convertedTemp;
  final int convertedMaxTemp;
  final int convertedMinTemp;
  final int convertedFeelsLike;
  final int currentWeatherIconCode;
  final int currentisDay;
  final num currentFeelsLike;

  const _WeatherTopCardVertical({
    required this.convertedTemp,
    required this.convertedMaxTemp,
    required this.convertedMinTemp,
    required this.convertedFeelsLike,
    required this.currentWeatherIconCode,
    required this.currentisDay,
    required this.currentFeelsLike,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final useTempAnimation = PreferencesHelper.getBool("useTempAnimation") != false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            WeatherConditionMapper.getConditionLabel(currentWeatherIconCode, currentisDay).tr(),
            style: TextStyle(color: scheme.onSurface, fontSize: 22),
          ),
          const SizedBox(height: 6),
          Row(
            spacing: 3,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              useTempAnimation
                  ? _AnimatedTemperature(
                      targetTemp: convertedTemp.toDouble(),
                      brightness: brightness,
                      scheme: scheme,
                      isLarge: true,
                    )
                  : Text(
                      "$convertedTemp",
                      style: TextStyle(
                        fontFamily: "FlexFontEn",
                        color: brightness == Brightness.light ? scheme.inverseSurface : scheme.primary,
                        fontSize: 136,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: SvgPicture.asset(
                  WeatherIconMapper.getIcon(currentWeatherIconCode, currentisDay),
                  width: 52,
                  height: 52,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "${'feels_like'.tr()} ${currentFeelsLike == 0000 ? '--' : '$convertedFeelsLike°'}",
            style: TextStyle(color: scheme.onSurface, fontSize: 18),
          ),
          const SizedBox(height: 7),
          Text(
            "${'low_text'.tr()}: $convertedMinTemp° • ${'high_text'.tr()}: $convertedMaxTemp°",
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTemperature extends StatelessWidget {
  final double targetTemp;
  final Brightness brightness;
  final ColorScheme scheme;
  final bool isLarge;

  const _AnimatedTemperature({
    required this.targetTemp,
    required this.brightness,
    required this.scheme,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: (targetTemp * 0.50).clamp(0, double.infinity),
        end: targetTemp,
      ),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Text(
          isLarge ? value.toStringAsFixed(0) : '${value.toStringAsFixed(0)}°',
          style: TextStyle(
            fontFamily: "FlexFontEn",
            color: brightness == Brightness.light ? scheme.inverseSurface : scheme.primary,
            fontSize: isLarge ? 136 : 65,
            fontWeight: isLarge ? FontWeight.bold : null,
            height: isLarge ? 1 : 1.3,
          ),
        );
      },
    );
  }
}
