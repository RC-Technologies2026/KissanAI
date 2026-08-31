import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/local_storage.dart';
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
    bool clearError = false,
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
        error: clearError ? null : (error ?? this.error),
        hourlyForecast: hourlyForecast ?? this.hourlyForecast,
        dailyForecast: dailyForecast ?? this.dailyForecast,
      );
}

/// Weather provider using backend API.
class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier(this._dio) : super(const WeatherState()) {
    refresh();
  }

  /// Shared Dio (auth interceptor attached in core_providers).
  final Dio _dio;

  /// Backend `/api/weather/current` requires lat/lon; map the farmer's
  /// stored city to coordinates (fallback: Faisalabad).
  static const Map<String, List<double>> _cityCoords = {
    'faisalabad': [31.4187, 73.0791],
    'lahore': [31.5204, 74.3587],
    'islamabad': [33.6844, 73.0479],
    'rawalpindi': [33.5651, 73.0169],
    'multan': [30.1575, 71.5246],
    'gujranwala': [32.1570, 74.1867],
    'sialkot': [32.5031, 74.5156],
    'sargodha': [32.0836, 72.6711],
    'sahiwal': [30.5706, 73.1050],
    'bahawalpur': [29.3977, 71.6755],
    'abbottabad': [34.1463, 73.2116],
    'peshawar': [34.0151, 71.5249],
    'mardan': [34.1979, 72.0496],
    'quetta': [30.1798, 66.9750],
    'karachi': [24.8607, 67.0011],
    'hyderabad': [25.3960, 68.3578],
    'sukkur': [27.7052, 68.8574],
    'gilgit': [35.9201, 74.3078],
    'muzaffarabad': [34.3700, 73.4720],
  };

  List<double> _coordsFor(String city) =>
      _cityCoords[city.trim().toLowerCase()] ?? const [31.4187, 73.0791];

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);

    // Get location from storage or use default (Faisalabad)
    final storage = LocalStorage.instance;
    final city = storage.farmCity ?? 'Faisalabad';
    final province = storage.farmProvince ?? 'Punjab';
    final coords = _coordsFor(city);

    try {
      // Call backend weather endpoint with a 10 s budget so a dead
      // connection surfaces quickly instead of hanging on Dio defaults.
      final response = await _dio.get(
        ApiConstants.weatherCurrent,
        queryParameters: {
          'lat': coords[0],
          'lon': coords[1],
        },
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data as Map<String, dynamic>;

      // The auth interceptor resolves connection failures as a 200 with
      // {'error': 'offline'} — surface that as a friendly message too.
      if (data['error'] == 'offline') {
        state = state.copyWith(
          loading: false,
          error: 'Internet connection error. Please check your network.',
        );
        return;
      }

      // Backend returns a flat WeatherResponse:
      // {temperature, humidity, rain_probability, wind_speed (m/s), description}
      final description = (data['description'] as String?) ?? 'clear';

      state = WeatherState(
        temperatureC: (data['temperature'] as num?)?.round() ?? state.temperatureC,
        feelsLike: (data['feels_like'] as num?)?.round() ?? state.feelsLike,
        rainProbability: (data['rain_probability'] as num?)?.round() ?? state.rainProbability,
        windSpeedKmh: (((data['wind_speed'] as num?) ?? state.windSpeedKmh / 3.6) * 3.6).round(),
        humidity: (data['humidity'] as num?)?.round() ?? state.humidity,
        uvIndex: (data['uv_index'] as num?)?.round() ?? state.uvIndex,
        visibility: ((data['visibility'] as num?) != null
            ? (data['visibility'] as num) ~/ 1000
            : state.visibility),
        pressure: (data['pressure'] as num?)?.round() ?? state.pressure,
        dewPoint: (data['dew_point'] as num?)?.round() ?? state.dewPoint,
        location: '$city, $province',
        condition: _capitalize(description),
        conditionIcon: _iconFromDescription(description),
        loading: false,
        hourlyForecast: state.hourlyForecast,
        dailyForecast: state.dailyForecast,
      );
    } on DioException catch (e, s) {
      // Never surface raw Dio stack traces in the UI — log details, show
      // a short farmer-friendly message.
      debugPrint('Weather DioException (${e.type}): $s');
      if (e.type == DioExceptionType.cancel) {
        // Request intentionally aborted (e.g. screen disposed) — no error.
        state = state.copyWith(loading: false);
        return;
      }
      state = state.copyWith(
        loading: false,
        error: _friendlyErrorMessage(e),
      );
    } catch (e, s) {
      debugPrint('Weather parse error: $s');
      state = state.copyWith(
        loading: false,
        error: 'Unable to load weather right now. Pull down to retry.',
      );
    }
  }

  /// Maps a [DioException] (incl. raw `SocketException` DNS/connect
  /// failures like "Failed host lookup") to a user-friendly message.
  String _friendlyErrorMessage(DioException e) {
    final isSocketError = e.error is SocketException;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (isSocketError) {
          return 'Internet connection error. Please check your network.';
        }
        return 'Unable to reach the weather service. Please try again.';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The weather service is taking too long to respond. Please try again.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 401 || code == 403) {
          return 'Session expired — please log in again to load weather.';
        }
        return 'Weather service error ($code). Please try again later.';
      default:
        return 'Unable to load weather right now. Pull down to retry.';
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  IconData _iconFromDescription(String description) {
    final d = description.toLowerCase();
    if (d.contains('thunder') || d.contains('storm')) return Icons.flash_on;
    if (d.contains('drizzle')) return Icons.grain;
    if (d.contains('rain')) return Icons.water_drop;
    if (d.contains('snow')) return Icons.ac_unit;
    if (d.contains('fog') || d.contains('mist') || d.contains('haze')) {
      return Icons.foggy;
    }
    if (d.contains('clear')) return Icons.wb_sunny;
    if (d.contains('few clouds')) return Icons.cloud_queue;
    return Icons.cloud;
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
  (ref) => WeatherNotifier(ref.watch(dioProvider)),
);
