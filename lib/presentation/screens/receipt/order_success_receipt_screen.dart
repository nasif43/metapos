import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/sync_queue_provider.dart';
import '../../widgets/language_toggle_button.dart';
import '../orders/widgets/return_process_bottom_sheet.dart';

/// Screen 6: OrderSuccessReceiptScreen (`/receipt`)
///
/// Features:
/// - Real-time dynamic order confirmation driven by actual validated `OrderModel`.
/// - Thermal receipt roll preview (32-column roll) with Bengali typography.
/// - ESC/POS print action dispatching real order items to `printerProvider`.
/// - Start new order action cleanly cycling back to `/catalog`.
/// - Accepts `isRefund: bool` via route args (as RefundReceiptArgs) to show
///   "REFUND VOUCHER" header, negative amounts and মোট ফেরত label.
class OrderSuccessReceiptScreen extends ConsumerWidget {
  const OrderSuccessReceiptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Decode route args — may be plain OrderModel or RefundReceiptArgs
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    OrderModel? order;
    bool isRefund = false;

    if (rawArgs is RefundReceiptArgs) {
      order = rawArgs.order;
      isRefund = rawArgs.isRefund;
    } else if (rawArgs is OrderModel) {
      order = rawArgs;
      isRefund = rawArgs.isRefund;
    } else {
      order = ref.watch(lastCompletedOrderProvider);
      isRefund = order?.isRefund ?? false;
    }

    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final syncStatusAsync = order != null
        ? ref.watch(orderSyncStatusProvider(order.uuid))
        : const AsyncValue<String?>.data(null);
    final isSynced = (order?.isSynced ?? false) || (syncStatusAsync.value == 'synced');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/catalog',
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: isBangla ? 'পণ্য তালিকায় ফিরে যান' : 'Back to Catalog',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/catalog',
                (route) => false,
              );
            },
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isBangla
                  ? (isRefund ? 'রিফান্ড ভাউচার' : 'অর্ডার নিশ্চিতকরণ')
                  : (isRefund ? 'Refund Voucher' : 'Order Confirmation'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          actions: const [
            LanguageToggleButton(),
            SizedBox(width: 4),
          ],
        ),
        body: order == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isBangla ? 'কোনো সক্রিয় অর্ডার নেই' : 'No Active Order',
                        style: AppTypography.heading2,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/catalog',
                            (route) => false,
                          );
                        },
                        child: Text(
                          isBangla ? 'ক্যাটালগে ফিরে যান' : 'Back to Catalog',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        // Success / Refund Badge
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isRefund
                                ? AppColors.statusOutOfStockBg
                                : AppColors.mint,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRefund
                                ? Icons.replay_circle_filled_rounded
                                : Icons.check_circle_rounded,
                            color: isRefund
                                ? AppColors.statusOutOfStock
                                : AppColors.emerald,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          isBangla
                              ? (isRefund ? 'রিফান্ড সম্পন্ন!' : 'বিক্রয় সম্পন্ন!')
                              : (isRefund ? 'Refund Complete!' : 'Sale Complete!'),
                          style: AppTypography.heading1.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'POS Ref: ${order.posReference} • Ticket: ${order.ticketCode}',
                          style: AppTypography.caption
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Sync Status Pill (Dynamic)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSynced
                                ? AppColors.statusInStockBg
                                : AppColors.statusLowStockBg,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: isSynced
                                  ? AppColors.statusInStock
                                  : AppColors.statusLowStock,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSynced
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_queue_rounded,
                                color: isSynced
                                    ? AppColors.statusInStock
                                    : AppColors.statusLowStock,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isSynced
                                    ? (isBangla
                                        ? (AppStrings.syncedOnline['bn'] ?? 'সার্ভারে সংরক্ষিত')
                                        : 'Synced with Cloud')
                                    : (isBangla
                                        ? 'অফলাইনে জমা হয়েছে'
                                        : 'Queued Locally • Offline'),
                                style: AppTypography.caption.copyWith(
                                  color: isSynced
                                      ? AppColors.statusInStock
                                      : AppColors.statusLowStock,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Thermal Receipt Preview Card (32-column roll preview)
                        Card(
                          elevation: 2,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  isRefund ? 'REFUND VOUCHER' : 'মেটাপস বুক ফেয়ার স্টল',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.heading2Bengali.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: isRefund
                                        ? AppColors.statusOutOfStock
                                        : null,
                                  ),
                                ),
                                Text(
                                  'বাংলা একাডেমি প্রাঙ্গণ, ঢাকা',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.captionBengali,
                                ),
                                Text(
                                  'Phone: +880 1711-000000',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '--------------------------------',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Date: ${DateFormat('dd-MMM-yyyy').format(order.createdAt)}',
                                        style: AppTypography.caption,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        'Time: ${DateFormat('HH:mm').format(order.createdAt)}',
                                        style: AppTypography.caption,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Cashier: Administrator',
                                        style: AppTypography.caption,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        'POS: Book Fair',
                                        style: AppTypography.caption,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  '--------------------------------',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: AppColors.textSecondary,
                                  ),
                                ),

                                // Dynamic Line Items
                                ...order.lines.map((line) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${line.productName} x ${line.qty.toInt()}${line.discount > 0 ? " • ${line.discount.toInt()}% ছাড়" : ""}',
                                            style: AppTypography
                                                .bodyMediumBengali,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          CurrencyFormatter.formatBDT(
                                              line.priceSubtotalIncl),
                                          style: AppTypography.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                const Text(
                                  '--------------------------------',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: AppColors.textSecondary,
                                  ),
                                ),

                                // Financial Breakdown
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        isBangla ? '১০% ভ্যাট অন্তর্ভুক্ত:' : '10% VAT Included:',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.formatBDT(
                                          order.amountTax),
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'TOTAL DUE:',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        CurrencyFormatter.formatBDT(
                                            order.amountTotal),
                                        style: AppTypography.heading2.copyWith(
                                          color: AppColors.emeraldDark,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Payments Detail
                                ...order.payments
                                    .where((p) => !p.isChange)
                                    .map((p) {
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Paid (${p.paymentMethodName ?? "Payment"}):',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.caption,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        CurrencyFormatter.formatBDT(p.amount),
                                        style: AppTypography.caption,
                                      ),
                                    ],
                                  );
                                }),

                                if (order.amountReturn > 0)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          isBangla ? 'ফেরত:' : 'Change Due:',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.caption.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        CurrencyFormatter.formatBDT(
                                            order.amountReturn),
                                        style: AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 6),
                                const Text(
                                  '--------------------------------',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'ধন্যবাদ! আবার আসবেন।',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMediumBengali.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Powered by MetaPOS BD • metaposbd.com',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Action Button: New Sale
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                            ),
                            icon: const Icon(Icons.add_shopping_cart_rounded,
                                color: Colors.white),
                            label: Text(
                              isBangla ? 'নতুন বিক্রয়' : 'New Sale',
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () {
                              ref.read(cartProvider.notifier).clearCart();
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/catalog',
                                (route) => false,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
