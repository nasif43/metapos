import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/cart_provider.dart';

/// Dribbble/Behance-grade horizontal active cart switcher.
///
/// Enables cashiers to handle multiple concurrent walk-in customers:
/// 1. Cycle between active customer carts with 1-tap switching.
/// 2. Instant visual badges showing items count per cart.
/// 3. Add new walk-in customer cart via `+ নতুন কার্ট`.
/// 4. Discard/close held carts with confirmation.
/// 5. Long-press to rename cart (e.g. customer name).
class MultiCartTabBar extends ConsumerWidget {
  final EdgeInsetsGeometry padding;
  final bool showAddButton;

  const MultiCartTabBar({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final allCarts = cartState.allCarts;

    return Container(
      width: double.infinity,
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...allCarts.map((cart) {
              final isActive = cart.id == cartState.activeCartId;
              final itemCount = cart.totalItemsCount;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (!isActive) {
                        HapticFeedback.lightImpact();
                        cartNotifier.switchCart(cart.id);
                      }
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      _showRenameCartDialog(context, ref, cart, isBangla);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.emerald : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? AppColors.emeraldDark : AppColors.border,
                          width: isActive ? 1.5 : 1.0,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.emerald.withValues(alpha: 0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive
                                ? Icons.shopping_bag_rounded
                                : Icons.shopping_bag_outlined,
                            size: 15,
                            color: isActive ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cart.name,
                            style: TextStyle(
                              fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                              color: isActive ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : (itemCount > 0
                                      ? AppColors.emerald.withValues(alpha: 0.12)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isBangla ? '$itemCount' : '$itemCount',
                              style: TextStyle(
                                fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.white
                                    : (itemCount > 0
                                        ? AppColors.emeraldDark
                                        : AppColors.textMuted),
                              ),
                            ),
                          ),
                          if (allCarts.length > 1) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _confirmCloseCart(context, ref, cart, isBangla);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: isActive ? Colors.white70 : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (showAddButton)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    cartNotifier.addNewCart();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isBangla
                              ? 'নতুন কার্ট তৈরি করা হয়েছে'
                              : 'New customer cart created',
                          style: TextStyle(
                            fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                          ),
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.emerald,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: AppColors.emerald,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBangla ? 'নতুন কার্ট' : 'New Cart',
                          style: TextStyle(
                            fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmCloseCart(
    BuildContext context,
    WidgetRef ref,
    SingleCart cart,
    bool isBangla,
  ) {
    if (cart.isEmpty) {
      ref.read(cartProvider.notifier).removeCart(cart.id);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(
          isBangla ? '${cart.name} বন্ধ করবেন?' : 'Close ${cart.name}?',
          style: AppTypography.heading2.copyWith(fontSize: 18),
        ),
        content: Text(
          isBangla
              ? 'এই কার্টে ${cart.totalItemsCount} টি বই আছে। কার্ট বন্ধ করলে এই বইগুলো মুছে যাবে।'
              : 'This cart contains ${cart.totalItemsCount} items. Closing will discard them.',
          style: AppTypography.bodyRegularBengali,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isBangla ? 'বাতিল' : 'Cancel',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusOutOfStock,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).removeCart(cart.id);
            },
            child: Text(isBangla ? 'বন্ধ করুন' : 'Close Cart'),
          ),
        ],
      ),
    );
  }

  void _showRenameCartDialog(
    BuildContext context,
    WidgetRef ref,
    SingleCart cart,
    bool isBangla,
  ) {
    final controller = TextEditingController(text: cart.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(
          isBangla ? 'কার্টের নাম পরিবর্তন' : 'Rename Cart',
          style: AppTypography.heading2.copyWith(fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isBangla ? 'কার্ট / ক্রেতার নাম' : 'Cart / Customer Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isBangla ? 'বাতিল' : 'Cancel',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(cartProvider.notifier).renameCart(cart.id, newName);
              }
              Navigator.pop(ctx);
            },
            child: Text(isBangla ? 'সংরক্ষণ' : 'Save'),
          ),
        ],
      ),
    );
  }
}
