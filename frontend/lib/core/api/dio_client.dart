import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Singleton secure storage for JWT persistence.
const _secureStorage = FlutterSecureStorage();

/// Creates the app-wide [Dio] instance with base config + retry + auth.
///
/// Timeouts are set to 30 seconds so Render cold starts (the free tier can
/// take ~30s to wake the backend) don't surface as raw Dio crashes.
Dio createDio() {
  final dio = Dio(
    BaseOptions(
      // Explicit production base URL — https is required (http fails TLS
      // redirect handshake on Render).
      baseUrl: ApiConstants.baseUrl, // https://kissanai-pkzn.onrender.com
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Order matters for error interceptors (they run in insertion order):
  // 1. _RetryInterceptor  — silently retries cold-start / DNS failures.
  // 2. _AuthInterceptor   — attaches JWT; converts *unrecoverable*
  //    connection failures into the {'error': 'offline'} sentinel.
  dio.interceptors.add(_RetryInterceptor(dio));
  dio.interceptors.add(_AuthInterceptor(dio));
  return dio;
}

/// Silently retries requests that failed because the Render backend was
/// asleep or the network blipped (SocketException / "Failed host lookup").
///
/// Only idempotent-safe JSON payloads are retried — multipart uploads are
/// skipped because their file stream may already be consumed.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;

  static const int _maxRetries = 2;
  static const String _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (attempt >= _maxRetries || !_isRetryable(err)) {
      handler.next(err); // pass to _AuthInterceptor (offline sentinel) / caller
      return;
    }

    // Don't re-send multipart bodies — the stream is already consumed.
    if (options.data is FormData) {
      handler.next(err);
      return;
    }

    options.extra[_attemptKey] = attempt + 1;
    // Exponential backoff: 1.5s, then 3s — enough for Render to wake up.
    await Future.delayed(Duration(milliseconds: 1500 * (attempt + 1)));

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.unknown:
        return err.error is SocketException ||
            err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout;
      case DioExceptionType.badResponse:
        // Render returns 502/503/504 while the cold start is in progress.
        final code = err.response?.statusCode ?? 0;
        return code == 502 || code == 503 || code == 504;
      default:
        return false;
    }
  }
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
    // After retries are exhausted: fold connection failures into a
    // friendly offline sentinel the UI layer already understands.
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.type == DioExceptionType.unknown && err.error is SocketException)) {
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

/// Turns any [DioException] into a short, user-safe message.
/// Never expose raw Dio stack traces in the UI.
String friendlyDioErrorMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      if (e.error is SocketException) {
        return 'Internet connection error. Please check your network.';
      }
      return 'Unable to reach the server. Please try again.';
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The server is taking too long to respond (it may be waking up). Please try again.';
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) {
        return 'Session expired — please log in again.';
      }
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      if (detail != null && detail.isNotEmpty) return detail;
      return 'Server error ($code). Please try again later.';
    case DioExceptionType.cancel:
      return 'Request was cancelled.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

/// Convenience helpers to persist / clear the JWT.
Future<void> saveToken(String token) =>
    _secureStorage.write(key: HiveKeys.token, value: token);

Future<String?> readToken() => _secureStorage.read(key: HiveKeys.token);

Future<void> clearToken() => _secureStorage.delete(key: HiveKeys.token);
