import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';

/// Detection type enum — shared between Disease and Pest flows.
enum DetectionType {
  disease,
  pest;

  String get appBarTitle => this == disease
      ? 'Crop Disease Detection'
      : 'Pest & Insect Detection';

  String get previewTitle => this == disease
      ? 'Review Your Photo'
      : 'Review Your Photo';

  String get instructionTitle => this == disease
      ? 'Photograph the affected area'
      : 'Photograph the affected pest';

  String get instructionSubtitle => this == disease
      ? 'Get the closest clear shot of the infected leaf or plant part'
      : 'Get a clear close-up of the pest or insect';

  String get analyzeButton => this == disease
      ? 'Looks Good — Analyze Now'
      : 'Looks Good — Analyze Now';

  String get retakeButton => this == disease
      ? 'Retake / Choose Another'
      : 'Retake / Choose Another';

  String get resultTitle => this == disease
      ? 'Detection Result'
      : 'Detection Result';

  String get recommendationTitle => this == disease
      ? 'Pesticide Recommendation'
      : 'Insecticide Recommendation';

  String get recommendationButton => this == disease
      ? 'View Pesticide Recommendation →'
      : 'View Insecticide Recommendation →';

  String get saveHistoryButton => this == disease
      ? 'Save to History'
      : 'Save to History';
}

/// Screen 1 — Camera / Gallery Picker (shared for Disease + Pest).
class CameraPickerScreen extends StatefulWidget {
  const CameraPickerScreen({super.key, required this.detectionType});

  final DetectionType detectionType;

  @override
  State<CameraPickerScreen> createState() => _CameraPickerScreenState();
}

class _CameraPickerScreenState extends State<CameraPickerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _takePhoto() async {
    setState(() => _isLoading = true);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null && mounted) {
        context.push(
          '/detection/preview',
          extra: {
            'detectionType': widget.detectionType,
            'imagePath': photo.path,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _chooseFromGallery() async {
    setState(() => _isLoading = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        context.push(
          '/detection/preview',
          extra: {
            'detectionType': widget.detectionType,
            'imagePath': image.path,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          widget.detectionType.appBarTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
      ),
      body: Column(
        children: [
          // Camera preview area — ~55% of screen height
          Expanded(
            flex: 55,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E4D8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 64, color: AppColors.bodyText),
                      SizedBox(height: 12),
                      Text(
                        'Tap a button below to capture',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.bodyText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom white card
          Expanded(
            flex: 45,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instruction title
                  Text(
                    widget.detectionType.instructionTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingText,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Instruction subtitle
                  Text(
                    widget.detectionType.instructionSubtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.bodyText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Take Photo — solid green
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _takePhoto,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt, size: 22),
                    label: const Text('Take Photo'),
                  ),
                  const SizedBox(height: 12),

                  // Choose from Gallery — outline green
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _chooseFromGallery,
                    icon: const Icon(Icons.photo_library, size: 22),
                    label: const Text('Choose from Gallery'),
                  ),
                  const SizedBox(height: 16),

                  // Tip row
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Good lighting + close-up = accurate results',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
