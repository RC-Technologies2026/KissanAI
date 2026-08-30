import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import 'camera_picker_screen.dart';

/// Screen 2 — Image Preview.
///
/// Shows the captured/selected photo with Analyze / Retake buttons.
class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({
    super.key,
    required this.detectionType,
    this.imagePath,
  });

  final DetectionType detectionType;
  final String? imagePath;

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
          detectionType.previewTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
      ),
      body: Column(
        children: [
          // Full image preview
          Expanded(
            flex: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E4D8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: imagePath != null && File(imagePath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(imagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_outlined,
                                size: 64, color: AppColors.bodyText),
                            SizedBox(height: 12),
                            Text(
                              'No photo captured',
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
            flex: 40,
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
                children: [
                  // Analyze Now — solid green
                  ElevatedButton.icon(
                    onPressed: imagePath != null
                        ? () => context.push(
                              '/detection/analyzing',
                              extra: {
                                'detectionType': detectionType,
                                'imagePath': imagePath,
                              },
                            )
                        : null,
                    icon: const Icon(Icons.check_circle, size: 22),
                    label: Text(detectionType.analyzeButton),
                  ),
                  const SizedBox(height: 12),

                  // Retake — outline green
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.refresh, size: 22),
                    label: Text(detectionType.retakeButton),
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
