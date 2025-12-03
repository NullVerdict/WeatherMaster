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
    final preprocessed = _preprocessData();
    
    return Padding(
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
              _HourlyHeader(colorScheme: Theme.of(context).colorScheme),
              const Divider(height: 6, color: Colors.transparent),
              SizedBox(
                height: 128,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: preprocessed.length,
                  itemBuilder: (context, index) {
                    final item = preprocessed[index];
                    return _HourItem(
                      key: ValueKey('hour_$index'),
                      isFirst: index == 0,
                      isLast: index == preprocessed.length - 1,
                      hour: item.hour,
                      temp: item.temp,
                      precipProb: item.precipProb,
                      code: item.code,
                      isDay: item.isDay,
                      selectedContainerBgIndex: selectedContainerBgIndex,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_HourData> _preprocessData() {
    final offset = Duration(seconds: int.parse(utcOffsetSeconds));
    final nowUtc = DateTime.now().toUtc();
    final nowLocal = nowUtc.add(offset);
    final roundedNow = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, nowLocal.hour);

    int startIndex = hourlyTime.indexWhere((timeStr) {
      final forecastLocal = DateTime.parse(timeStr);
      return !forecastLocal.isBefore(roundedNow);
    });

    if (startIndex == -1) startIndex = 0;
    
    final result = <_HourData>[];
    final itemCount = (48 - startIndex).clamp(0, 48);
    
    for (int i = 0; i < itemCount; i++) {
      final dataIndex = startIndex + i;
      if (dataIndex >= hourlyTime.length) break;

      final forecastLocal = DateTime.parse(hourlyTime[dataIndex]);
      final roundedDisplayTime = DateTime(
        forecastLocal.year,
        forecastLocal.month,
        forecastLocal.day,
        forecastLocal.hour,
      );

      final hour = timeUnit == '24 hr'
          ? "${roundedDisplayTime.hour.toString().padLeft(2, '0')}:00"
          : UnitConverter.formatTo12Hour(roundedDisplayTime);

      final temp = tempUnit == 'Fahrenheit'
          ? UnitConverter.celsiusToFahrenheit(hourlyTemps[dataIndex].toDouble()).round()
          : hourlyTemps[dataIndex].toDouble().round();

      result.add(_HourData(
        hour: hour,
        temp: temp,
        precipProb: hourlyPrecpProb[dataIndex] ?? 0.1111111,
        code: hourlyWeatherCodes[dataIndex],
        isDay: isHourDuringDaylightOptimized(roundedDisplayTime),
      ));
    }
    
    return result;
  }
}

class _HourData {
  final String hour;
  final int temp;
  final dynamic precipProb;
  final int code;
  final bool isDay;

  const _HourData({
    required this.hour,
    required this.temp,
    required this.precipProb,
    required this.code,
    required this.isDay,
  });
}

class _HourlyHeader extends StatelessWidget {
  final ColorScheme colorScheme;

  const _HourlyHeader({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 20),
        Icon(
          Symbols.schedule,
          weight: 500,
          color: colorScheme.secondary,
          size: 21,
          fill: 1,
        ),
        const SizedBox(width: 5),
        Text(
          "hourly_forecast".tr(),
          style: TextStyle(color: colorScheme.secondary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
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
  final int selectedContainerBgIndex;

  const _HourItem({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.hour,
    required this.temp,
    required this.precipProb,
    required this.code,
    required this.isDay,
    required this.selectedContainerBgIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colorTheme = Theme.of(context).colorScheme;
    
    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.none,
        width: 56,
        margin: EdgeInsetsDirectional.only(end: isLast ? 10 : 0, start: isFirst ? 10 : 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 3),
            _TemperatureCircle(
              temp: temp,
              isFirst: isFirst,
              colorTheme: colorTheme,
              selectedContainerBgIndex: selectedContainerBgIndex,
            ),
            _PrecipitationProb(precipProb: precipProb, colorTheme: colorTheme),
            _WeatherIcon(code: code, isDay: isDay),
            const SizedBox(height: 5),
            _TimeLabel(hour: hour, colorTheme: colorTheme),
          ],
        ),
      ),
    );
  }
}

class _TemperatureCircle extends StatelessWidget {
  final int temp;
  final bool isFirst;
  final ColorScheme colorTheme;
  final int selectedContainerBgIndex;

  const _TemperatureCircle({
    required this.temp,
    required this.isFirst,
    required this.colorTheme,
    required this.selectedContainerBgIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          child: SvgPicture.string(
            _buildSvg(isFirst ? colorTheme.tertiary : Color(selectedContainerBgIndex)),
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
    );
  }

  String _buildSvg(Color fill) {
    return '''<svg width="56" height="56" viewBox="0 0 56 56" xmlns="http://www.w3.org/2000/svg">
      <circle cx="28" cy="28" r="21" fill="${_colorToHex(fill)}"/>
    </svg>''';
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}

class _PrecipitationProb extends StatelessWidget {
  final dynamic precipProb;
  final ColorScheme colorTheme;

  const _PrecipitationProb({required this.precipProb, required this.colorTheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      precipProb == 0.1111111
          ? '--%'
          : precipProb > 10
              ? "${precipProb.round()}%"
              : "‎",
      style: TextStyle(
        fontFamily: "FlexFontEn",
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
        color: colorTheme.primary,
      ),
    );
  }
}

class _WeatherIcon extends StatelessWidget {
  final int code;
  final bool isDay;

  const _WeatherIcon({required this.code, required this.isDay});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      WeatherIconMapper.getIcon(code, isDay ? 1 : 0),
      width: 26,
    );
  }
}

class _TimeLabel extends StatelessWidget {
  final String hour;
  final ColorScheme colorTheme;

  const _TimeLabel({required this.hour, required this.colorTheme});

  @override
  Widget build(BuildContext context) {
    return Text(
      hour,
      style: TextStyle(
        fontSize: 14,
        color: colorTheme.onSurfaceVariant,
        fontFamily: "FlexFontEn",
      ),
    );
  }
}
