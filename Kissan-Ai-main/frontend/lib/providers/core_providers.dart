import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/dio_client.dart';
import '../core/storage/local_storage.dart';

/// Provides the singleton [Dio] instance configured with auth interceptor.
final dioProvider = Provider<Dio>((ref) {
  final dio = createDio();
  ApiClient.instance.init(dio);
  return dio;
});

/// Provides the [ApiClient] singleton.
final apiClientProvider = Provider<ApiClient>((ref) {
  ref.watch(dioProvider); // ensure Dio is initialised
  return ApiClient.instance;
});

/// Provides [LocalStorage] singleton.
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage.instance;
});
