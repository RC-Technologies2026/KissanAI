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

      // Demo mode: backend returned offline mock — authenticate locally.
      if (data is Map && data['error'] == 'offline') {
        final demoId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
        await saveToken('demo_token');
        _storage.userId = demoId;
        _storage.userName = name;
        _storage.userEmail = email;
        state = state.copyWith(
          status: AuthStatus.authenticated,
          userId: demoId,
          userName: name,
          userEmail: email,
        );
        return;
      }

      final token = data['token'] as String;
      final userId = data['user_id'] as String;

      await saveToken(token);
      _storage.userId = userId;
      _storage.userName = name;
      _storage.userEmail = email;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: userId,
        userName: name,
        userEmail: email,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
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

      // Demo mode: backend returned offline mock — authenticate locally.
      if (data is Map && data['error'] == 'offline') {
        final demoId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
        final name = email.split('@').first;
        await saveToken('demo_token');
        _storage.userId = demoId;
        _storage.userName = name;
        _storage.userEmail = email;
        state = state.copyWith(
          status: AuthStatus.authenticated,
          userId: demoId,
          userName: name,
          userEmail: email,
        );
        return;
      }

      final token = data['token'] as String;
      final userId = data['user_id'] as String;
      final name = data['name'] as String? ?? '';

      await saveToken(token);
      _storage.userId = userId;
      _storage.userName = name;
      _storage.userEmail = email;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: userId,
        userName: name,
        userEmail: email,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
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
}

/// Main auth state provider.
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageProvider);
  return AuthNotifier(api, storage);
});
