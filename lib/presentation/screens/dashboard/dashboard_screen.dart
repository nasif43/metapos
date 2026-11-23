import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/dashboard_model.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/language_toggle_button.dart';

/// Primary Home Screen: Mobile-first Book Fair Management & Sales Dashboard.
///
/// Features:
/// 1. Quick POS Action Hero Banner
/// 2. 8 KPI Metric Cards (Revenue, Orders, Copies, Titles, Avg Basket, Discounts, Customers, Books/Order)
/// 3. 2 Statistics Histograms (Hourly Revenue & Hourly Orders)
/// 4. Direct navigation to POS Register (`/catalog`)
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Initial load of catalog and dashboard telemetry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).fetchDashboard();
      ref.read(catalogProvider.notifier).loadCatalog();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    _refreshController.repeat();
    try {
      await Future.wait([
        ref.read(dashboardProvider.notifier).fetchDashboard(forceRefresh: true),
        ref.read(catalogProvider.notifier).loadCatalog(forceRefresh: true),
      ]);
    } finally {
      _refreshController.stop();
      _refreshController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final data = dashboardState.data;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Row(
          children: [
            const BrandLogo(size: 24.0, showText: false),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isBangla ? 'বইমেলা ড্যাশবোর্ড' : 'Book Fair Dashboard',
                  style: TextStyle(
                    fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: isBangla ? 'অর্ডার ইতিহাস ও ফেরত' : 'Order History & Returns',
            onPressed: () {
              Navigator.pushNamed(context, '/orders');
            },
          ),
          const LanguageToggleButton(),
          RotationTransition(
            turns: _refreshController,
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: isBangla ? 'রিফ্রেশ' : 'Refresh Data',
              onPressed: dashboardState.isLoading ? null : _handleRefresh,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: isBangla ? 'লগআউট' : 'Log Out',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.point_of_sale_rounded, size: 22),
        label: Text(
          isBangla ? 'পয়েন্ট অব সেল' : 'Point of Sale',
          style: TextStyle(
            fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        onPressed: () {
          Navigator.pushNamed(context, '/catalog');
        },
      ),
      body: RefreshIndicator(
        color: AppColors.emerald,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero CTA Banner
              _buildHeroPosBanner(context, isBangla, data),
              const SizedBox(height: AppSpacing.lg),

              // 2. Section Header: 8 KPI Cards
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.emerald,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBangla ? 'আজকের পরিসংখ্যান' : "Today's Overview",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading2.copyWith(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // 8 KPI Cards Grid (4 rows x 2 cols)
              _buildKpiGrid(isBangla, data),
              const SizedBox(height: AppSpacing.xl),

              // 3. Section Header: Histograms
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBangla ? 'ঘণ্টা প্রতি পরিসংখ্যান' : 'Hourly Statistics',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading2.copyWith(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Histogram 1: Hourly Revenue
              _buildHourlyRevenueHistogram(isBangla, data.hourly),
              const SizedBox(height: AppSpacing.lg),

              // Histogram 2: Hourly Orders
              _buildHourlyOrdersHistogram(isBangla, data.hourly),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }

  /// Top hero banner with live Odoo session telemetry and POS navigation.
  Widget _buildHeroPosBanner(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    final activeSession = data.sessions.isNotEmpty ? data.sessions.first : null;
    final stallTitle = activeSession != null
        ? '${activeSession.config} (${activeSession.name})'
        : (isBangla ? 'বইমেলা স্টল নং ১' : 'Book Fair Stall #1');
    final sessionStatus = activeSession != null
        ? '${activeSession.stateLabel} • ${activeSession.user}'
        : (isBangla ? 'লাইভ সেশন সক্রিয়' : 'Live Session Active');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surfaceDark, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusInStockBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.statusInStock,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          stallTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.emeraldDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  sessionStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isBangla ? 'অমর একুশে বইমেলা ২০২৬' : 'Amar Ekushey Boi Mela 2026',
            style: AppTypography.heading1.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            activeSession != null
                ? (isBangla
                    ? 'মোট সেশন কালেকশন: ${CurrencyFormatter.formatBDT(activeSession.revenue)} (${activeSession.orders} টি অর্ডার)'
                    : 'Total Session: ${CurrencyFormatter.formatBDT(activeSession.revenue)} (${activeSession.orders} orders)')
                : (isBangla ? 'বইমেলা রেজিস্টার' : 'Book Fair Register'),
            style: AppTypography.bodyRegularBengali.copyWith(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// 8 Interactive Functional KPI Cards arranged in a 2-column Grid.
  Widget _buildKpiGrid(bool isBangla, DashboardModel data) {
    final kpiItems = [
      _KpiData(
        title: isBangla ? 'দৈনিক আয়' : 'Daily Sales',
        value: CurrencyFormatter.formatBDT(data.revenue),
        subtitle: data.payments.isNotEmpty
            ? '${data.payments.first.name}: ${CurrencyFormatter.formatBDT(data.payments.first.amount)}'
            : (isBangla ? 'বিস্তারিত দেখুন ›' : 'View details ›'),
        icon: Icons.monetization_on_rounded,
        accentColor: AppColors.emerald,
        bgColor: const Color(0xFFE8F9F1),
        onTap: () => _showRevenueDetails(context, isBangla, data),
      ),
      _KpiData(
        title: isBangla ? 'মোট অর্ডার' : 'Total Orders',
        value: isBangla ? '${data.orders} টি' : '${data.orders}',
        subtitle: data.previousOrders > 0
            ? (isBangla ? 'পূর্ববর্তী: ${data.previousOrders} টি' : 'Prev: ${data.previousOrders}')
            : (isBangla ? 'অর্ডার তালিকা ›' : 'Order list ›'),
        icon: Icons.receipt_long_rounded,
        accentColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        onTap: () => _showOrdersDetails(context, isBangla, data),
      ),
      _KpiData(
        title: isBangla ? 'মোট বই বিক্রি' : 'Copies Sold',
        value: isBangla ? '${data.bookCopies} কপি' : '${data.bookCopies}',
        subtitle: data.topTitles.isNotEmpty
            ? (isBangla ? '${data.topTitles.length} টি শীর্ষ বই ›' : '${data.topTitles.length} top books ›')
            : (isBangla ? 'বিক্রিত বইসমূহ ›' : 'Sold books ›'),
        icon: Icons.menu_book_rounded,
        accentColor: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
        onTap: () => _showTopTitlesDetails(context, isBangla, data),
      ),
      _KpiData(
        title: isBangla ? 'বিক্রিত শিরোনাম' : 'Unique Titles',
        value: isBangla ? '${data.titles} টি' : '${data.titles}',
        subtitle: data.genres.isNotEmpty
            ? (isBangla ? '${data.genres.length} টি জঁনর ›' : '${data.genres.length} genres ›')
            : (isBangla ? 'ক্যাটাগরি ভিত্তিক ›' : 'Category breakdown ›'),
        icon: Icons.auto_stories_rounded,
        accentColor: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        onTap: () => _showGenresDetails(context, isBangla, data),
      ),
      _KpiData(
        title: isBangla ? 'গড় অর্ডার মূল্য' : 'Average Basket',
        value: CurrencyFormatter.formatBDT(data.avgBasket),
        subtitle: isBangla
            ? 'প্রতি অর্ডারে ${data.booksPerOrder.toStringAsFixed(1)} বই'
            : '${data.booksPerOrder.toStringAsFixed(1)} books/order',
        icon: Icons.shopping_basket_rounded,
        accentColor: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
        onTap: () => _showAvgBasketDetails(context, isBangla, data),
      ),
      _KpiData(
        title: isBangla ? 'মোট মেলা ছাড়' : 'Total Discounts',
        value: CurrencyFormatter.formatBDT(data.discounts),
        subtitle: isBangla ? 'মেলা হার ১০% ছাড় ›' : 'Fair 10% rate ›',
        icon: Icons.discount_rounded,
        accentColor: const Color(0xFFE11D48),
        bgColor: const Color(0xFFFFF1F2),
        onTap: () => _showDiscountsDetails(context, isBangla, data),
      ),
      _KpiData(
        title: isBangla ? 'মোট ক্রেতা' : 'Customers',
        value: isBangla ? '${data.customers} জন' : '${data.customers}',
        subtitle: isBangla ? 'ক্রেতা পরিসংখ্যান ›' : 'Customer telemetry ›',
        icon: Icons.group_rounded,
        accentColor: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF),
        onTap: () => _showCustomersDetails(context, isBangla, data),
      ),
      _KpiData(
        title: isBangla ? 'প্রতি অর্ডারে বই' : 'Books Per Order',
        value: data.booksPerOrder.toStringAsFixed(1),
        subtitle: isBangla ? 'গড় ঝুড়ি গভীরতা ›' : 'Basket depth ›',
        icon: Icons.library_books_rounded,
        accentColor: const Color(0xFF0891B2),
        bgColor: const Color(0xFFECFEFF),
        onTap: () => _showBooksPerOrderDetails(context, isBangla, data),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpiItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.22,
      ),
      itemBuilder: (context, index) {
        final item = kpiItems[index];
        return _buildKpiCard(item, isBangla);
      },
    );
  }

  Widget _buildKpiCard(_KpiData item, bool isBangla) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        splashColor: item.accentColor.withValues(alpha: 0.12),
        highlightColor: item.accentColor.withValues(alpha: 0.06),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, size: 16, color: item.accentColor),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.value,
                      style: TextStyle(
                        fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                        fontSize: 10,
                        color: item.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Odoo Interface Drill-Down Bottom Sheets ---

  void _showRevenueDetails(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    _showDrillDownSheet(
      context: context,
      title: isBangla ? 'বিক্রয় ও পেমেন্ট বিবরণী' : 'Sales & Payment Breakdown',
      icon: Icons.monetization_on_rounded,
      accentColor: AppColors.emerald,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricRow(
            isBangla ? 'মোট গ্রস রাজস্ব' : 'Gross Sales Revenue',
            CurrencyFormatter.formatBDT(data.revenue),
            isBold: true,
            color: AppColors.emeraldDark,
          ),
          _buildMetricRow(
            isBangla ? 'কর ব্যতীত বিক্রয়' : 'Untaxed Revenue',
            CurrencyFormatter.formatBDT(data.revenueUntaxed),
          ),
          _buildMetricRow(
            isBangla ? '১০% ভ্যাট অন্তর্ভুক্ত' : '10% VAT Included',
            CurrencyFormatter.formatBDT(data.revenue - data.revenueUntaxed),
          ),
          if (data.refunds > 0)
            _buildMetricRow(
              isBangla ? 'রিফান্ড / ফেরত' : 'Refunds',
              CurrencyFormatter.formatBDT(data.refunds),
              color: AppColors.statusOutOfStock,
            ),
          const Divider(height: 24),
          Text(
            isBangla ? 'পেমেন্ট মেথড বিভাজন' : 'Payment Methods Breakdown',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (data.payments.isEmpty)
            Text(
              isBangla ? 'কোনো পেমেন্ট রেকর্ড নেই' : 'No payments recorded',
              style: const TextStyle(color: AppColors.textMuted),
            )
          else
            ...data.payments.map((p) => _buildMetricRow(
                  '${p.name} (${p.orders} orders)',
                  CurrencyFormatter.formatBDT(p.amount),
                )),
          if (data.previousRevenue > 0) ...[
            const Divider(height: 24),
            _buildMetricRow(
              isBangla ? 'পূর্ববর্তী সেশন বিক্রয়' : 'Previous Session Revenue',
              CurrencyFormatter.formatBDT(data.previousRevenue),
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }

  void _showOrdersDetails(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    _showDrillDownSheet(
      context: context,
      title: isBangla ? 'অর্ডার পরিসংখ্যান' : 'Orders Overview',
      icon: Icons.receipt_long_rounded,
      accentColor: const Color(0xFF2563EB),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricRow(
            isBangla ? 'মোট সম্পন্ন অর্ডার' : 'Completed Orders',
            '${data.orders} টি',
            isBold: true,
            color: const Color(0xFF2563EB),
          ),
          _buildMetricRow(
            isBangla ? 'পূর্ববর্তী সময়ের অর্ডার' : 'Previous Period Orders',
            '${data.previousOrders} টি',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: Text(
              isBangla ? 'অর্ডার হিস্টোরি ও রিসিট দেখুন' : 'View Order History',
            ),
            onPressed: () {
              Navigator.pop(context);
              _showOrdersDetails(context, isBangla, data);
            },
          ),
        ],
      ),
    );
  }

  void _showTopTitlesDetails(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    _showDrillDownSheet(
      context: context,
      title: isBangla ? 'শীর্ষ বিক্রিত বইসমূহ' : 'Top Selling Titles',
      icon: Icons.menu_book_rounded,
      accentColor: const Color(0xFF7C3AED),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricRow(
            isBangla ? 'মোট বিক্রিত বই' : 'Total Copies Sold',
            '${data.bookCopies} কপি',
            isBold: true,
          ),
          const Divider(height: 20),
          if (data.topTitles.isEmpty)
            Text(
              isBangla ? 'শীর্ষ বিক্রিত বই রেকর্ড নেই' : 'No top titles recorded',
              style: const TextStyle(color: AppColors.textMuted),
            )
          else
            ...data.topTitles.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            if (t.authors != null && t.authors!.isNotEmpty)
                              Text(
                                t.authors!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${t.qty.toInt()} কপি',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatBDT(t.revenue),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  void _showGenresDetails(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    _showDrillDownSheet(
      context: context,
      title: isBangla ? 'জনপ্রিয় ক্যাটাগরি ও জঁনর' : 'Top Genres & Categories',
      icon: Icons.auto_stories_rounded,
      accentColor: const Color(0xFFD97706),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricRow(
            isBangla ? 'মোট শিরোনাম' : 'Unique Titles',
            '${data.titles} টি',
            isBold: true,
          ),
          const Divider(height: 20),
          if (data.genres.isEmpty)
            Text(
              isBangla ? 'জঁনর পরিসংখ্যান রেকর্ড নেই' : 'No genre telemetry',
              style: const TextStyle(color: AppColors.textMuted),
            )
          else
            ...data.genres.map((g) => _buildMetricRow(
                  g.name,
                  '${g.qty.toInt()} কপি • ${CurrencyFormatter.formatBDT(g.revenue)}',
                )),
        ],
      ),
    );
  }

  void _showAvgBasketDetails(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    _showDrillDownSheet(
      context: context,
      title: isBangla ? 'গড় বাস্কেট বিশ্লেষণ' : 'Basket Telemetry',
      icon: Icons.shopping_basket_rounded,
      accentColor: const Color(0xFF0D9488),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricRow(
            isBangla ? 'বর্তমান গড় অর্ডার মূল্য' : 'Average Basket Value',
            CurrencyFormatter.formatBDT(data.avgBasket),
            isBold: true,
            color: const Color(0xFF0D9488),
          ),
          _buildMetricRow(
            isBangla ? 'পূর্ববর্তী গড় অর্ডার মূল্য' : 'Previous Avg Basket',
            CurrencyFormatter.formatBDT(data.previousAvgBasket),
          ),
          _buildMetricRow(
            isBangla ? 'প্রতি অর্ডারে বইয়ের সংখ্যা' : 'Books per Order',
            '${data.booksPerOrder.toStringAsFixed(1)} কপি',
          ),
        ],
      ),
    );
  }

  void _showDiscountsDetails(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    _showDrillDownSheet(
      context: context,
      title: isBangla ? 'মেলা ছাড় বিশ্লেষণ' : 'Fair Discount Details',
      icon: Icons.discount_rounded,
      accentColor: const Color(0xFFE11D48),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricRow(
            isBangla ? 'মোট মেলা ছাড় প্রদান' : 'Total Discounts Granted',
            CurrencyFormatter.formatBDT(data.discounts),
            isBold: true,
            color: const Color(0xFFE11D48),
          ),
          _buildMetricRow(
            isBangla ? 'স্ট্যান্ডার্ড বইমেলা হার' : 'Standard Boi Mela Rate',
            '১০% ফ্ল্যাট ছাড়',
          ),
          _buildMetricRow(
            isBangla ? 'পূর্ববর্তী সেশন মোট ছাড়' : 'Previous Session Discounts',
            CurrencyFormatter.formatBDT(data.previousDiscounts),
          ),
        ],
      ),
    );
  }

  void _showCustomersDetails(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    _showDrillDownSheet(
      context: context,
      title: isBangla ? 'ক্রেতা পরিসংখ্যান' : 'Customer Telemetry',
      icon: Icons.group_rounded,
      accentColor: const Color(0xFF4F46E5),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricRow(
            isBangla ? 'মোট ক্রেতা' : 'Total Customers',
            '${data.customers} জন',
            isBold: true,
          ),
          _buildMetricRow(
            isBangla ? 'সাধারণ পথচারী ক্রেতা' : 'Walk-in / Guest Customers',
            isBangla ? 'সক্রিয়' : 'Active',
          ),
          _buildMetricRow(
            isBangla ? 'নিবন্ধিত গ্রাহক ফোন সার্চ' : 'Customer Phone Search',
            isBangla ? 'সক্রিয়' : 'Enabled',
          ),
        ],
      ),
    );
  }

  void _showBooksPerOrderDetails(
    BuildContext context,
    bool isBangla,
    DashboardModel data,
  ) {
    _showDrillDownSheet(
      context: context,
      title: isBangla ? 'অর্ডার গভীরতা বিশ্লেষণ' : 'Order Depth Analysis',
      icon: Icons.library_books_rounded,
      accentColor: const Color(0xFF0891B2),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricRow(
            isBangla ? 'প্রতি অর্ডারে বইয়ের অনুপাত' : 'Books Per Order Ratio',
            '${data.booksPerOrder.toStringAsFixed(1)} কপি',
            isBold: true,
            color: const Color(0xFF0891B2),
          ),
          _buildMetricRow(
            isBangla ? 'মোট বই কপি' : 'Total Book Copies',
            '${data.bookCopies} কপি',
          ),
          _buildMetricRow(
            isBangla ? 'মোট অর্ডার' : 'Total Orders',
            '${data.orders} টি',
          ),
        ],
      ),
    );
  }

  void _showDrillDownSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 20),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
              color: color ?? (isBold ? AppColors.textPrimary : AppColors.textSecondary),
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Histogram 1: Hourly Sales Revenue in BDT
  Widget _buildHourlyRevenueHistogram(bool isBangla, List<HourlyStat> hourly) {
    return _buildHistogram(
      title: isBangla ? 'ঘণ্টা প্রতি বিক্রয়' : 'Hourly Sales',
      emptyMessage: isBangla
          ? 'আজকে এখনও কোনো বিক্রয় ডাটা রেকর্ড হয়নি'
          : 'No hourly sales recorded yet today',
      isBangla: isBangla,
      hourly: hourly,
      getValue: (h) => h.revenue,
      formatValue: (h) => _formatCompactBdt(h.revenue),
      valueColor: AppColors.emeraldDark,
      gradientColors: const [AppColors.emerald, Color(0xFF059669)],
    );
  }

  /// Histogram 2: Hourly Orders Volume
  Widget _buildHourlyOrdersHistogram(bool isBangla, List<HourlyStat> hourly) {
    return _buildHistogram(
      title: isBangla ? 'ঘণ্টা প্রতি অর্ডার' : 'Hourly Orders',
      emptyMessage: isBangla
          ? 'আজকে এখনও কোনো অর্ডার সম্পন্ন হয়নি'
          : 'No orders recorded yet today',
      isBangla: isBangla,
      hourly: hourly,
      getValue: (h) => h.orders.toDouble(),
      formatValue: (h) => '${h.orders}',
      valueColor: const Color(0xFF1D4ED8),
      gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    );
  }

  Widget _buildHistogram({
    required String title,
    required String emptyMessage,
    required bool isBangla,
    required List<HourlyStat> hourly,
    required double Function(HourlyStat) getValue,
    required String Function(HourlyStat) formatValue,
    required Color valueColor,
    required List<Color> gradientColors,
  }) {
    final maxValue = hourly.fold<double>(
      0.0,
      (max, e) => getValue(e) > max ? getValue(e) : max,
    );

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hourly.isEmpty)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: Text(
                emptyMessage,
                style: AppTypography.bodyRegularBengali.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: hourly.map((h) {
                  final val = getValue(h);
                  final double ratio = maxValue > 0 ? (val / maxValue) : 0.0;
                  final double barHeight = (ratio * 80).clamp(6.0, 80.0);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatValue(h),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: valueColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradientColors,
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isBangla ? h.hourLabelBn : h.hourLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCompactBdt(double amount) {
    return CurrencyFormatter.formatBDTCompact(amount);
  }
}

class _KpiData {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final VoidCallback? onTap;

  const _KpiData({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    this.onTap,
  });
}
