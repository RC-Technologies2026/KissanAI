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

/// Weather provider using OpenWeatherMap API.
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

      // City coordinates mapping for Pakistan
      final coords = _getCityCoordinates(city);
      final lat = coords.$1;
      final lon = coords.$2;

      const apiKey = ApiConstants.openWeatherApiKey;

      // Fetch current weather and 5-day forecast in parallel
      final results = await Future.wait([
        _fetchCurrentWeather(lat, lon, apiKey),
        _fetchForecast(lat, lon, apiKey),
      ]);

      final currentData = results[0];
      final forecastData = results[1];

      // Parse current weather
      final current = currentData;
      final main = current['main'] as Map<String, dynamic>;
      final weather = (current['weather'] as List).first as Map<String, dynamic>;
      final wind = current['wind'] as Map<String, dynamic>;

      // Parse forecast
      final forecastList = forecastData['list'] as List;
      final hourly = _parseHourlyForecast(forecastList);
      final daily = _parseDailyForecast(forecastList);

      state = WeatherState(
        temperatureC: (main['temp'] as num).round(),
        feelsLike: (main['feels_like'] as num).round(),
        rainProbability: ((current['clouds']?['all'] ?? 20) as num).round(),
        windSpeedKmh: (((wind['speed'] as num) * 3.6).round()), // m/s to km/h
        humidity: (main['humidity'] as num).round(),
        uvIndex: 6, // Not in free API, using default
        visibility: ((current['visibility'] as num? ?? 10000) ~/ 1000),
        pressure: (main['pressure'] as num).round(),
        dewPoint: (main['temp'] as num).round() - ((100 - (main['humidity'] as num)) ~/ 5),
        location: '$city, $province',
        condition: weather['main'] as String? ?? 'Clear',
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

  Future<Map<String, dynamic>> _fetchCurrentWeather(
      double lat, double lon, String apiKey) async {
    final response = await _dio.get(
      '${ApiConstants.openWeatherBaseUrl}/weather',
      queryParameters: {
        'lat': lat,
        'lon': lon,
        'appid': apiKey,
        'units': 'metric',
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchForecast(
      double lat, double lon, String apiKey) async {
    final response = await _dio.get(
      '${ApiConstants.openWeatherBaseUrl}/forecast',
      queryParameters: {
        'lat': lat,
        'lon': lon,
        'appid': apiKey,
        'units': 'metric',
      },
    );
    return response.data as Map<String, dynamic>;
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

  /// Get latitude and longitude for a Pakistani city.
  (double, double) _getCityCoordinates(String city) {
    // Major city coordinates
    const cityCoords = <String, (double, double)>{
      'Karachi': (24.8607, 67.0011),
      'Lahore': (31.5204, 74.3587),
      'Islamabad': (33.6844, 73.0479),
      'Rawalpindi': (33.5651, 73.0169),
      'Faisalabad': (31.4504, 73.1350),
      'Multan': (30.1575, 71.5249),
      'Peshawar': (34.0151, 71.5249),
      'Quetta': (30.1798, 66.9750),
      'Hyderabad': (25.3960, 68.3578),
      'Sialkot': (32.4945, 74.5229),
      'Gujranwala': (32.1877, 74.1945),
      'Bahawalpur': (29.3545, 71.6911),
      'Sargodha': (32.0859, 72.6738),
      'Sukkur': (27.7032, 68.8589),
      'Larkana': (27.5590, 68.2104),
      'Mardan': (34.1976, 72.0490),
      'Mingora': (34.7795, 72.3617),
      'Sheikhupura': (31.7133, 73.9419),
      'Muzaffargarh': (30.0736, 70.5867),
      'Sahiwal': (30.6612, 73.1020),
      'Okara': (30.8103, 73.4528),
      'Jhang': (31.3053, 72.3253),
      'Gujrat': (32.5742, 74.0754),
      'Kasur': (31.1186, 74.4500),
      'Rahim Yar Khan': (28.4213, 70.3049),
      'Dera Ghazi Khan': (30.0458, 70.6403),
      'Nawabshah': (26.2395, 68.4089),
      'Mirpur Khas': (25.5276, 69.0095),
      'Chiniot': (31.7209, 72.9788),
      'Jhelum': (32.9345, 73.7311),
      'Abbottabad': (34.1694, 73.2134),
      'Muzaffarabad': (34.3700, 73.4700),
      'Gilgit': (35.9186, 74.3124),
      'Skardu': (35.2975, 75.6333),
    };

    // Try to find matching city
    for (final entry in cityCoords.entries) {
      if (city.toLowerCase().contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(city.toLowerCase())) {
        return entry.value;
      }
    }

    // Default to Faisalabad
    return (31.4504, 73.1350);
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
