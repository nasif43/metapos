import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/printer_provider.dart';

/// Modal bottom sheet displaying Bluetooth thermal printer connection,
/// 58mm/80mm roll width toggles, test print trigger, and paired devices.
class PrinterStatusBottomSheet extends ConsumerWidget {
  const PrinterStatusBottomSheet({super.key});

  /// Displays the printer status modal sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrinterStatusBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerState = ref.watch(printerProvider);
    final printerNotifier = ref.read(printerProvider.notifier);
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final isConnected = printerState.isConnected;
    final selectedDevice = printerState.selectedDevice;

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
                    color: isConnected ? AppColors.mint : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: isConnected ? AppColors.emerald : AppColors.textMuted,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bluetooth Thermal Printer',
                        style: AppTypography.heading2.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ব্লুটুথ থার্মাল রসিদ প্রিন্টার • ESC/POS',
                        style: AppTypography.bodyRegularBengali.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
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

            // Status Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: isConnected ? AppColors.emerald.withValues(alpha: 0.3) : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Status Badge
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? AppColors.statusInStockBg
                                  : AppColors.statusOutOfStockBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isConnected
                                        ? AppColors.statusInStock
                                        : AppColors.statusOutOfStock,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    isConnected
                                        ? (isBangla ? 'সংযুক্ত' : 'Connected')
                                        : (isBangla ? 'বিচ্ছিন্ন' : 'Disconnected'),
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: isConnected
                                          ? AppColors.emeraldDark
                                          : AppColors.statusOutOfStock,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Connect/Disconnect Button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: isConnected
                              ? AppColors.statusOutOfStock
                              : AppColors.emeraldDark,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          isConnected ? Icons.link_off_rounded : Icons.link_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isConnected ? 'Disconnect' : 'Connect',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        onPressed: () => printerNotifier.toggleConnection(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Selected Device Details
                  Text(
                    selectedDevice?.name ?? 'No Device Selected',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MAC: ${selectedDevice?.address ?? "N/A"} • Bluetooth SPP / RFCOMM',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Paper Width Selector
            Text(
              isBangla ? 'রোল সাইজ' : 'Paper Width',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _buildPaperWidthOption(
                    context: context,
                    width: PrinterPaperWidth.mm58,
                    title: '58mm Roll',
                    subtitle: '32 cols • Boi Mela Standard',
                    isSelected: printerState.paperWidth == PrinterPaperWidth.mm58,
                    onTap: () => printerNotifier.setPaperWidth(PrinterPaperWidth.mm58),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildPaperWidthOption(
                    context: context,
                    width: PrinterPaperWidth.mm80,
                    title: '80mm Roll',
                    subtitle: '48 cols • Desktop Standard',
                    isSelected: printerState.paperWidth == PrinterPaperWidth.mm80,
                    onTap: () => printerNotifier.setPaperWidth(PrinterPaperWidth.mm80),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Full-Width Print Test Receipt Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? AppColors.emerald : AppColors.textMuted,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                elevation: 0,
              ),
              onPressed: (!isConnected || printerState.isPrinting)
                  ? (isConnected ? null : () => _showDisconnectedWarning(context))
                  : () => _handlePrintTest(context, ref),
              child: printerState.isPrinting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Text(
                          'Printing Test Receipt...',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            isBangla ? 'টেস্ট রসিদ প্রিন্ট' : 'Print Test Receipt',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Paired Devices List Section
            Text(
              isBangla ? 'সংযুক্তযোগ্য ডিভাইস' : 'Available / Paired Devices',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: printerState.availableDevices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.bluetooth_disabled_rounded, color: AppColors.textMuted),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              isBangla
                                  ? 'কোনো ব্লুটুথ প্রিন্টার পেয়ার করা নেই। আপনার ফোনের সেটিংস থেকে থার্মাল প্রিন্টার সংযুক্ত করুন।'
                                  : 'No Bluetooth printer paired. Connect a thermal printer in your device settings.',
                              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: printerState.availableDevices.map((device) {
                        final isCurrent = device.address == selectedDevice?.address;
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 2,
                            ),
                            leading: Icon(
                              Icons.bluetooth_rounded,
                              color: isCurrent && isConnected
                                  ? AppColors.emerald
                                  : AppColors.textMuted,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    device.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                      color: isCurrent ? AppColors.emeraldDark : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (device.isDefault) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.mint,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.emeraldDark,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              device.address,
                              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.emerald)
                                : const Icon(Icons.radio_button_unchecked, color: AppColors.textMuted),
                            onTap: () {
                              printerNotifier.selectDevice(device);
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperWidthOption({
    required BuildContext context,
    required PrinterPaperWidth width,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mint : AppColors.canvas,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.emerald : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.emeraldDark : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.emerald : AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.emeraldDark : AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisconnectedWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.statusOutOfStock, width: 1.5),
        ),
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.statusOutOfStock, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'প্রিন্টার সংযুক্ত নয়। অনুগ্রহ করে প্রথমে কানেক্ট করুন।',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrintTest(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(printerProvider.notifier).printTestReceipt();
    if (!context.mounted) return;

    final printerState = ref.read(printerProvider);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: const BorderSide(color: AppColors.emerald, width: 1.5),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'টেস্ট রসিদ সফলভাবে প্রিন্ট হয়েছে!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${printerState.selectedDevice?.name ?? "POS-58BT"} • ${printerState.paperWidth.name} (${printerState.paperWidth.columns} cols)',
                      style: const TextStyle(
                        color: AppColors.emerald,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
