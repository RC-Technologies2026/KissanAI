import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

/// Thin wrapper around Hive boxes used across the app.
class LocalStorage {
  LocalStorage._();

  static final LocalStorage instance = LocalStorage._();

  late Box _authBox;
  late Box _settingsBox;
  late Box _onboardingBox;

  /// Initialise all Hive boxes. Call once at startup.
  Future<void> init() async {
    await Hive.initFlutter();
    _authBox = await Hive.openBox(HiveBoxes.authBox);
    _settingsBox = await Hive.openBox(HiveBoxes.settingsBox);
    _onboardingBox = await Hive.openBox(HiveBoxes.onboardingBox);
  }

  // ─── Auth box ────────────────────────────────────────────

  String? get userId => _authBox.get(HiveKeys.userId) as String?;
  set userId(String? v) => v == null ? _authBox.delete(HiveKeys.userId) : _authBox.put(HiveKeys.userId, v);

  String? get userName => _authBox.get(HiveKeys.userName) as String?;
  set userName(String? v) => v == null ? _authBox.delete(HiveKeys.userName) : _authBox.put(HiveKeys.userName, v);

  String? get userEmail => _authBox.get(HiveKeys.userEmail) as String?;
  set userEmail(String? v) => v == null ? _authBox.delete(HiveKeys.userEmail) : _authBox.put(HiveKeys.userEmail, v);

  String? get userPhone => _authBox.get(HiveKeys.userPhone) as String?;
  set userPhone(String? v) => v == null ? _authBox.delete(HiveKeys.userPhone) : _authBox.put(HiveKeys.userPhone, v);

  // ─── Farm details ──────────────────────────────────────────

  String? get farmName => _authBox.get(HiveKeys.farmName) as String?;
  set farmName(String? v) => v == null ? _authBox.delete(HiveKeys.farmName) : _authBox.put(HiveKeys.farmName, v);

  String? get farmProvince => _authBox.get(HiveKeys.farmProvince) as String?;
  set farmProvince(String? v) => v == null ? _authBox.delete(HiveKeys.farmProvince) : _authBox.put(HiveKeys.farmProvince, v);

  String? get farmDistrict => _authBox.get(HiveKeys.farmDistrict) as String?;
  set farmDistrict(String? v) => v == null ? _authBox.delete(HiveKeys.farmDistrict) : _authBox.put(HiveKeys.farmDistrict, v);

  String? get farmCity => _authBox.get(HiveKeys.farmCity) as String?;
  set farmCity(String? v) => v == null ? _authBox.delete(HiveKeys.farmCity) : _authBox.put(HiveKeys.farmCity, v);

  double get farmSize => (_authBox.get(HiveKeys.farmSize) as num?)?.toDouble() ?? 0.0;
  set farmSize(double v) => _authBox.put(HiveKeys.farmSize, v);

  String get farmSizeUnit => _authBox.get(HiveKeys.farmSizeUnit, defaultValue: 'Acres') as String;
  set farmSizeUnit(String v) => _authBox.put(HiveKeys.farmSizeUnit, v);

  String? get farmLocation => _authBox.get(HiveKeys.farmLocation) as String?;
  set farmLocation(String? v) => v == null ? _authBox.delete(HiveKeys.farmLocation) : _authBox.put(HiveKeys.farmLocation, v);

  String? get farmerType => _authBox.get(HiveKeys.farmerType) as String?;
  set farmerType(String? v) => v == null ? _authBox.delete(HiveKeys.farmerType) : _authBox.put(HiveKeys.farmerType, v);

  double? get farmLat {
    final v = _authBox.get(HiveKeys.farmLat);
    return v != null ? (v as num).toDouble() : null;
  }
  set farmLat(double? v) => v == null ? _authBox.delete(HiveKeys.farmLat) : _authBox.put(HiveKeys.farmLat, v);

  double? get farmLon {
    final v = _authBox.get(HiveKeys.farmLon);
    return v != null ? (v as num).toDouble() : null;
  }
  set farmLon(double? v) => v == null ? _authBox.delete(HiveKeys.farmLon) : _authBox.put(HiveKeys.farmLon, v);

  Future<void> clearAuth() => _authBox.clear();

  // ─── Settings box ────────────────────────────────────────

  String get language => _settingsBox.get(HiveKeys.language, defaultValue: 'English') as String;
  set language(String v) => _settingsBox.put(HiveKeys.language, v);

  bool get notificationsEnabled =>
      _settingsBox.get(HiveKeys.notificationsEnabled, defaultValue: true) as bool;
  set notificationsEnabled(bool v) =>
      _settingsBox.put(HiveKeys.notificationsEnabled, v);

  // ─── Onboarding box ──────────────────────────────────────

  bool get onboardingComplete =>
      _onboardingBox.get(HiveKeys.onboardingComplete, defaultValue: false) as bool;
  set onboardingComplete(bool v) =>
      _onboardingBox.put(HiveKeys.onboardingComplete, v);

  /// Save a draft of onboarding data so the user can resume.
  void saveOnboardingDraft(Map<String, dynamic> data) =>
      _onboardingBox.put('draft', data);

  Map<String, dynamic>? get onboardingDraft =>
      _onboardingBox.get('draft') as Map<String, dynamic>?;

  Future<void> clearOnboardingDraft() => _onboardingBox.delete('draft');
}
