import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/dashboard_model.dart';
import '../../providers/printer_provider.dart';

/// Modal bottom sheet for viewing and generating Daily POS & Session Sales Reports.
class SalesReportSheet extends ConsumerWidget {
  final bool isBangla;
  final DashboardModel data;

  const SalesReportSheet({
    super.key,
    required this.isBangla,
    required this.data,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isBangla,
    required DashboardModel data,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SalesReportSheet(isBangla: isBangla, data: data),
    );
  }

  String _generateReportText() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final activeSession =
        data.sessions.isNotEmpty ? data.sessions.first : null;
    final sessionName = activeSession?.name ?? 'Boi Mela Session';

    final sep = '--------------------------------';
    final buf = StringBuffer();
    buf.writeln('================================');
    buf.writeln(isBangla ? '  মেটাপস দৈনিক বিক্রয় রিপোর্ট' : '   METAPOS DAILY SALES REPORT');
    buf.writeln('================================');
    buf.writeln('${isBangla ? "তারিখ ও সময়" : "Date & Time"}: $dateStr');
    buf.writeln('${isBangla ? "সেশন" : "Session"}: $sessionName');
    buf.writeln(sep);
    buf.writeln('${isBangla ? "মোট বিক্রয়" : "Gross Sales"}: ${CurrencyFormatter.formatBDT(data.revenue)}');
    buf.writeln('${isBangla ? "কর বহির্ভূত বিক্রয়" : "Untaxed Sales"}: ${CurrencyFormatter.formatBDT(data.revenueUntaxed)}');
    final taxAmount = (data.revenue - data.revenueUntaxed).clamp(0.0, double.infinity);
    buf.writeln('${isBangla ? "ভ্যাট (১০%)" : "Tax (10%)"}: ${CurrencyFormatter.formatBDT(taxAmount)}');
    buf.writeln('${isBangla ? "মোট ছাড়" : "Total Discounts"}: ${CurrencyFormatter.formatBDT(data.discounts)}');
    buf.writeln(sep);
    buf.writeln('${isBangla ? "সম্পন্ন অর্ডার" : "Total Orders"}: ${data.orders}');
    buf.writeln('${isBangla ? "বিক্রিত বই" : "Copies Sold"}: ${data.bookCopies}');
    buf.writeln('${isBangla ? "বিক্রিত শিরোনাম" : "Unique Titles"}: ${data.titles}');
    buf.writeln('${isBangla ? "গড় অর্ডার মূল্য" : "Avg Basket"}: ${CurrencyFormatter.formatBDT(data.avgBasket)}');
    buf.writeln(sep);
    buf.writeln(isBangla ? 'পেমেন্ট মাধ্যম:' : 'Payment Breakdown:');
    if (data.payments.isEmpty) {
      buf.writeln('  - Cash / Card: ${CurrencyFormatter.formatBDT(data.revenue)}');
    } else {
      for (final p in data.payments) {
        buf.writeln('  - ${p.name}: ${CurrencyFormatter.formatBDT(p.amount)} (${p.orders} orders)');
      }
    }
    if (data.topTitles.isNotEmpty) {
      buf.writeln(sep);
      buf.writeln(isBangla ? 'শীর্ষ বিক্রিত বই:' : 'Top Selling Titles:');
      for (int i = 0; i < data.topTitles.length && i < 5; i++) {
        final t = data.topTitles[i];
        buf.writeln('  ${i + 1}. ${t.name} (x${t.qty.toInt()}) - ${CurrencyFormatter.formatBDT(t.revenue)}');
      }
    }
    buf.writeln('================================');
    buf.writeln(isBangla ? 'রিপোর্ট সফলভাবে প্রস্তুতকৃত।' : 'Report generated successfully.');
    buf.writeln('================================');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerState = ref.watch(printerProvider);
    final activeSession =
        data.sessions.isNotEmpty ? data.sessions.first : null;
    final sessionName = activeSession?.name ??
        (isBangla ? 'বই মেলা/00052' : 'Boi Mela/00052');
    final cashierName = activeSession?.user ??
        (isBangla ? 'এডমিনিস্ট্রেটর' : 'Administrator');
    final taxAmount =
        (data.revenue - data.revenueUntaxed).clamp(0.0, double.infinity);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Drag Handle & Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.assessment_rounded,
                            color: AppColors.emerald,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isBangla
                                    ? 'দৈনিক বিক্রয় প্রতিবেদন'
                                    : 'Daily POS Sales Report',
                                style: AppTypography.heading2.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                isBangla
                                    ? 'সেশন: $sessionName • $cashierName'
                                    : 'Session: $sessionName • $cashierName',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Report Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Financial Summary Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.monetization_on_rounded,
                                color: AppColors.emerald,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isBangla ? 'আর্থিক বিবরণী' : 'Financial Summary',
                                style: AppTypography.bodyMediumBengali.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildRow(
                            isBangla ? 'মোট বিক্রয় (Gross)' : 'Gross Sales',
                            CurrencyFormatter.formatBDT(data.revenue),
                            isBold: true,
                            color: AppColors.emeraldDark,
                          ),
                          _buildRow(
                            isBangla ? 'কর বহির্ভূত (Untaxed)' : 'Untaxed Amount',
                            CurrencyFormatter.formatBDT(data.revenueUntaxed),
                          ),
                          _buildRow(
                            isBangla ? 'ভ্যাট (১০% VAT)' : 'Tax (10%)',
                            CurrencyFormatter.formatBDT(taxAmount),
                          ),
                          _buildRow(
                            isBangla ? 'মোট মেলা ছাড়' : 'Total Discounts',
                            CurrencyFormatter.formatBDT(data.discounts),
                            color: AppColors.statusOutOfStock,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Sales Activity Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF2563EB),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isBangla
                                    ? 'অর্ডার ও বইয়ের পরিসংখ্যান'
                                    : 'Orders & Volume Metrics',
                                style: AppTypography.bodyMediumBengali.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildRow(
                            isBangla ? 'মোট সম্পন্ন অর্ডার' : 'Completed Orders',
                            '${data.orders} টি',
                            isBold: true,
                          ),
                          _buildRow(
                            isBangla ? 'মোট বিক্রিত কপি' : 'Total Copies Sold',
                            '${data.bookCopies} কপি',
                          ),
                          _buildRow(
                            isBangla ? 'বিক্রিত শিরোনাম' : 'Unique Titles',
                            '${data.titles} টি',
                          ),
                          _buildRow(
                            isBangla ? 'গড় বাস্কেট মূল্য' : 'Average Basket',
                            CurrencyFormatter.formatBDT(data.avgBasket),
                          ),
                          _buildRow(
                            isBangla ? 'প্রতি অর্ডারে বই' : 'Books per Order',
                            data.booksPerOrder.toStringAsFixed(1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Payment Breakdown Card
                    if (data.payments.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Color(0xFF7C3AED),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isBangla
                                      ? 'পেমেন্ট মাধ্যম বিভাজন'
                                      : 'Payment Breakdown',
                                  style: AppTypography.bodyMediumBengali.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            for (final p in data.payments)
                              _buildRow(
                                '${p.name} (${p.orders} orders)',
                                CurrencyFormatter.formatBDT(p.amount),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Top Selling Books Card
                    if (data.topTitles.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFD97706),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isBangla ? 'শীর্ষ বিক্রিত বই' : 'Top Selling Titles',
                                  style: AppTypography.bodyMediumBengali.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            for (int i = 0; i < data.topTitles.length && i < 5; i++) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: AppColors.mint,
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.emeraldDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        data.topTitles[i].name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${data.topTitles[i].qty.toInt()} কপি',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),

              // Bottom Action Bar: Print & Export
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(
                            isBangla ? 'কপি করুন' : 'Copy Text',
                            style: AppTypography.bodyRegularBengali.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            final text = _generateReportText();
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.surfaceDark,
                                content: Text(
                                  isBangla
                                      ? 'রিপোর্ট ক্লিপবোর্ডে কপি করা হয়েছে'
                                      : 'Report copied to clipboard',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: AppColors.emerald,
                            foregroundColor: Colors.white,
                          ),
                          icon: printerState.isPrinting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.print_rounded, size: 18),
                          label: Text(
                            isBangla ? 'রিপোর্ট প্রিন্ট' : 'Print Report',
                            style: AppTypography.bodyRegularBengali.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: printerState.isPrinting
                              ? null
                              : () async {
                                  final text = _generateReportText();
                                  final success = await ref
                                      .read(printerProvider.notifier)
                                      .printReportReceipt(text);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: success
                                            ? AppColors.emerald
                                            : AppColors.statusOutOfStock,
                                        content: Text(
                                          success
                                              ? (isBangla
                                                  ? 'রিপোর্ট প্রিন্টারে প্রেরণ করা হয়েছে'
                                                  : 'Report sent to thermal printer')
                                              : (isBangla
                                                  ? 'প্রিন্টার সংযোগ পাওয়া যায়নি'
                                                  : 'Printer not connected'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color ??
                  (isBold ? AppColors.textPrimary : AppColors.textSecondary),
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
