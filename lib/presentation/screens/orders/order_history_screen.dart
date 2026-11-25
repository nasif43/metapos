import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/past_orders_provider.dart';
import '../../widgets/language_toggle_button.dart';
import '../../widgets/order_barcode_scanner_sheet.dart';
import 'order_detail_screen.dart';

/// Screen M3.1 — Order History & Returns
///
/// Features:
/// - Bilingual AppBar (EN/BN)
/// - Debounced search bar + barcode scan shortcut
/// - Filter chips: সব / ফেরতযোগ্য / রিফান্ড
/// - Order cards with ফেরতযোগ্য badge
/// - Tap → navigates to OrderDetailScreen
class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pastOrdersProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(pastOrdersProvider.notifier).search(value);
    });
  }

  void _showBarcodeScanner() {
    OrderBarcodeScannerSheet.show(
      context: context,
      onCodeScanned: (code) {
        if (code.trim().isNotEmpty) {
          _searchController.text = code.trim();
          ref.read(pastOrdersProvider.notifier).scanBarcode(code.trim());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final state = ref.watch(pastOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlate,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textOnDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isBangla ? 'অর্ডার ইতিহাস / ফেরত' : 'Order History / Returns',
          style: const TextStyle(
            color: AppColors.textOnDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: const [
          LanguageToggleButton(),
          SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // Search bar + barcode button
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isBangla
                          ? 'অর্ডার নম্বর বা তারিখ দিয়ে খুঁজুন…'
                          : 'Search by order ref or date…',
                      hintStyle: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  size: 18, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(pastOrdersProvider.notifier)
                                    .search('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.canvas,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide: const BorderSide(
                            color: AppColors.emerald, width: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ScanButton(onTap: _showBarcodeScanner),
              ],
            ),
          ),

          // Filter chips
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: isBangla ? 'সব' : 'All',
                  selected: state.filter == PastOrdersFilter.all,
                  onSelected: (_) => ref
                      .read(pastOrdersProvider.notifier)
                      .setFilter(PastOrdersFilter.all),
                ),
                const SizedBox(width: AppSpacing.xs),
                _FilterChip(
                  label: isBangla ? 'ফেরতযোগ্য' : 'Refundable',
                  selected: state.filter == PastOrdersFilter.refundable,
                  onSelected: (_) => ref
                      .read(pastOrdersProvider.notifier)
                      .setFilter(PastOrdersFilter.refundable),
                  activeColor: AppColors.emerald,
                ),
                const SizedBox(width: AppSpacing.xs),
                _FilterChip(
                  label: isBangla ? 'রিফান্ড' : 'Refunds',
                  selected: state.filter == PastOrdersFilter.refunds,
                  onSelected: (_) => ref
                      .read(pastOrdersProvider.notifier)
                      .setFilter(PastOrdersFilter.refunds),
                  activeColor: AppColors.statusOutOfStock,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Body: list or states
          Expanded(
            child: _buildBody(context, isBangla, state),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isBangla,
    PastOrdersState state,
  ) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.statusOutOfStock),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isBangla ? 'ত্রুটি ঘটেছে' : 'An error occurred',
                style: isBangla
                    ? AppTypography.bodyMediumBengali
                    : AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.error!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                ),
                onPressed: () =>
                    ref.read(pastOrdersProvider.notifier).loadOrders(),
                child: Text(isBangla ? 'আবার চেষ্টা করুন' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final orders = state.filteredOrders;

    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isBangla ? 'কোনো অর্ডার পাওয়া যায়নি' : 'No orders found',
                style: isBangla
                    ? AppTypography.bodyMediumBengali
                    : AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: () => ref.read(pastOrdersProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.md,
        ),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, i) => _OrderCard(
          order: orders[i],
          isBangla: isBangla,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OrderDetailScreen(order: orders[i]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _ScanButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          border: Border.all(color: AppColors.border, width: 1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: const Icon(
          Icons.barcode_reader,
          color: AppColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color activeColor;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.activeColor = AppColors.emerald,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: activeColor,
      backgroundColor: AppColors.canvas,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected ? activeColor : AppColors.border,
        width: 1,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isBangla;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.isBangla,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRefund = order.isRefund;
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt);
    final itemCount = order.lines.fold<int>(
      0,
      (sum, l) => sum + l.qty.abs().toInt(),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isRefund
                ? AppColors.statusOutOfStock.withAlpha(80)
                : AppColors.border,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Left: icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isRefund
                    ? AppColors.statusOutOfStockBg
                    : AppColors.statusInStockBg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                isRefund ? Icons.undo_rounded : Icons.receipt_rounded,
                size: 20,
                color: isRefund
                    ? AppColors.statusOutOfStock
                    : AppColors.statusInStock,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Middle: info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          order.posReference.isNotEmpty
                              ? order.posReference
                              : (order.name?.isNotEmpty == true
                                  ? order.name!
                                  : order.uuid.substring(0, 8)),
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (order.hasRefundableLines) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _Badge(
                          label: isBangla ? 'ফেরতযোগ্য' : 'Refundable',
                          color: AppColors.emerald,
                        ),
                      ],
                      if (isRefund) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _Badge(
                          label: isBangla ? 'রিফান্ড' : 'Refund',
                          color: AppColors.statusOutOfStock,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    isBangla
                        ? '$itemCount টি বই'
                        : '$itemCount item${itemCount != 1 ? 's' : ''}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Right: amount + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatBDT(order.amountTotal),
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isRefund
                        ? AppColors.statusOutOfStock
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
