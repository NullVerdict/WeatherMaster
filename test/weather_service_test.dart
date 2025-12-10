import 'package:flutter_test/flutter_test.dart';
import 'package:weather_master_app/services/fetch_data.dart';

void main() {
  group('WeatherService unit tests', () {
    test('WeatherService can be instantiated', () {
      final service = WeatherService();
      expect(service, isA<WeatherService>());
    });
  });
}
