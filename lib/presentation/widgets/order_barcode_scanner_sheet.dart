import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';

/// Modal bottom sheet providing REAL live hardware camera barcode/QR scanning
/// specifically for order tickets, tracking numbers, or receipt barcodes.
class OrderBarcodeScannerSheet extends ConsumerStatefulWidget {
  final ValueChanged<String> onCodeScanned;

  const OrderBarcodeScannerSheet({
    super.key,
    required this.onCodeScanned,
  });

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onCodeScanned,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderBarcodeScannerSheet(
        onCodeScanned: onCodeScanned,
      ),
    );
  }

  @override
  ConsumerState<OrderBarcodeScannerSheet> createState() =>
      _OrderBarcodeScannerSheetState();
}

class _OrderBarcodeScannerSheetState
    extends ConsumerState<OrderBarcodeScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final _inputController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _isProcessing = true;
        _submitCode(rawValue.trim());
        break;
      }
    }
  }

  void _submitCode(String rawCode) {
    final code = rawCode.trim();
    if (code.isEmpty) {
      _isProcessing = false;
      return;
    }
    Navigator.of(context).pop();
    widget.onCodeScanned(code);
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSheet),
        ),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.emerald,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBangla ? 'রসিদ / অর্ডার স্ক্যানার' : 'Receipt / Order Scanner',
                        style: AppTypography.heading2.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBangla
                            ? 'অর্ডার স্লিপের বারকোড বা কিউআর কোড স্ক্যান করুন'
                            : 'Scan barcode or QR on customer receipt',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Live Camera Viewfinder
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.emerald, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.videocam_off_rounded,
                                color: AppColors.statusOutOfStock,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isBangla
                                    ? 'ক্যামেরা অনুমতি প্রয়োজন'
                                    : 'Camera permission required',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Horizontal glowing laser line
                  Container(
                    width: 200,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.emerald,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withValues(alpha: 0.9),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),

                  // Camera controls
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          icon: ValueListenableBuilder<MobileScannerState>(
                            valueListenable: _scannerController,
                            builder: (context, state, child) {
                              return Icon(
                                state.torchState == TorchState.on
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                size: 20,
                              );
                            },
                          ),
                          onPressed: () => _scannerController.toggleTorch(),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(
                              Icons.flip_camera_android_rounded,
                              size: 20),
                          onPressed: () => _scannerController.switchCamera(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Manual Text Entry Fallback
            Text(
              isBangla ? 'অথবা নম্বর লিখুন:' : 'Or Enter Code Manually:',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _inputController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitCode,
              decoration: InputDecoration(
                hintText: isBangla
                    ? 'অর্ডার নম্বর বা টিকেট কোড…'
                    : 'Order ref or ticket code…',
                hintStyle: AppTypography.bodyRegularBengali.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.barcode_reader,
                  color: AppColors.emerald,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.emerald,
                  ),
                  onPressed: () => _submitCode(_inputController.text),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
