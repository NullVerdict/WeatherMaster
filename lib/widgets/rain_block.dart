import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/unit_converter.dart';
import '../helper/locale_helper.dart';
import 'package:easy_localization/easy_localization.dart';

class RainBlock extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<double> bars;
  final List<String> labels;
  final double max;
  final ColorScheme scheme;
  final int bg;
  final DateFormat hm;
  final DateFormat jm;

  const RainBlock({
    super.key,
    required this.title,
    required this.subtitle,
    required this.bars,
    required this.labels,
    required this.max,
    required this.scheme,
    required this.bg,
    required this.hm,
    required this.jm,
  });

  factory RainBlock.preprocessed({
    required List<String> hourlyTime,
    required List<double> hourlyPrecp,
    required List<dynamic> hourlyPrecpProb,
    required int selectedContainerBgIndex,
    required String utcOffsetSeconds,
    required ColorScheme colorScheme,
  }) {
    final offset = int.parse(utcOffsetSeconds);
    final now = DateTime.now().toUtc().add(Duration(seconds: offset));

    int start = 0;
    for (int i = 0; i < hourlyTime.length; i++) {
      if (!DateTime.parse(hourlyTime[i]).isBefore(now)) {
        start = i;
        break;
      }
    }

    final len = hourlyTime.length - start;
    final take = len > 12 ? 12 : len;
    final times = hourlyTime.sublist(start, start + take);
    final precps = hourlyPrecp.sublist(start, start + take);
    final probs = hourlyPrecpProb.sublist(start, start + take);

    double maxR = 3;
    if (precps.isNotEmpty) {
      final m = precps.reduce((a, b) => a > b ? a : b);
      maxR = m < 3 ? 3 : (m * 1.3).ceilToDouble();
    }

    int? rainS;
    int? rainE;
    int longest = 0;
    int? curS;

    for (int i = 0; i < precps.length; i++) {
      final p = precps[i];
      final pb = (probs[i] is int) ? probs[i] : 0;

      if (p > 0.2 && pb >= 40) {
        curS ??= i;
      } else {
        if (curS != null) {
          final len = i - curS;
          if (len >= 2 && len > longest) {
            rainS = curS;
            rainE = i - 1;
            longest = len;
          }
          curS = null;
        }
      }
    }

    if (curS != null) {
      final len = precps.length - curS;
      if (len >= 2 && len > longest) {
        rainS = curS;
        rainE = precps.length - 1;
      }
    }

    String title = "rain_card_no_rain_exp".tr();
    String? subtitle;

    if (rainS != null) {
      if (rainS == 0 && precps.isNotEmpty && precps[0] > 0.2) {
        bool stop = false;
        if (precps.isNotEmpty) {
          final fP = (probs[0] is int) ? probs[0] : 0;
          if (precps[0] > 0.2 && fP >= 30) {
            int dry = 0;
            for (int i = 1; i < precps.length; i++) {
              final pb = (probs[i] is int) ? probs[i] : 0;
              if (precps[i] <= 0.2 || pb < 30) {
                if (++dry >= 2) {
                  stop = true;
                  break;
                }
              } else {
                dry = 0;
              }
            }
          }
        }
        title = stop ? "rain_will_stop_soon".tr() : "its_currently_raining".tr();
      } else if (rainS < times.length) {
        final hr = DateTime.parse(times[rainS]).hour;
        if (hr >= 0 && hr <= 5)
          title = "rain_expected_overnight".tr();
        else if (hr >= 6 && hr < 12)
          title = "rain_expected_this_morning".tr();
        else if (hr >= 12 && hr < 17)
          title = "rain_expected_this_afternoon".tr();
        else
          title = "rain_expected_later_today".tr();
      }
    }

    if (rainS != null && rainE != null && rainS < precps.length && rainE < precps.length) {
      double seg = 0;
      for (int i = rainS; i <= rainE; i++) {
        if (precps[i] > seg) seg = precps[i];
      }
      final lbl = seg > 5 ? "heavy_rain".tr() : seg > 2 ? "moderate_rain".tr() : "light_rain".tr();

      final hm = DateFormat.Hm();
      final jm = DateFormat.jm();
      const tu = '24 hr';

      final sT = DateTime.parse(times[rainS]);
      final eT = DateTime.parse(times[rainE]);
      final sStr = tu == '24 hr' ? hm.format(sT) : jm.format(sT);
      final eStr = tu == '24 hr' ? hm.format(eT) : jm.format(eT);

      subtitle = "$lbl ${'from_text'.tr()} $sStr ${'to_text'.tr()} $eStr";
    }

    return RainBlock(
      title: title,
      subtitle: subtitle,
      bars: precps,
      labels: times,
      max: maxR,
      scheme: colorScheme,
      bg: selectedContainerBgIndex,
      hm: DateFormat.Hm(),
      jm: DateFormat.jm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pu = 'mm';
    const tu = '24 hr';
    final loc = context.locale;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.7),
        child: Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(20),
          color: Color(bg),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style:
                        TextStyle(color: scheme.secondary, fontSize: 16, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: SizedBox(
                    height: 90,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.start,
                        maxY: max,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBorderRadius: BorderRadius.circular(50),
                            getTooltipColor: (_) => scheme.primaryContainer,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 5),
                            getTooltipItem: (_, __, rod, ___) {
                              final v = rod.toY;
                              final c = pu == 'cm'
                                  ? UnitConverter.mmToCm(v)
                                  : pu == 'in'
                                      ? UnitConverter.mmToIn(v)
                                      : v;
                              return BarTooltipItem(
                                '${c.toStringAsFixed(1)} $pu',
                                TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w500),
                              );
                            },
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(bottom: BorderSide(color: scheme.outlineVariant, width: 1)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          horizontalInterval: max / 3,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (v, _) {
                                final s = max / 2;
                                if (v == 0 || (v - s).abs() < 0.1 || (v - max).abs() < 0.1) {
                                  final c = pu == 'cm'
                                      ? UnitConverter.mmToCm(v)
                                      : pu == 'in'
                                          ? UnitConverter.mmToIn(v)
                                          : v;
                                  return Text(
                                    '${double.parse(c.toStringAsFixed(1))} ${localizePrecipUnit(pu, loc)}',
                                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              interval: max / 2,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 16,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i % 3 != 0 || i >= labels.length) return const SizedBox.shrink();
                                final dt = DateTime.parse(labels[i]);
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    tu == '24 hr' ? hm.format(dt) : jm.format(dt),
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: List.generate(
                          bars.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: bars[i],
                                width: 15,
                                color: bars[i] > 5
                                    ? scheme.error
                                    : bars[i] > 2
                                        ? scheme.tertiary
                                        : scheme.primary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(50),
                                  topRight: Radius.circular(50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
