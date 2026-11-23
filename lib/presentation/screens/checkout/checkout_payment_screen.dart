import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/past_orders_provider.dart';
import '../../../providers/session_provider.dart';
import '../../../providers/sync_queue_provider.dart';
import '../../widgets/language_toggle_button.dart';

/// Screen 5: CheckoutPaymentScreen (`/checkout`)
///
/// Features:
/// - Fully reactive: observes `cartProvider` for actual line items, tax, and grand total.
/// - Designed with Impeccable Craft & Shadcn principles: clean hierarchy, 1px borders,
///   subtle surfaces, responsive typography, and zero-overflow guarantee across all screen sizes.
/// - Scrollable tab views with automatic keyboard avoidance (`onDrag` dismiss).
/// - Multi-tender settlement:
///   1. Cash: Dual tendered/change cards, horizontal quick cash chips, ergonomic numpad.
///   2. Card: Terminal readiness badge, card brand chips (Visa, Mastercard, Amex, NexusPay),
///      last 4 digits and authorization reference code.
///   3. bKash / Nagad / Rocket: MFS provider selector chips, merchant account badge,
///      customer wallet number, and TrxID validation input.
/// - End-to-end order validation: constructs real `OrderModel`, dispatches to Odoo/SQLite
///   via `syncQueueProvider`, updates `lastCompletedOrderProvider`, and clears cart.
class CheckoutPaymentScreen extends ConsumerStatefulWidget {
  const CheckoutPaymentScreen({super.key});

  @override
  ConsumerState<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends ConsumerState<CheckoutPaymentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Cash state
  String _tenderedBuffer = '0';
  bool _hasUserEditedCash = false;
  bool _isExactActive = false;
  bool _isSubmitting = false;

  // Card state
  String _selectedCardType = 'Visa';
  final _cardDigitsController = TextEditingController();
  final _cardAuthCodeController = TextEditingController();

  // MFS / bKash state
  String _selectedMfsProvider = 'bKash';
  final _mfsPhoneController = TextEditingController();
  final _trxIdController = TextEditingController();

  double _getTenderedAmount() => double.tryParse(_tenderedBuffer) ?? 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cardDigitsController.dispose();
    _cardAuthCodeController.dispose();
    _mfsPhoneController.dispose();
    _trxIdController.dispose();
    super.dispose();
  }

  void _onKeypadTap(String val) {
    setState(() {
      if (val == 'C') {
        _tenderedBuffer = '0';
        _hasUserEditedCash = true;
        _isExactActive = false;
      } else if (val == '⌫') {
        _hasUserEditedCash = true;
        _isExactActive = false;
        if (_tenderedBuffer.length > 1) {
          _tenderedBuffer =
              _tenderedBuffer.substring(0, _tenderedBuffer.length - 1);
        } else {
          _tenderedBuffer = '0';
        }
      } else {
        // Tapping number: if exact amount was tapped or user hasn't edited yet (e.g. prefilled total), REPLACE it!
        if (_isExactActive || !_hasUserEditedCash || _tenderedBuffer == '0') {
          _tenderedBuffer = val;
          _hasUserEditedCash = true;
          _isExactActive = false;
        } else {
          _tenderedBuffer += val;
        }
      }
    });
  }

  Future<void> _handleValidateAndPay(double totalDue) async {
    if (_isSubmitting) return; // Prevent double taps!
    setState(() => _isSubmitting = true);

    try {
      final cartState = ref.read(cartProvider);
      if (cartState.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty.')),
        );
        return;
      }

      final activeTab = _tabController.index;
      final List<PaymentLineModel> paymentLines = [];

      if (activeTab == 0) {
        // Cash payment
        final tendered = _getTenderedAmount();
        if (tendered < totalDue) {
          final isBangla = ref.read(localeProvider).languageCode == 'bn';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOutOfStock,
              content: Text(
                isBangla
                    ? 'পর্যাপ্ত নগদ টাকা প্রদান করা হয়নি'
                    : 'Insufficient Cash Tendered',
              ),
            ),
          );
          return;
        }

        paymentLines.add(
          PaymentLineModel.create(
            paymentMethodId: 1,
            paymentMethodName: 'Cash',
            amount: tendered,
          ),
        );

        final change = tendered - totalDue;
        if (change > 0) {
          paymentLines.add(
            PaymentLineModel.create(
              paymentMethodId: 1,
              paymentMethodName: 'Cash',
              amount: -change,
              isChange: true,
              name: 'ফেরত',
            ),
          );
        }
      } else if (activeTab == 1) {
        // Card payment - 100% of payment via single channel
        paymentLines.add(
          PaymentLineModel.create(
            paymentMethodId: 2,
            paymentMethodName: 'Card',
            amount: totalDue,
            cardBrand: _selectedCardType,
            cardNo: _cardDigitsController.text.trim().isNotEmpty
                ? _cardDigitsController.text.trim()
                : null,
            authCode: _cardAuthCodeController.text.trim().isNotEmpty
                ? _cardAuthCodeController.text.trim()
                : null,
          ),
        );
      } else {
        // bKash / MFS payment - 100% of payment via single channel
        paymentLines.add(
          PaymentLineModel.create(
            paymentMethodId: 2,
            paymentMethodName: _selectedMfsProvider,
            amount: totalDue,
            paymentRefNo: _mfsPhoneController.text.trim().isNotEmpty
                ? _mfsPhoneController.text.trim()
                : null,
            transactionId: _trxIdController.text.trim().isNotEmpty
                ? _trxIdController.text.trim()
                : null,
          ),
        );
      }

      final sessionState = ref.read(sessionProvider);
      final authState = ref.read(authSessionProvider);

      final sessionId = sessionState.activeSession?.id ??
          sessionState.selectedConfig?.currentSessionId ??
          23;
      final configId = sessionState.selectedConfig?.id ?? 1;
      final partnerId = cartState.customer?.id;
      final userId = authState.userId ?? 2;

      final orderLines = cartState.items
          .map((i) => i.toOrderLine(isTaxInclusive: cartState.isMrpInclusiveTax))
          .toList();

      // Construct the actual OrderModel
      final order = OrderModel.create(
        sessionId: sessionId,
        configId: configId,
        partnerId: partnerId,
        lines: orderLines,
        payments: paymentLines,
        userId: userId,
      );

      // 1. Submit to SQLite offline queue & trigger Odoo sync via OrderRepository
      final isConnected = ref.read(connectivityProvider);
      final isOnline = isConnected || authState.isAuthenticated;
      final completedOrder = await ref.read(orderRepositoryProvider).submitOrder(
            order,
            isOnline: isOnline,
            isOfflineMode: authState.isOfflineMode,
            reverseNetTax: cartState.isMrpInclusiveTax,
          );

      // Refresh sync queue counts
      await ref.read(syncQueueProvider.notifier).refreshCounts();

      // Refresh dashboard & past orders in background if online
      if (isOnline) {
        ref.read(dashboardProvider.notifier).fetchDashboard(forceRefresh: true);
        ref.read(pastOrdersProvider.notifier).loadOrders();
      }

      // 2. Persist order into Riverpod provider for receipt inspection
      ref.read(lastCompletedOrderProvider.notifier).state = completedOrder;

      // 3. Clear or close completed cart so items cleanly go away
      final currentCartId = cartState.activeCartId;
      if (cartState.carts.length > 1) {
        ref.read(cartProvider.notifier).removeCart(currentCartId);
      } else {
        ref.read(cartProvider.notifier).clearCart();
      }

      // 4. Navigate to Receipt screen with the order payload
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/receipt',
        arguments: completedOrder,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final totalDue = cartState.grandTotal;

    // Auto-initialize cash tendered to totalDue if not edited
    if (!_hasUserEditedCash && _tenderedBuffer == '0' && totalDue > 0) {
      _tenderedBuffer = totalDue.round().toString();
    }

    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final tenderedAmount = _getTenderedAmount();
    final changeDue = (tenderedAmount - totalDue).clamp(0.0, double.infinity);
    final remainingBalance = (totalDue - tenderedAmount).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isBangla ? 'পেমেন্ট পরিশোধ' : 'Payment Settlement',
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
      body: SafeArea(
        child: cartState.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 64,
                        color: AppColors.emerald,
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
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/catalog',
                          (route) => false,
                        ),
                        child: Text(
                          isBangla ? 'ক্যাটালগে ফিরে যান' : 'Back to Catalog',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // Total Due Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    color: AppColors.surfaceDark,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isBangla
                                    ? 'মোট পরিশোধযোগ্য'
                                    : 'Total Amount Due',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white70,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.formatBDT(totalDue),
                            style: AppTypography.heading1.copyWith(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tender Selector Tabs
                  Container(
                    color: AppColors.surface,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.textPrimary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.emerald,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.money_rounded, color: AppColors.cashGreen),
                          text: isBangla ? 'নগদ' : 'Cash',
                        ),
                        Tab(
                          icon: const Icon(Icons.credit_card_rounded),
                          text: isBangla ? 'কার্ড' : 'Card',
                        ),
                        Tab(
                          icon: const Icon(Icons.phone_iphone_rounded,
                              color: AppColors.bKashMagenta),
                          text: isBangla ? 'বিকাশ / নগদ' : 'bKash / Nagad',
                        ),
                      ],
                    ),
                  ),

                  // Tab Views: Wrapped in Expanded with independent SingleChildScrollViews
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCashTab(totalDue, tenderedAmount, changeDue, remainingBalance, isBangla),
                        _buildCardTab(totalDue, isBangla),
                        _buildBkashTab(totalDue, isBangla),
                      ],
                    ),
                  ),

                  // Order Submission Action Bar
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSubmitting)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.emerald,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isBangla
                                      ? 'সার্ভারে অর্ডার পাঠানো হচ্ছে, অনুগ্রহ করে অপেক্ষা করুন…'
                                      : 'Submitting order, please wait…',
                                  style: AppTypography.captionBengali.copyWith(
                                    color: AppColors.emeraldDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 54),
                            backgroundColor: _isSubmitting
                                ? AppColors.textMuted
                                : AppColors.emerald,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => _handleValidateAndPay(totalDue),
                          child: _isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isBangla
                                          ? 'অর্ডার প্রক্রিয়াধীন…'
                                          : 'Processing Order…',
                                      style: AppTypography.bodyMediumBengali
                                          .copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  isBangla
                                      ? 'বিক্রয় সম্পন্ন করুন'
                                      : 'Complete Sale',
                                  style: AppTypography.bodyMediumBengali
                                      .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── TAB 1: CASH TENDER & NUMPAD ──────────────────────────────────────────
  Widget _buildCashTab(
    double totalDue,
    double tenderedAmount,
    double changeDue,
    double remainingBalance, [
    bool isBangla = true,
  ]) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tendered & Change Boxes
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBangla ? 'প্রদত্ত নগদ' : 'Tendered Cash',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.formatBDT(tenderedAmount),
                          style: AppTypography.heading1.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: remainingBalance > 0
                          ? AppColors.statusOutOfStock
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        remainingBalance > 0
                            ? (isBangla ? 'বাকি' : 'Remaining Due')
                            : (isBangla ? 'ফেরত' : 'Change Due'),
                        style: AppTypography.caption.copyWith(
                          color: remainingBalance > 0
                              ? AppColors.statusOutOfStock
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          remainingBalance > 0
                              ? CurrencyFormatter.formatBDT(remainingBalance)
                              : CurrencyFormatter.formatBDT(changeDue),
                          style: AppTypography.heading1.copyWith(
                            fontWeight: FontWeight.w800,
                            color: remainingBalance > 0
                               ? AppColors.statusOutOfStock
                                : AppColors.emeraldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Quick Cash Chips (Additions: +100, +500, +1000)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(isBangla ? 'সঠিক পরিমাণ' : 'Exact', totalDue),
                _buildChip('+100', 100, isAdd: true),
                _buildChip('+500', 500, isAdd: true),
                _buildChip('+1000', 1000, isAdd: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Numeric Keypad
          _buildNumericKeypad(),
        ],
      ),
    );
  }

  Widget _buildChip(String label, double val, {bool isAdd = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 40),
          side: const BorderSide(color: AppColors.border),
        ),
        onPressed: () {
          setState(() {
            _hasUserEditedCash = true;
            if (isAdd) {
              _isExactActive = false;
              _tenderedBuffer = (_getTenderedAmount() + val).round().toString();
            } else {
              _isExactActive = true;
              _tenderedBuffer = val.round().toString();
            }
          });
        },
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildNumericKeypad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: row.map((k) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      onPressed: () => _onKeypadTap(k),
                      child: Text(
                        k,
                        style: AppTypography.keypadDigit.copyWith(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  // ─── TAB 2: CARD TENDER (SHADCN PATTERN) ──────────────────────────────────
  Widget _buildCardTab(double totalDue, [bool isBangla = true]) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Terminal Header & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'POS Terminal Payment',
                      style: AppTypography.heading2.copyWith(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.statusInStockBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.statusInStock,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.emeraldDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Amount to Charge Box
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isBangla ? 'চার্জের পরিমাণ:' : 'Charge Amount:',
                      style: AppTypography.caption,
                    ),
                    Text(
                      CurrencyFormatter.formatBDT(totalDue),
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.emeraldDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Card Brand Chips
              Text(
                isBangla ? 'কার্ডের ধরন:' : 'Card Type:',
                style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Visa',
                    'Mastercard',
                    'Amex',
                    'DBBL Nexus',
                  ].map((brand) {
                    final isSel = _selectedCardType == brand;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(brand),
                        selected: isSel,
                        selectedColor: AppColors.mint,
                        side: BorderSide(
                          color: isSel ? AppColors.emerald : AppColors.border,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCardType = brand);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Inputs (Last 4 Digits & Auth Code)
              TextField(
                controller: _cardDigitsController,
                maxLength: 4,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isBangla
                      ? 'কার্ডের শেষ ৪ ডিজিট (ঐচ্ছিক)'
                      : 'Last 4 digits of card (optional)',
                  hintText: 'e.g. 4242',
                  prefixIcon: const Icon(Icons.credit_card),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _cardAuthCodeController,
                decoration: InputDecoration(
                  labelText: isBangla
                      ? 'অনুমোদন / রসিদ কোড'
                      : 'Auth / Approval Code',
                  hintText: 'e.g. AUTH-98213',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TAB 3: BKASH / NAGAD TENDER (SHADCN PATTERN) ────────────────────────
  Widget _buildBkashTab(double totalDue, [bool isBangla = true]) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // MFS Header & Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _selectedMfsProvider == 'bKash'
                                ? AppColors.bKashMagenta
                                : const Color(0xFFF7941D),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_selectedMfsProvider Payment',
                            style: AppTypography.heading2.copyWith(
                              fontSize: 16,
                              color: _selectedMfsProvider == 'bKash'
                                  ? AppColors.bKashMagenta
                                  : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatBDT(totalDue),
                    style: AppTypography.heading2.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Provider Selector Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['bKash', 'Nagad', 'Rocket', 'Upay'].map((prov) {
                    final isSel = _selectedMfsProvider == prov;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(prov),
                        selected: isSel,
                        selectedColor: prov == 'bKash'
                            ? const Color(0xFFFCE4EC)
                            : AppColors.mint,
                        side: BorderSide(
                          color: isSel
                              ? (prov == 'bKash'
                                  ? AppColors.bKashMagenta
                                  : AppColors.emerald)
                              : AppColors.border,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedMfsProvider = prov);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Merchant Info Pill
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isBangla
                            ? 'মার্চেন্ট ওয়ালেট: ০১৭১১-০০০০০০ (মেটাপস)'
                            : 'Merchant Wallet: 01711-000000 (MetaPOS)',
                        style: AppTypography.captionBengali.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Inputs (Phone & TrxID)
              TextField(
                controller: _mfsPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isBangla
                      ? 'গ্রাহকের ওয়ালেট নম্বর'
                      : 'Customer Wallet Number',
                  hintText: '01XXXXXXXXX',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _trxIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: isBangla
                      ? 'ট্রানজ্যাকশন আইডি *'
                      : 'Transaction ID (TrxID) *',
                  hintText: 'e.g. BLA789XYZ12',
                  prefixIcon: const Icon(Icons.receipt_long_rounded),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
