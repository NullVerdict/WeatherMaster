import 'package:flutter/material.dart';
import '../utils/icon_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/unit_converter.dart';
import 'package:easy_localization/easy_localization.dart';

class HourlyCard extends StatelessWidget {
  final List<String> times;
  final List<int> temps;
  final List<int> probs;
  final List<int> codes;
  final List<bool> isDays;
  final ColorScheme scheme;
  final int bg;

  const HourlyCard({
    super.key,
    required this.times,
    required this.temps,
    required this.probs,
    required this.codes,
    required this.isDays,
    required this.scheme,
    required this.bg,
  });

  factory HourlyCard.preprocessed({
    required List<dynamic> hourlyTime,
    required List<dynamic> hourlyTemps,
    required List<dynamic> hourlyWeatherCodes,
    required bool Function(DateTime) isDaylight,
    required int selectedContainerBgIndex,
    required String utcOffsetSeconds,
    required List<dynamic> hourlyPrecpProb,
    required String tempUnit,
    required String timeUnit,
    required ColorScheme colorScheme,
  }) {
    final offset = Duration(seconds: int.parse(utcOffsetSeconds));
    final now = DateTime.now().toUtc().add(offset);
    final rounded = DateTime(now.year, now.month, now.day, now.hour);

    int start = hourlyTime.indexWhere((t) => !DateTime.parse(t).isBefore(rounded));
    if (start == -1) start = 0;

    final count = (48 - start).clamp(0, 48);
    final isFahr = tempUnit == 'Fahrenheit';
    final is24 = timeUnit == '24 hr';

    final times = List<String>.generate(count, (i) {
      final dt = DateTime.parse(hourlyTime[start + i]);
      return is24 ? "${dt.hour.toString().padLeft(2, '0')}:00" : UnitConverter.formatTo12Hour(dt);
    });

    final temps = List<int>.generate(count, (i) {
      final t = hourlyTemps[start + i].toDouble();
      return isFahr ? UnitConverter.celsiusToFahrenheit(t).round() : t.round();
    });

    final probs = List<int>.generate(count, (i) {
      final p = hourlyPrecpProb[start + i];
      return p == null ? -1 : (p is int ? p : (p as double).round());
    });

    final codes = List<int>.generate(count, (i) => hourlyWeatherCodes[start + i] as int);

    final isDays = List<bool>.generate(
        count, (i) => isDaylight(DateTime.parse(hourlyTime[start + i])));

    return HourlyCard(
      times: times,
      temps: temps,
      probs: probs,
      codes: codes,
      isDays: isDays,
      scheme: colorScheme,
      bg: selectedContainerBgIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final h = 98 + (textScale - 1.0) * 30 + 30;

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
                    Icon(Icons.schedule, weight: 500, size: 21, fill: 1),
                    SizedBox(width: 5),
                    Text("hourly_forecast",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Divider(height: 6, color: Colors.transparent),
                SizedBox(
                  height: h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: times.length,
                    itemBuilder: (_, i) => _HourItem(
                      first: i == 0,
                      last: i == times.length - 1,
                      time: times[i],
                      temp: temps[i],
                      prob: probs[i],
                      code: codes[i],
                      day: isDays[i],
                      scheme: scheme,
                      bg: bg,
                    ),
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
  final bool first;
  final bool last;
  final String time;
  final int temp;
  final int prob;
  final int code;
  final bool day;
  final ColorScheme scheme;
  final int bg;

  const _HourItem({
    required this.first,
    required this.last,
    required this.time,
    required this.temp,
    required this.prob,
    required this.code,
    required this.day,
    required this.scheme,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final pText = prob == -1 ? '--%' : prob > 10 ? "$prob%" : "‎";
    final svg = '<svg width="56" height="56" viewBox="0 0 56 56" xmlns="http://www.w3.org/2000/svg">'
        '<circle cx="28" cy="28" r="21" fill="${first ? _hex(scheme.tertiary) : _hex(Color(bg))}"/></svg>';

    return RepaintBoundary(
      child: Container(
        width: 56,
        margin: EdgeInsetsDirectional.only(end: last ? 10.0 : 0, start: first ? 10.0 : 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 3),
            Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.string(svg, width: 42, height: 42),
                Text(
                  "$temp°",
                  style: TextStyle(
                    fontFamily: "FlexFontEn",
                    fontSize: 16,
                    color: first ? scheme.onTertiary : scheme.onSurface,
                  ),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                ),
              ],
            ),
            Text(
              pText,
              style: TextStyle(
                fontFamily: "FlexFontEn",
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: scheme.primary,
              ),
            ),
            SvgPicture.asset(WeatherIconMapper.getIcon(code, day ? 1 : 0), width: 26),
            const SizedBox(height: 5),
            Text(
              time,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                fontFamily: "FlexFontEn",
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
}
