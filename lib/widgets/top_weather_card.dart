import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/icon_map.dart';

class WeatherTopCard extends StatelessWidget {
  final double currentTemp;
  final double currentFeelsLike;
  final double currentMaxTemp;
  final double currentMinTemp;
  final int currentWeatherIconCode;
  final int currentisDay;
  final String currentLastUpdated;
  final String tempUnit;
  final bool isShowFrog;

  const WeatherTopCard({
    super.key,
    required this.currentTemp,
    required this.currentFeelsLike,
    required this.currentMaxTemp,
    required this.currentMinTemp,
    required this.currentWeatherIconCode,
    required this.currentisDay,
    required this.currentLastUpdated,
    required this.tempUnit,
    required this.isShowFrog,
  });

  @override
  Widget build(BuildContext context) {
    final displayTemp = _convertTemp(currentTemp);
    final displayFeelsLike = _convertTemp(currentFeelsLike);
    final displayMax = _convertTemp(currentMaxTemp);
    final displayMin = _convertTemp(currentMinTemp);

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isShowFrog) ...[
            _CurrentTemperature(temp: displayTemp),
            const SizedBox(height: 4),
            _TemperatureRange(max: displayMax, min: displayMin),
            const SizedBox(height: 4),
            _FeelsLike(feelsLike: displayFeelsLike),
            const SizedBox(height: 8),
            _LastUpdated(lastUpdated: currentLastUpdated),
          ] else ...[
            _WeatherIcon(
              code: currentWeatherIconCode,
              isDay: currentisDay,
            ),
            const SizedBox(height: 12),
            _CurrentTemperature(temp: displayTemp),
            const SizedBox(height: 4),
            _TemperatureRange(max: displayMax, min: displayMin),
            const SizedBox(height: 4),
            _FeelsLike(feelsLike: displayFeelsLike),
            const SizedBox(height: 8),
            _LastUpdated(lastUpdated: currentLastUpdated),
          ],
        ],
      ),
    );
  }

  int _convertTemp(double temp) {
    if (tempUnit == 'Fahrenheit') {
      return ((temp * 9 / 5) + 32).round();
    }
    return temp.round();
  }
}

class _CurrentTemperature extends StatelessWidget {
  final int temp;

  const _CurrentTemperature({required this.temp});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$temp°',
      style: TextStyle(
        fontSize: MediaQuery.of(context).size.width * 0.22,
        fontWeight: FontWeight.w300,
        fontFamily: 'FlexFontEn',
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.0,
      ),
    );
  }
}

class _TemperatureRange extends StatelessWidget {
  final int max;
  final int min;

  const _TemperatureRange({required this.max, required this.min});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'H:$max°',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'FlexFontEn',
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'L:$min°',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'FlexFontEn',
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FeelsLike extends StatelessWidget {
  final int feelsLike;

  const _FeelsLike({required this.feelsLike});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Feels like $feelsLike°',
      style: TextStyle(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _LastUpdated extends StatelessWidget {
  final String lastUpdated;

  const _LastUpdated({required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Updated $lastUpdated',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }
}

class _WeatherIcon extends StatelessWidget {
  final int code;
  final int isDay;

  const _WeatherIcon({required this.code, required this.isDay});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      WeatherIconMapper.getIcon(code, isDay),
      width: 120,
      height: 120,
    );
  }
}
