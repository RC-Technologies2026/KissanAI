import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/local_storage.dart';

/// Daily forecast entry.
class DailyForecast {
  const DailyForecast({
    required this.day,
    required this.high,
    required this.low,
    required this.condition,
    required this.conditionIcon,
    required this.rainChance,
    required this.humidity,
    required this.windSpeed,
  });

  final String day;
  final int high;
  final int low;
  final String condition;
  final IconData conditionIcon;
  final int rainChance;
  final int humidity;
  final int windSpeed;
}

/// Hourly forecast entry.
class HourlyForecast {
  const HourlyForecast({
    required this.hour,
    required this.temp,
    required this.conditionIcon,
    required this.rainChance,
  });

  final String hour;
  final int temp;
  final IconData conditionIcon;
  final int rainChance;
}

/// Weather reading used by the dashboard and recommendation screens.
class WeatherState {
  const WeatherState({
    this.temperatureC = 32,
    this.feelsLike = 35,
    this.rainProbability = 20,
    this.windSpeedKmh = 8,
    this.humidity = 65,
    this.uvIndex = 6,
    this.visibility = 10,
    this.pressure = 1013,
    this.dewPoint = 22,
    this.location = 'Faisalabad, Punjab',
    this.condition = 'Partly Cloudy',
    this.conditionIcon = Icons.cloud,
    this.loading = false,
    this.error,
    this.hourlyForecast = const [],
    this.dailyForecast = const [],
  });

  final int temperatureC;
  final int feelsLike;
  final int rainProbability;
  final int windSpeedKmh;
  final int humidity;
  final int uvIndex;
  final int visibility;
  final int pressure;
  final int dewPoint;
  final String location;
  final String condition;
  final IconData conditionIcon;
  final bool loading;
  final String? error;
  final List<HourlyForecast> hourlyForecast;
  final List<DailyForecast> dailyForecast;

  bool get isBlocked => rainProbability > 60 || windSpeedKmh > 15;

  String? get alertMessage {
    if (!isBlocked) return null;
    if (windSpeedKmh > 15) {
      return 'High wind — spraying not recommended today';
    }
    return 'Rain expected — irrigation may not be needed today';
  }

  WeatherState copyWith({
    int? temperatureC,
    int? feelsLike,
    int? rainProbability,
    int? windSpeedKmh,
    int? humidity,
    int? uvIndex,
    int? visibility,
    int? pressure,
    int? dewPoint,
    String? location,
    String? condition,
    IconData? conditionIcon,
    bool? loading,
    String? error,
    List<HourlyForecast>? hourlyForecast,
    List<DailyForecast>? dailyForecast,
  }) =>
      WeatherState(
        temperatureC: temperatureC ?? this.temperatureC,
        feelsLike: feelsLike ?? this.feelsLike,
        rainProbability: rainProbability ?? this.rainProbability,
        windSpeedKmh: windSpeedKmh ?? this.windSpeedKmh,
        humidity: humidity ?? this.humidity,
        uvIndex: uvIndex ?? this.uvIndex,
        visibility: visibility ?? this.visibility,
        pressure: pressure ?? this.pressure,
        dewPoint: dewPoint ?? this.dewPoint,
        location: location ?? this.location,
        condition: condition ?? this.condition,
        conditionIcon: conditionIcon ?? this.conditionIcon,
        loading: loading ?? this.loading,
        error: error ?? this.error,
        hourlyForecast: hourlyForecast ?? this.hourlyForecast,
        dailyForecast: dailyForecast ?? this.dailyForecast,
      );
}

/// Weather provider using backend API.
class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier() : super(const WeatherState()) {
    refresh();
  }

  final Dio _dio = Dio();

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);

    try {
      // Get location from storage or use default (Faisalabad)
      final storage = LocalStorage.instance;
      final city = storage.farmCity ?? 'Faisalabad';
      final province = storage.farmProvince ?? 'Punjab';

      // Call backend weather endpoint
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/api/weather/current',
        queryParameters: {
          'city': city,
          'province': province,
        },
      );

      final data = response.data;

      // Parse current weather from backend response
      final current = data['current'] as Map<String, dynamic>? ?? data;
      final main = current['main'] as Map<String, dynamic>? ?? {};
      final weather = (current['weather'] as List?)?.first as Map<String, dynamic>? ?? {};
      final wind = current['wind'] as Map<String, dynamic>? ?? {};

      // Parse forecast if available
      final forecastList = data['forecast']?['list'] as List? ?? [];
      final hourly = forecastList.isNotEmpty ? _parseHourlyForecast(forecastList) : <HourlyForecast>[];
      final daily = forecastList.isNotEmpty ? _parseDailyForecast(forecastList) : <DailyForecast>[];

      state = WeatherState(
        temperatureC: (main['temp'] as num?)?.round() ?? 32,
        feelsLike: (main['feels_like'] as num?)?.round() ?? 35,
        rainProbability: ((current['clouds']?['all'] ?? data['rain_probability'] ?? 20) as num).round(),
        windSpeedKmh: (((wind['speed'] as num?) ?? 2.2) * 3.6).round(), // m/s to km/h
        humidity: (main['humidity'] as num?)?.round() ?? 65,
        uvIndex: (data['uv_index'] as num?)?.round() ?? 6,
        visibility: ((current['visibility'] as num? ?? 10000) ~/ 1000),
        pressure: (main['pressure'] as num?)?.round() ?? 1013,
        dewPoint: (main['temp'] as num?)?.round() ?? 22,
        location: '$city, $province',
        condition: weather['main'] as String? ?? data['condition'] ?? 'Clear',
        conditionIcon: _getWeatherIcon(weather['id'] as int? ?? 800),
        loading: false,
        hourlyForecast: hourly,
        dailyForecast: daily,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to fetch weather: $e',
      );
    }
  }

  List<HourlyForecast> _parseHourlyForecast(List forecastList) {
    // Take next 8 entries (3-hour intervals = 24 hours)
    final hours = <HourlyForecast>[];

    for (var i = 0; i < forecastList.length && i < 8; i++) {
      final item = forecastList[i] as Map<String, dynamic>;
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (item['dt'] as int) * 1000,
      );
      final main = item['main'] as Map<String, dynamic>;
      final weather = (item['weather'] as List).first as Map<String, dynamic>;
      final pop = (item['pop'] as num? ?? 0).round(); // probability of precipitation

      String hourLabel;
      if (i == 0) {
        hourLabel = 'Now';
      } else {
        final hour = dt.hour;
        final suffix = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        hourLabel = '$displayHour $suffix';
      }

      hours.add(HourlyForecast(
        hour: hourLabel,
        temp: (main['temp'] as num).round(),
        conditionIcon: _getWeatherIcon(weather['id'] as int? ?? 800),
        rainChance: (pop * 100).round(),
      ));
    }

    return hours;
  }

  List<DailyForecast> _parseDailyForecast(List forecastList) {
    // Group by day and get high/low for each day
    final dailyMap = <String, List<Map<String, dynamic>>>{};

    for (var i = 0; i < forecastList.length; i++) {
      final item = forecastList[i] as Map<String, dynamic>;
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (item['dt'] as int) * 1000,
      );
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';

      dailyMap.putIfAbsent(dayKey, () => []).add(item);
    }

    final days = <DailyForecast>[];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    var dayIndex = 0;

    dailyMap.forEach((dayKey, items) {
      if (dayIndex >= 7) return;

      final temps = items.map((e) => (e['main']['temp'] as num).toDouble()).toList();
      final high = temps.reduce((a, b) => a > b ? a : b).round();
      final low = temps.reduce((a, b) => a < b ? a : b).round();

      // Use midday item for condition
      final middayItem = items.first;
      final weather = (middayItem['weather'] as List).first as Map<String, dynamic>;
      final pop = (items.map((e) => (e['pop'] as num? ?? 0).toDouble()).reduce((a, b) => a > b ? a : b) * 100).round();
      final humidity = (middayItem['main']['humidity'] as num).round();
      final windSpeed = (((middayItem['wind']['speed'] as num) * 3.6).round());

      final dt = DateTime.fromMillisecondsSinceEpoch(
        (middayItem['dt'] as int) * 1000,
      );

      String dayLabel;
      if (dayIndex == 0 && dt.day == now.day) {
        dayLabel = 'Today';
      } else {
        dayLabel = dayNames[dt.weekday - 1];
      }

      days.add(DailyForecast(
        day: dayLabel,
        high: high,
        low: low,
        condition: weather['main'] as String? ?? 'Clear',
        conditionIcon: _getWeatherIcon(weather['id'] as int? ?? 800),
        rainChance: pop,
        humidity: humidity,
        windSpeed: windSpeed,
      ));

      dayIndex++;
    });

    return days;
  }

  IconData _getWeatherIcon(int weatherCode) {
    // OpenWeatherMap weather condition codes
    if (weatherCode >= 200 && weatherCode < 300) return Icons.flash_on; // Thunderstorm
    if (weatherCode >= 300 && weatherCode < 400) return Icons.grain; // Drizzle
    if (weatherCode >= 500 && weatherCode < 600) return Icons.water_drop; // Rain
    if (weatherCode >= 600 && weatherCode < 700) return Icons.ac_unit; // Snow
    if (weatherCode >= 700 && weatherCode < 800) return Icons.foggy; // Atmosphere
    if (weatherCode == 800) return Icons.wb_sunny; // Clear
    if (weatherCode == 801) return Icons.cloud_queue; // Few clouds
    if (weatherCode == 802) return Icons.cloud; // Scattered clouds
    if (weatherCode >= 803) return Icons.cloud; // Broken/overcast clouds
    return Icons.cloud;
  }

  void setMock({
    int? temperatureC,
    int? rainProbability,
    int? windSpeedKmh,
    int? humidity,
  }) {
    state = state.copyWith(
      temperatureC: temperatureC,
      rainProbability: rainProbability,
      windSpeedKmh: windSpeedKmh,
      humidity: humidity,
    );
  }
}

final weatherProvider =
    StateNotifierProvider<WeatherNotifier, WeatherState>(
  (_) => WeatherNotifier(),
);
