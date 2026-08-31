import 'package:dio/dio.dart';

/// Dio singleton instance — lazily created.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;

  /// Must be called once at app startup after [Dio] is configured.
  void init(Dio dio) => _dio = dio;

  Dio get dio => _dio;

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
  }) =>
      _dio.post('/api/irrigation/recommend', data: {
        'plot_id': plotId,
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

  // ─── Irrigation ──────────────────────────────────────────

  Future<Response> getIrrigationGuide(String cropRecommendationId) =>
      _dio.get('/api/irrigation/guide/$cropRecommendationId');

  // ─── Chat ────────────────────────────────────────────────

  Future<Response> sendChatMessage(String message) =>
      _dio.post('/api/chat', data: {'message': message});

  Future<Response> getChatHistory({int limit = 50}) =>
      _dio.get('/api/chat', queryParameters: {'limit': limit});

  // ─── History ─────────────────────────────────────────────

  Future<Response> getHistoryList({String? analysisType, int limit = 50}) =>
      _dio.get('/api/history', queryParameters: {
        if (analysisType != null) 'analysis_type': analysisType,
        'limit': limit,
      });
}
