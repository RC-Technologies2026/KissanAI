import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio singleton instance — lazily created.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  Timer? _keepAliveTimer;

  /// Must be called once at app startup after [Dio] is configured.
  void init(Dio dio) {
    _dio = dio;
    _startKeepAlive();
  }

  Dio get dio => _dio;

  /// Pings the lightweight /health endpoint every 10 minutes so the
  /// Render free-tier backend does not go to sleep (cold-start adds ~60s).
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      try {
        await _dio.get('/health');
      } catch (e) {
        debugPrint('Keep-alive ping failed: $e');
      }
    });
  }

  /// Cancel the keep-alive timer (e.g. on logout).
  void dispose() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  // ─── Auth ────────────────────────────────────────────────

  Future<Response> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) =>
      _dio.post('/api/auth/register', data: {
        'full_name': name,
        'phone': phone,
        'email': email,
        'password': password,
      });

  Future<Response> login({
    required String email,
    required String password,
  }) =>
      _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });

  Future<Response> getProfile() => _dio.get('/api/auth/profile');

  Future<Response> updateProfile({
    String? fullName,
    String? phone,
    String? preferredLanguage,
  }) =>
      _dio.put('/api/auth/profile', data: {
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (preferredLanguage != null) 'preferred_language': preferredLanguage,
      });

  Future<Response> uploadProfileImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _dio.post('/api/auth/profile/image', data: formData);
  }

  Future<Response> refreshToken(String refreshToken) =>
      _dio.post('/api/auth/refresh', data: {'refresh_token': refreshToken});

  // ─── Onboarding ──────────────────────────────────────────

  Future<Response> submitOnboarding(Map<String, dynamic> data) =>
      _dio.post('/api/onboarding/submit', data: data);

  // ─── Images ──────────────────────────────────────────────

  Future<Response> uploadImage(String filePath, String imageType) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _dio.post(
      '/api/images/upload',
      data: formData,
      queryParameters: {'image_type': imageType},
    );
  }

  // ─── Disease ─────────────────────────────────────────────

  Future<Response> detectDisease(String filePath, {String language = 'english'}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'language': language,
    });
    return _dio.post('/api/disease/detect', data: formData);
  }

  // ─── Pests ───────────────────────────────────────────────

  Future<Response> detectPest(String filePath, {String language = 'english'}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'language': language,
    });
    return _dio.post('/api/pests/detect', data: formData);
  }

  // ─── Recommendations ─────────────────────────────────────

  Future<Response> getPesticides({
    required String diseaseDetectionId,
    double? lat,
    double? lon,
  }) =>
      _dio.post('/api/pesticides/recommend', data: {
        'disease_detection_id': diseaseDetectionId,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      });

  Future<Response> getInsecticides({
    required String pestDetectionId,
    double? lat,
    double? lon,
  }) =>
      _dio.post('/api/insecticides/recommend', data: {
        'pest_detection_id': pestDetectionId,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      });

  // ─── Weather ─────────────────────────────────────────────

  Future<Response> getCurrentWeather({
    required double lat,
    required double lon,
  }) =>
      _dio.get('/api/weather/current', queryParameters: {
        'lat': lat,
        'lon': lon,
      });

  // ─── Crop Recommendation ─────────────────────────────────

  Future<Response> getCropRecommendation({
    required String plotId,
    String? season,
    String? soilType,
    String? waterAvailability,
  }) =>
      _dio.post('/api/irrigation/recommend', data: {
        'plot_id': plotId,
        if (season != null) 'season': season,
        if (soilType != null) 'soil_type': soilType,
        if (waterAvailability != null) 'water_availability': waterAvailability,
      });

  // ─── Plots ───────────────────────────────────────────────

  Future<Response> getPlots() => _dio.get('/api/plots');

  Future<Response> createPlot({
    required String name,
    String? location,
    double? areaHectares,
    String? soilType,
    double? latitude,
    double? longitude,
  }) =>
      _dio.post('/api/plots', data: {
        'name': name,
        if (location != null) 'location': location,
        if (areaHectares != null) 'area_hectares': areaHectares,
        if (soilType != null) 'soil_type': soilType,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

  Future<Response> updatePlot(String plotId, Map<String, dynamic> data) =>
      _dio.put('/api/plots/$plotId', data: data);

  Future<Response> deletePlot(String plotId) =>
      _dio.delete('/api/plots/$plotId');

  // ─── Irrigation ──────────────────────────────────────────

  Future<Response> getIrrigationGuide(String cropRecommendationId) =>
      _dio.get('/api/irrigation/guide/$cropRecommendationId');

  Future<Response> getDirectIrrigationGuide({
    required String plotId,
    required String cropName,
    String? waterAvailability,
    String? growthStage,
  }) =>
      _dio.post('/api/irrigation/direct-guide', data: {
        'plot_id': plotId,
        'crop_name': cropName,
        if (waterAvailability != null) 'water_availability': waterAvailability,
        if (growthStage != null) 'growth_stage': growthStage,
      });

  // ─── Chat ────────────────────────────────────────────────

  Future<Response> sendChatMessage(String message) =>
      _dio.post('/api/chat', data: {'message': message});

  Future<Response> getChatHistory({int limit = 50}) =>
      _dio.get('/api/chat', queryParameters: {'limit': limit});

  Future<Response> clearChatHistory() =>
      _dio.delete('/api/chat');

  // ─── History ─────────────────────────────────────────────

  Future<Response> getHistoryList({String? analysisType, int limit = 50}) =>
      _dio.get('/api/history', queryParameters: {
        if (analysisType != null) 'analysis_type': analysisType,
        'limit': limit,
      });

  // ─── Plants (houseplants / ornamental plants) ────────────

  /// List all plants for the authenticated user.
  Future<Response> getPlants() => _dio.get('/api/plants');

  /// Create / register a new plant.
  Future<Response> createPlant({
    required String plantName,
    String? species,
    String? imageUrl,
    String? healthStatus,
    String? notes,
  }) =>
      _dio.post('/api/plants', data: {
        'plant_name': plantName,
        if (species != null) 'species': species,
        if (imageUrl != null) 'image_url': imageUrl,
        if (healthStatus != null) 'health_status': healthStatus,
        if (notes != null) 'notes': notes,
      });

  /// Get a single plant by ID.
  Future<Response> getPlant(String plantId) =>
      _dio.get('/api/plants/$plantId');

  /// Upload an image and run plant diagnosis for a specific plant.
  Future<Response> diagnosePlant(
    String plantId,
    String filePath, {
    String language = 'english',
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'language': language,
    });
    return _dio.post('/api/plants/$plantId/diagnose', data: formData);
  }
}
