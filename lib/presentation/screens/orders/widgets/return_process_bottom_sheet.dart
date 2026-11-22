import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/order_model.dart';
import '../../../../providers/return_order_provider.dart';

/// M3.3 — Return / Refund DraggableScrollableSheet modal.
///
/// Shows:
/// - Selected lines with qty steppers bounded by refundableQty
/// - Payout tender selector: Cash / Bank / bKash
/// - Total refund summary in whole BDT
/// - Confirm button with loading state + re-entrancy guard
class ReturnProcessBottomSheet extends ConsumerStatefulWidget {
  final OrderModel order;

  const ReturnProcessBottomSheet({super.key, required this.order});

  @override
  ConsumerState<ReturnProcessBottomSheet> createState() =>
      _ReturnProcessBottomSheetState();
}

class _ReturnProcessBottomSheetState
    extends ConsumerState<ReturnProcessBottomSheet> {
  // Simple tender options with IDs matching typical Odoo payment method IDs
  static const _tenders = [
    _TenderOption(id: 1, labelBn: 'নগদ', labelEn: 'Cash', icon: Icons.payments_rounded),
    _TenderOption(id: 2, labelBn: 'ব্যাংক', labelEn: 'Bank', icon: Icons.account_balance_rounded),
    _TenderOption(id: 3, labelBn: 'বিকাশ', labelEn: 'bKash', icon: Icons.phone_android_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final returnState = ref.watch(returnOrderProvider);
    final selectedLines = _buildSelectedLines(returnState);
    final totalRefund = _calcTotal(selectedLines);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusSheet),
            ),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.statusOutOfStockBg,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(
                        Icons.undo_rounded,
                        color: AppColors.statusOutOfStock,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isBangla ? 'ফেরত / রিফান্ড' : 'Return / Refund',
                      style: isBangla
                          ? AppTypography.heading2Bengali
                              .copyWith(fontWeight: FontWeight.w800)
                          : AppTypography.heading2
                              .copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Selected lines
                    if (selectedLines.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text(
                          isBangla
                              ? 'কোনো পণ্য নির্বাচন করা হয়নি'
                              : 'No items selected',
                          style: AppTypography.bodyRegular
                              .copyWith(color: AppColors.textMuted),
                        ),
                      )
                    else ...[
                      Text(
                        isBangla ? 'নির্বাচিত পণ্য:' : 'Selected items:',
                        style: AppTypography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...selectedLines.map(
                        (entry) => _SelectedLineRow(
                          line: entry.line,
                          qty: entry.qty,
                          isBangla: isBangla,
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: AppSpacing.sm),

                    // Tender selector
                    Text(
                      isBangla ? 'ফেরত পেমেন্ট পদ্ধতি:' : 'Refund via:',
                      style: AppTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: _tenders
                          .map(
                            (t) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _TenderChip(
                                  tender: t,
                                  selected:
                                      returnState.paymentMethodId == t.id,
                                  isBangla: isBangla,
                                  onTap: () => ref
                                      .read(returnOrderProvider.notifier)
                                      .setPaymentMethod(t.id),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: AppSpacing.sm),

                    // Error banner
                    if (returnState.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.statusOutOfStockBg,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                              color: AppColors.statusOutOfStock, width: 1),
                        ),
                        child: Text(
                          returnState.error!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.statusOutOfStock,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isBangla ? 'মোট ফেরত পরিমাণ:' : 'Total Refund:',
                          style: AppTypography.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          CurrencyFormatter.formatBDT(totalRefund),
                          style: AppTypography.heading2.copyWith(
                            color: AppColors.statusOutOfStock,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: returnState.isSubmitting ||
                                  !returnState.hasSelectedLines ||
                                  returnState.paymentMethodId == null
                              ? AppColors.border
                              : AppColors.statusOutOfStock,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                        ),
                        onPressed: returnState.isSubmitting ||
                                !returnState.hasSelectedLines ||
                                returnState.paymentMethodId == null
                            ? null
                            : () => _confirmReturn(context, isBangla),
                        icon: returnState.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded,
                                color: Colors.white),
                        label: Text(
                          returnState.isSubmitting
                              ? (isBangla ? 'প্রক্রিয়া হচ্ছে…' : 'Processing…')
                              : (isBangla ? 'রিফান্ড নিশ্চিত করুন' : 'Confirm Refund'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmReturn(BuildContext context, bool isBangla) async {
    final navigator = Navigator.of(context);
    final refundOrder =
        await ref.read(returnOrderProvider.notifier).submitReturn();

    if (!mounted) return;

    if (refundOrder != null) {
      // Success — pop sheet + detail, navigate to receipt with isRefund
      navigator.popUntil((route) => route.isFirst);
      navigator.pushNamed(
        AppRoutes.receipt,
        arguments: RefundReceiptArgs(order: refundOrder, isRefund: true),
      );
    }
  }

  List<_LineEntry> _buildSelectedLines(ReturnOrderState state) {
    final original = state.originalOrder;
    if (original == null) return [];

    final result = <_LineEntry>[];
    for (final entry in state.selectedQuantities.entries) {
      if (entry.value <= 0) continue;
      final line = original.lines
          .cast<OrderLineModel?>()
          .firstWhere((l) => l?.id == entry.key, orElse: () => null);
      if (line != null) {
        result.add(_LineEntry(line: line, qty: entry.value));
      }
    }
    return result;
  }

  double _calcTotal(List<_LineEntry> lines) {
    return lines.fold(0.0, (sum, e) {
      final unitPrice = e.line.qty != 0
          ? (e.line.priceSubtotalIncl / e.line.qty).abs()
          : 0.0;
      return sum + unitPrice * e.qty;
    });
  }
}

// ─── Helper types ─────────────────────────────────────────────────────────────

class _LineEntry {
  final OrderLineModel line;
  final double qty;

  const _LineEntry({required this.line, required this.qty});
}

class _TenderOption {
  final int id;
  final String labelBn;
  final String labelEn;
  final IconData icon;

  const _TenderOption({
    required this.id,
    required this.labelBn,
    required this.labelEn,
    required this.icon,
  });
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SelectedLineRow extends StatelessWidget {
  final OrderLineModel line;
  final double qty;
  final bool isBangla;

  const _SelectedLineRow({
    required this.line,
    required this.qty,
    required this.isBangla,
  });

  @override
  Widget build(BuildContext context) {
    final unitPrice =
        line.qty != 0 ? (line.priceSubtotalIncl / line.qty).abs() : 0.0;
    final lineTotal = unitPrice * qty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.productName,
              style: isBangla
                  ? AppTypography.bodyMediumBengali
                  : AppTypography.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '× ${qty.toInt()}',
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            CurrencyFormatter.formatBDT(lineTotal),
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.statusOutOfStock,
            ),
          ),
        ],
      ),
    );
  }
}

class _TenderChip extends StatelessWidget {
  final _TenderOption tender;
  final bool selected;
  final bool isBangla;
  final VoidCallback onTap;

  const _TenderChip({
    required this.tender,
    required this.selected,
    required this.isBangla,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : AppColors.canvas,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: selected ? AppColors.emerald : AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tender.icon,
              size: 20,
              color: selected ? AppColors.emerald : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              isBangla ? tender.labelBn : tender.labelEn,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.emerald : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Public type alias used by OrderSuccessReceiptScreen to decode args.
class RefundReceiptArgs {
  final OrderModel order;
  final bool isRefund;

  const RefundReceiptArgs({required this.order, required this.isRefund});
}
