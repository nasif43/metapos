import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/sync_queue_provider.dart';
import '../../widgets/barcode_scanner_sheet.dart';
import '../../widgets/book_cover_image.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/language_toggle_button.dart';
import '../../widgets/multi_cart_tab_bar.dart';

/// Screen 2: CatalogMasterScreen (`/catalog`)
///
/// Book Fair catalog grid, real dynamic Odoo 19 categories, live ISBN/search bar,
/// barcode scanner modal sheet, and bottom cart dock.
class CatalogMasterScreen extends ConsumerStatefulWidget {
  const CatalogMasterScreen({super.key});

  @override
  ConsumerState<CatalogMasterScreen> createState() => _CatalogMasterScreenState();
}

class _CatalogMasterScreenState extends ConsumerState<CatalogMasterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _syncController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(catalogProvider.notifier).loadCatalog();
    });
  }

  @override
  void dispose() {
    _syncController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Triggers full master data sync from Odoo 19 backend and pending orders queue.
  Future<void> _handleSync() async {
    _syncController.repeat();
    final isBangla = ref.read(localeProvider).languageCode == 'bn';

    try {
      final result = await ref
          .read(catalogProvider.notifier)
          .loadCatalog(forceRefresh: true);

      // Replay pending offline sales orders to Odoo if any
      ref.read(syncQueueProvider.notifier).syncPendingOrders();

      if (!mounted) return;

      if (result.success) {
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
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.emerald,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBangla
                        ? 'মাস্টার ডাটা সিঙ্ক সম্পন্ন: ${result.productsCount} টি বই, ${result.categoriesCount} টি ক্যাটাগরি'
                        : 'Master data synced: ${result.productsCount} books, ${result.categoriesCount} categories',
                    style: TextStyle(
                      fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.statusOutOfStock, width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.statusOutOfStock,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.isFromCache
                        ? (isBangla
                            ? 'অফলাইন মোড: ক্যাশ ডাটা প্রদর্শিত, ${result.productsCount} টি বই'
                            : 'Offline mode: ${result.productsCount} books cached')
                        : (isBangla
                            ? 'সিঙ্ক ব্যর্থ: ${result.errorMessage}'
                            : 'Sync failed: ${result.errorMessage}'),
                    style: TextStyle(
                      fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      _syncController.stop();
      _syncController.reset();
    }
  }

  /// Opens the Barcode / ISBN Camera Scanner & Simulation modal sheet.
  void _openBarcodeScanner() {
    final catalogState = ref.read(catalogProvider);
    final isBangla = ref.read(localeProvider).languageCode == 'bn';

    BarcodeScannerSheet.show(
      context: context,
      products: catalogState.products,
      onProductScanned: (product) {
        // Add to Riverpod cart
        ref.read(cartProvider.notifier).addItem(product);

        // Update search query to highlight matched book
        _searchController.text = product.name;
        ref.read(catalogProvider.notifier).search(product.name);
        setState(() {});

        // Floating emerald SnackBar with View Cart action
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
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.emerald,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBangla
                            ? '${product.displayName} কার্টে যোগ করা হয়েছে'
                            : '${product.displayName} added to cart',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatBDT(product.listPrice),
                        style: const TextStyle(
                          color: AppColors.emerald,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: isBangla ? 'কার্ট দেখুন' : 'View Cart',
              textColor: AppColors.emerald,
              onPressed: () {
                Navigator.pushNamed(context, '/cart');
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      onOutOfStock: (product) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.statusOutOfStock, width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.statusOutOfStock,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBangla
                        ? '${product.name} বর্তমানে স্টক শেষ'
                        : '${product.name} is out of stock',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onNotFound: (code) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.statusOutOfStock, width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.statusOutOfStock,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBangla
                        ? 'কোনো বই পাওয়া যায়নি: "$code"'
                        : 'No book found for code: "$code"',
                    style: const TextStyle(
                      color: Colors.white,
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
  }

  void _showAddedFeedback(ProductModel book, bool isBangla) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceDark,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isBangla
                    ? '${book.displayName} কার্টে যোগ হয়েছে'
                    : '${book.displayName} added to cart',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: isBangla ? 'কার্ট দেখুন ›' : 'Go to Cart ›',
          textColor: AppColors.mint,
          onPressed: () {
            Navigator.pushNamed(context, '/cart');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogProvider);
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final selectedCatId = catalogState.selectedCategoryId;
    final displayBooks = catalogState.filteredProducts;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: isBangla ? 'ড্যাশবোর্ডে ফিরুন' : 'Back to Dashboard',
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/dashboard');
          },
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 26.0, showText: false),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.statusInStockBg,
                  borderRadius: BorderRadius.circular(10),
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
                    const SizedBox(width: 5),
                    Text(
                      isBangla ? 'স্টল নং ১' : 'Stall #1',
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
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: isBangla ? 'অর্ডার ইতিহাস ও ফেরত' : 'Order History & Returns',
            onPressed: () {
              Navigator.pushNamed(context, '/orders');
            },
          ),
          // Language Toggle Button
          const LanguageToggleButton(),

          // Sync Master Data Button with Rotating Transition
          RotationTransition(
            turns: _syncController,
            child: IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: isBangla ? 'মাস্টার ডাটা সিঙ্ক' : 'Sync Master Data',
              onPressed: catalogState.isLoading ? null : _handleSync,
            ),
          ),

          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search & Scanner Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      ref.read(catalogProvider.notifier).search(val);
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: isBangla
                          ? 'বইয়ের নাম, লেখক বা ISBN দিয়ে খুঁজুন…'
                          : 'Search title, author, or ISBN…',
                      hintStyle: TextStyle(
                        fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 12,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(catalogProvider.notifier).search('');
                                setState(() {});
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: _openBarcodeScanner,
                            tooltip: isBangla ? 'বারকোড বা ISBN স্ক্যান' : 'Scan Barcode / ISBN',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dynamic Categories Strip from Odoo
          Container(
            height: 48,
            color: AppColors.surface,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(
                      isBangla ? 'সব বই' : 'All Books',
                      style: TextStyle(
                        fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                        fontWeight: selectedCatId == null ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    selected: selectedCatId == null,
                    selectedColor: AppColors.mint,
                    backgroundColor: AppColors.canvas,
                    side: BorderSide(
                      color: selectedCatId == null
                          ? AppColors.emerald
                          : AppColors.border,
                    ),
                    onSelected: (_) {
                      ref.read(catalogProvider.notifier).selectCategory(null);
                    },
                  ),
                ),
                ...catalogState.categories.map((c) {
                  final isSel = selectedCatId == c.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(
                        c.name,
                        style: TextStyle(
                          fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.mint,
                      backgroundColor: AppColors.canvas,
                      side: BorderSide(
                        color: isSel ? AppColors.emerald : AppColors.border,
                      ),
                      onSelected: (_) {
                        ref.read(catalogProvider.notifier).selectCategory(c.id);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Multi-Cart Switcher Bar for Concurrent Walk-In Customers
          const MultiCartTabBar(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, 6, AppSpacing.md, 6),
          ),
          const Divider(height: 1),

          // Product Grid
          Expanded(
            child: catalogState.isLoading && catalogState.products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: AppColors.emerald),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          isBangla
                              ? 'বই লোড হচ্ছে…'
                              : 'Loading books…',
                          style: TextStyle(
                            fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : displayBooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              isBangla
                                  ? 'কোনো বই পাওয়া যায়নি'
                                  : 'No books found',
                              style: AppTypography.heading2,
                            ),
                            if (catalogState.searchQuery?.isNotEmpty == true ||
                                selectedCatId != null) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(catalogProvider.notifier).search('');
                                  ref.read(catalogProvider.notifier).selectCategory(null);
                                  setState(() {});
                                },
                                child: Text(
                                  isBangla ? 'ফিল্টার পরিষ্কার করুন' : 'Clear filters',
                                  style: const TextStyle(color: AppColors.emerald),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: displayBooks.length,
                        itemBuilder: (context, index) {
                          final book = displayBooks[index];
                          final stock = book.bookQtyOnHand;
                          final isOutOfStock = stock <= 0;
                          final isLowStock = stock > 0 && stock <= 10;

                          final stockColor = isOutOfStock
                              ? AppColors.statusOutOfStock
                              : (isLowStock
                                  ? AppColors.statusLowStock
                                  : AppColors.statusInStock);
                          final stockBgColor = isOutOfStock
                              ? AppColors.statusOutOfStockBg
                              : (isLowStock
                                  ? AppColors.statusLowStockBg
                                  : AppColors.statusInStockBg);
                          final stockLabel = isOutOfStock
                              ? (isBangla ? 'স্টক শেষ' : 'Out of stock')
                              : (isLowStock
                                  ? (isBangla ? '$stock কপি বাকি' : '$stock left')
                                  : (isBangla ? 'মজুদ: $stock' : 'Stock: $stock'));

                          final qtyInCart = ref.watch(
                            cartProvider.select(
                              (s) => s.getQuantityForProduct(book.id),
                            ),
                          );

                          return Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: qtyInCart > 0 ? 3 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              side: BorderSide(
                                color: qtyInCart > 0
                                    ? AppColors.emerald
                                    : AppColors.border,
                                width: qtyInCart > 0 ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(cartProvider.notifier).addItem(book);
                                _showAddedFeedback(book, isBangla);
                              },
                              splashColor: AppColors.mint.withValues(alpha: 0.35),
                              highlightColor: AppColors.mint.withValues(alpha: 0.15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Thumbnail & Stock Badge
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          color: const Color(0xFFF8FAFC),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          child: Center(
                                            child: BookCoverImage(
                                              imageBase64: book.image128,
                                              width: double.infinity,
                                              height: double.infinity,
                                              cacheWidth: 240,
                                              cacheHeight: 360,
                                              fit: BoxFit.contain,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: stockBgColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: stockColor,
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              stockLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: stockColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (qtyInCart > 0)
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.emerald,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x33000000),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.check_rounded,
                                                    size: 11,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isBangla
                                                        ? '$qtyInCart টি'
                                                        : '$qtyInCart',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        if (book.barcode != null &&
                                            book.barcode!.isNotEmpty)
                                          Positioned(
                                            bottom: 6,
                                            left: 6,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                book.barcode!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Book Info & Price Display
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: isBangla
                                                ? 'HindSiliguri'
                                                : 'PlusJakartaSans',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          book.bookAuthorsDisplay ??
                                              (isBangla ? 'লেখক অজানা' : 'Author Unknown'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: isBangla
                                                ? 'HindSiliguri'
                                                : 'PlusJakartaSans',
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  CurrencyFormatter.formatBDT(
                                                    book.listPrice,
                                                  ),
                                                  style: TextStyle(
                                                    fontFamily: isBangla
                                                        ? 'HindSiliguri'
                                                        : 'PlusJakartaSans',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.emeraldDark,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (qtyInCart == 0)
                                              InkWell(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  ref.read(cartProvider.notifier).addItem(book);
                                                  _showAddedFeedback(book, isBangla);
                                                },
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.emerald,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.add_rounded,
                                                        size: 14,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        isBangla ? 'যোগ' : 'Add',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            else
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: AppColors.canvas,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: AppColors.emerald,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        HapticFeedback.lightImpact();
                                                        ref
                                                            .read(cartProvider.notifier)
                                                            .updateQuantity(
                                                              book.id,
                                                              qtyInCart - 1,
                                                            );
                                                      },
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 3,
                                                        ),
                                                        child: Icon(
                                                          Icons.remove_rounded,
                                                          size: 13,
                                                          color: AppColors.emeraldDark,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '$qtyInCart',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.emeraldDark,
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () {
                                                        HapticFeedback.lightImpact();
                                                        ref
                                                            .read(cartProvider.notifier)
                                                            .addItem(book);
                                                        _showAddedFeedback(book, isBangla);
                                                      },
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 3,
                                                        ),
                                                        child: Icon(
                                                          Icons.add_rounded,
                                                          size: 13,
                                                          color: AppColors.emeraldDark,
                                                        ),
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Sticky Mini-Cart Bottom Dock (Rebuilds only dock when cart changes)
          Consumer(
            builder: (context, ref, _) {
              final cartState = ref.watch(cartProvider);
              return Material(
                color: AppColors.surfaceDark,
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '/cart'),
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x28000000),
                          blurRadius: 16,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                            if (cartState.totalItemsCount > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.emerald,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${cartState.totalItemsCount}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isBangla
                                    ? 'মোট ${cartState.totalItemsCount} টি বই'
                                    : 'Total • ${cartState.totalItemsCount} items',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.formatBDT(cartState.grandTotal),
                                  style: AppTypography.heading2.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/cart');
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isBangla ? 'কার্ট দেখুন' : 'View Cart',
                                style: TextStyle(
                                  fontFamily: isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
