import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/data/pakistan_locations.dart';
import '../core/storage/local_storage.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/onboarding_provider.dart';
import '../router/app_router.dart';
import '../widgets/pill_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/cascading_dropdown.dart';

/// Registration screen — account info + farm details in one flow.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _lastError;

  // Farm details
  String _province = 'Punjab';
  String _district = 'Faisalabad';
  String _city = 'Faisalabad City';
  double _farmSize = 5;
  String _sizeUnit = 'Acres';

  // Use comprehensive Pakistan location data
  final _locationData = PakistanLocations.data;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Clear previous error so the listener can fire again
    _lastError = null;

    // Save farm details to onboarding provider
    final onboarding = ref.read(onboardingProvider.notifier);
    onboarding.setLocation(
      province: _province,
      district: _district,
      city: _city,
    );
    onboarding.setLanguage('Urdu');
    onboarding.setFarmSize(_farmSize);
    onboarding.setSizeUnit(_sizeUnit);

    // Save farm details to local storage
    final storage = LocalStorage.instance;
    storage.farmProvince = _province;
    storage.farmDistrict = _district;
    storage.farmCity = _city;
    storage.farmSize = _farmSize;
    storage.farmSizeUnit = _sizeUnit;

    await ref.read(authProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final lang = ref.watch(languageProvider);

    // Navigate to dashboard on success
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.authenticated) {
        // Mark onboarding as complete since farm details are captured here
        LocalStorage.instance.onboardingComplete = true;
        // Use context.go() — GoRouter's redirect guard handles route protection.
        if (context.mounted) {
          context.go(Routes.dashboard);
        }
      } else if (next.status == AuthStatus.unauthenticated &&
          next.error != null &&
          next.error != _lastError) {
        _lastError = next.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor:
                next.error!.contains('successful') ? Colors.green.shade700 : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final provinces = _locationData.keys.toList();
    final districts = _locationData[_province]?.keys.toList() ?? [];
    final cities = _locationData[_province]?[_district] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go(Routes.welcome),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  lang.t('auth.create_account'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.t('auth.signup_hint'),
                  style: const TextStyle(fontSize: 15, color: AppColors.bodyText),
                ),
                const SizedBox(height: 28),

                // ── Account Details ──────────────────────────
                Text(
                  lang.t('edit_profile.personal_info'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _nameCtrl,
                  label: lang.t('auth.full_name'),
                  hint: lang.t('auth.name_hint'),
                  prefixIcon: Icons.person_outline,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? lang.t('auth.required') : null,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _phoneCtrl,
                  label: lang.t('auth.phone'),
                  hint: lang.t('auth.phone_hint'),
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().length < 10
                          ? lang.t('auth.valid_phone')
                          : null,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _emailCtrl,
                  label: lang.t('auth.email'),
                  hint: lang.t('auth.email_hint'),
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || !v.contains('@') ? lang.t('auth.valid_email') : null,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _passCtrl,
                  label: lang.t('auth.password'),
                  hint: lang.t('auth.password_hint'),
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != null && v.length >= 8
                      ? null
                      : lang.t('auth.password_length'),
                ),
                const SizedBox(height: 28),

                // ── Farm Details ─────────────────────────────
                Text(
                  lang.t('edit_profile.farm_details'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 16),

                CascadingDropdown(
                  label: lang.t('farm.province'),
                  value: _province,
                  items: provinces,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _province = v;
                      final newDistricts =
                          _locationData[v]?.keys.toList() ?? [];
                      _district =
                          newDistricts.isNotEmpty ? newDistricts.first : '';
                      final newCities =
                          _locationData[v]?[_district] ?? [];
                      _city = newCities.isNotEmpty ? newCities.first : '';
                    });
                  },
                ),
                const SizedBox(height: 16),

                CascadingDropdown(
                  label: lang.t('farm.district'),
                  value: _district,
                  items: districts,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _district = v;
                      final newCities =
                          _locationData[_province]?[v] ?? [];
                      _city = newCities.isNotEmpty ? newCities.first : '';
                    });
                  },
                ),
                const SizedBox(height: 16),

                CascadingDropdown(
                  label: lang.t('farm.city'),
                  value: _city,
                  items: cities,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _city = v);
                  },
                ),
                const SizedBox(height: 20),

                // Farm size
                Text(
                  lang.t('farm.size'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 12),

                // Unit selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: OnboardingData.sizeUnits.map((unit) {
                    final isSelected = _sizeUnit == unit;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _sizeUnit = unit),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            unit,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.headingText,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Size display + stepper
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stepButton(
                      icon: Icons.remove,
                      onPressed: _farmSize > 0
                          ? () => setState(
                              () => _farmSize = (_farmSize - 0.5).clamp(0, 9999))
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        Text(
                          _farmSize.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          _sizeUnit.toLowerCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    _stepButton(
                      icon: Icons.add,
                      onPressed: () => setState(
                          () => _farmSize = (_farmSize + 0.5).clamp(0, 9999)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                PillButton(
                  label: lang.t('auth.create_account'),
                  isLoading: authState.status == AuthStatus.loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () => context.go(Routes.login),
                    child: Text(lang.t('auth.have_account')),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepButton({required IconData icon, VoidCallback? onPressed}) {
    return Material(
      color: onPressed == null ? AppColors.divider : AppColors.primary,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
