import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks onboarding form data across the steps.
/// Step indices: 1=Location, 2=Language, 3=FarmerType, 4=Crops, 5=Livestock, 6=FarmSize
/// (Index 0 = Welcome, which has no progress bar.)
class OnboardingState {
  const OnboardingState({
    this.currentStep = 1,
    this.province,
    this.district,
    this.city,
    this.language,
    this.farmerType,
    this.selectedCrops = const [],
    this.selectedLivestock = const [],
    this.farmSize = 0,
    this.sizeUnit = 'Acres',
    this.isSubmitting = false,
    this.error,
  });

  final int currentStep;
  final String? province;
  final String? district;
  final String? city;
  final String? language;
  final String? farmerType;
  final List<String> selectedCrops;
  final List<String> selectedLivestock;
  final double farmSize;
  final String sizeUnit;
  final bool isSubmitting;
  final String? error;

  OnboardingState copyWith({
    int? currentStep,
    String? province,
    String? district,
    String? city,
    String? language,
    String? farmerType,
    List<String>? selectedCrops,
    List<String>? selectedLivestock,
    double? farmSize,
    String? sizeUnit,
    bool? isSubmitting,
    String? error,
  }) =>
      OnboardingState(
        currentStep: currentStep ?? this.currentStep,
        province: province ?? this.province,
        district: district ?? this.district,
        city: city ?? this.city,
        language: language ?? this.language,
        farmerType: farmerType ?? this.farmerType,
        selectedCrops: selectedCrops ?? this.selectedCrops,
        selectedLivestock: selectedLivestock ?? this.selectedLivestock,
        farmSize: farmSize ?? this.farmSize,
        sizeUnit: sizeUnit ?? this.sizeUnit,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: error,
      );

  /// Build the JSON payload for `POST /api/onboarding/submit`.
  Map<String, dynamic> toPayload() => {
        'province': province,
        'district': district,
        'city': city,
        'language': language,
        'farmer_type': farmerType,
        'farm_size': farmSize,
        'size_unit': sizeUnit.toLowerCase(),
        'crops': selectedCrops,
        'livestock': selectedLivestock,
      };

  /// Whether the current step has enough data to proceed.
  bool get canContinue {
    switch (currentStep) {
      case 1:
        return province != null && district != null && city != null;
      case 2:
        return language != null;
      case 3:
        return farmerType != null;
      case 4:
        return selectedCrops.isNotEmpty;
      case 5:
        return selectedLivestock.isNotEmpty;
      case 6:
        return farmSize > 0;
      default:
        return false;
    }
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void nextStep() {
    if (state.currentStep < 6 && state.canContinue) {
      state = state.copyWith(currentStep: state.currentStep + 1, error: null);
    }
  }

  void previousStep() {
    if (state.currentStep > 1) {
      state = state.copyWith(currentStep: state.currentStep - 1, error: null);
    }
  }

  void goToStep(int step) =>
      state = state.copyWith(currentStep: step, error: null);

  void setLocation({String? province, String? district, String? city}) =>
      state = state.copyWith(
        province: province,
        district: district,
        city: city,
      );

  void setLanguage(String language) =>
      state = state.copyWith(language: language);

  void setFarmerType(String type) =>
      state = state.copyWith(farmerType: type);

  void toggleCrop(String crop) {
    final list = List<String>.from(state.selectedCrops);
    list.contains(crop) ? list.remove(crop) : list.add(crop);
    state = state.copyWith(selectedCrops: list);
  }

  void toggleLivestock(String animal) {
    final list = List<String>.from(state.selectedLivestock);
    list.contains(animal) ? list.remove(animal) : list.add(animal);
    state = state.copyWith(selectedLivestock: list);
  }

  void setFarmSize(double size) =>
      state = state.copyWith(farmSize: size);

  void setSizeUnit(String unit) =>
      state = state.copyWith(sizeUnit: unit);

  void setSubmitting(bool v) =>
      state = state.copyWith(isSubmitting: v, error: null);

  void setError(String msg) =>
      state = state.copyWith(isSubmitting: false, error: msg);

  void reset() => state = const OnboardingState();
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
