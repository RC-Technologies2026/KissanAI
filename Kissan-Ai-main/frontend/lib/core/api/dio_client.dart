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
/// handles 401 responses by attempting a token refresh before giving up.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  bool _isRefreshing = false;

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
    if (err.response?.statusCode == 401) {
      // Don't try to refresh if the 401 came from the refresh endpoint itself.
      if (err.requestOptions.path == ApiConstants.refresh) {
        await _clearCredentials();
        handler.next(err);
        return;
      }

      // Attempt token refresh (only one refresh at a time).
      if (!_isRefreshing) {
        _isRefreshing = true;
        try {
          final refreshToken =
              await _secureStorage.read(key: HiveKeys.refreshToken);
          if (refreshToken == null || refreshToken.isEmpty) {
            await _clearCredentials();
            handler.next(err);
            return;
          }

          final res = await Dio().post(
            '${ApiConstants.baseUrl}${ApiConstants.refresh}',
            data: {'refresh_token': refreshToken},
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          final newAccess = res.data['access_token'] as String;
          final newRefresh = res.data['refresh_token'] as String;
          await _secureStorage.write(key: HiveKeys.token, value: newAccess);
          await _secureStorage.write(
              key: HiveKeys.refreshToken, value: newRefresh);

          // Retry the original request with the new access token.
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          final retryRes = await _dio.fetch(opts);
          _isRefreshing = false;
          handler.resolve(retryRes);
          return;
        } catch (_) {
          // Refresh failed — clear credentials and propagate the original error.
          await _clearCredentials();
        } finally {
          _isRefreshing = false;
        }
      }
    }
    handler.next(err);
  }

  Future<void> _clearCredentials() async {
    await _secureStorage.delete(key: HiveKeys.token);
    await _secureStorage.delete(key: HiveKeys.refreshToken);
  }
}

/// Convenience helpers to persist / clear the JWT.
Future<void> saveToken(String token) =>
    _secureStorage.write(key: HiveKeys.token, value: token);

Future<String?> readToken() => _secureStorage.read(key: HiveKeys.token);

Future<void> clearToken() async {
  await _secureStorage.delete(key: HiveKeys.token);
  await _secureStorage.delete(key: HiveKeys.refreshToken);
}

/// Convenience helpers to persist / read the refresh token.
Future<void> saveRefreshToken(String token) =>
    _secureStorage.write(key: HiveKeys.refreshToken, value: token);

Future<String?> readRefreshToken() =>
    _secureStorage.read(key: HiveKeys.refreshToken);
