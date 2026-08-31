import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

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
        'name': name,
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

  Future<Response> uploadImage(String filePath, String uploadType) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'upload_type': uploadType,
    });
    return _dio.post('/api/images/upload', data: formData);
  }

  // ─── Disease ─────────────────────────────────────────────

  /// POST /api/disease/detect — multipart upload (file + language + crop_name).
  /// Gemini diagnosis can take a while, so this request gets its own
  /// longer receive timeout instead of the global 30s.
  Future<Response> detectDisease({
    required String filePath,
    String language = 'english',
    String? cropName,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: Uri.file(filePath).pathSegments.last,
      ),
      'language': language,
      if (cropName != null && cropName.isNotEmpty) 'crop_name': cropName,
    });
    return _dio.post(
      ApiConstants.diseaseDetect,
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
  }

  // ─── Pests ───────────────────────────────────────────────

  /// POST /api/pests/detect — multipart upload (file + language + crop_name).
  Future<Response> detectPest({
    required String filePath,
    String language = 'english',
    String? cropName,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: Uri.file(filePath).pathSegments.last,
      ),
      'language': language,
      if (cropName != null && cropName.isNotEmpty) 'crop_name': cropName,
    });
    return _dio.post(
      ApiConstants.pestDetect,
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
  }

  // ─── Recommendations ─────────────────────────────────────

  Future<Response> getPesticides(String diseaseDetectionId) =>
      _dio.get('/api/pesticides/$diseaseDetectionId');

  Future<Response> getInsecticides(String pestDetectionId) =>
      _dio.get('/api/insecticides/$pestDetectionId');

  // ─── Weather ─────────────────────────────────────────────

  Future<Response> getCurrentWeather() =>
      _dio.get('/api/weather/current');

  // ─── Crop Recommendation ─────────────────────────────────

  Future<Response> getCropRecommendation({
    required String season,
    required String soilType,
    required String waterAvailability,
  }) =>
      _dio.post('/api/crop-recommendation/get', data: {
        'season': season,
        'soil_type': soilType,
        'water_availability': waterAvailability,
      });

  // ─── Irrigation ──────────────────────────────────────────

  Future<Response> getIrrigationGuide() =>
      _dio.post('/api/irrigation/get');

  // ─── Chat ────────────────────────────────────────────────

  Future<Response> sendChatMessage(String message) =>
      _dio.post('/api/chat/message', data: {'message': message});

  // ─── History ─────────────────────────────────────────────

  Future<Response> getHistoryList() => _dio.get('/api/history/list');
}
