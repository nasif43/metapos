# MetaPOS Server Reconnaissance & Odoo 19 Backend Contract Report

**Target Server:** `185.7.81.172`  
**Web Demo:** `https://demostore.metaposbd.com`  
**Odoo Version:** Odoo 19.0 Community Edition (Final)  
**Host Architecture:** Ubuntu 24.04.5 LTS (LXC, 4 vCPUs Xeon E5-2667 v4, 6 GB RAM, PostgreSQL 16.15)  
**Systemd Service:** `metapos-odoo.service` (Python 3.12 venv, 5 prefork workers + gevent, Nginx SSL)  
**Tenant Database:** `demostore` (multi-tenant routing `dbfilter = ^%d$`)

---

## 1. Discovered Architecture & Custom Modules

Inspection of `/opt/metapos/repos/odoo19-book-fair-addons` on the server verified that the store runs a specialized POS suite for **book publishing, bookstores, and book fair retail** in Bangladesh:

| Module Name | Version | Purpose & Technical Behavior |
|-------------|---------|------------------------------|
| `book_fair_pos` | 19.0.1.0.0 | Strips warehouse logistics & accounting journal entries (`Book Fair Mode`). Adds ISBN normalization/validation, author/publisher/genre registries, management dashboard, and book search. |
| `book_fair_stock` | 19.0.1.0.0 | Lightweight inventory counter on `product.template.book_qty_on_hand`. Decremented automatically upon paid orders and refunds without creating `stock.move` records. |
| `bangla_translations` | 19.0.1.0.0 | Native Bengali (`bn_IN`) translation layer for core Odoo POS, accounts, and products via dynamic PO hook. |
| `metamorphosis_backend_theme` | 19.0.1.0.0 | Modern slate and emerald UI theme with Plus Jakarta Sans typography. |
| `metapos_saas` | 1.0.0 | Enforces SaaS plan limits (e.g. maximum 2 active POS terminals per tenant). |

---

## 2. Active POS Session & Master Data

- **Active Register:** Config ID `1` (`"Book Fair"`), Session ID `7` (`"Book Fair/00004"`, State: `"opened"`).
- **Secondary Register:** Config ID `2` (`"nilkhet"`, State: closed).
- **Payment Methods:**
  - ID `1`: `"Cash"` (Cash register, change calculation enabled)
  - ID `2`: `"Card"` (Bank/card/digital terminal)
- **Currency:** BDT (`৳`), ID `55`, position `after`, rounding `0.01`.
- **Default Tax:** 10% VAT (Tax ID `1`, `amount: 10.0`, `price_include: False`).
- **Catalog Size:** 76 book products with Bengali literature titles, authors, publishers, and ISBNs.

---

## 3. Odoo 19 JSON-RPC Integration Endpoints

All calls are sent over HTTPS with `Content-Type: application/json`.

### 3.1 Authenticate Session
- **URL:** `POST https://demostore.metaposbd.com/web/session/authenticate`
```json
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": {
    "db": "demostore",
    "login": "admin",
    "password": "CaEYjbVrDuk8JtD9qykXifeKsmqQZ"
  }
}
```
*Stores `session_id` cookie.*

### 3.2 Fetch Book Catalog & On-Hand Stock
- **URL:** `POST https://demostore.metaposbd.com/web/dataset/call_kw/product.product/search_read`
```json
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": {
    "model": "product.product",
    "method": "search_read",
    "args": [[["available_in_pos", "=", true]]],
    "kwargs": {
      "fields": [
        "id", "name", "display_name", "barcode", "list_price",
        "pos_categ_ids", "taxes_id", "is_book", "isbn", "isbn10",
        "book_authors_display", "book_publisher_name",
        "book_genre_name", "book_qty_on_hand"
      ]
    }
  }
}
```

### 3.3 Post POS Order (`sync_from_ui`)
- **URL:** `POST https://demostore.metaposbd.com/web/dataset/call_kw/pos.order/sync_from_ui`
- **Important:** Replaces deprecated `create_from_ui`. Must include client-generated UUIDs on order, lines, and payments.
```json
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": {
    "model": "pos.order",
    "method": "sync_from_ui",
    "args": [
      [
        {
          "name": "Book Fair - 000005",
          "pos_reference": "264-1-000005",
          "sequence_number": 5,
          "session_id": 7,
          "config_id": 1,
          "company_id": 1,
          "user_id": 2,
          "partner_id": false,
          "date_order": "2026-11-19 15:30:00",
          "amount_tax": 10.0,
          "amount_total": 110.0,
          "amount_paid": 110.0,
          "amount_return": 390.0,
          "state": "paid",
          "to_invoice": false,
          "uuid": "b53f66c0-7d3e-4b68-b7c1-0c5a21e49120",
          "access_token": "a1c2d3e4-f5a6-7b8c-9d0e-1f2a3b4c5d6e",
          "ticket_code": "k8x9m",
          "tracking_number": "4005",
          "lines": [
            [
              0,
              0,
              {
                "name": "000005",
                "product_id": 62,
                "qty": 1.0,
                "price_unit": 100.0,
                "discount": 0.0,
                "price_subtotal": 100.0,
                "price_subtotal_incl": 110.0,
                "tax_ids": [[6, 0, [1]]],
                "customer_note": false,
                "full_product_name": "Blackbird Classic",
                "uuid": "c4d5e6f7-a8b9-0c1d-2e3f-4a5b6c7d8e9f"
              }
            ]
          ],
          "payment_ids": [
            [
              0,
              0,
              {
                "name": false,
                "payment_method_id": 1,
                "amount": 500.0,
                "payment_date": "2026-11-19 15:30:00",
                "is_change": false,
                "session_id": 7,
                "uuid": "d1e2f3a4-b5c6-7d8e-9f0a-1b2c3d4e5f6a"
              }
            ]
          ]
        }
      ]
    ],
    "kwargs": {}
  }
}
```

---

## 4. Verification Check Commands

To verify live communication from your development terminal:
```bash
# 1. Authenticate and store cookie
curl -s -c /tmp/ck.txt -X POST https://demostore.metaposbd.com/web/session/authenticate \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"call","params":{"db":"demostore","login":"admin","password":"CaEYjbVrDuk8JtD9qykXifeKsmqQZ"}}'

# 2. Query books
curl -s -b /tmp/ck.txt -X POST https://demostore.metaposbd.com/web/dataset/call_kw/product.product/search_read \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"call","params":{"model":"product.product","method":"search_read","args":[[["available_in_pos","=",true]]],"kwargs":{"fields":["name","isbn","list_price","book_qty_on_hand"],"limit":3}}}'
```
