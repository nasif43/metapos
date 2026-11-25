import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/partner_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/session_provider.dart';
import '../../widgets/book_cover_image.dart';
import '../../widgets/language_toggle_button.dart';
import '../../widgets/multi_cart_tab_bar.dart';

/// Screen 3: CartOrderScreen (`/cart`)
///
/// Features:
/// - Fully reactive: observes and mutates `cartProvider` via Riverpod.
/// - Whole-number BDT currency rendering (zero decimals, clean integer format).
/// - Dual Discount System adhering to Odoo standards:
///   1. Line-item discounts (`pos.order.line.discount`): custom per-book discount percentages with modal selector.
///   2. Global order discounts (Fair Discount / মেলা ছাড়): applied across all cart lines.
/// - Itemized dynamic list with quantity steppers (+/-), discount pills, and delete actions.
/// - Customer selector strip wired to `PartnerModel`.
/// - Accurate MRP-inclusive 10% VAT and savings breakdown.
/// - Sticky checkout navigation button.
class CartOrderScreen extends ConsumerStatefulWidget {
  const CartOrderScreen({super.key});

  @override
  ConsumerState<CartOrderScreen> createState() => _CartOrderScreenState();
}

class _CartOrderScreenState extends ConsumerState<CartOrderScreen> {
  /// Opens dialog to customize an individual line-item discount
  void _showLineDiscountDialog(CartItemModel item) {
    final title = item.product.displayName.isNotEmpty
        ? item.product.displayName
        : item.product.name;
    final price = item.product.listPrice;
    final currentDisc = item.discount;
    double tempDisc = currentDisc;
    final odooDiscount =
        ref.read(sessionProvider).selectedConfig?.discountPc ?? 0.0;
    final List<double> presetList = [0.0];
    if (odooDiscount > 0.0 && !presetList.contains(odooDiscount)) {
      presetList.add(odooDiscount);
    }
    final textController = TextEditingController(
      text: currentDisc == currentDisc.roundToDouble()
          ? currentDisc.toInt().toString()
          : currentDisc.toString(),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final discFactor = 1.0 - (tempDisc / 100.0);
            final discountedUnitPrice = price * discFactor;
            final savingsPerUnit = price - discountedUnitPrice;

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ref.read(localeProvider).languageCode == 'bn'
                            ? 'বইয়ের ছাড়'
                            : 'Line Discount',
                        style: AppTypography.heading2.copyWith(fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Text(
                    title,
                    style: AppTypography.bodyMediumBengali.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('মূল MRP মূল্য', style: AppTypography.caption),
                            Text(
                              CurrencyFormatter.formatBDT(price),
                              style: AppTypography.bodyMedium.copyWith(
                                decoration: tempDisc > 0
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: tempDisc > 0
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (tempDisc > 0) ...[
                          const Icon(Icons.arrow_forward_rounded,
                              color: AppColors.emerald, size: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('ছাড়ের পর প্রতি বই',
                                  style: AppTypography.captionBengali),
                              Text(
                                CurrencyFormatter.formatBDT(discountedUnitPrice),
                                style: AppTypography.heading2.copyWith(
                                  color: AppColors.emeraldDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    ref.read(localeProvider).languageCode == 'bn'
                        ? 'ছাড়ের হার বেছে নিন:'
                        : 'Select Discount %:',
                    style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presetList.map((p) {
                        final isSel = (tempDisc - p).abs() < 0.01;
                        final label = p == 0.0
                            ? (ref.read(localeProvider).languageCode == 'bn'
                                ? 'ছাড় নেই'
                                : 'No Disc')
                            : '${p == p.roundToDouble() ? p.toInt() : p}%';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: Text(label),
                            selected: isSel,
                            selectedColor: AppColors.mint,
                            backgroundColor: Colors.transparent,
                            side: BorderSide(
                              color: isSel ? AppColors.emerald : AppColors.border,
                              width: isSel ? 1.5 : 1.0,
                            ),
                            labelStyle: TextStyle(
                              color: isSel
                                  ? AppColors.emeraldDark
                                  : AppColors.textPrimary,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  tempDisc = p;
                                  textController.text = p == p.roundToDouble()
                                      ? p.toInt().toString()
                                      : p.toString();
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: ref.read(localeProvider).languageCode == 'bn'
                                ? 'কাস্টম ছাড়ের হার'
                                : 'Custom Discount %',
                            suffixText: '%',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val) ?? 0.0;
                            setModalState(() {
                              tempDisc = parsed.clamp(0.0, 100.0);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(cartProvider.notifier)
                              .setLineDiscount(item.product.id, tempDisc);
                          Navigator.pop(context);
                        },
                        child: const Text('প্রয়োগ করুন'),
                      ),
                    ],
                  ),
                  if (tempDisc > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '✓ প্রতি কপিতে সাশ্রয়: ${CurrencyFormatter.formatBDT(savingsPerUnit)}',
                        style: AppTypography.captionBengali.copyWith(
                          color: AppColors.emeraldDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        );
      },
    );
  }

  /// Opens custom global discount dialog
  void _showCustomGlobalDiscountDialog(double currentPercent) {
    final textController = TextEditingController(
      text: currentPercent.toInt().toString(),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            ref.read(localeProvider).languageCode == 'bn'
                ? 'মেলার সাধারণ ছাড়'
                : 'Global Fair Discount',
            style: AppTypography.heading2.copyWith(fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'পুরো অর্ডারের সকল বইয়ের ওপর প্রযোজ্য ছাড়ের শতাংশ লিখুন:',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: ref.read(localeProvider).languageCode == 'bn'
                      ? 'ছাড়ের হার'
                      : 'Discount %',
                  suffixText: '%',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('বাতিল'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final pct = double.tryParse(textController.text) ?? 0.0;
                ref
                    .read(cartProvider.notifier)
                    .setGlobalDiscount(pct.clamp(0.0, 100.0));
                Navigator.pop(ctx);
              },
              child: const Text('প্রয়োগ করুন'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final sessionState = ref.watch(sessionProvider);
    final odooDiscount = sessionState.selectedConfig?.discountPc ?? 0.0;

    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final customerDisplayName = cartState.customer != null
        ? '${cartState.customer!.name}${cartState.customer!.phone != null ? " • ${cartState.customer!.phone}" : ""}'
        : (isBangla ? 'সাধারণ ক্রেতা' : 'Walk-in / Guest Customer');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isBangla
                ? '${cartState.activeCartName} (${cartState.totalItemsCount} টি বই)'
                : '${cartState.activeCartName} (${cartState.totalItemsCount} items)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        actions: [
          const LanguageToggleButton(),
          if (cartState.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
              tooltip: isBangla ? 'সব মুছুন' : 'Clear All',
              onPressed: () {
                cartNotifier.clearCart();
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Multi-Cart Switcher for Concurrent Walk-In Customers
          const MultiCartTabBar(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 4),
          ),
          const Divider(height: 1),

          // Customer Link Strip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(
                  Icons.person_pin_rounded,
                  color: AppColors.emeraldDark,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    customerDisplayName,
                    style: AppTypography.bodyMediumBengali.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final selected =
                        await Navigator.pushNamed(context, '/customer');
                    if (selected is PartnerModel) {
                      cartNotifier.setCustomer(selected);
                    } else if (selected == null) {
                      // Walk-in / Guest mode
                      cartNotifier.setCustomer(null);
                    }
                  },
                  child: Text(isBangla ? 'পরিবর্তন / যোগ' : 'Change / Add'),
                ),
              ],
            ),
          ),

          // Item List Header with Count & Scroll Cue
          if (cartState.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              color: AppColors.canvas,
              child: Row(
                children: [
                  const Icon(
                    Icons.format_list_numbered_rounded,
                    size: 16,
                    color: AppColors.emerald,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isBangla
                          ? 'নির্বাচিত বই (${cartState.items.length} টি • স্ক্রোল করুন)'
                          : 'Items (${cartState.items.length} books • Scroll)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isBangla
                          ? 'মোট ${cartState.totalItemsCount} টি'
                          : 'Total: ${cartState.totalItemsCount}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.emeraldDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Dynamic Items List or Empty State
          Expanded(
            child: cartState.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.remove_shopping_cart_outlined,
                              size: 40,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            isBangla ? 'কার্ট খালি' : 'Cart is empty',
                            style: AppTypography.heading1.copyWith(fontSize: 20),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            isBangla
                                ? 'অর্ডার শুরু করতে ক্যাটালগ থেকে বই যোগ করুন'
                                : 'Add books from catalog to start order',
                            style: AppTypography.bodyMediumBengali.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: Text(
                              isBangla
                                  ? 'বইয়ের তালিকায় ফিরুন'
                                  : 'Back to Catalog',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: cartState.items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final item = cartState.items[index];
                        final book = item.product;
                        final price = book.listPrice;
                        final qty = item.qty.toInt();
                        final discount = item.discount;
                        final lineGross = item.lineGross;
                        final lineNet = item.lineNetTotal;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ROW 1: Book Details (Serial, Cover Thumbnail, Full Title & Authors)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Serial Number Badge
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.mint,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: AppColors.emerald.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.emeraldDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),

                                    // Book Icon Thumbnail
                                    BookCoverImage(
                                      imageBase64: item.product.image128,
                                      width: 42,
                                      height: 52,
                                      cacheWidth: 84,
                                      cacheHeight: 104,
                                      borderRadius:
                                          BorderRadius.circular(AppSpacing.radiusSm),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),

                                    // Book Title, Authors & Unit Price
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            book.displayName.isNotEmpty
                                                ? book.displayName
                                                : book.name,
                                            style: AppTypography.bodyMediumBengali.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              height: 1.25,
                                            ),
                                          ),
                                          if (book.bookAuthorsDisplay != null &&
                                              book.bookAuthorsDisplay!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              book.bookAuthorsDisplay!,
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          if (book.bookEdition != null &&
                                              book.bookEdition!.isNotEmpty) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              book.bookEdition!,
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 3),
                                          Text(
                                            '${CurrencyFormatter.formatBDT(price)} each',
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AppSpacing.xs + 2),
                                const Divider(height: 1, thickness: 0.5, color: AppColors.border),
                                const SizedBox(height: AppSpacing.xs),

                                // ROW 2: Action Controls (Line Discount, Quantity Steppers, and Total Price)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Line-Item Discount Pill
                                    InkWell(
                                      onTap: () => _showLineDiscountDialog(item),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: discount > 0
                                              ? AppColors.mint
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: discount > 0
                                                ? AppColors.emerald
                                                : AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.local_offer_outlined,
                                              size: 12,
                                              color: discount > 0
                                                  ? AppColors.emeraldDark
                                                  : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              discount > 0
                                                  ? '${discount.toInt()}% ছাড়'
                                                  : '+ ছাড়',
                                              style: AppTypography.captionBengali.copyWith(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: discount > 0
                                                    ? AppColors.emeraldDark
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Quantity Stepper Controls
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                        border: Border.all(color: AppColors.border, width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove),
                                            color: AppColors.textSecondary,
                                            iconSize: 16,
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              cartNotifier.decrementQuantity(book.id);
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Text(
                                              '$qty',
                                              style: AppTypography.bodyMedium.copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add),
                                            color: AppColors.emerald,
                                            iconSize: 16,
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              cartNotifier.incrementQuantity(book.id);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Line Total (Strikethrough gross if discount applied)
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (discount > 0)
                                            Text(
                                              CurrencyFormatter.formatBDT(lineGross),
                                              style: AppTypography.caption.copyWith(
                                                decoration: TextDecoration.lineThrough,
                                                color: AppColors.textMuted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          Text(
                                            CurrencyFormatter.formatBDT(lineNet),
                                            style: AppTypography.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: discount > 0
                                                  ? AppColors.emeraldDark
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                    },
                  ),
                ),
          ),

          // Fair / Global Discount Bar (Synchronized dynamically with Odoo backend pos.config)
          if (cartState.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              color: AppColors.surface,
              child: Row(
                children: [
                  Text(
                    isBangla ? 'মেলা ছাড়:' : 'Fair Discount:',
                    style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...() {
                            // Strictly show only Odoo backend configured discounts (zero hardcoded auto discounts)
                            final List<double> discountList = [0.0];
                            if (odooDiscount > 0.0 && !discountList.contains(odooDiscount)) {
                              discountList.add(odooDiscount);
                            }

                            return discountList.map((pct) {
                              final isSelected =
                                  (cartState.discountPercent - pct).abs() < 0.01;
                              final label = pct == 0.0
                                  ? (isBangla ? 'ছাড় নেই' : 'No Disc')
                                  : '${pct == pct.roundToDouble() ? pct.toInt() : pct}%';
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  showCheckmark: false,
                                  label: Text(label),
                                  selected: isSelected,
                                  selectedColor: AppColors.mint,
                                  backgroundColor: Colors.transparent,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppColors.emeraldDark
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.emerald
                                        : AppColors.border,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      cartNotifier.setGlobalDiscount(pct);
                                    }
                                  },
                                ),
                              );
                            });
                          }(),
                          ...() {
                            final isCustomSelected = cartState.discountPercent > 0.0 &&
                                (odooDiscount <= 0.0 ||
                                    (cartState.discountPercent - odooDiscount).abs() >= 0.01);
                            final customPercentText = cartState.discountPercent ==
                                    cartState.discountPercent.roundToDouble()
                                ? '${cartState.discountPercent.toInt()}%'
                                : '${cartState.discountPercent}%';
                            final customLabel = isCustomSelected
                                ? (isBangla
                                    ? 'কাস্টম ($customPercentText)'
                                    : 'Custom ($customPercentText)')
                                : (isBangla ? 'কাস্টম %' : 'Custom %');

                            return [
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  showCheckmark: false,
                                  avatar: isCustomSelected
                                      ? null
                                      : const Icon(Icons.edit_outlined, size: 14),
                                  label: Text(customLabel),
                                  selected: isCustomSelected,
                                  selectedColor: AppColors.mint,
                                  backgroundColor: Colors.transparent,
                                  labelStyle: TextStyle(
                                    color: isCustomSelected
                                        ? AppColors.emeraldDark
                                        : AppColors.textPrimary,
                                    fontWeight: isCustomSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  side: BorderSide(
                                    color: isCustomSelected
                                        ? AppColors.emerald
                                        : AppColors.border,
                                    width: isCustomSelected ? 1.5 : 1.0,
                                  ),
                                  onSelected: (_) => _showCustomGlobalDiscountDialog(
                                    cartState.discountPercent,
                                  ),
                                ),
                              ),
                            ];
                          }(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Order Financial Breakdown Card (Whole BDT numbers, no decimals)
          if (cartState.items.isNotEmpty)
            Container(
              color: AppColors.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBangla ? 'উপমোট' : 'Subtotal',
                        style: AppTypography.bodyRegular,
                      ),
                      Text(
                        CurrencyFormatter.formatBDT(cartState.grossSubtotal),
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBangla ? 'মোট ছাড়' : 'Total Discount',
                        style: AppTypography.bodyRegular.copyWith(
                          color: AppColors.statusOutOfStock,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatBDTSigned(-cartState.totalDiscountAmount),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.statusOutOfStock,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBangla ? '১০% ভ্যাট অন্তর্ভুক্ত' : '10% VAT Included',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatBDT(cartState.taxAmount),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBangla ? 'সর্বমোট' : 'Grand Total',
                        style: AppTypography.heading2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        CurrencyFormatter.formatBDT(cartState.grandTotal),
                        style: AppTypography.heading1.copyWith(
                          color: AppColors.emeraldDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: cartState.isEmpty
                        ? null
                        : () {
                            Navigator.pushNamed(context, '/checkout');
                          },
                    child: Text(
                      isBangla
                          ? 'পেমেন্ট করুন • ${CurrencyFormatter.formatBDT(cartState.grandTotal)}'
                          : 'Proceed to Payment • ${CurrencyFormatter.formatBDT(cartState.grandTotal)}',
                      style: AppTypography.bodyMediumBengali.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
