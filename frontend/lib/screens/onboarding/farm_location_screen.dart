import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/cascading_dropdown.dart';

/// District/city data for cascading dropdowns.
/// Defaults to Punjab > Faisalabad > Faisalabad City.
class _LocationData {
  static const Map<String, Map<String, List<String>>> data = {
    'Punjab': {
      'Faisalabad': ['Faisalabad City', 'Jaranwala', 'Sammundri'],
      'Lahore': ['Lahore City', 'Muridke', 'Kahna Nau'],
      'Multan': ['Multan City', 'Shujabad', 'Jalalpur Pirwala'],
      'Rawalpindi': ['Rawalpindi City', 'Gujar Khan', 'Taxila'],
    },
    'Sindh': {
      'Karachi': ['Karachi City', 'Korangi', 'Malir'],
      'Hyderabad': ['Hyderabad City', 'Latifabad', 'Qasimabad'],
      'Sukkur': ['Sukkur City', 'Rohri', 'Pano Aqil'],
    },
    'Khyber Pakhtunkhwa': {
      'Peshawar': ['Peshawar City', 'Charsadda', 'Nowshera'],
      'Mardan': ['Mardan City', 'Swabi', 'Takht-i-Bahi'],
      'Abbottabad': ['Abbottabad City', 'Mansehra', 'Haripur'],
    },
    'Balochistan': {
      'Quetta': ['Quetta City', 'Mastung', 'Pishin'],
      'Gwadar': ['Gwadar City', 'Ormara', 'Pasni'],
    },
    'Gilgit-Baltistan': {
      'Gilgit': ['Gilgit City', 'Skardu', 'Hunza'],
    },
    'Azad Kashmir': {
      'Muzaffarabad': ['Muzaffarabad City', 'Mirpur', 'Bhimber'],
    },
    'Islamabad': {
      'Islamabad': ['Islamabad City', 'Bani Gala', 'Bharakahu'],
    },
  };
}

/// Step 1 — Farm Location (Province → District → City/Tehsil).
class FarmLocationScreen extends ConsumerStatefulWidget {
  const FarmLocationScreen({super.key});

  @override
  ConsumerState<FarmLocationScreen> createState() =>
      _FarmLocationScreenState();
}

class _FarmLocationScreenState extends ConsumerState<FarmLocationScreen> {
  String _province = 'Punjab';
  String _district = 'Faisalabad';
  String _city = 'Faisalabad City';

  @override
  Widget build(BuildContext context) {
    final provinces = _LocationData.data.keys.toList();
    final districts =
        _LocationData.data[_province]?.keys.toList() ?? [];
    final cities =
        _LocationData.data[_province]?[_district] ?? [];

    return OnboardingScaffold(
      currentStep: 1,
      title: 'Where is your farm\nlocated?',
      showSkipLink: true,
      onSkip: () => context.go(Routes.dashboard),
      canContinue: true, // defaults are pre-filled
      onBack: () => context.go(Routes.register),
      onContinue: () {
        ref.read(onboardingProvider.notifier).setLocation(
              province: _province,
              district: _district,
              city: _city,
            );
        ref.read(onboardingProvider.notifier).nextStep();
        context.go(Routes.onboardingLanguage);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select your province, district, and city/tehsil.',
            style: TextStyle(fontSize: 15, color: AppColors.bodyText),
          ),
          const SizedBox(height: 28),

          CascadingDropdown(
            label: 'Province',
            value: _province,
            items: provinces,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _province = v;
                final newDistricts =
                    _LocationData.data[v]?.keys.toList() ?? [];
                _district =
                    newDistricts.isNotEmpty ? newDistricts.first : '';
                final newCities =
                    _LocationData.data[v]?[_district] ?? [];
                _city = newCities.isNotEmpty ? newCities.first : '';
              });
            },
          ),
          const SizedBox(height: 20),

          CascadingDropdown(
            label: 'District',
            value: _district,
            items: districts,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _district = v;
                final newCities =
                    _LocationData.data[_province]?[v] ?? [];
                _city = newCities.isNotEmpty ? newCities.first : '';
              });
            },
          ),
          const SizedBox(height: 20),

          CascadingDropdown(
            label: 'City / Tehsil',
            value: _city,
            items: cities,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _city = v);
            },
          ),
        ],
      ),
    );
  }
}
