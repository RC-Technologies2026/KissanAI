import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Singleton secure storage for JWT persistence.
const _secureStorage = FlutterSecureStorage();

/// Creates the app-wide [Dio] instance with base config + auth interceptor.
Dio createDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      // Render free tier needs extra time to wake from sleep (up to 60s).
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 120),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(_AuthInterceptor(dio));
  return dio;
}

/// Interceptor that attaches the JWT to every outbound request and
/// handles 401 responses by clearing stored credentials.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  // ignore: unused_field
  final Dio _dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.read(key: HiveKeys.token);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // On 401, clear the stored token so the next request prompts re-login.
    if (err.response?.statusCode == 401) {
      await _secureStorage.delete(key: HiveKeys.token);
    }
    // Let ALL errors (including connection / timeout) pass through to the
    // caller so it can show a proper message instead of a fake "offline" one.
    handler.next(err);
  }
}

/// Convenience helpers to persist / clear the JWT.
Future<void> saveToken(String token) =>
    _secureStorage.write(key: HiveKeys.token, value: token);

Future<String?> readToken() => _secureStorage.read(key: HiveKeys.token);

Future<void> clearToken() => _secureStorage.delete(key: HiveKeys.token);
