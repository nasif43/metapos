import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/product_model.dart';

/// Modal bottom sheet providing REAL live hardware camera barcode/QR scanning
/// using mobile_scanner, with flash toggle, camera switch, and manual text fallback.
class BarcodeScannerSheet extends ConsumerStatefulWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onProductScanned;
  final ValueChanged<ProductModel>? onOutOfStock;
  final ValueChanged<String>? onNotFound;

  const BarcodeScannerSheet({
    super.key,
    required this.products,
    required this.onProductScanned,
    this.onOutOfStock,
    this.onNotFound,
  });

  /// Displays the barcode scanner sheet as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required List<ProductModel> products,
    required ValueChanged<ProductModel> onProductScanned,
    ValueChanged<ProductModel>? onOutOfStock,
    ValueChanged<String>? onNotFound,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeScannerSheet(
        products: products,
        onProductScanned: onProductScanned,
        onOutOfStock: onOutOfStock,
        onNotFound: onNotFound,
      ),
    );
  }

  @override
  ConsumerState<BarcodeScannerSheet> createState() =>
      _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends ConsumerState<BarcodeScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final _inputController = TextEditingController();
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _isProcessing = true;
        _processCode(rawValue.trim());
        break;
      }
    }
  }

  void _processCode(String rawCode) {
    final code = rawCode.trim();
    if (code.isEmpty) {
      _isProcessing = false;
      return;
    }

    final lowerCode = code.toLowerCase();
    ProductModel? matched;

    for (final p in widget.products) {
      if ((p.barcode?.toLowerCase() == lowerCode) ||
          (p.isbn?.toLowerCase() == lowerCode) ||
          (p.isbn10?.toLowerCase() == lowerCode) ||
          (p.defaultCode?.toLowerCase() == lowerCode) ||
          (p.id.toString() == lowerCode) ||
          (p.name.toLowerCase() == lowerCode)) {
        matched = p;
        break;
      }
    }

    if (matched == null) {
      // Try loose match on book title
      for (final p in widget.products) {
        if (p.name.toLowerCase().contains(lowerCode)) {
          matched = p;
          break;
        }
      }
    }

    final isBangla = ref.read(localeProvider).languageCode == 'bn';

    if (matched == null) {
      setState(() {
        _errorMessage = isBangla
            ? 'কোনো বই পাওয়া যায়নি: "$code"'
            : 'No book found for "$code"';
        _isProcessing = false;
      });
      if (widget.onNotFound != null) {
        widget.onNotFound!(code);
      }
      return;
    }

    // Check stock
    if (matched.bookQtyOnHand <= 0) {
      Navigator.of(context).pop();
      if (widget.onOutOfStock != null) {
        widget.onOutOfStock!(matched);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.statusOutOfStock, width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.statusOutOfStock, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBangla
                        ? '${matched.name} বর্তমানে স্টক শেষ'
                        : '${matched.name} is currently Out of Stock',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    // Match found and in stock
    Navigator.of(context).pop();
    widget.onProductScanned(matched);
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
            // Top Drag Handle
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

            // Header Row
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
                        isBangla ? 'বারকোড / কিউআর স্ক্যানার' : 'Barcode / QR Scanner',
                        style: AppTypography.heading2.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBangla
                            ? 'বইয়ের বারকোড বা কিউআর কোড স্ক্যান করুন'
                            : 'Scan physical book Barcode or ISBN',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
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

            // REAL Live Camera Viewfinder with Hardware Feed
            Container(
              height: 260,
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
                                    ? 'ক্যামেরা অনুমতি প্রয়োজন অথবা ত্রুটি হয়েছে'
                                    : 'Camera permission required or camera unavailable',
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

                  // Reticle Frame with Emerald Corners
                  CustomPaint(
                    size: const Size(220, 140),
                    painter: _ReticlePainter(),
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

                  // Live Controls Overlay (Torch & Camera Switch)
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
                          icon: const Icon(Icons.flip_camera_android_rounded, size: 20),
                          onPressed: () => _scannerController.switchCamera(),
                        ),
                      ],
                    ),
                  ),

                  // Live hardware scanning indicator badge
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.emerald, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isBangla ? 'ক্যামেরা সক্রিয় • কোড নির্দেশ করুন' : 'Camera Active • Align barcode in frame',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Error Message (if any)
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.statusOutOfStockBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.statusOutOfStock,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.statusOutOfStock,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Manual Barcode / ISBN Entry Field (Always useful if barcode is damaged)
            Text(
              isBangla ? 'ম্যানুয়াল বারকোড / ISBN লিখুন:' : 'Manual Barcode / ISBN Entry:',
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
              onSubmitted: _processCode,
              decoration: InputDecoration(
                hintText: isBangla
                    ? 'বারকোড বা ISBN লিখুন, যেমন 5556666…'
                    : 'Enter Barcode or ISBN, e.g. 5556666…',
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
                  tooltip: 'Submit / Scan',
                  onPressed: () => _processCode(_inputController.text),
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

/// Custom painter rendering four emerald corner brackets for the reticle.
class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.emerald
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 22.0;

    // Top-Left
    canvas.drawLine(const Offset(0, cornerLength), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width - cornerLength, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(const Offset(0, 0 + cornerLength), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height - cornerLength), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width - cornerLength, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
