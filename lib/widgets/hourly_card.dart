import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../utils/icon_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/unit_converter.dart';

class HourlyCard extends StatelessWidget {
  final List<dynamic> hourlyTime;
  final List<dynamic> hourlyTemps;
  final List<dynamic> hourlyWeatherCodes;
  final bool Function(DateTime) isHourDuringDaylightOptimized;
  final int selectedContainerBgIndex;
  final String timezone;
  final String utcOffsetSeconds;
  final List<dynamic> hourlyPrecpProb;
  final String tempUnit;
  final String timeUnit;

  const HourlyCard({
    super.key,
    required this.hourlyTime,
    required this.hourlyTemps,
    required this.hourlyWeatherCodes,
    required this.isHourDuringDaylightOptimized,
    required this.selectedContainerBgIndex,
    required this.timezone,
    required this.utcOffsetSeconds,
    required this.hourlyPrecpProb,
    required this.tempUnit,
    required this.timeUnit,
  });

  @override
  Widget build(BuildContext context) {
    final offset = Duration(seconds: int.parse(utcOffsetSeconds));
    final nowUtc = DateTime.now().toUtc();
    final nowLocal = nowUtc.add(offset);
    final colorTheme = Theme.of(context).colorScheme;
    final roundedNow = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, nowLocal.hour);

    int startIndex = hourlyTime.indexWhere((timeStr) {
      final forecastLocal = DateTime.parse(timeStr);
      return !forecastLocal.isBefore(roundedNow);
    });

    if (startIndex == -1) startIndex = 0;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final extraHeight = (textScale - 1.0) * 30;
    final is24Hr = timeUnit == '24 hr';
    final isFahrenheit = tempUnit == 'Fahrenheit';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.7),
        child: Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(20),
          color: Color(selectedContainerBgIndex),
          child: Container(
            padding: const EdgeInsets.only(top: 15, bottom: 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 20),
                    Icon(
                      Symbols.schedule,
                      weight: 500,
                      color: colorTheme.secondary,
                      size: 21,
                      fill: 1,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "hourly_forecast".tr(),
                      style: TextStyle(color: colorTheme.secondary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Divider(height: 6, color: Colors.transparent),
                SizedBox(
                  height: 98 + extraHeight + 30,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: (48 - startIndex).clamp(0, 48),
                    itemBuilder: (context, index) {
                      final dataIndex = startIndex + index;
                      final itemCount = (48 - startIndex).clamp(0, 48);
                      final isFirst = index == 0;
                      final isLast = index == itemCount - 1;

                      if (dataIndex >= hourlyTime.length) return const SizedBox.shrink();

                      final forecastLocal = DateTime.parse(hourlyTime[dataIndex]);
                      final roundedDisplayTime = DateTime(
                        forecastLocal.year,
                        forecastLocal.month,
                        forecastLocal.day,
                        forecastLocal.hour,
                      );

                      final hour = is24Hr
                          ? "${roundedDisplayTime.hour.toString().padLeft(2, '0')}:00"
                          : UnitConverter.formatTo12Hour(roundedDisplayTime);

                      final temp = isFahrenheit
                          ? UnitConverter.celsiusToFahrenheit(hourlyTemps[dataIndex].toDouble()).round()
                          : hourlyTemps[dataIndex].toDouble().round();

                      final code = hourlyWeatherCodes[dataIndex];
                      final precipProb = hourlyPrecpProb[dataIndex] ?? 0.1111111;
                      final isDay = isHourDuringDaylightOptimized(roundedDisplayTime);

                      return _HourItem(
                        isFirst: isFirst,
                        isLast: isLast,
                        hour: hour,
                        temp: temp,
                        precipProb: precipProb,
                        code: code,
                        isDay: isDay,
                        colorTheme: colorTheme,
                        selectedContainerBgIndex: selectedContainerBgIndex,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HourItem extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final String hour;
  final int temp;
  final dynamic precipProb;
  final int code;
  final bool isDay;
  final ColorScheme colorTheme;
  final int selectedContainerBgIndex;

  const _HourItem({
    required this.isFirst,
    required this.isLast,
    required this.hour,
    required this.temp,
    required this.precipProb,
    required this.code,
    required this.isDay,
    required this.colorTheme,
    required this.selectedContainerBgIndex,
  });

  @override
  Widget build(BuildContext context) {
    final displayPrecip = precipProb == 0.1111111
        ? '--%'
        : precipProb > 10
            ? "${precipProb.round()}%"
            : "‎";

    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.none,
        width: 56,
        margin: EdgeInsetsDirectional.only(end: isLast ? 10.0 : 0, start: isFirst ? 10.0 : 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 3),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  child: SvgPicture.string(
                    _buildNowHourSvg(isFirst ? colorTheme.tertiary : Color(selectedContainerBgIndex)),
                    width: 42,
                    height: 42,
                  ),
                ),
                Text(
                  "$temp°",
                  style: TextStyle(
                    fontFamily: "FlexFontEn",
                    fontSize: 16,
                    color: isFirst ? colorTheme.onTertiary : colorTheme.onSurface,
                  ),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                ),
              ],
            ),
            Text(
              displayPrecip,
              style: TextStyle(
                fontFamily: "FlexFontEn",
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: colorTheme.primary,
              ),
            ),
            SvgPicture.asset(
              WeatherIconMapper.getIcon(code, isDay ? 1 : 0),
              width: 26,
            ),
            const SizedBox(height: 5),
            Text(
              hour,
              style: TextStyle(
                fontSize: 14,
                color: colorTheme.onSurfaceVariant,
                fontFamily: "FlexFontEn",
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildNowHourSvg(Color fill) {
    return '''<svg width="56" height="56" viewBox="0 0 56 56" xmlns="http://www.w3.org/2000/svg">
      <circle cx="28" cy="28" r="21" fill="${_colorToHex(fill)}"/>
    </svg>''';
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
