import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/dio_client.dart';
import '../core/storage/local_storage.dart';
import 'core_providers.dart';

/// Auth state — authenticated / unauthenticated / loading.
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.userName,
    this.userEmail,
    this.error,
  });

  final AuthStatus status;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? userName,
    String? userEmail,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        userEmail: userEmail ?? this.userEmail,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    _checkExistingSession();
  }

  final dynamic _api; // ApiClient
  final LocalStorage _storage;

  Future<void> _checkExistingSession() async {
    final token = await readToken();
    if (token != null && token.isNotEmpty && _storage.userId != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: _storage.userId,
        userName: _storage.userName,
        userEmail: _storage.userEmail,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final res = await _api.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
      );
      final data = res.data;

      // Backend returns UserOut (no token). Extract user id from response.
      final userId = data['id'] as String? ?? '';

      // Auto-login after registration to obtain the JWT token.
      try {
        final loginRes = await _api.login(email: email, password: password);
        final loginData = loginRes.data;

        final token = loginData['access_token'] as String;
        await saveToken(token);
      } catch (loginErr) {
        // If auto-login fails after successful registration, still save user info
        // so the user can manually log in.
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Registration successful! Please log in with your credentials.',
        );
        return;
      }

      _storage.userId = userId;
      _storage.userName = name;
      _storage.userEmail = email;
      _storage.userPhone = phone;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: userId,
        userName: name,
        userEmail: email,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _networkMessage(e, fallback: 'Registration failed. Please try again.'),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Registration failed. Please check your connection.',
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final res = await _api.login(email: email, password: password);
      final data = res.data;

      // Backend returns Token: {access_token, token_type}
      final token = data['access_token'] as String;

      await saveToken(token);

      // Backend doesn't return user details in login response.
      // Use email as the user identifier; preserve existing name if available.
      _storage.userId = email;
      _storage.userEmail = email;
      // Keep existing userName if already set (e.g. from registration)
      if (_storage.userName == null || _storage.userName!.isEmpty) {
        _storage.userName = email.split('@').first;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: email,
        userName: _storage.userName,
        userEmail: email,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _networkMessage(e, fallback: 'Login failed. Please try again.'),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Login failed. Please check your connection.',
      );
    }
  }

  void updateProfile({String? name, String? email}) {
    state = state.copyWith(
      userName: name ?? state.userName,
      userEmail: email ?? state.userEmail,
    );
  }

  Future<void> logout() async {
    await clearToken();
    await _storage.clearAuth();
    _storage.onboardingComplete = false;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Build a user-friendly error message from a [DioException].
  String _networkMessage(DioException e, {String fallback = 'Something went wrong.'}) {
    // Connection-level errors (no response from server)
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return 'Server is taking too long to respond. It may be waking up from sleep — please try again in 30 seconds.';
    }
    // Server responded with an error
    final statusCode = e.response?.statusCode;
    final detail = e.response?.data is Map
        ? e.response!.data['detail'] as String?
        : null;
    if (statusCode == 401) {
      return detail ?? 'Invalid email or password.';
    } else if (statusCode == 422) {
      return detail ?? 'Please check the information you entered.';
    } else if (statusCode != null && statusCode >= 500) {
      return 'Server error ($statusCode). Please try again in a moment.';
    }
    return detail ?? fallback;
  }
}

/// Main auth state provider.
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageProvider);
  return AuthNotifier(api, storage);
});
