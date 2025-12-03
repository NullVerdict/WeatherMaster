import 'package:flutter/material.dart';
import '../utils/icon_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/unit_converter.dart';
import '../screens/daily_forecast.dart';
import '../controllers/home_f.dart';
import 'package:easy_localization/easy_localization.dart';

class DailyCard extends StatelessWidget {
  final List<DateTime> times;
  final List<int> maxs;
  final List<int> mins;
  final List<String> probs;
  final List<int> codes;
  final List<String> days;
  final List<String> dates;
  final ColorScheme scheme;
  final Brightness bright;
  final bool dark;
  final int bg;

  const DailyCard({
    super.key,
    required this.times,
    required this.maxs,
    required this.mins,
    required this.probs,
    required this.codes,
    required this.days,
    required this.dates,
    required this.scheme,
    required this.bright,
    required this.dark,
    required this.bg,
  });

  factory DailyCard.preprocessed({
    required List<dynamic> dailyTime,
    required List<dynamic> dailyTempsMin,
    required List<dynamic> dailyWeatherCodes,
    required List<dynamic> dailyTempsMax,
    required List<dynamic> dailyPrecProb,
    required int selectedContainerBgIndex,
    required String utcOffsetSeconds,
    required String tempUnit,
    required bool isDarkCards,
    required ColorScheme colorTheme,
    required Brightness brightness,
    required Locale locale,
  }) {
    final len = dailyTime.length;
    final times = <DateTime>[];
    final maxs = <int>[];
    final mins = <int>[];
    final probs = <String>[];
    final codes = <int>[];
    final days = <String>[];
    final dates = <String>[];

    final isFahr = tempUnit == "Fahrenheit";
    final lang = locale.languageCode;
    final country = locale.countryCode;

    for (int i = 0; i < len; i++) {
      if (i >= dailyTempsMin.length ||
          i >= dailyTempsMax.length ||
          i >= dailyWeatherCodes.length ||
          i >= dailyPrecProb.length ||
          dailyTime[i] == null ||
          dailyTempsMin[i] == null ||
          dailyTempsMax[i] == null ||
          dailyWeatherCodes[i] == null) continue;

      final t = DateTime.parse(dailyTime[i] as String);
      final tmax = isFahr
          ? UnitConverter.celsiusToFahrenheit((dailyTempsMax[i] as num).toDouble()).round()
          : (dailyTempsMax[i] as num).round();
      final tmin = isFahr
          ? UnitConverter.celsiusToFahrenheit((dailyTempsMin[i] as num).toDouble()).round()
          : (dailyTempsMin[i] as num).round();
      final p = dailyPrecProb[i];
      final pStr = (p == null || (p is num && p == 0.0000001)) ? '--' : "${(p as num).round()}%";
      final c = dailyWeatherCodes[i] as int;

      final day = getDayLabel(t, i, utcOffsetSeconds).toLowerCase().tr();
      final date = _dateFmt(t, lang, country);

      times.add(t);
      maxs.add(tmax);
      mins.add(tmin);
      probs.add(pStr);
      codes.add(c);
      days.add(day);
      dates.add(date);
    }

    return DailyCard(
      times: times,
      maxs: maxs,
      mins: mins,
      probs: probs,
      codes: codes,
      days: days,
      dates: dates,
      scheme: colorTheme,
      bright: brightness,
      dark: isDarkCards,
      bg: selectedContainerBgIndex,
    );
  }

  static String _dateFmt(DateTime t, String lang, String? country) {
    if (lang == 'en' && country == 'US') return DateFormat('MM/dd').format(t);
    if (lang == 'ja') return DateFormat('MM月dd日', 'ja').format(t);
    if (lang == 'fa') return DateFormat('yyyy/MM/dd', 'fa').format(t);
    if (lang == 'de') return DateFormat('dd.MM').format(t);
    return DateFormat('dd/MM').format(t);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.7),
        child: Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(20),
          color: Color(bg),
          child: Container(
            padding: const EdgeInsets.only(top: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    SizedBox(width: 20),
                    Icon(Icons.calendar_month, weight: 500, size: 21, fill: 1),
                    SizedBox(width: 5),
                    Text("daily_forecast",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Divider(height: 14, color: Colors.transparent),
                SizedBox(
                  height: 213,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: times.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 5),
                    itemBuilder: (_, i) => _DailyItem(
                      first: i == 0,
                      last: i == times.length - 1,
                      time: times[i],
                      max: maxs[i],
                      min: mins[i],
                      prob: probs[i],
                      code: codes[i],
                      day: days[i],
                      date: dates[i],
                      scheme: scheme,
                      bright: bright,
                      dark: dark,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyItem extends StatelessWidget {
  final bool first;
  final bool last;
  final DateTime time;
  final int max;
  final int min;
  final String prob;
  final int code;
  final String day;
  final String date;
  final ColorScheme scheme;
  final Brightness bright;
  final bool dark;

  const _DailyItem({
    required this.first,
    required this.last,
    required this.time,
    required this.max,
    required this.min,
    required this.prob,
    required this.code,
    required this.day,
    required this.date,
    required this.scheme,
    required this.bright,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DailyForecastPage(initialSelectedDate: time)),
        ),
        child: Opacity(
          opacity: first ? 0.6 : 1,
          child: Container(
            width: 68,
            margin:
                EdgeInsetsDirectional.only(start: first ? 15.0 : 0, end: last ? 15.0 : 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: bright == Brightness.light
                  ? scheme.surfaceContainer
                  : dark
                      ? scheme.surfaceContainerLow.withValues(alpha: 0.6)
                      : const Color.fromRGBO(0, 0, 0, 0.247),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text("$max°",
                    style:
                        TextStyle(fontSize: 16, color: scheme.onSurface, fontFamily: "FlexFontEn")),
                Text("$min°",
                    style: TextStyle(
                        fontSize: 16, color: scheme.onSurfaceVariant, fontFamily: "FlexFontEn")),
                const SizedBox(height: 10),
                SvgPicture.asset(WeatherIconMapper.getIcon(code, 1), width: 35),
                const SizedBox(height: 5),
                Text(prob,
                    style: TextStyle(
                        fontSize: 14,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontFamily: "FlexFontEn")),
                const SizedBox(height: 3),
                Text(day, style: const TextStyle(fontSize: 14), maxLines: 1),
                Text(date, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
