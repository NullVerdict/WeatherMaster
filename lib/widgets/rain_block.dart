import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/unit_converter.dart';
import '../helper/locale_helper.dart';

class RainBlock extends StatefulWidget {
  final List<String> hourlyTime;
  final List<double> hourlyPrecp;
  final List<dynamic> hourlyPrecpProb;
  final int selectedContainerBgIndex;
  final String timezone;
  final String utcOffsetSeconds;

  const RainBlock({
    super.key,
    required this.hourlyTime,
    required this.hourlyPrecp,
    required this.selectedContainerBgIndex,
    required this.timezone,
    required this.utcOffsetSeconds,
    required this.hourlyPrecpProb,
  });

  @override
  State<RainBlock> createState() => _RainBlockState();
}

class _RainBlockState extends State<RainBlock> {
  late _RainDataCache _cache;
  late final DateFormat _hmFormat;
  late final DateFormat _jmFormat;

  @override
  void initState() {
    super.initState();
    _hmFormat = DateFormat.Hm();
    _jmFormat = DateFormat.jm();
    _cache = _RainDataCache(
      widget.hourlyTime,
      widget.hourlyPrecp,
      widget.hourlyPrecpProb,
      widget.utcOffsetSeconds,
    );
  }

  @override
  void didUpdateWidget(covariant RainBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hourlyTime != widget.hourlyTime ||
        oldWidget.hourlyPrecp != widget.hourlyPrecp ||
        oldWidget.utcOffsetSeconds != widget.utcOffsetSeconds) {
      _cache.update(
        widget.hourlyTime,
        widget.hourlyPrecp,
        widget.hourlyPrecpProb,
        widget.utcOffsetSeconds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.7),
        child: Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(20),
          color: Color(widget.selectedContainerBgIndex),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _TitleSection(
                  cache: _cache,
                  scheme: scheme,
                ),
                const SizedBox(height: 16),
                _ChartSection(
                  cache: _cache,
                  scheme: scheme,
                  hmFormat: _hmFormat,
                  jmFormat: _jmFormat,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RainDataCache {
  List<String> next12Time = [];
  List<double> next12Precp = [];
  List<dynamic> next12PrecpProb = [];
  double maxRain = 3;
  int? rainStart;
  int? rainEnd;

  _RainDataCache(
    List<String> hourlyTime,
    List<double> hourlyPrecp,
    List<dynamic> hourlyPrecpProb,
    String utcOffsetSeconds,
  ) {
    update(hourlyTime, hourlyPrecp, hourlyPrecpProb, utcOffsetSeconds);
  }

  void update(
    List<String> hourlyTime,
    List<double> hourlyPrecp,
    List<dynamic> hourlyPrecpProb,
    String utcOffsetSeconds,
  ) {
    final currentIndex = _calculateCurrentIndex(hourlyTime, utcOffsetSeconds);
    final len = hourlyTime.length - currentIndex;
    final take = len > 12 ? 12 : len;

    next12Time = hourlyTime.sublist(currentIndex, currentIndex + take);
    next12Precp = hourlyPrecp.sublist(currentIndex, currentIndex + take);
    next12PrecpProb = hourlyPrecpProb.sublist(currentIndex, currentIndex + take);

    if (next12Precp.isEmpty) {
      maxRain = 3;
      rainStart = null;
      rainEnd = null;
      return;
    }

    double maxR = next12Precp.reduce((a, b) => a > b ? a : b);
    maxRain = (maxR < 3) ? 3 : (maxR * 1.3).ceilToDouble();

    final period = _calculateRainPeriod();
    rainStart = period.$1;
    rainEnd = period.$2;
  }

  int _calculateCurrentIndex(List<String> hourlyTime, String utcOffsetSeconds) {
    try {
      final offsetSeconds = int.parse(utcOffsetSeconds);
      final now = DateTime.now().toUtc().add(Duration(seconds: offsetSeconds));

      for (int i = 0; i < hourlyTime.length; i++) {
        if (!DateTime.parse(hourlyTime[i]).isBefore(now)) return i;
      }
    } catch (_) {}
    return 0;
  }

  (int?, int?) _calculateRainPeriod() {
    int? bestStart;
    int? bestEnd;
    int longestLength = 0;
    int? currentStart;

    for (int i = 0; i < next12Precp.length; i++) {
      final precp = next12Precp[i];
      final prob = (next12PrecpProb[i] is int) ? next12PrecpProb[i] : 0;

      if (precp > 0.2 && prob >= 40) {
        currentStart ??= i;
      } else {
        if (currentStart != null) {
          final length = i - currentStart;
          if (length >= 2 && length > longestLength) {
            bestStart = currentStart;
            bestEnd = i - 1;
            longestLength = length;
          }
          currentStart = null;
        }
      }
    }

    if (currentStart != null) {
      final length = next12Precp.length - currentStart;
      if (length >= 2 && length > longestLength) {
        bestStart = currentStart;
        bestEnd = next12Precp.length - 1;
      }
    }

    return (bestStart, bestEnd);
  }

  bool willRainStopSoon() {
    if (next12Precp.isEmpty) return false;
    final firstProb = (next12PrecpProb[0] is int) ? next12PrecpProb[0] : 0;

    if (next12Precp[0] <= 0.2 || firstProb < 30) return false;

    int dryCount = 0;
    for (int i = 1; i < next12Precp.length; i++) {
      if (next12Precp[i] <= 0.2 || ((next12PrecpProb[i] is int) ? next12PrecpProb[i] : 0) < 30) {
        if (++dryCount >= 2) return true;
      } else {
        dryCount = 0;
      }
    }
    return false;
  }
}

class _TitleSection extends StatelessWidget {
  final _RainDataCache cache;
  final ColorScheme scheme;

  const _TitleSection({required this.cache, required this.scheme});

  String _generateTitle() {
    final start = cache.rainStart;
    if (start == null) return "rain_card_no_rain_exp".tr();

    if (start == 0 && cache.next12Precp.isNotEmpty && cache.next12Precp[0] > 0.2) {
      return cache.willRainStopSoon() ? "rain_will_stop_soon".tr() : "its_currently_raining".tr();
    }

    if (start < cache.next12Time.length) {
      final hour = DateTime.parse(cache.next12Time[start]).hour;
      if (hour >= 0 && hour <= 5) return "rain_expected_overnight".tr();
      if (hour >= 6 && hour < 12) return "rain_expected_this_morning".tr();
      if (hour >= 12 && hour < 17) return "rain_expected_this_afternoon".tr();
      if (hour >= 17 && hour <= 22) return "rain_expected_later_today".tr();
    }

    return "rain_expected_later_today".tr();
  }

  @override
  Widget build(BuildContext context) {
    final title = _generateTitle();
    final start = cache.rainStart;
    final end = cache.rainEnd;

    String? subtitle;
    if (start != null && end != null && start < cache.next12Precp.length && end < cache.next12Precp.length) {
      double segmentMax = 0;
      for (int i = start; i <= end; i++) {
        if (cache.next12Precp[i] > segmentMax) segmentMax = cache.next12Precp[i];
      }

      final label = switch (segmentMax) {
        > 5 => "heavy_rain".tr(),
        > 2 => "moderate_rain".tr(),
        _ => "light_rain".tr()
      };

      final hmFormat = DateFormat.Hm();
      final jmFormat = DateFormat.jm();
      const timeUnit = '24 hr';

      final startTime = DateTime.parse(cache.next12Time[start]);
      final endTime = DateTime.parse(cache.next12Time[end]);

      final startStr = timeUnit == '24 hr' ? hmFormat.format(startTime) : jmFormat.format(startTime);
      final endStr = timeUnit == '24 hr' ? hmFormat.format(endTime) : jmFormat.format(endTime);

      subtitle = "$label ${'from_text'.tr()} $startStr ${'to_text'.tr()} $endStr";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(color: scheme.secondary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ),
      ],
    );
  }
}

class _ChartSection extends StatelessWidget {
  final _RainDataCache cache;
  final ColorScheme scheme;
  final DateFormat hmFormat;
  final DateFormat jmFormat;

  const _ChartSection({
    required this.cache,
    required this.scheme,
    required this.hmFormat,
    required this.jmFormat,
  });

  Color _barColor(double mm) {
    if (mm > 5) return scheme.error;
    if (mm > 2) return scheme.tertiary;
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    const precipitationUnit = 'mm';
    const timeUnit = '24 hr';
    final locale = context.locale;

    return RepaintBoundary(
      child: SizedBox(
        height: 90,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.start,
            maxY: cache.maxRain,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBorderRadius: BorderRadius.circular(50),
                getTooltipColor: (_) => scheme.primaryContainer,
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 5),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final val = rod.toY;
                  final convertedPrecip = precipitationUnit == 'cm'
                      ? UnitConverter.mmToCm(val)
                      : precipitationUnit == 'in'
                          ? UnitConverter.mmToIn(val)
                          : val;
                  return BarTooltipItem(
                    '${convertedPrecip.toStringAsFixed(1)} $precipitationUnit',
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
              horizontalInterval: cache.maxRain / 3,
              getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    final step = cache.maxRain / 2;
                    if (value == 0 || (value - step).abs() < 0.1 || (value - cache.maxRain).abs() < 0.1) {
                      final convertedPrecip = precipitationUnit == 'cm'
                          ? UnitConverter.mmToCm(value)
                          : precipitationUnit == 'in'
                              ? UnitConverter.mmToIn(value)
                              : value;
                      return Text(
                        '${double.parse(convertedPrecip.toStringAsFixed(1))} ${localizePrecipUnit(precipitationUnit, locale)}',
                        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  interval: cache.maxRain / 2,
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 16,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx % 3 != 0 || idx >= cache.next12Time.length) return const SizedBox.shrink();
                    final dt = DateTime.parse(cache.next12Time[idx]);
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        timeUnit == '24 hr' ? hmFormat.format(dt) : jmFormat.format(dt),
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(
              cache.next12Precp.length,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: cache.next12Precp[i],
                    width: 15,
                    color: _barColor(cache.next12Precp[i]),
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
    );
  }
}
