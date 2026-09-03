import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/location_service.dart';
import '../core/utils/error_handler.dart';
import 'core_providers.dart';

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
    this.alerts = const [],
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
  final List<String> alerts;

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
    List<String>? alerts,
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
        alerts: alerts ?? this.alerts,
      );
}

/// Weather provider using backend API.
class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier(this._dio) : super(const WeatherState()) {
    refresh();
  }

  final Dio _dio;

  /// When true, the weather is using the hardcoded Faisalabad default
  /// because GPS and saved farm city both failed.
  bool _usingDefaultLocation = false;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);

    try {
      // Resolve location via LocationService (GPS -> geocoded city -> default).
      final resolved = await LocationService.instance.resolveLocation();
      _usingDefaultLocation = resolved.isDefault;

      final double lat = resolved.lat;
      final double lon = resolved.lon;

      // Call backend forecast endpoint (includes current + 3-day + alerts)
      final response = await _dio.get(
        '/api/weather/forecast',
        queryParameters: {
          'lat': lat,
          'lon': lon,
        },
      );

      final data = response.data;

      // Parse current weather from forecast response
      final current = data['current'] ?? data;
      final temperature = (current['temperature'] as num?)?.round() ?? 32;
      final humidity = (current['humidity'] as num?)?.round() ?? 65;
      final rainProb = (current['rain_probability'] as num?)?.round() ?? 20;
      final windSpeed = (current['wind_speed'] as num?)?.round() ?? 8;
      final description = current['description'] as String? ?? 'Clear';
      final location = current['location'] as String? ?? resolved.label;

      // Parse 3-day forecast
      final dailyList = (data['daily'] as List?) ?? [];
      final dailyForecasts = dailyList.map<DailyForecast>((d) {
        return DailyForecast(
          day: d['day']?.toString() ?? '',
          high: (d['high'] as num?)?.round() ?? 30,
          low: (d['low'] as num?)?.round() ?? 20,
          condition: d['condition']?.toString() ?? 'Clear',
          conditionIcon: _conditionToIcon(d['condition_icon']?.toString() ?? 'clear'),
          rainChance: (d['rain_chance'] as num?)?.round() ?? 0,
          humidity: (d['humidity'] as num?)?.round() ?? 65,
          windSpeed: (d['wind_speed'] as num?)?.round() ?? 0,
        );
      }).toList();

      // Parse alerts
      final alertList = (data['alerts'] as List?)?.cast<String>() ?? [];

      state = WeatherState(
        temperatureC: temperature,
        feelsLike: temperature + 3,
        rainProbability: rainProb,
        windSpeedKmh: windSpeed,
        humidity: humidity,
        uvIndex: 6,
        visibility: 10,
        pressure: 1013,
        dewPoint: (temperature - 10).clamp(-10, 40),
        location: location,
        condition: _mapCondition(description),
        conditionIcon: _conditionToIcon(description),
        loading: false,
        hourlyForecast: const <HourlyForecast>[],
        dailyForecast: dailyForecasts,
        alerts: alertList,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: AppError.fromException(e),
      );
    }
  }

  /// Whether the provider fell back to the hardcoded default location.
  bool get usingDefaultLocation => _usingDefaultLocation;

  /// Map backend description string to a display-friendly condition label.
  String _mapCondition(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('clear')) return 'Clear';
    if (lower.contains('partly')) return 'Partly Cloudy';
    if (lower.contains('cloud')) return 'Cloudy';
    if (lower.contains('rain')) return 'Rainy';
    if (lower.contains('thunder')) return 'Thunderstorm';
    if (lower.contains('drizzle')) return 'Drizzle';
    if (lower.contains('snow')) return 'Snowy';
    if (lower.contains('fog') || lower.contains('mist')) return 'Foggy';
    return description;
  }

  /// Map backend description to a Material icon.
  IconData _conditionToIcon(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('clear') || lower.contains('sun')) return Icons.wb_sunny;
    if (lower.contains('partly') || lower.contains('cloud')) return Icons.cloud;
    if (lower.contains('rain') || lower.contains('drizzle')) return Icons.water_drop;
    if (lower.contains('thunder')) return Icons.flash_on;
    if (lower.contains('snow')) return Icons.ac_unit;
    if (lower.contains('fog') || lower.contains('mist')) return Icons.foggy;
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
  (ref) {
    final dio = ref.watch(dioProvider);
    return WeatherNotifier(dio);
  },
);
