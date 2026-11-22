import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/order_model.dart';
import '../data/models/partner_model.dart';
import '../data/models/product_model.dart';

/// Individual cart line item.
class CartItemModel {
  final ProductModel product;
  final double qty;
  final double discount; // 0.0 to 100.0 (Line item discount percentage)
  final bool hasCustomDiscount; // Whether individually set/locked

  const CartItemModel({
    required this.product,
    this.qty = 1.0,
    this.discount = 0.0,
    this.hasCustomDiscount = false,
  });

  /// Original gross amount before discount.
  double get lineGross => product.listPrice * qty;

  /// Absolute monetary savings on this line item.
  double get lineDiscountAmount => lineGross * (discount / 100.0);

  /// Net total after line discount.
  double get lineNetTotal => lineGross - lineDiscountAmount;

  CartItemModel copyWith({
    ProductModel? product,
    double? qty,
    double? discount,
    bool? hasCustomDiscount,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      discount: discount ?? this.discount,
      hasCustomDiscount: hasCustomDiscount ?? this.hasCustomDiscount,
    );
  }

  /// Converts cart item into an OrderLineModel.
  OrderLineModel toOrderLine({
    bool isTaxInclusive = true,
    double taxRate = 0.10,
  }) {
    return OrderLineModel.create(
      productId: product.id,
      productName: product.displayName.isNotEmpty ? product.displayName : product.name,
      qty: qty,
      priceUnit: product.listPrice,
      discount: discount,
      taxIds: product.taxesId.isNotEmpty ? product.taxesId : [1],
      taxRate: taxRate,
      isTaxInclusive: isTaxInclusive,
    );
  }
}

/// Model representing an individual walk-in customer's active cart.
class SingleCart {
  final String id;
  final String name; // e.g. "কার্ট ১" / "Cart 1"
  final List<CartItemModel> items;
  final PartnerModel? customer;
  final double discountPercent; // Order-wide global discount percentage
  final double grossSubtotal; // Undiscounted MRP gross sum
  final double totalDiscountAmount; // Total discount savings across all lines
  final double subtotal; // Net taxable base
  final double taxAmount; // 10% VAT
  final double grandTotal; // Final payable amount
  final bool isMrpInclusiveTax; // Default true (Bangladeshi publishing standard)
  final DateTime createdAt;

  const SingleCart({
    required this.id,
    required this.name,
    this.items = const [],
    this.customer,
    this.discountPercent = 0.0,
    this.grossSubtotal = 0.0,
    this.totalDiscountAmount = 0.0,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.grandTotal = 0.0,
    this.isMrpInclusiveTax = true,
    required this.createdAt,
  });

  int get totalItemsCount =>
      items.fold(0, (sum, item) => sum + item.qty.toInt());

  int getQuantityForProduct(int productId) {
    for (final item in items) {
      if (item.product.id == productId) {
        return item.qty.toInt();
      }
    }
    return 0;
  }

  bool get isEmpty => items.isEmpty;

  SingleCart copyWith({
    String? id,
    String? name,
    List<CartItemModel>? items,
    PartnerModel? customer,
    bool clearCustomer = false,
    double? discountPercent,
    double? grossSubtotal,
    double? totalDiscountAmount,
    double? subtotal,
    double? taxAmount,
    double? grandTotal,
    bool? isMrpInclusiveTax,
    DateTime? createdAt,
  }) {
    return SingleCart(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      customer: clearCustomer ? null : (customer ?? this.customer),
      discountPercent: discountPercent ?? this.discountPercent,
      grossSubtotal: grossSubtotal ?? this.grossSubtotal,
      totalDiscountAmount: totalDiscountAmount ?? this.totalDiscountAmount,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      isMrpInclusiveTax: isMrpInclusiveTax ?? this.isMrpInclusiveTax,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// State representation for active POS multi-cart management.
class CartState {
  final Map<String, SingleCart> carts;
  final String activeCartId;

  CartState({
    Map<String, SingleCart>? carts,
    String? activeCartId,
    // Optional legacy parameters for 100% backwards compatibility
    List<CartItemModel>? items,
    PartnerModel? customer,
    double? discountPercent,
    double? grossSubtotal,
    double? totalDiscountAmount,
    double? subtotal,
    double? taxAmount,
    double? grandTotal,
    bool isMrpInclusiveTax = true,
  })  : carts = carts ??
            {
              'cart_1': SingleCart(
                id: 'cart_1',
                name: 'কার্ট ১',
                items: items ?? const [],
                customer: customer,
                discountPercent: discountPercent ?? 0.0,
                grossSubtotal: grossSubtotal ?? 0.0,
                totalDiscountAmount: totalDiscountAmount ?? 0.0,
                subtotal: subtotal ?? 0.0,
                taxAmount: taxAmount ?? 0.0,
                grandTotal: grandTotal ?? 0.0,
                isMrpInclusiveTax: isMrpInclusiveTax,
                createdAt: DateTime.now(),
              )
            },
        activeCartId = activeCartId ?? 'cart_1';

  /// Currently active cart being viewed or edited by cashier.
  SingleCart get activeCart =>
      carts[activeCartId] ??
      (carts.isNotEmpty
          ? carts.values.first
          : SingleCart(id: 'cart_1', name: 'কার্ট ১', createdAt: DateTime.now()));

  // Backwards compatibility delegations to activeCart
  List<CartItemModel> get items => activeCart.items;
  PartnerModel? get customer => activeCart.customer;
  double get discountPercent => activeCart.discountPercent;
  double get grossSubtotal => activeCart.grossSubtotal;
  double get totalDiscountAmount => activeCart.totalDiscountAmount;
  double get subtotal => activeCart.subtotal;
  double get taxAmount => activeCart.taxAmount;
  double get grandTotal => activeCart.grandTotal;
  bool get isMrpInclusiveTax => activeCart.isMrpInclusiveTax;
  int get totalItemsCount => activeCart.totalItemsCount;
  bool get isEmpty => activeCart.isEmpty;
  int getQuantityForProduct(int productId) =>
      activeCart.getQuantityForProduct(productId);

  // Multi-cart getters
  List<SingleCart> get allCarts => carts.values.toList();
  int get cartCount => carts.length;
  String get activeCartName => activeCart.name;

  CartState copyWith({
    Map<String, SingleCart>? carts,
    String? activeCartId,
    // Legacy copyWith arguments forwarding to active cart
    List<CartItemModel>? items,
    PartnerModel? customer,
    bool clearCustomer = false,
    double? discountPercent,
    double? grossSubtotal,
    double? totalDiscountAmount,
    double? subtotal,
    double? taxAmount,
    double? grandTotal,
    bool? isMrpInclusiveTax,
  }) {
    if (items != null ||
        customer != null ||
        clearCustomer ||
        discountPercent != null ||
        grossSubtotal != null ||
        totalDiscountAmount != null ||
        subtotal != null ||
        taxAmount != null ||
        grandTotal != null ||
        isMrpInclusiveTax != null) {
      final updatedActive = activeCart.copyWith(
        items: items,
        customer: customer,
        clearCustomer: clearCustomer,
        discountPercent: discountPercent,
        grossSubtotal: grossSubtotal,
        totalDiscountAmount: totalDiscountAmount,
        subtotal: subtotal,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
        isMrpInclusiveTax: isMrpInclusiveTax,
      );
      final updatedMap = Map<String, SingleCart>.from(carts ?? this.carts);
      updatedMap[activeCart.id] = updatedActive;
      return CartState(
        carts: updatedMap,
        activeCartId: activeCartId ?? this.activeCartId,
      );
    }
    return CartState(
      carts: carts ?? this.carts,
      activeCartId: activeCartId ?? this.activeCartId,
    );
  }
}

/// State notifier managing active cart items, multiple customer carts,
/// dual discounts (line-item & global), customer assignment, and financial calculations.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  /// Helper to update active cart in multi-cart map.
  void _updateActiveCart(SingleCart updatedCart) {
    final updatedCarts = Map<String, SingleCart>.from(state.carts);
    updatedCarts[updatedCart.id] = updatedCart;
    state = state.copyWith(carts: updatedCarts);
  }

  /// Adds a new active walk-in customer cart and switches to it.
  String addNewCart({String? customName}) {
    final existingNumbers = state.carts.values.map((c) {
      final match = RegExp(r'\d+').firstMatch(c.name);
      return match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
    }).toList();
    final nextNum = (existingNumbers.isEmpty
            ? 0
            : existingNumbers.reduce((a, b) => a > b ? a : b)) +
        1;
    final newId = 'cart_${DateTime.now().millisecondsSinceEpoch}';
    final name = customName ?? 'কার্ট $nextNum';

    final newCart = SingleCart(
      id: newId,
      name: name,
      createdAt: DateTime.now(),
      isMrpInclusiveTax: state.isMrpInclusiveTax,
    );

    final updatedCarts = Map<String, SingleCart>.from(state.carts);
    updatedCarts[newId] = newCart;

    state = CartState(
      carts: updatedCarts,
      activeCartId: newId,
    );
    return newId;
  }

  /// Switches active cart to the specified cart ID.
  void switchCart(String cartId) {
    if (state.carts.containsKey(cartId) && state.activeCartId != cartId) {
      state = state.copyWith(activeCartId: cartId);
    }
  }

  /// Removes/closes a cart. If the removed cart was active, switches to the nearest remaining cart.
  /// If it was the only cart, resets it to an empty cart.
  void removeCart(String cartId) {
    if (state.carts.length <= 1) {
      clearCart();
      return;
    }

    final updatedCarts = Map<String, SingleCart>.from(state.carts);
    updatedCarts.remove(cartId);

    String nextActiveId = state.activeCartId;
    if (cartId == state.activeCartId) {
      nextActiveId = updatedCarts.keys.first;
    }

    state = CartState(
      carts: updatedCarts,
      activeCartId: nextActiveId,
    );
  }

  /// Renames an active or held cart (e.g. customer name).
  void renameCart(String cartId, String newName) {
    if (!state.carts.containsKey(cartId)) return;
    final existing = state.carts[cartId]!;
    final updated = existing.copyWith(name: newName);
    final updatedCarts = Map<String, SingleCart>.from(state.carts);
    updatedCarts[cartId] = updated;
    state = state.copyWith(carts: updatedCarts);
  }

  /// Adds a product to the active cart or increments quantity if already present.
  void addItem(ProductModel product, [double qty = 1.0, double? lineDiscount]) {
    final existingIndex =
        state.items.indexWhere((item) => item.product.id == product.id);

    List<CartItemModel> updatedItems;
    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updated = existing.copyWith(
        qty: existing.qty + qty,
        discount: lineDiscount ?? existing.discount,
        hasCustomDiscount: lineDiscount != null ? true : existing.hasCustomDiscount,
      );
      updatedItems = List<CartItemModel>.from(state.items);
      updatedItems[existingIndex] = updated;
    } else {
      updatedItems = [
        ...state.items,
        CartItemModel(
          product: product,
          qty: qty,
          discount: lineDiscount ?? state.discountPercent,
          hasCustomDiscount: lineDiscount != null,
        ),
      ];
    }

    _updateStateWithRecalculation(updatedItems, state.discountPercent);
  }

  /// Sets specific quantity for product in cart.
  void updateQuantity(int productId, double qty) {
    if (qty <= 0) {
      removeItem(productId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(qty: qty);
      }
      return item;
    }).toList();

    _updateStateWithRecalculation(updatedItems, state.discountPercent);
  }

  void incrementQuantity(int productId) {
    final existing = state.items.firstWhere((i) => i.product.id == productId);
    updateQuantity(productId, existing.qty + 1.0);
  }

  void decrementQuantity(int productId) {
    final existing = state.items.firstWhere((i) => i.product.id == productId);
    updateQuantity(productId, existing.qty - 1.0);
  }

  /// Removes an item from the cart.
  void removeItem(int productId) {
    final updatedItems =
        state.items.where((item) => item.product.id != productId).toList();
    _updateStateWithRecalculation(updatedItems, state.discountPercent);
  }

  /// Sets individual line-item discount percentage (Odoo `pos.order.line.discount`).
  void setLineDiscount(int productId, double discount) {
    final clamped = discount.clamp(0.0, 100.0);
    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(
          discount: clamped,
          hasCustomDiscount: true,
        );
      }
      return item;
    }).toList();

    _updateStateWithRecalculation(updatedItems, state.discountPercent);
  }

  /// Resets an individual line discount back to the active order-level global discount.
  void resetLineDiscount(int productId) {
    final updatedItems = state.items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(
          discount: state.discountPercent,
          hasCustomDiscount: false,
        );
      }
      return item;
    }).toList();

    _updateStateWithRecalculation(updatedItems, state.discountPercent);
  }

  /// Sets order-wide global discount percentage (e.g. 10.0 for 10% Boi Mela fair discount).
  void setGlobalDiscount(double discountPercent, {bool applyToAll = true}) {
    final clamped = discountPercent.clamp(0.0, 100.0);
    List<CartItemModel> updatedItems = state.items;

    if (applyToAll) {
      updatedItems = state.items
          .map((item) => item.copyWith(discount: clamped, hasCustomDiscount: false))
          .toList();
    }

    _updateStateWithRecalculation(updatedItems, clamped);
  }

  /// Alias for setting order-wide discount (backward compatibility).
  void setDiscount(double discountPercent) {
    setGlobalDiscount(discountPercent, applyToAll: true);
  }

  /// Assigns or unassigns customer for this sale.
  void setCustomer(PartnerModel? customer) {
    if (customer == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(customer: customer);
    }
  }

  /// Toggles between MRP-inclusive tax mode and additive tax mode.
  void setTaxInclusive(bool isInclusive) {
    final updatedCart = state.activeCart.copyWith(isMrpInclusiveTax: isInclusive);
    _updateActiveCart(updatedCart);
    _updateStateWithRecalculation(state.items, state.discountPercent);
  }

  /// Clears active cart.
  void clearCart() {
    final active = state.activeCart;
    final cleared = SingleCart(
      id: active.id,
      name: active.name,
      createdAt: active.createdAt,
      isMrpInclusiveTax: active.isMrpInclusiveTax,
    );
    _updateActiveCart(cleared);
  }

  /// Re-calculates gross subtotal, line discounts, net subtotal, taxes, and grand total.
  void _updateStateWithRecalculation(
    List<CartItemModel> items,
    double globalDiscountPercent,
  ) {
    final active = state.activeCart;
    const double taxRate = 0.10; // 10% VAT standard
    double totalGross = 0.0;
    double totalDiscountedGross = 0.0;
    double netSubtotal = 0.0;
    double totalTax = 0.0;

    for (final item in items) {
      final gross = item.product.listPrice * item.qty;
      totalGross += gross;

      final discountFactor = 1.0 - (item.discount / 100.0);
      final lineDiscountedGross = gross * discountFactor;
      totalDiscountedGross += lineDiscountedGross;

      if (active.isMrpInclusiveTax) {
        // Model A: MRP-inclusive retail mode (reverse net tax calculation)
        final lineNet = lineDiscountedGross / (1.0 + taxRate);
        final lineTax = lineDiscountedGross - lineNet;

        netSubtotal += lineNet;
        totalTax += lineTax;
      } else {
        // Model B: Additive tax mode
        final lineTax = lineDiscountedGross * taxRate;
        netSubtotal += lineDiscountedGross;
        totalTax += lineTax;
      }
    }

    final double total = active.isMrpInclusiveTax
        ? totalDiscountedGross
        : (netSubtotal + totalTax);

    final double totalDiscount = totalGross - totalDiscountedGross;

    final updatedCart = active.copyWith(
      items: items,
      discountPercent: globalDiscountPercent,
      grossSubtotal: double.parse(totalGross.toStringAsFixed(2)),
      totalDiscountAmount: double.parse(totalDiscount.toStringAsFixed(2)),
      subtotal: double.parse(netSubtotal.toStringAsFixed(2)),
      taxAmount: double.parse(totalTax.toStringAsFixed(2)),
      grandTotal: double.parse(total.toStringAsFixed(2)),
    );

    _updateActiveCart(updatedCart);
  }
}

/// Global provider for active Cart state and actions.
final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
