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
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
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
    // Silently swallow connection errors when no backend is running.
    // The app works in demo/mock mode without a server.
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.unknown) {
      // Return a mock empty response so the app doesn't crash.
      handler.resolve(Response(
        requestOptions: err.requestOptions,
        data: {'error': 'offline'},
        statusCode: 200,
      ));
      return;
    }
    if (err.response?.statusCode == 401) {
      await _secureStorage.delete(key: HiveKeys.token);
    }
    handler.next(err);
  }
}

/// Convenience helpers to persist / clear the JWT.
Future<void> saveToken(String token) =>
    _secureStorage.write(key: HiveKeys.token, value: token);

Future<String?> readToken() => _secureStorage.read(key: HiveKeys.token);

Future<void> clearToken() => _secureStorage.delete(key: HiveKeys.token);
