import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/return_order_provider.dart';
import '../../widgets/language_toggle_button.dart';
import 'widgets/return_process_bottom_sheet.dart';

/// Screen M3.2 — Order Detail with return line selection
///
/// Shows full order header, all line items, per-line qty steppers
/// for refundable items, and "Process Return" FAB.
class OrderDetailScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(returnOrderProvider.notifier);
      notifier.reset();
      notifier.initForOrder(widget.order);
    });
  }

  void _openReturnSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReturnProcessBottomSheet(order: widget.order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final returnState = ref.watch(returnOrderProvider);
    final hasSelection = returnState.hasSelectedLines;
    final order = widget.order;
    final dateStr =
        DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlate,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textOnDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isBangla ? 'অর্ডার বিবরণ' : 'Order Detail',
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: const [LanguageToggleButton(), SizedBox(width: 4)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header card
            _OrderHeaderCard(order: order, dateStr: dateStr, isBangla: isBangla),
            const SizedBox(height: AppSpacing.md),

            // Section title
            Text(
              isBangla ? 'পণ্য তালিকা' : 'Line Items',
              style: isBangla
                  ? AppTypography.heading2Bengali
                  : AppTypography.heading2,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Line items
            ...order.lines.map(
              (line) => _LineItemRow(
                line: line,
                isBangla: isBangla,
                returnState: returnState,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      floatingActionButton: order.isRefund
          ? null
          : FloatingActionButton.extended(
              onPressed: hasSelection ? _openReturnSheet : null,
              backgroundColor:
                  hasSelection ? AppColors.statusOutOfStock : AppColors.border,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.undo_rounded),
              label: Text(
                isBangla ? 'ফেরত প্রক্রিয়া করুন' : 'Process Return',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}

// ─── Order Header Card ───────────────────────────────────────────────────────

class _OrderHeaderCard extends StatelessWidget {
  final OrderModel order;
  final String dateStr;
  final bool isBangla;

  const _OrderHeaderCard({
    required this.order,
    required this.dateStr,
    required this.isBangla,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.posReference.isNotEmpty
                      ? order.posReference
                      : (order.name?.isNotEmpty == true
                          ? order.name!
                          : order.uuid.substring(0, 8)),
                  style: AppTypography.heading2
                      .copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (order.isRefund)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusOutOfStockBg,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                        color: AppColors.statusOutOfStock, width: 1),
                  ),
                  child: Text(
                    isBangla ? 'রিফান্ড' : 'REFUND',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusOutOfStock,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: isBangla ? 'তারিখ:' : 'Date:',
            value: dateStr,
          ),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: isBangla ? 'ক্যাশিয়ার:' : 'Cashier:',
            value: 'Administrator',
          ),
          const Divider(height: AppSpacing.md, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBangla ? 'মোট পরিমাণ' : 'Grand Total',
                style: AppTypography.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                CurrencyFormatter.formatBDT(order.amountTotal),
                style: AppTypography.heading2.copyWith(
                  color: order.isRefund
                      ? AppColors.statusOutOfStock
                      : AppColors.emeraldDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              style: AppTypography.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Line Item Row ────────────────────────────────────────────────────────────

class _LineItemRow extends ConsumerWidget {
  final OrderLineModel line;
  final bool isBangla;
  final ReturnOrderState returnState;

  const _LineItemRow({
    required this.line,
    required this.isBangla,
    required this.returnState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRefundable = line.id != null && line.refundableQty > 0;
    final selectedQty = line.id != null
        ? (returnState.selectedQuantities[line.id!] ?? 0.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: selectedQty > 0
              ? AppColors.statusOutOfStock.withAlpha(80)
              : AppColors.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.productName,
                      style: isBangla
                          ? AppTypography.bodyMediumBengali
                              .copyWith(fontWeight: FontWeight.w700)
                          : AppTypography.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isBangla ? 'পরিমাণ' : 'Qty'}: ${line.qty.toInt()}  •  '
                      '${isBangla ? 'মূল্য' : 'Price'}: ${CurrencyFormatter.formatBDT(line.priceSubtotalIncl)}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    if (line.refundedQty > 0)
                      Text(
                        '${isBangla ? 'ফেরত দেওয়া হয়েছে' : 'Refunded'}: ${line.refundedQty.toInt()}  •  '
                        '${isBangla ? 'অবশিষ্ট' : 'Remaining'}: ${line.refundableQty.toInt()}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.statusOutOfStock,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatBDT(line.priceSubtotalIncl),
                style:
                    AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),

          // Stepper for refundable lines
          if (isRefundable) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  isBangla ? 'ফেরত পরিমাণ:' : 'Return qty:',
                  style: AppTypography.caption
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _QtyStepper(
                  value: selectedQty.toInt(),
                  max: line.refundableQty.toInt(),
                  onChanged: (val) {
                    if (line.id != null) {
                      ref
                          .read(returnOrderProvider.notifier)
                          .setQuantity(line.id!, val.toDouble());
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove_rounded,
          enabled: value > 0,
          onTap: () => onChanged((value - 1).clamp(0, max)),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _StepBtn(
          icon: Icons.add_rounded,
          enabled: value < max,
          onTap: () => onChanged((value + 1).clamp(0, max)),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppColors.canvas : AppColors.border,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
  }
}
