import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import '../storage/local_storage.dart';

/// Result returned by [LocationService.resolveLocation].
class ResolvedLocation {
  const ResolvedLocation({
    required this.lat,
    required this.lon,
    required this.label,
    this.isDefault = false,
  });

  final double lat;
  final double lon;

  /// Human-readable label, e.g. "Faisalabad, Punjab".
  final String label;

  /// True when the fallback Faisalabad default was used.
  final bool isDefault;
}

/// Handles GPS permission, position, reverse-geocoding, and fallback logic.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // ── Hardcoded last-resort default ──────────────────────────
  static const double _defaultLat = 31.4504;
  static const double _defaultLon = 73.1350;
  static const String _defaultLabel = 'Faisalabad, Punjab';

  /// Checks / requests location permission, gets GPS position,
  /// reverse-geocodes to city/province, and persists lat/lon.
  ///
  /// Falls back in order:
  ///   1. GPS position (if permission granted)
  ///   2. Saved farmCity geocoded to lat/lon
  ///   3. Hardcoded Faisalabad default
  Future<ResolvedLocation> resolveLocation() async {
    // 1. Try GPS position
    final gps = await _tryGpsPosition();
    if (gps != null) {
      return gps;
    }

    // 2. Try geocoding the saved farm city
    final storage = LocalStorage.instance;
    final savedCity = storage.farmCity;
    final savedProvince = storage.farmProvince;
    if (savedCity != null && savedCity.isNotEmpty) {
      final geocoded = await _tryGeocodeAddress('$savedCity, $savedProvince');
      if (geocoded != null) {
        // Persist so next time we skip the geocoding step.
        storage.farmLat = geocoded.lat;
        storage.farmLon = geocoded.lon;
        return geocoded;
      }
    }

    // 3. Use persisted lat/lon if they exist
    final cachedLat = storage.farmLat;
    final cachedLon = storage.farmLon;
    if (cachedLat != null && cachedLon != null) {
      return ResolvedLocation(
        lat: cachedLat,
        lon: cachedLon,
        label: '$savedCity, $savedProvince',
      );
    }

    // 4. Hardcoded last resort
    return ResolvedLocation(
      lat: _defaultLat,
      lon: _defaultLon,
      label: _defaultLabel,
      isDefault: true,
    );
  }

  /// Attempts to get the current GPS position after checking permission.
  /// Returns null if permission is denied or position cannot be obtained.
  Future<ResolvedLocation?> _tryGpsPosition() async {
    try {
      // Check and request permission
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        debugPrint('Location permission not granted: $status');
        return null;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      // Reverse-geocode to get a human-readable label (with retry)
      String label = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final placemarks = await geo.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final city = p.locality ?? p.subAdministrativeArea ?? '';
            final province = p.administrativeArea ?? '';
            if (city.isNotEmpty) {
              label = province.isNotEmpty ? '$city, $province' : city;
              break;
            }
          }
        } catch (e) {
          debugPrint('Reverse geocoding attempt ${attempt + 1} failed: $e');
          if (attempt == 0) await Future.delayed(const Duration(seconds: 2));
        }
      }

      // Persist
      final storage = LocalStorage.instance;
      storage.farmLat = position.latitude;
      storage.farmLon = position.longitude;

      return ResolvedLocation(
        lat: position.latitude,
        lon: position.longitude,
        label: label,
      );
    } catch (e) {
      debugPrint('GPS position failed: $e');
      return null;
    }
  }

  /// Geocodes a text address (e.g. "Faisalabad, Punjab") into lat/lon.
  Future<ResolvedLocation?> _tryGeocodeAddress(String address) async {
    try {
      final locations = await geo.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return ResolvedLocation(
          lat: loc.latitude,
          lon: loc.longitude,
          label: address,
        );
      }
    } catch (e) {
      debugPrint('Geocoding "$address" failed: $e');
    }
    return null;
  }

  /// Geocodes a city name and returns lat/lon (used by register/edit-profile).
  Future<({double lat, double lon})?> geocodeCity(String city, String province) async {
    final result = await _tryGeocodeAddress('$city, $province');
    if (result != null) {
      return (lat: result.lat, lon: result.lon);
    }
    return null;
  }
}
