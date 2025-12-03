import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../utils/icon_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/unit_converter.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../screens/daily_forecast.dart';
import '../controllers/home_f.dart';

class DailyCard extends StatelessWidget {
  final List<dynamic> dailyTime;
  final List<dynamic> dailyTempsMin;
  final List<dynamic> dailyWeatherCodes;
  final List<dynamic> dailyTempsMax;
  final List<dynamic> dailyPrecProb;
  final int selectedContainerBgIndex;
  final String utcOffsetSeconds;
  final String tempUnit;
  final bool isDarkCards;

  const DailyCard({
    super.key,
    required this.dailyTime,
    required this.dailyTempsMin,
    required this.dailyWeatherCodes,
    required this.dailyTempsMax,
    required this.dailyPrecProb,
    required this.utcOffsetSeconds,
    required this.selectedContainerBgIndex,
    required this.tempUnit,
    required this.isDarkCards,
  });

  @override
  Widget build(BuildContext context) {
    final colorTheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    final validDailyData = _preprocessDailyData();

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 20),
                  Icon(
                    Symbols.calendar_month,
                    weight: 500,
                    color: colorTheme.secondary,
                    size: 21,
                    fill: 1,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "daily_forecast".tr(),
                    style: TextStyle(color: colorTheme.secondary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 14, color: Colors.transparent),
              SizedBox(
                height: 213,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics:const BouncingScrollPhysics(),
                  itemCount: validDailyData.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 5),
                  itemBuilder: (context, index) {
                    final item = validDailyData[index];
                    return _DailyItem(
                      item: item,
                      index: index,
                      totalCount: validDailyData.length,
                      tempUnit: tempUnit,
                      colorTheme: colorTheme,
                      brightness: brightness,
                      isDarkCards: isDarkCards,
                      utcOffsetSeconds: utcOffsetSeconds,
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  List<_DailyDataItem> _preprocessDailyData() {
    final result = <_DailyDataItem>[];
    for (int i = 0; i < dailyTime.length; i++) {
      if (i < dailyTempsMin.length &&
          i < dailyTempsMax.length &&
          i < dailyWeatherCodes.length &&
          i < dailyPrecProb.length &&
          dailyTime[i] != null &&
          dailyTempsMin[i] != null &&
          dailyTempsMax[i] != null &&
          dailyWeatherCodes[i] != null) {
        result.add(_DailyDataItem(
          time: DateTime.parse(dailyTime[i] as String),
          tempMin: dailyTempsMin[i] as num,
          tempMax: dailyTempsMax[i] as num,
          weatherCode: dailyWeatherCodes[i] as int,
          precipProb: (dailyPrecProb[i] as num?)?.toDouble() ?? 0.0000001,
        ));
      }
    }
    return result;
  }
}

class _DailyDataItem {
  final DateTime time;
  final num tempMin;
  final num tempMax;
  final int weatherCode;
  final double precipProb;

  const _DailyDataItem({
    required this.time,
    required this.tempMin,
    required this.tempMax,
    required this.weatherCode,
    required this.precipProb,
  });
}

class _DailyItem extends StatelessWidget {
  final _DailyDataItem item;
  final int index;
  final int totalCount;
  final String tempUnit;
  final ColorScheme colorTheme;
  final Brightness brightness;
  final bool isDarkCards;
  final String utcOffsetSeconds;

  const _DailyItem({
    required this.item,
    required this.index,
    required this.totalCount,
    required this.tempUnit,
    required this.colorTheme,
    required this.brightness,
    required this.isDarkCards,
    required this.utcOffsetSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final tempMax = tempUnit == "Fahrenheit"
        ? UnitConverter.celsiusToFahrenheit(item.tempMax.toDouble()).round()
        : item.tempMax.round();

    final tempMin = tempUnit == "Fahrenheit"
        ? UnitConverter.celsiusToFahrenheit(item.tempMin.toDouble()).round()
        : item.tempMin.round();

    final itemMargin = EdgeInsetsDirectional.only(
      start: index == 0 ? 15 : 0,
      end: index == totalCount - 1 ? 15 : 0,
    );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DailyForecastPage(initialSelectedDate: item.time),
            ),
          );
        },
        child: Opacity(
          opacity: index == 0 ? 0.6 : 1,
          child: Container(
            width: 68,
            margin: itemMargin,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: brightness == Brightness.light
                  ? colorTheme.surfaceContainer
                  : isDarkCards
                      ? colorTheme.surfaceContainerLow.withValues(alpha: 0.6)
                      : const Color.fromRGBO(0, 0, 0, 0.247),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$tempMax°",
                      style: TextStyle(fontSize: 16, color: colorTheme.onSurface, fontFamily: "FlexFontEn"),
                    ),
                    Text(
                      "$tempMin°",
                      style: TextStyle(fontSize: 16, color: colorTheme.onSurfaceVariant, fontFamily: "FlexFontEn"),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SvgPicture.asset(
                  WeatherIconMapper.getIcon(item.weatherCode, 1),
                  width: 35,
                ),
                const SizedBox(height: 5),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.precipProb == 0.0000001 ? '--' : "${item.precipProb.round()}%",
                      style: TextStyle(
                        fontSize: 14,
                        color: colorTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontFamily: "FlexFontEn",
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      getDayLabel(item.time, index, utcOffsetSeconds).toLowerCase().tr(),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getLocalizedDateFormat(item.time, Localizations.localeOf(context)),
                      style: TextStyle(fontSize: 13, color: colorTheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _getLocalizedDateFormat(DateTime time, Locale locale) {
    final lang = locale.languageCode;
    final country = locale.countryCode;

    if (lang == 'en' && country == 'US') {
      return DateFormat('MM/dd').format(time);
    } else if (lang == 'ja') {
      return DateFormat('MM月dd日', 'ja').format(time);
    } else if (lang == 'fa') {
      return DateFormat('yyyy/MM/dd', 'fa').format(time);
    } else if (lang == 'de') {
      return DateFormat('dd.MM').format(time);
    }

    return DateFormat('dd/MM').format(time);
  }
}
