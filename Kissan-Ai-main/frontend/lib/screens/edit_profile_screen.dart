import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/data/pakistan_locations.dart';
import '../core/storage/local_storage.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_text_field.dart';
import '../widgets/cascading_dropdown.dart';
import '../widgets/pill_button.dart';

/// Edit Profile screen — fully editable personal and farm details.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _farmNameCtrl;
  late TextEditingController _farmLocationCtrl;

  // Farm details
  String _province = 'Punjab';
  String _district = 'Faisalabad';
  String _city = 'Faisalabad City';
  double _farmSize = 5;
  String _sizeUnit = 'Acres';
  String _farmerType = 'Experienced Farmer';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final storage = LocalStorage.instance;
    final auth = ref.read(authProvider);

    // Personal details
    _nameCtrl = TextEditingController(text: auth.userName ?? '');
    _phoneCtrl = TextEditingController(text: storage.userPhone ?? '');
    _emailCtrl = TextEditingController(text: auth.userEmail ?? '');

    // Farm details
    _farmNameCtrl = TextEditingController(text: storage.farmName ?? '');
    _farmLocationCtrl = TextEditingController(text: storage.farmLocation ?? '');
    _province = storage.farmProvince ?? 'Punjab';
    _district = storage.farmDistrict ?? 'Faisalabad';
    _city = storage.farmCity ?? 'Faisalabad City';
    _farmSize = storage.farmSize > 0 ? storage.farmSize : 5;
    _sizeUnit = storage.farmSizeUnit;
    _farmerType = storage.farmerType ?? 'Experienced Farmer';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _farmNameCtrl.dispose();
    _farmLocationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final storage = LocalStorage.instance;

    // Save personal details
    storage.userName = _nameCtrl.text.trim();
    storage.userEmail = _emailCtrl.text.trim();
    storage.userPhone = _phoneCtrl.text.trim();

    // Save farm details
    storage.farmName = _farmNameCtrl.text.trim();
    storage.farmLocation = _farmLocationCtrl.text.trim();
    storage.farmProvince = _province;
    storage.farmDistrict = _district;
    storage.farmCity = _city;
    storage.farmSize = _farmSize;
    storage.farmSizeUnit = _sizeUnit;
    storage.farmerType = _farmerType;

    // Update Riverpod auth state
    ref.read(authProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
        );

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provinces = PakistanLocations.provinces;
    final districts = PakistanLocations.districtsOf(_province);
    final cities = PakistanLocations.citiesOf(_province, _district);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.headingText),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Avatar section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (_nameCtrl.text.isNotEmpty)
                              ? _nameCtrl.text.trim()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Personal Information ─────────────────────────
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 16),

              // Full Name
              AppTextField(
                controller: _nameCtrl,
                label: 'Full Name',
                hint: 'Enter your full name',
                prefixIcon: Icons.person_outline,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Phone
              AppTextField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                hint: '03XX XXXXXXX',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().length < 10
                        ? 'Enter a valid phone number'
                        : null,
              ),
              const SizedBox(height: 16),

              // Email
              AppTextField(
                controller: _emailCtrl,
                label: 'Email',
                hint: 'you@example.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 28),

              // ── Farm Details ─────────────────────────────────
              const Text(
                'Farm Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 16),

              // Farm Name
              AppTextField(
                controller: _farmNameCtrl,
                label: 'Farm Name',
                hint: 'e.g., Green Valley Farm',
                prefixIcon: Icons.agriculture_outlined,
              ),
              const SizedBox(height: 16),

              // Farmer Type
              const Text(
                'Farmer Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _farmerType,
                    isExpanded: true,
                    items: ['New Farmer', 'Experienced Farmer', 'Commercial Farmer']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _farmerType = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Province
              CascadingDropdown(
                label: 'Province',
                value: _province,
                items: provinces,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _province = v;
                    final newDistricts = PakistanLocations.districtsOf(v);
                    _district = newDistricts.isNotEmpty ? newDistricts.first : '';
                    final newCities = PakistanLocations.citiesOf(v, _district);
                    _city = newCities.isNotEmpty ? newCities.first : '';
                  });
                },
              ),
              const SizedBox(height: 16),

              // District
              CascadingDropdown(
                label: 'District',
                value: _district,
                items: districts,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _district = v;
                    final newCities = PakistanLocations.citiesOf(_province, v);
                    _city = newCities.isNotEmpty ? newCities.first : '';
                  });
                },
              ),
              const SizedBox(height: 16),

              // City
              CascadingDropdown(
                label: 'City / Tehsil',
                value: _city,
                items: cities,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _city = v);
                },
              ),
              const SizedBox(height: 16),

              // Farm Location (GPS coordinates or address)
              AppTextField(
                controller: _farmLocationCtrl,
                label: 'Farm Location (GPS or Address)',
                hint: 'e.g., 31.4504, 73.1350 or Main Road, Faisalabad',
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 20),

              // Farm Size
              const Text(
                'Farm Size',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 12),

              // Unit selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['Acres', 'Kanal', 'Hectares'].map((unit) {
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

              // Save button
              PillButton(
                label: 'Save Changes',
                isLoading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 16),

              // Cancel
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.bodyText),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
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
