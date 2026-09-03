import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../providers/core_providers.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// A single plant owned by the user.
class PlantData {
  const PlantData({
    required this.id,
    required this.userId,
    required this.plantName,
    this.species,
    this.imageUrl,
    this.healthStatus,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String plantName;
  final String? species;
  final String? imageUrl;
  final String? healthStatus;
  final String? notes;
  final DateTime? createdAt;

  factory PlantData.fromMap(Map data) => PlantData(
        id: data['id']?.toString() ?? '',
        userId: data['user_id']?.toString() ?? '',
        plantName: data['plant_name']?.toString() ?? '',
        species: data['species']?.toString(),
        imageUrl: data['image_url']?.toString(),
        healthStatus: data['health_status']?.toString(),
        notes: data['notes']?.toString(),
        createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '')?.toLocal(),
      );
}

/// Parsed result of a plant diagnosis (/api/plants/{id}/diagnose).
class PlantDiagnosisData {
  const PlantDiagnosisData({
    required this.plantId,
    this.diagnosisId,
    this.imageId,
    required this.issueName,
    this.issueCategory,
    this.confidence,
    this.diagnosis,
    this.detectedAt,
    this.sections = const [],
  });

  final String plantId;
  final String? diagnosisId;
  final String? imageId;
  final String issueName;
  final String? issueCategory;
  final double? confidence;
  final String? diagnosis;
  final DateTime? detectedAt;

  /// Symptoms / Treatment blocks parsed from the diagnosis markdown.
  final List<PlantDiagnosisSection> sections;
}

/// One titled block parsed out of the backend's `diagnosis` markdown.
class PlantDiagnosisSection {
  const PlantDiagnosisSection({required this.title, required this.body});
  final String title;
  final String body;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum PlantStatus { idle, loadingPlants, loadingDiagnosis, success, failure }

class PlantState {
  const PlantState({
    this.status = PlantStatus.idle,
    this.plants = const [],
    this.diagnosisResult,
    this.errorMessage,
  });

  final PlantStatus status;
  final List<PlantData> plants;
  final PlantDiagnosisData? diagnosisResult;
  final String? errorMessage;

  PlantState copyWith({
    PlantStatus? status,
    List<PlantData>? plants,
    PlantDiagnosisData? diagnosisResult,
    String? errorMessage,
    bool clearDiagnosis = false,
  }) =>
      PlantState(
        status: status ?? this.status,
        plants: plants ?? this.plants,
        diagnosisResult: clearDiagnosis ? null : (diagnosisResult ?? this.diagnosisResult),
        errorMessage: errorMessage,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the Plant feature state — listing plants, creating plants, and
/// running plant diagnosis via the /api/plants endpoints.
class PlantNotifier extends StateNotifier<PlantState> {
  PlantNotifier(this._api) : super(const PlantState());

  final ApiClient _api;

  /// Fetch all plants for the current user.
  Future<void> loadPlants() async {
    state = state.copyWith(status: PlantStatus.loadingPlants);
    try {
      final res = await _api.getPlants();
      final data = res.data;
      if (data is List) {
        final plants = data
            .whereType<Map>()
            .map((m) => PlantData.fromMap(m))
            .toList();
        state = state.copyWith(status: PlantStatus.idle, plants: plants);
      } else {
        state = state.copyWith(
          status: PlantStatus.failure,
          errorMessage: 'Unexpected response from the server.',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        status: PlantStatus.failure,
        errorMessage: _friendlyError(e),
      );
    } catch (_) {
      state = state.copyWith(
        status: PlantStatus.failure,
        errorMessage: 'Could not load plants. Please try again.',
      );
    }
  }

  /// Create a new plant and prepend it to the list.
  Future<bool> createPlant({
    required String plantName,
    String? species,
    String? notes,
  }) async {
    try {
      final res = await _api.createPlant(
        plantName: plantName,
        species: species,
        notes: notes,
      );
      final data = res.data;
      if (data is Map) {
        final plant = PlantData.fromMap(data);
        state = state.copyWith(plants: [plant, ...state.plants]);
        return true;
      }
    } on DioException catch (e) {
      state = state.copyWith(
        status: PlantStatus.failure,
        errorMessage: _friendlyError(e),
      );
    } catch (_) {
      state = state.copyWith(
        status: PlantStatus.failure,
        errorMessage: 'Could not create plant. Please try again.',
      );
    }
    return false;
  }

  /// Run diagnosis on a plant by uploading an image.
  Future<void> diagnosePlant({
    required String plantId,
    required String filePath,
    String language = 'english',
  }) async {
    state = state.copyWith(
      status: PlantStatus.loadingDiagnosis,
      clearDiagnosis: true,
    );
    try {
      final res = await _api.diagnosePlant(plantId, filePath, language: language);
      final data = res.data;

      if (data is Map && data['error'] == 'offline') {
        state = state.copyWith(
          status: PlantStatus.failure,
          errorMessage: 'Internet connection error. Please check your network.',
        );
        return;
      }
      if (data is! Map) {
        state = state.copyWith(
          status: PlantStatus.failure,
          errorMessage: 'Unexpected response from the server.',
        );
        return;
      }

      state = PlantState(
        status: PlantStatus.success,
        plants: state.plants,
        diagnosisResult: _parseDiagnosis(plantId, data),
      );
    } on DioException catch (e) {
      state = state.copyWith(
        status: PlantStatus.failure,
        errorMessage: _friendlyError(e),
      );
    } catch (_) {
      state = state.copyWith(
        status: PlantStatus.failure,
        errorMessage: 'Could not analyze the photo. Please try again.',
      );
    }
  }

  void reset() => state = const PlantState();

  // ── Helpers ──────────────────────────────────────────────

  String _friendlyError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Server is taking too long. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach server. Please check your internet connection.';
    }
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please login again.';
    }
    if (e.response?.statusCode != null && e.response!.statusCode! >= 500) {
      return 'Server error. Please try again later.';
    }
    return e.message ?? 'An unexpected error occurred.';
  }

  PlantDiagnosisData _parseDiagnosis(String plantId, Map data) {
    final sections = _parseMarkdown(data['diagnosis']?.toString() ?? '');

    var issueName = data['issue_name']?.toString() ?? '';
    if (issueName.isEmpty) {
      for (final s in sections) {
        if (s.title.toLowerCase().contains('diagnosis')) {
          issueName = s.body.replaceAll('\n', ' ').trim();
          break;
        }
      }
    }
    if (issueName.isEmpty) issueName = 'Plant Issue Diagnosis';

    final rawConfidence = data['confidence_score'];
    double? confidence;
    if (rawConfidence != null) {
      confidence = double.tryParse(rawConfidence.toString());
      if (confidence != null) {
        if (confidence > 1) confidence /= 100;
        confidence = confidence.clamp(0.0, 1.0);
      }
    }

    return PlantDiagnosisData(
      plantId: plantId,
      diagnosisId: data['id']?.toString(),
      imageId: data['image_id']?.toString(),
      issueName: issueName,
      issueCategory: data['issue_category']?.toString(),
      confidence: confidence,
      diagnosis: data['diagnosis']?.toString(),
      detectedAt: DateTime.tryParse(data['detected_at']?.toString() ?? '')?.toLocal(),
      sections: sections,
    );
  }

  /// Splits "### **Title**: body…" / "#### **Title**:\n- item" markdown
  /// into titled sections.
  List<PlantDiagnosisSection> _parseMarkdown(String markdown) {
    if (markdown.trim().isEmpty) return const [];
    final sections = <PlantDiagnosisSection>[];
    String? title;
    final buffer = StringBuffer();

    void flush() {
      if (title != null) {
        final body = buffer.toString().trim();
        if (body.isNotEmpty) {
          sections.add(PlantDiagnosisSection(title: title, body: body));
        }
        buffer.clear();
      }
    }

    for (final line in markdown.split('\n')) {
      final headerMatch = RegExp(r'^#{2,6}\s*(.*)$').firstMatch(line.trim());
      if (headerMatch != null) {
        flush();
        final headerText = headerMatch.group(1)!.trim();
        final colonIdx = headerText.indexOf(':');
        final rawTitle = colonIdx == -1 ? headerText : headerText.substring(0, colonIdx);
        final inlineValue = colonIdx == -1 ? '' : headerText.substring(colonIdx + 1).trim();
        title = rawTitle.replaceAll('*', '').trim();
        if (inlineValue.isNotEmpty) buffer.write(inlineValue);
      } else if (title != null) {
        if (line.trim().isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(line.trim());
      }
    }
    flush();
    return sections;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final plantProvider =
    StateNotifierProvider<PlantNotifier, PlantState>((ref) {
  return PlantNotifier(ref.watch(apiClientProvider));
});
