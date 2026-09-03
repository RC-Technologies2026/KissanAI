import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/dio_client.dart';
import '../core/storage/local_storage.dart';
import '../core/utils/error_handler.dart';
import 'core_providers.dart';

/// Auth state — authenticated / unauthenticated / loading.
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.profileImageUrl,
    this.farmName,
    this.farmLocation,
    this.province,
    this.district,
    this.city,
    this.farmSize,
    this.farmSizeUnit,
    this.farmerType,
    this.error,
  });

  final AuthStatus status;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? profileImageUrl;
  final String? farmName;
  final String? farmLocation;
  final String? province;
  final String? district;
  final String? city;
  final double? farmSize;
  final String? farmSizeUnit;
  final String? farmerType;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? profileImageUrl,
    String? farmName,
    String? farmLocation,
    String? province,
    String? district,
    String? city,
    double? farmSize,
    String? farmSizeUnit,
    String? farmerType,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        userEmail: userEmail ?? this.userEmail,
        userPhone: userPhone ?? this.userPhone,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        farmName: farmName ?? this.farmName,
        farmLocation: farmLocation ?? this.farmLocation,
        province: province ?? this.province,
        district: district ?? this.district,
        city: city ?? this.city,
        farmSize: farmSize ?? this.farmSize,
        farmSizeUnit: farmSizeUnit ?? this.farmSizeUnit,
        farmerType: farmerType ?? this.farmerType,
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
      // Fetch profile from backend to get latest data
      await _fetchProfile();
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await _api.getProfile();
      final data = res.data;
      final userId = data['id']?.toString() ?? _storage.userId ?? '';
      final userName = data['full_name'] as String? ?? _storage.userName;
      final userEmail = data['email'] as String? ?? _storage.userEmail;
      final userPhone = data['phone'] as String? ?? _storage.userPhone;
      final profileImageUrl = data['profile_image_url'] as String?;
      final farmName = data['farm_name'] as String?;
      final farmLocation = data['farm_location'] as String?;
      final province = data['province'] as String?;
      final district = data['district'] as String?;
      final city = data['city'] as String?;
      final farmSize = (data['farm_size'] as num?)?.toDouble();
      final farmSizeUnit = data['farm_size_unit'] as String?;
      final farmerType = data['farmer_type'] as String?;

      _storage.userId = userId;
      _storage.userName = userName;
      _storage.userEmail = userEmail;
      if (userPhone != null) _storage.userPhone = userPhone;
      if (profileImageUrl != null) _storage.profileImageUrl = profileImageUrl;
      if (farmName != null) _storage.farmName = farmName;
      if (farmLocation != null) _storage.farmLocation = farmLocation;
      if (province != null) _storage.farmProvince = province;
      if (district != null) _storage.farmDistrict = district;
      if (city != null) _storage.farmCity = city;
      if (farmSize != null) _storage.farmSize = farmSize;
      if (farmSizeUnit != null) _storage.farmSizeUnit = farmSizeUnit;
      if (farmerType != null) _storage.farmerType = farmerType;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        profileImageUrl: profileImageUrl,
        farmName: farmName,
        farmLocation: farmLocation,
        province: province,
        district: district,
        city: city,
        farmSize: farmSize,
        farmSizeUnit: farmSizeUnit,
        farmerType: farmerType,
      );
    } catch (e) {
      debugPrint('Failed to fetch profile: $e');
      // Use cached data if fetch fails
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: _storage.userId,
        userName: _storage.userName,
        userEmail: _storage.userEmail,
        userPhone: _storage.userPhone,
        profileImageUrl: _storage.profileImageUrl,
        farmName: _storage.farmName,
        farmLocation: _storage.farmLocation,
        province: _storage.farmProvince,
        district: _storage.farmDistrict,
        city: _storage.farmCity,
        farmSize: _storage.farmSize,
        farmSizeUnit: _storage.farmSizeUnit,
        farmerType: _storage.farmerType,
      );
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
        final refreshToken = loginData['refresh_token'] as String?;
        await saveToken(token);
        if (refreshToken != null) await saveRefreshToken(refreshToken);
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
        userPhone: phone,
      );

      // Fetch full profile from backend
      await _fetchProfile();
    } on DioException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: AppError.fromException(e),
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: AppError.fromException(e),
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

      // Backend returns Token: {access_token, refresh_token, token_type}
      final token = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String?;

      await saveToken(token);
      if (refreshToken != null) await saveRefreshToken(refreshToken);

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

      // Fetch full profile from backend
      await _fetchProfile();
    } on DioException catch (e) {
      // Special case for login: show "Invalid email or password" for 401
      final msg = (e.response?.statusCode == 401)
          ? 'Invalid email or password.'
          : AppError.fromException(e);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: msg,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: AppError.fromException(e),
      );
    }
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
    String? farmName,
    String? farmLocation,
    String? province,
    String? district,
    String? city,
    double? farmSize,
    String? farmSizeUnit,
    String? farmerType,
  }) async {
    // Update local state immediately for responsive UI
    state = state.copyWith(
      userName: name ?? state.userName,
      userEmail: email ?? state.userEmail,
      userPhone: phone ?? state.userPhone,
      profileImageUrl: profileImageUrl ?? state.profileImageUrl,
      farmName: farmName ?? state.farmName,
      farmLocation: farmLocation ?? state.farmLocation,
      province: province ?? state.province,
      district: district ?? state.district,
      city: city ?? state.city,
      farmSize: farmSize ?? state.farmSize,
      farmSizeUnit: farmSizeUnit ?? state.farmSizeUnit,
      farmerType: farmerType ?? state.farmerType,
    );

    // Save to local storage
    if (name != null) _storage.userName = name;
    if (email != null) _storage.userEmail = email;
    if (phone != null) _storage.userPhone = phone;
    if (profileImageUrl != null) _storage.profileImageUrl = profileImageUrl;
    if (farmName != null) _storage.farmName = farmName;
    if (farmLocation != null) _storage.farmLocation = farmLocation;
    if (province != null) _storage.farmProvince = province;
    if (district != null) _storage.farmDistrict = district;
    if (city != null) _storage.farmCity = city;
    if (farmSize != null) _storage.farmSize = farmSize;
    if (farmSizeUnit != null) _storage.farmSizeUnit = farmSizeUnit;
    if (farmerType != null) _storage.farmerType = farmerType;

    // Sync to backend
    try {
      await _api.updateProfile(
        fullName: name,
        phone: phone,
        farmName: farmName,
        farmLocation: farmLocation,
        province: province,
        district: district,
        city: city,
        farmSize: farmSize,
        farmSizeUnit: farmSizeUnit,
        farmerType: farmerType,
      );
    } catch (e) {
      debugPrint('Failed to update profile on backend: $e');
    }
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
