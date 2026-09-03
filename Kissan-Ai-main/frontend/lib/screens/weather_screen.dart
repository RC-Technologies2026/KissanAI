import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';
import '../providers/weather_provider.dart';

/// Dedicated weather screen with current conditions, hourly & 3-day forecast.
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});

  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    await ref.read(weatherProvider.notifier).refresh();
    if (mounted) setState(() => _locating = false);
  }

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherProvider);
    final lang = ref.watch(languageProvider);
    final usingDefault = ref.read(weatherProvider.notifier).usingDefaultLocation;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.headingText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lang.t('weather.title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
        actions: [
          IconButton(
            icon: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.my_location, color: AppColors.primary),
            tooltip: 'Use my current location',
            onPressed: _locating
                ? null
                : _useMyLocation,
          ),
          IconButton(
            icon: weather.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: weather.loading
                ? null
                : () => ref.read(weatherProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Error banner
            if (weather.error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        weather.error!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.red.shade400),
                      onPressed: () =>
                          ref.read(weatherProvider.notifier).refresh(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Default-location banner
            if (usingDefault) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Using default location \u2014 enable location or update your farm city in profile for accurate weather.',
                        style: TextStyle(fontSize: 12, color: AppColors.bodyText, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Current Weather Card ─────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2E7D32),
                    Color(0xFF1565C0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(weather.conditionIcon,
                          color: Colors.white, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weather.condition,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              weather.location,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weather.temperatureC}°',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${lang.t('weather.feels_like')} ${weather.feelsLike}°C',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'H: ${weather.dailyForecast.isNotEmpty ? weather.dailyForecast.first.high : weather.temperatureC + 2}°  L: ${weather.dailyForecast.isNotEmpty ? weather.dailyForecast.first.low : weather.temperatureC - 8}°',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Weather alerts from forecast
                  if (weather.alerts.isNotEmpty)
                    ...weather.alerts.map((alert) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFFFE082), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alert,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFFFE082),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                  else if (weather.isBlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFFE082), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              weather.alertMessage ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFFFE082),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Color(0xFFA5D6A7), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            lang.t('weather.no_alerts'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFC8E6C9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Detailed Stats Grid ──────────────────────────
            Text(
              lang.t('weather.details'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.headingText,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _statCard(Icons.thermostat, lang.t('weather.feels_like'),
                    '${weather.feelsLike}°C'),
                _statCard(Icons.water_drop, lang.t('weather.humidity'),
                    '${weather.humidity}%'),
                _statCard(Icons.air, lang.t('weather.wind'),
                    '${weather.windSpeedKmh} km/h'),
                _statCard(Icons.wb_sunny, lang.t('weather.uv'),
                    '${weather.uvIndex}'),
                _statCard(Icons.visibility, lang.t('weather.visibility'),
                    '${weather.visibility} km'),
                _statCard(Icons.compress, lang.t('weather.pressure'),
                    '${weather.pressure} hPa'),
              ],
            ),
            const SizedBox(height: 24),

            // ── Hourly Forecast ──────────────────────────────
            if (weather.hourlyForecast.isNotEmpty) ...[
              Text(
                lang.t('weather.hourly'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: weather.hourlyForecast.length,
                  itemBuilder: (_, i) {
                    final h = weather.hourlyForecast[i];
                    return Container(
                      width: 72,
                      margin: EdgeInsets.only(
                          right:
                              i < weather.hourlyForecast.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            h.hour,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bodyText,
                            ),
                          ),
                          Icon(h.conditionIcon,
                              size: 28, color: AppColors.primary),
                          Text(
                            '${h.temp}°',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.headingText,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.water_drop,
                                  size: 10, color: Colors.blue),
                              const SizedBox(width: 2),
                              Text(
                                '${h.rainChance}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── 3-Day Forecast ───────────────────────────────
            if (weather.dailyForecast.isNotEmpty) ...[
              Text(
                lang.t('weather.daily'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: weather.dailyForecast.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 60,
                                child: Text(
                                  d.day,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: d.day == lang.t('weather.today')
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: d.day == lang.t('weather.today')
                                        ? AppColors.primary
                                        : AppColors.headingText,
                                  ),
                                ),
                              ),
                              Icon(d.conditionIcon,
                                  size: 24, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  d.condition,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.bodyText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.water_drop,
                                      size: 14, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${d.rainChance}%',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 70,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${d.high}°',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.headingText,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${d.low}°',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.bodyText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < weather.dailyForecast.length - 1)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.bodyText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
