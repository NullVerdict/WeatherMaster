import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../notifiers/unit_settings_notifier.dart';
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
  // Cached data
  late List<String> _next12Time;
  late List<double> _next12Precp;
  late List<dynamic> _next12PrecpProb;
  late double _maxRain;
  late (int?, int?) _rainPeriod;
  
  late DateFormat _hmFormat;
  late DateFormat _jmFormat;

  @override
  void initState() {
    super.initState();
    _hmFormat = DateFormat.Hm();
    _jmFormat = DateFormat.jm();
    _processData();
  }

  @override
  void didUpdateWidget(covariant RainBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hourlyTime != widget.hourlyTime ||
        oldWidget.hourlyPrecp != widget.hourlyPrecp ||
        oldWidget.utcOffsetSeconds != widget.utcOffsetSeconds) {
      _processData();
    }
  }

  void _processData() {
    final int currentIndex = _calculateCurrentIndex();
    
    _next12Time = widget.hourlyTime.skip(currentIndex).take(12).toList();
    _next12Precp = widget.hourlyPrecp.skip(currentIndex).take(12).toList();
    _next12PrecpProb = widget.hourlyPrecpProb.skip(currentIndex).take(12).toList();
    
    if (_next12Precp.isEmpty) {
      _maxRain = 3;
      _rainPeriod = (null, null);
      return;
    }

    // Calculate max rain efficiently
    double maxR = 0;
    for (final val in _next12Precp) {
      if (val > maxR) maxR = val;
    }
    _maxRain = (maxR < 3) ? 3 : (maxR * 1.3).ceilToDouble();

    _rainPeriod = _calculateRainPeriod();
  }

  int _calculateCurrentIndex() {
    try {
      final int offsetSeconds = int.parse(widget.utcOffsetSeconds);
      final DateTime utcNow = DateTime.now().toUtc();
      final DateTime now = utcNow.add(Duration(seconds: offsetSeconds));
      
      
      for (int i = 0; i < widget.hourlyTime.length; i++) {
        // Parse only what's needed. 
        final dt = DateTime.parse(widget.hourlyTime[i]);
        if (!dt.isBefore(now)) return i;
      }
    } catch (e) {
      // Fallback
    }
    return 0;
  }

  (int?, int?) _calculateRainPeriod() {
    int? bestStart;
    int? bestEnd;
    int longestLength = 0;
    int? currentStart;

    final len = _next12Precp.length;
    for (int i = 0; i < len; i++) {
      final double precp = _next12Precp[i];
      final int prob = (_next12PrecpProb[i] is int) ? _next12PrecpProb[i] : 0;
      
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
      final length = len - currentStart;
      if (length >= 2 && length > longestLength) {
        bestStart = currentStart;
        bestEnd = len - 1;
      }
    }

    return (bestStart, bestEnd);
  }

  bool _willRainStopSoon() {
    if (_next12Precp.isEmpty) return false;
    final firstProb = (_next12PrecpProb[0] is int) ? _next12PrecpProb[0] : 0;
    
    if (_next12Precp[0] <= 0.2 || firstProb < 30) return false;

    int dryCount = 0;
    for (int i = 1; i < _next12Precp.length; i++) {
      final double precp = _next12Precp[i];
      final int prob = (_next12PrecpProb[i] is int) ? _next12PrecpProb[i] : 0;

      if (precp <= 0.2 || prob < 30) {
        dryCount++;
        if (dryCount >= 2) return true;
      } else {
        dryCount = 0;
      }
    }
    return false;
  }

  String _generateTitle(int? start) {
    if (start == null) return "rain_card_no_rain_exp".tr();

    if (start == 0 && _next12Precp.isNotEmpty && _next12Precp[0] > 0.2) {
      return _willRainStopSoon()
          ? "rain_will_stop_soon".tr()
          : "its_currently_raining".tr();
    }

    if (start != null && start < _next12Time.length) {
       final hour = DateTime.parse(_next12Time[start]).hour;
       if (hour >= 0 && hour <= 5) return "rain_expected_overnight".tr();
       if (hour >= 6 && hour < 12) return "rain_expected_this_morning".tr();
       if (hour >= 12 && hour < 17) return "rain_expected_this_afternoon".tr();
       if (hour >= 17 && hour <= 22) return "rain_expected_later_today".tr();
    }

    return "rain_expected_later_today".tr();
  }

  Color _barColor(double mm, ColorScheme scheme) {
    if (mm > 5) return scheme.error;
    if (mm > 2) return scheme.tertiary;
    if (mm > 0.2) return scheme.primary;
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    // Access providers once
    final unitSettings = context.watch<UnitSettingsNotifier>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    final timeUnit = unitSettings.timeUnit;
    final precipitationUnit = unitSettings.precipitationUnit;

    final (start, end) = _rainPeriod;
    final title = _generateTitle(start);
    
    String? subtitle;
    if (start != null && end != null && start < _next12Precp.length && end < _next12Precp.length) {
       // Calculate max for segment
       double segmentMax = 0;
       for (int i = start; i <= end; i++) {
         if (_next12Precp[i] > segmentMax) segmentMax = _next12Precp[i];
       }

       final label = switch (segmentMax) {
        > 5 => "heavy_rain".tr(),
        > 2 => "moderate_rain".tr(),
        _ => "light_rain".tr()
      };

      final startTime = DateTime.parse(_next12Time[start]);
      final endTime = DateTime.parse(_next12Time[end]);
      
      final startStr = timeUnit == '24 hr' ? _hmFormat.format(startTime) : _jmFormat.format(startTime);
      final endStr = timeUnit == '24 hr' ? _hmFormat.format(endTime) : _jmFormat.format(endTime);

      subtitle = "$label ${'from_text'.tr()} $startStr ${'to_text'.tr()} $endStr";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.7),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(20),
        color: Color(widget.selectedContainerBgIndex),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: scheme.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13)),
                ),

              const SizedBox(height: 16),

              SizedBox(
                height: 90,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.start,
                    maxY: _maxRain,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBorderRadius: BorderRadius.circular(50),
                        getTooltipColor: (group) => scheme.primaryContainer,
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
                            TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: scheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                      horizontalInterval: _maxRain / 3,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: scheme.outlineVariant,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            final roundedMax = _maxRain;
                            final step = roundedMax / 2;
                            
                            // Only show 0, middle, and max
                            if (value == 0 || (value - step).abs() < 0.1 || (value - roundedMax).abs() < 0.1) {
                               final convertedPrecip = precipitationUnit == 'cm'
                                  ? UnitConverter.mmToCm(value)
                                  : precipitationUnit == 'in'
                                      ? UnitConverter.mmToIn(value)
                                      : value;
                                      
                              return Text(
                                '${double.parse(convertedPrecip.toStringAsFixed(1))} ${localizePrecipUnit(precipitationUnit, context.locale)}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.onSurfaceVariant),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          interval: _maxRain / 2,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 16,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx % 3 != 0 || idx >= _next12Time.length) {
                              return const SizedBox.shrink();
                            }
                            final dt = DateTime.parse(_next12Time[idx]);
                            return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  timeUnit == '24 hr'
                                      ? _hmFormat.format(dt)
                                      : _jmFormat.format(dt),
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 9),
                                ));
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(_next12Precp.length, (i) {
                      final val = _next12Precp[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: val,
                            width: 15,
                            color: _barColor(val, scheme),
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(50),
                                topRight: Radius.circular(50)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
