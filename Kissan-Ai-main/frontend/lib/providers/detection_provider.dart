import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/api/dio_client.dart';
import '../screens/detection/camera_picker_screen.dart';

/// One titled block parsed out of the backend's `diagnosis` markdown,
/// e.g. "Symptoms" → bullet list, "Treatment & Management" → bullet list.
class DetectionSection {
  const DetectionSection({required this.title, required this.body});

  final String title;
  final String body;
}

/// Parsed response of /api/disease/detect or /api/pests/detect.
class DetectionResultData {
  const DetectionResultData({
    required this.type,
    this.detectionId,
    this.imageId,
    required this.name,
    this.cropName,
    required this.confidence,
    this.detectedAt,
    this.modelVersion,
    this.sections = const [],
  });

  final DetectionType type;
  final String? detectionId;
  final String? imageId;

  /// disease_name (disease flow) or pest_name (pest flow) from the API.
  final String name;
  final String? cropName;

  /// Normalized 0.0 – 1.0 confidence_score from the API.
  final double confidence;
  final DateTime? detectedAt;
  final String? modelVersion;

  /// Symptoms / Treatment blocks parsed from the diagnosis markdown.
  final List<DetectionSection> sections;
}

enum DetectionStatus { idle, loading, success, failure }

class DetectionState {
  const DetectionState({
    this.status = DetectionStatus.idle,
    this.result,
    this.errorMessage,
  });

  final DetectionStatus status;
  final DetectionResultData? result;
  final String? errorMessage;

  DetectionState copyWith({
    DetectionStatus? status,
    DetectionResultData? result,
    String? errorMessage,
  }) =>
      DetectionState(
        status: status ?? this.status,
        result: result ?? this.result,
        errorMessage: errorMessage,
      );
}

/// Runs the real disease/pest detection API call (replaces the old 2-second
/// mock delay) and exposes the parsed result to the analyzing/result screens.
class DetectionNotifier extends StateNotifier<DetectionState> {
  DetectionNotifier(this._api) : super(const DetectionState());

  final ApiClient _api;

  Future<void> analyze({
    required DetectionType type,
    required String filePath,
    String? cropName,
    String language = 'english',
  }) async {
    state = const DetectionState(status: DetectionStatus.loading);
    try {
      final res = type == DetectionType.disease
          ? await _api.detectDisease(
              filePath: filePath, language: language, cropName: cropName)
          : await _api.detectPest(
              filePath: filePath, language: language, cropName: cropName);

      final data = res.data;

      // Offline sentinel produced by the auth interceptor after retries fail.
      if (data is Map && data['error'] == 'offline') {
        state = const DetectionState(
          status: DetectionStatus.failure,
          errorMessage:
              'Internet connection error. Please check your network.',
        );
        return;
      }
      if (data is! Map) {
        state = const DetectionState(
          status: DetectionStatus.failure,
          errorMessage: 'Unexpected response from the server.',
        );
        return;
      }

      state = DetectionState(
        status: DetectionStatus.success,
        result: _parse(type, data),
      );
    } on DioException catch (e) {
      state = DetectionState(
        status: DetectionStatus.failure,
        errorMessage: friendlyDioErrorMessage(e),
      );
    } catch (_) {
      state = const DetectionState(
        status: DetectionStatus.failure,
        errorMessage: 'Could not analyze the photo. Please try again.',
      );
    }
  }

  void reset() => state = const DetectionState();

  // ── Response parsing ─────────────────────────────────────

  DetectionResultData _parse(DetectionType type, Map data) {
    final isDisease = type == DetectionType.disease;
    final sections = _parseMarkdown(data['diagnosis']?.toString() ?? '');

    // disease_name / pest_name — fall back to the matching markdown header.
    var name = (isDisease ? data['disease_name'] : data['pest_name'])
            ?.toString() ??
        '';
    var cropName = data['crop_name']?.toString();

    for (final s in sections) {
      final t = s.title.toLowerCase();
      if (name.isEmpty && (t.contains('diagnosis') || t.contains('pest'))) {
        name = s.body.replaceAll('\n', ' ').trim();
      }
      if ((cropName == null || cropName.isEmpty) && t == 'crop') {
        cropName = s.body.replaceAll('\n', ' ').trim();
      }
    }

    var confidence = double.tryParse(
          (data['confidence_score']?.toString() ?? ''),
        ) ??
        0.0;
    if (confidence > 1) confidence /= 100; // tolerate 0–100 scale
    confidence = confidence.clamp(0.0, 1.0);

    return DetectionResultData(
      type: type,
      detectionId: data['id']?.toString(),
      imageId: data['image_id']?.toString(),
      name: name.isEmpty ? (isDisease ? 'Disease Diagnosis' : 'Pest Identification') : name,
      cropName: (cropName == null || cropName.isEmpty) ? null : cropName,
      confidence: confidence,
      detectedAt: DateTime.tryParse(data['detected_at']?.toString() ?? '')?.toLocal(),
      modelVersion: data['model_version']?.toString(),
      sections: sections,
    );
  }

  /// Splits "### **Title**: body…" / "#### **Title**:\n- item" markdown
  /// produced by the backend into titled sections.
  List<DetectionSection> _parseMarkdown(String markdown) {
    if (markdown.trim().isEmpty) return const [];
    final sections = <DetectionSection>[];
    String? title;
    final buffer = StringBuffer();

    void flush() {
      if (title != null) {
        final body = buffer.toString().trim();
        if (body.isNotEmpty) {
          sections.add(DetectionSection(title: title!, body: body));
        }
        buffer.clear();
      }
    }

    for (final line in markdown.split('\n')) {
      final headerMatch =
          RegExp(r'^#{2,6}\s*(.*)$').firstMatch(line.trim());
      if (headerMatch != null) {
        flush();
        // "**Crop**: Pomegranate (انار)" → title "Crop", inline value after ':'
        final headerText = headerMatch.group(1)!.trim();
        final colonIdx = headerText.indexOf(':');
        final rawTitle = colonIdx == -1
            ? headerText
            : headerText.substring(0, colonIdx);
        final inlineValue =
            colonIdx == -1 ? '' : headerText.substring(colonIdx + 1).trim();
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

final detectionProvider =
    StateNotifierProvider<DetectionNotifier, DetectionState>((ref) {
  return DetectionNotifier(ref.watch(apiClientProvider));
});
