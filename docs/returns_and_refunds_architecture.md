# Returns & Refunds Architecture & Specification (Odoo 19 POS)

## 1. Overview
MetaPOS implements full bidirectional returns and partial refunds synchronized with Odoo 19 Point of Sale (`pos.order`).
The solution adheres strictly to:
- Offline-first SQLite persistence with transactional queuing.
- Negative quantity and financial lines matching Odoo 19 RPC payload schemas.
- Whole-BDT integer formatting.
- Strict bounded refundable quantity enforcement (`refundable_qty = max(0.0, qty - refunded_qty)`).
- Re-entrancy guards against double-tap race conditions.

---

## 2. Data Model & Invariants

### 2.1 Order Invariants
- `is_refund`: Boolean indicating whether the order is a return.
- `refunded_order_id`: Integer foreign key pointing directly to the parent `pos.order` in Odoo.
- `has_refundable_lines`: Dynamic helper checking if any order line has `refundable_qty > 0`.
- Single-parent constraint: A return order can only refund lines belonging to one parent order.

### 2.2 Order Line Invariants
- `qty`: Negative integer/float in the return payload (`-N`).
- `refunded_qty`: Cumulative count of previously returned units on the parent line.
- `refundableQty`: Computed property: `(qty - refunded_qty).clamp(0.0, double.infinity)`.
- `refunded_orderline_id`: Integer foreign key pointing to the original `pos.order.line` in Odoo.

### 2.3 Payment Tender Invariants
- `PaymentLineModel`: Negative tender amount (`-totalRefund`).
- `is_change`: False.
- Supported tenders: Cash, Bank, and bKash.

---

## 3. Remote Synchronization (Odoo 19 JSON-RPC)

### 3.1 Endpoint
Return orders are submitted through `/web/dataset/call_kw/pos.order/sync_from_ui`.

### 3.2 Payload Schema
```json
{
  "name": "Return Book Fair/00014-001-0001",
  "data": {
    "name": "Return Book Fair/00014-001-0001",
    "amount_paid": -500.0,
    "amount_total": -500.0,
    "amount_tax": -45.45,
    "amount_return": 0.0,
    "lines": [
      [0, 0, {
        "qty": -1.0,
        "price_unit": 500.0,
        "price_subtotal": -454.55,
        "price_subtotal_incl": -500.0,
        "discount": 0.0,
        "product_id": 42,
        "tax_ids": [[6, false, [1]]],
        "refunded_orderline_id": 105
      }]
    ],
    "statement_ids": [
      [0, 0, {
        "amount": -500.0,
        "payment_method_id": 1,
        "name": "2026-11-22 06:40:00"
      }]
    ],
    "pos_session_id": 14,
    "is_refund": true,
    "refunded_order_id": 89
  }
}
```

---

## 4. SQLite Schema (v4 Migration)
In `lib/data/local/database_helper.dart`, tables `local_orders` and `local_order_lines` include:
- `local_orders.is_refund` (INTEGER: 0 or 1)
- `local_orders.refunded_order_id` (INTEGER, NULLABLE)
- `local_order_lines.refunded_orderline_id` (INTEGER, NULLABLE)
- `local_order_lines.refunded_qty` (REAL DEFAULT 0.0)

---

## 5. UI & Navigation Flow
1. **Catalog / Dashboard AppBar**: Tapping the History icon navigates to `/orders` (`OrderHistoryScreen`).
2. **OrderHistoryScreen**:
   - Filter chips: `সব` (All), `ফেরতযোগ্য` (Refundable), `রিফান্ড` (Refunds).
   - Search by order reference or scan barcode.
   - Tap order item -> Navigates to `/orders/detail` (`OrderDetailScreen`).
3. **OrderDetailScreen**:
   - Inspect individual lines and view refundable quantities.
   - Adjust quantities with steppers.
   - Tap "পণ্য ফেরত প্রক্রিয়া" -> Opens `ReturnProcessBottomSheet`.
4. **ReturnProcessBottomSheet**:
   - Select payment tender (Cash / Bank / bKash).
   - Atomic submission with re-entrancy protection.
   - Success -> Clears stack to root and navigates to `/receipt` (`OrderSuccessReceiptScreen`).
5. **OrderSuccessReceiptScreen**:
   - Displays "REFUND VOUCHER" / "রিফান্ড ভাউচার".
   - Shows negative amount totals, red refund indicators, and thermal ESC/POS printable preview.
