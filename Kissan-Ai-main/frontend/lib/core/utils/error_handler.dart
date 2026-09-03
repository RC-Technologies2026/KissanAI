import 'package:dio/dio.dart';

/// Converts any DioException or generic error into a user-friendly message.
/// Used across the app for consistent error display.
class AppError {
  /// Returns a human-readable error message from any exception.
  static String fromException(dynamic error) {
    if (error is DioException) {
      return _fromDio(error);
    }
    if (error is String) {
      return error;
    }
    return 'Something went wrong. Please try again.';
  }

  static String _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Please check your internet and try again.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out. Please check your internet connection.';
      case DioExceptionType.receiveTimeout:
        return 'Server is taking too long to respond. Please try again.';
      case DioExceptionType.badCertificate:
        return 'Secure connection failed. Please contact support.';
      case DioExceptionType.badResponse:
        return _fromStatusCode(error.response?.statusCode, error.response?.data);
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please turn on WiFi or mobile data.';
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        if (error.message != null && error.message!.contains('SocketException')) {
          return 'No internet connection. Please check your network.';
        }
        return 'Unable to connect to server. Please check your internet and try again.';
    }
  }

  static String _fromStatusCode(int? statusCode, dynamic data) {
    // Try to extract message from response body
    String? serverMessage;
    if (data is Map) {
      serverMessage = data['detail']?.toString() ?? data['message']?.toString();
    } else if (data is String && data.isNotEmpty) {
      serverMessage = data;
    }

    switch (statusCode) {
      case 400:
        return serverMessage ?? 'Invalid request. Please check your input.';
      case 401:
        return 'Please log in again. Your session has expired.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return serverMessage ?? 'The requested data was not found.';
      case 409:
        return serverMessage ?? 'This data already exists.';
      case 422:
        return serverMessage ?? 'Invalid input. Please check your details.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'Server error. Our team has been notified. Please try again later.';
      case 502:
        return 'Service temporarily unavailable. Please try again in a few moments.';
      case 503:
        return 'Service is under maintenance. Please try again later.';
      case 504:
        return 'Server is taking too long. Please try again.';
      default:
        return serverMessage ?? 'An unexpected error occurred. Please try again.';
    }
  }

  /// Short error suitable for a snackbar (max ~80 chars).
  static String short(dynamic error) {
    final msg = fromException(error);
    if (msg.length <= 80) return msg;
    return '${msg.substring(0, 77)}...';
  }
}
