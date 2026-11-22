# MetaPOS Mobile Sales Companion - Technical & API Integration Specification

**Document Version:** 1.0.0  
**Target Platform:** Flutter (Android & iOS)  
**Backend Target:** Odoo 19.0 Community (`https://demostore.metaposbd.com`)  
**Target Server:** `185.7.81.172` (LXC Ubuntu 24.04, PostgreSQL 16)  
**Author:** Teamwork Technical Specialist & Reverse-Engineer  
**Date:** November 19, 2026  

---

## 1. System Architecture & Mobile Strategy

The MetaPOS Mobile Sales Companion is designed as a high-speed, offline-first point-of-sale client built with Flutter. It connects directly to an Odoo 19 backend customized with `book_fair_pos` and `book_fair_stock` modules.

### 1.1 Architecture Diagram

```
+----------------------------------------------------------------------------------------------------+
|                                  FLUTTER MOBILE CLIENT ARCHITECTURE                                |
+----------------------------------------------------------------------------------------------------+
|                                                                                                    |
|  [ Presentation Layer ]                                                                            |
|    - Stitch-generated UI Screens (Catalog, Scanner, Cart, Customer, Checkout, Receipt)            |
|    - Riverpod / Bloc State Notifiers & Reactive ViewModels                                         |
|                                                                                                    |
|  [ Domain / Business Logic Layer ]                                                                 |
|    - Cart Manager (Tax calculations, discount matrices, line additions)                           |
|    - Session Controller (Float validation, register locking, cashier attribution)                 |
|    - UUID Generator (Client-side RFC 4122 v4 UUID creation)                                       |
|    - Sequence Generator (pos_reference formatted as '${year2Digits}${device}-${config}-${seq}')    |
|                                                                                                    |
|  [ Data & Persistence Layer ]                                                                      |
|    - Local SQLite / Drift Database (Product Cache, Customer Index, Pending Order Queue)            |
|    - Secure Storage (Encrypted session cookies, server credentials, register tokens)              |
|                                                                                                    |
|  [ Networking & Synchronization Engine ]                                                           |
|    - JSON-RPC 2.0 HTTP Client (Dio / http with CookieJar)                                         |
|    - Offline Sync Worker (Connectivity listener, queue replay, idempotent deduplication)          |
|    - Thermal ESC/POS Print Manager (Bluetooth RFCOMM / BLE / USB driver)                          |
+----------------------------------------------------------------------------------------------------+
                                      |
                            HTTPS / JSON-RPC 2.0
                                      v
+----------------------------------------------------------------------------------------------------+
|                                    ODOO 19 BACKEND STACK                                           |
|  - Nginx Reverse Proxy (SSL, WebSocket upstream 8072, HTTP upstream 8069)                         |
|  - Odoo 19 Community Edition (Prefork workers, Python 3.12)                                        |
|  - book_fair_pos (Book Fair Mode: no stock moves, no journal entries, ISBN validation)             |
|  - book_fair_stock (Direct book_qty_on_hand decrementing)                                           |
|  - PostgreSQL 16.15 (demostore database)                                                           |
+----------------------------------------------------------------------------------------------------+
```

### 1.2 Core Architectural Principles
1. **Zero-Friction Offline Selling**: Network drops at crowded events (such as the Dhaka Ekushey Boi Mela) must never stop sales. Orders are stored locally with client-generated UUIDs and synced asynchronously.
2. **Strict Odoo 19 Protocol Conformance**: Odoo 19 deprecated and removed legacy endpoints `create_from_ui` and `load_pos_data`. The mobile app natively integrates with `sync_from_ui` and `load_data`.
3. **Bangla Typography & Currency**: All monetary values are rendered in Bangladeshi Taka (`৳` / BDT), with full native Unicode rendering for Bengali titles, author names, and receipt receipts.

---

## 2. Authentication & Session Management API

All interactions with Odoo use standard JSON-RPC 2.0 over HTTPS.

### 2.1 Authenticate Session
Establishes a persistent session with the Odoo backend, sets an HTTP `session_id` cookie, and returns user identity, assigned company, and allowed currency.

- **HTTP Method**: `POST`
- **Endpoint**: `https://demostore.metaposbd.com/web/session/authenticate`
- **Headers**:
  ```http
  Content-Type: application/json
  Accept: application/json
  ```
- **Request Payload**:
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
- **Response Headers**:
  ```http
  Set-Cookie: session_id=f48b9487c9dfbfb43485fa6bdae703ff36ea0dfb; Path=/; HttpOnly; SameSite=Lax
  ```
- **Response Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": null,
    "result": {
      "uid": 2,
      "is_system": true,
      "is_admin": true,
      "user_companies": {
        "current_company": 1,
        "allowed_companies": {
          "1": {
            "id": 1,
            "name": "Demo Store",
            "currency_id": 55
          }
        }
      },
      "name": "Administrator",
      "username": "admin",
      "partner_id": 3,
      "server_version": "19.0",
      "server_version_info": [19, 0, 0, "final", 0, ""]
    }
  }
  ```

### 2.2 Client Cookie Handling
The Flutter network layer must configure a persistent `CookieJar` (e.g. `dio_cookie_manager` with `cookie_jar`) to attach `Cookie: session_id=...` to all subsequent JSON-RPC requests.

---

## 3. POS Session & Register Initialization

### 3.1 Fetch Available POS Registers
Retrieves available point of sale terminals configured for the tenant.

- **Endpoint**: `POST https://demostore.metaposbd.com/web/dataset/call_kw/pos.config/search_read`
- **Request Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "model": "pos.config",
      "method": "search_read",
      "args": [[]],
      "kwargs": {
        "fields": [
          "id", "name", "book_fair_mode", "current_session_id",
          "current_session_state", "payment_method_ids",
          "currency_id", "iface_tax_included", "limit_categories"
        ]
      }
    }
  }
  ```
- **Response Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": null,
    "result": [
      {
        "id": 1,
        "name": "Book Fair",
        "book_fair_mode": true,
        "current_session_id": [7, "Book Fair/00004"],
        "current_session_state": "opened",
        "payment_method_ids": [1, 2],
        "currency_id": [55, "BDT"],
        "iface_tax_included": "total",
        "limit_categories": true
      },
      {
        "id": 2,
        "name": "nilkhet",
        "book_fair_mode": true,
        "current_session_id": false,
        "current_session_state": false,
        "payment_method_ids": [2],
        "currency_id": [55, "BDT"],
        "iface_tax_included": "total",
        "limit_categories": false
      }
    ]
  }
  ```

### 3.2 Odoo 19 Unified POS Data Loading (`load_data`)
In Odoo 19, `load_pos_data` was removed. The authoritative method is `pos.session.load_data(models_to_load)`. When called with empty list for models, it returns all 45 required POS models in a single server call.

- **Endpoint**: `POST https://demostore.metaposbd.com/web/dataset/call_kw/pos.session/load_data`
- **Request Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "model": "pos.session",
      "method": "load_data",
      "args": [[7], []],
      "kwargs": {}
    }
  }
  ```
- **Response Structure**:
  Returns a comprehensive dictionary containing:
  - `pos.session`: Current active session metadata, start time, cash register balance.
  - `pos.config`: Register flags (`book_fair_mode`).
  - `pos.payment.method`: Configured tender methods.
  - `pos.category`: Hierarchy of POS categories.
  - `product.product`: Full product master with pricing, taxes, and custom book fields.
  - `res.partner`: Active customer records.
  - `account.tax`: Tax definitions (10% VAT).

---

## 4. Product Catalog & Image APIs

### 4.1 Fetch Book Catalog
Retrieves active book products with industry metadata and live stock counters.

- **Endpoint**: `POST https://demostore.metaposbd.com/web/dataset/call_kw/product.product/search_read`
- **Request Payload**:
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
          "id", "display_name", "name", "barcode", "default_code",
          "list_price", "pos_categ_ids", "taxes_id",
          "is_book", "isbn", "isbn10", "book_subtitle",
          "book_authors_display", "book_publisher_name",
          "book_genre_name", "book_series", "book_edition",
          "book_publication_year", "book_pages", "book_format",
          "book_qty_on_hand"
        ]
      }
    }
  }
  ```
- **Sample Product Record**:
  ```json
  {
    "id": 62,
    "display_name": "[test_ref] Blackbrid Classic",
    "name": "Blackbrid Classic",
    "barcode": "5556666",
    "default_code": "test_ref",
    "list_price": 100.0,
    "pos_categ_ids": [1],
    "taxes_id": [1],
    "is_book": true,
    "isbn": "9796869458274",
    "isbn10": "",
    "book_subtitle": "A literary chronicle",
    "book_authors_display": "Black",
    "book_publisher_name": "black publisher",
    "book_genre_name": "noble",
    "book_series": "First Edition",
    "book_edition": "1st",
    "book_publication_year": 2024,
    "book_pages": 320,
    "book_format": "paperback",
    "book_qty_on_hand": 80
  }
  ```

### 4.2 Book Cover Thumbnail Image API
Fetches optimized image thumbnails for the mobile grid display.

- **HTTP Method**: `GET`
- **URL**: `https://demostore.metaposbd.com/web/image?model=product.product&id={product_id}&field=image_128`
- **Headers**: Session cookie attached.
- **Cache-Control**: Images are cached locally using Flutter `cached_network_image`.
- **High-Res URL**: Replace `image_128` with `image_1920` for full-screen detail view.

### 4.3 Fast Stock On Hand Refresh (`book_read_qty_on_hand`)
Allows the mobile client to re-poll stock quantities for visible items without refetching the entire catalog.

- **Endpoint**: `POST https://demostore.metaposbd.com/web/dataset/call_kw/product.template/book_read_qty_on_hand`
- **Request Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "model": "product.template",
      "method": "book_read_qty_on_hand",
      "args": [[62, 63, 64]],
      "kwargs": {}
    }
  }
  ```
- **Response Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": null,
    "result": {
      "62": 80,
      "63": 14,
      "64": -2
    }
  }
  ```

---

## 5. Customer Management APIs

### 5.1 Search Customers
Performs instant lookup against customer name, phone number, or barcode.

- **Endpoint**: `POST https://demostore.metaposbd.com/web/dataset/call_kw/res.partner/search_read`
- **Request Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "model": "res.partner",
      "method": "search_read",
      "args": [
        ["|", "|", ["name", "ilike", "Rahim"], ["phone", "ilike", "017"], ["barcode", "=", "Rahim"]]
      ],
      "kwargs": {
        "fields": ["id", "name", "phone", "email", "street", "city", "barcode"],
        "limit": 20
      }
    }
  }
  ```
- **Note on Odoo 19 Schema**: In Odoo 19, the partner model uses `phone`. Querying `mobile` will raise a `ValueError: Invalid field 'mobile' on 'res.partner'`.

### 5.2 Quick Create Customer
Allows cashier to onboard a new customer in seconds directly from the cart flow.

- **Endpoint**: `POST https://demostore.metaposbd.com/web/dataset/call_kw/res.partner/create`
- **Request Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "model": "res.partner",
      "method": "create",
      "args": [
        {
          "name": "Kazi Nazrul",
          "phone": "01711000000",
          "email": "nazrul@example.com",
          "street": "Dhanmondi 27",
          "city": "Dhaka",
          "customer_rank": 1
        }
      ],
      "kwargs": {}
    }
  }
  ```
- **Response Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": null,
    "result": 9
  }
  ```

---

## 6. Order Submission & Payment API (`sync_from_ui`)

### 6.1 Authoritative Odoo 19 Sync Endpoint
In Odoo 19, `pos.order.create_from_ui` has been replaced by `pos.order.sync_from_ui`. The method accepts an array of serialized order dictionaries, writes them to the database, processes payment lines, and updates stock.

- **Endpoint**: `POST https://demostore.metaposbd.com/web/dataset/call_kw/pos.order/sync_from_ui`
- **Idempotency Guarantee**: The server inspects each order's `uuid`. If an order with that `uuid` already exists, the server safely skips duplicate insertion and returns the existing order record.

### 6.2 Complete Order Payload Schema
The following JSON payload illustrates a sale with 1 book line (with 10% tax), Cash tender of `500.00 ৳`, grand total `110.00 ৳`, and cash change return `390.00 ৳`:

> **Tax Mode Note**: The sample payload below demonstrates **Additive Tax Mode** (Odoo default where `account.tax` ID 1 has `price_include: false`), with base `price_unit: 100.0` yielding `price_subtotal_incl: 110.0` and `amount_total: 110.0`. If the retail store operates in **MRP Tax-Inclusive Mode**, see Section 8.1 for the developer guide on reverse-calculating `price_unit = 100.0 / 1.10 = 90.91` to maintain parity with gross book cover prices.

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
          "name": "Book Fair - 000006",
          "pos_reference": "264-1-000006",
          "sequence_number": 6,
          "session_id": 7,
          "config_id": 1,
          "company_id": 1,
          "user_id": 2,
          "partner_id": 9,
          "date_order": "2026-11-19 15:45:00",
          "amount_tax": 10.0,
          "amount_total": 110.0,
          "amount_paid": 110.0,
          "amount_return": 390.0,
          "state": "paid",
          "to_invoice": false,
          "uuid": "e895b6c2-4a11-4f27-99bc-35914a8b7c20",
          "access_token": "f1234567-89ab-cdef-0123-456789abcdef",
          "ticket_code": "m5z7p",
          "tracking_number": "4006",
          "lines": [
            [
              0,
              0,
              {
                "name": "000006",
                "product_id": 62,
                "qty": 1.0,
                "price_unit": 100.0,
                "discount": 0.0,
                "price_subtotal": 100.0,
                "price_subtotal_incl": 110.0,
                "tax_ids": [[6, 0, [1]]],
                "customer_note": false,
                "full_product_name": "[test_ref] Blackbrid Classic",
                "uuid": "7a8b9c0d-1e2f-3a4b-5c6d-7e8f9a0b1c2d"
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
                "payment_date": "2026-11-19 15:45:00",
                "is_change": false,
                "session_id": 7,
                "uuid": "3b4c5d6e-7f8a-9b0c-1d2e-3f4a5b6c7d8e"
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

### 6.3 Server Sync Response Structure
Upon successful execution, the server returns the dictionary of created models:

```json
{
  "jsonrpc": "2.0",
  "id": null,
  "result": {
    "pos.order": [
      {
        "id": 6,
        "name": "Book Fair - 000006",
        "pos_reference": "264-1-000006",
        "amount_total": 110.0,
        "amount_paid": 110.0,
        "amount_return": 390.0,
        "state": "paid",
        "uuid": "e895b6c2-4a11-4f27-99bc-35914a8b7c20"
      }
    ],
    "pos.session": [],
    "pos.payment": [
      {
        "id": 8,
        "amount": 500.0,
        "payment_method_id": 1,
        "is_change": false,
        "uuid": "3b4c5d6e-7f8a-9b0c-1d2e-3f4a5b6c7d8e"
      },
      {
        "id": 9,
        "name": "ফেরত",
        "amount": -390.0,
        "payment_method_id": 1,
        "is_change": true,
        "uuid": "..."
      }
    ],
    "pos.order.line": [
      {
        "id": 6,
        "product_id": 62,
        "qty": 1.0,
        "price_subtotal_incl": 110.0,
        "uuid": "7a8b9c0d-1e2f-3a4b-5c6d-7e8f9a0b1c2d"
      }
    ],
    "pos.pack.operation.lot": [],
    "product.attribute.custom.value": [],
    "account.move": []
  }
}
```

---

## 7. Offline Queue & Synchronization Architecture

### 7.1 Local SQLite Schema (Drift / Sqflite)
The mobile client maintains a robust local database to persist unposted transactions:

```sql
CREATE TABLE local_orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE NOT NULL,
  pos_reference TEXT NOT NULL,
  session_id INTEGER NOT NULL,
  partner_id INTEGER,
  amount_total REAL NOT NULL,
  payload_json TEXT NOT NULL,
  sync_status TEXT CHECK(sync_status IN ('pending', 'syncing', 'synced', 'failed')) DEFAULT 'pending',
  retry_count INTEGER DEFAULT 0,
  last_error TEXT,
  created_at TEXT NOT NULL,
  synced_at TEXT
);

CREATE TABLE cached_products (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  barcode TEXT,
  isbn TEXT,
  authors TEXT,
  publisher TEXT,
  genre TEXT,
  price REAL NOT NULL,
  stock_qty INTEGER NOT NULL,
  category_id INTEGER,
  updated_at TEXT NOT NULL
);
```

### 7.2 Background Sync Protocol Flow
1. **Network Connectivity Detection**:
   The Flutter app listens to `connectivity_plus` streams. When transitioning to `wifi` or `mobileData`, the sync loop is initiated.
2. **Sequential Queue Replay**:
   Orders in `pending` or `failed` state are fetched ordered by `created_at ASC`.
3. **Transmission**:
   The worker invokes `pos.order.sync_from_ui` with the queued order's `payload_json`.
4. **Idempotent Acknowledgment**:
   - If the server returns HTTP 200 with matching `pos.order[0].uuid`, update `sync_status = 'synced'` and record `synced_at`.
   - If a transient network error occurs, retain `sync_status = 'failed'` and increment `retry_count`.
   - On the next sync attempt, the exact same `uuid` is transmitted. Odoo detects the existing UUID via `_get_open_order()` and returns the existing record without duplicating the transaction.
5. **Offline Queue Session Expiration Recovery Handler**:
   - If `sync_from_ui` returns an Odoo RPC exception:
     - `odoo.exceptions.MissingError: Record does not exist or has been deleted. (Record: pos.session(X,), User: Y)`
     - Or `UserError("This session is already closed.")` / `UserError("You cannot create an order in a closed session.")`
   - **Root Cause**: Orders accumulated offline were recorded with a `session_id` that was subsequently closed on the server (e.g. overnight shift close at the book fair). Retrying with the closed session will perpetually fail.
   - **Automated Re-binding Workflow**:
     a. **Query Current Active Session**: The sync manager invokes `pos.config.search_read`:
        ```json
        {
          "model": "pos.config",
          "method": "search_read",
          "args": [[["id", "=", config_id]]],
          "kwargs": {"fields": ["current_session_id", "current_session_state"]}
        }
        ```
     b. **Validate Session State**: If `current_session_state == "opened"` and `current_session_id` is valid, extract `new_session_id = current_session_id[0]`.
     c. **Re-bind Order Session**:
        - In the local SQLite `local_orders` table: update `session_id = new_session_id`.
        - In the order payload: update `payload_json["session_id"] = new_session_id` and all `payment_ids[i][2]["session_id"] = new_session_id`.
     d. **Immediate Resubmission**: Resubmit the order to `pos.order.sync_from_ui` under the active session.
     e. **Fallback / Register Closed State**: If no active session exists (`current_session_id == false`), mark `sync_status = 'failed'` with `last_error = 'Session closed; waiting for register opening'` and display a banner in the mobile app prompting the cashier to open a new POS session.
6. **Post-Sync Stock Update**:
   Upon order confirmation, decrement local product stock or invoke `book_read_qty_on_hand` to refresh server stock counters.

---

## 8. Financial Calculations & Tax Engine

### 8.1 Dual Tax Pricing Architecture & VAT Reconciliation
The mobile POS must harmonize two distinct financial pricing models encountered in Bangladeshi publishing retail:

#### Pricing Model Comparison Table
| Calculation Parameter | Model A: MRP Tax-Inclusive Mode (Retail Bookstore Standard) | Model B: Additive Tax Mode (Live Odoo Server Default) |
|---|---|---|
| **Underlying Philosophy** | Printed cover price (MRP) is the final gross price paid by customer. | Shelf price is net; 10% VAT is added on top at checkout. |
| **Backend Tax Setup** | `account.tax` ID 1 with `price_include: true` (or client reverse-net) | `account.tax` ID 1 with `price_include: false` (`demostore` setting) |
| **Shelf / List Price** | ৳ 1,700.00 (Gross MRP) | ৳ 1,700.00 (Net Base) |
| **Fair Discount (10%)** | - ৳ 170.00 | - ৳ 170.00 |
| **Customer Payable** | **৳ 1,530.00** | **৳ 1,683.00** |
| **Net Base (Price Subtotal)**| $\text{Payable} / 1.10 = \mathbf{৳ 1,390.91}$ | $\text{Base} - \text{Discount} = \mathbf{৳ 1,530.00}$ |
| **10% VAT Amount** | $\text{Net Base} \times 0.10 = \mathbf{৳ 139.09}$ | $\text{Net Base} \times 0.10 = \mathbf{৳ 153.00}$ |
| **Total (Subtotal + VAT)** | **৳ 1,530.00** | **৳ 1,683.00** |

#### Operational Formulae

1. **Model A (MRP Tax-Inclusive Formulae - Standard)**:
   $$\text{Discounted Gross} = \sum (\text{List Price} \times \text{Qty}) \times \left(1 - \frac{\text{Discount \%}}{100}\right)$$
   $$\text{Net Price Subtotal} = \frac{\text{Discounted Gross}}{1.10}$$
   $$\text{Tax Amount (10% VAT)} = \text{Discounted Gross} - \text{Net Price Subtotal} = \text{Net Price Subtotal} \times 0.10$$
   $$\text{Order Total (Grand Total)} = \text{Discounted Gross} = \text{Net Price Subtotal} + \text{Tax Amount}$$

2. **Model B (Additive Tax Formulae - Server Default)**:
   $$\text{Price Subtotal} = \text{Unit Price} \times \text{Quantity} \times \left(1 - \frac{\text{Discount \%}}{100}\right)$$
   $$\text{Tax Amount} = \text{Price Subtotal} \times 0.10$$
   $$\text{Price Subtotal Incl} = \text{Price Subtotal} + \text{Tax Amount} = \text{Price Subtotal} \times 1.10$$
   $$\text{Order Total} = \sum \text{Price Subtotal Incl}$$

#### Critical Instructions for Flutter Developers (`sync_from_ui` Payload Formatting)
To prevent underpayment, cash register imbalances, or Odoo reconciliation rejections:

1. **When Odoo Server has `account.tax` ID 1 with `price_include: false` (Current `demostore` status)**:
   - **If bookstore charges shelf price as Net (Model B Additive)**:
     - Transmit `price_unit` equal to shelf price (e.g. `100.0`).
     - Transmit `price_subtotal: 100.0`, `price_subtotal_incl: 110.0`, `amount_tax: 10.0`.
     - Customer is charged `৳ 110.00`.
   - **If bookstore operates on MRP-Inclusive Retail (Model A Standard)**:
     - **CRITICAL CLIENT-SIDE TRANSFORMATION**: Because the backend tax engine calculates tax additively ($P \times 1.10$), the Flutter app **must send the pre-tax net unit price** in `lines`:
       $$\text{price\_unit} = \frac{\text{MRP}}{1.10} \quad (\text{e.g. } \frac{100.0}{1.10} = 90.91)$$
       $$\text{price\_subtotal} = 90.91, \quad \text{price\_subtotal\_incl} = 100.00, \quad \text{amount\_tax} = 9.09$$
     - This guarantees that Odoo's additive tax engine calculates `amount_total = 100.00`, exactly matching the customer's cash tender and shelf MRP. If the app sent `price_unit: 100.0`, Odoo would calculate `amount_total: 110.0`, creating a ৳ 10.00 underpayment discrepancy!

2. **When Odoo Server has `account.tax` ID 1 with `price_include: true` and `pos.config.iface_tax_included = 'total'`**:
   - Transmit `price_unit` directly as the printed MRP (`100.0`).
   - Transmit `price_subtotal: 90.91`, `price_subtotal_incl: 100.0`, `amount_tax: 9.09`.
   - Odoo natively recognizes inclusive tax and requires no client-side unit price manipulation.

### 8.2 Payment Tender & Change Rules
- If payment method is **Cash** and $\text{Tendered} > \text{Grand Total}$:
  - Send the tendered amount in `payment_ids` with `is_change: false`.
  - The server automatically calculates $\text{amount\_return} = \text{Tendered} - \text{Grand Total}$ and creates the change line with `is_change: true` and name `"ফেরত"`.
- If payment method is **Card / Digital (bKash / Nagad)**:
  - **Tender Restriction**: Payment amount must strictly match or be less than the remaining balance due. Digital payment methods cannot accept over-tender or return cash change.
  - Optional `payment_ref_no` (e.g. bKash TrxID or card authorization code) is stored in payment line reference.

---

## 9. Error Codes & Diagnostic Matrix

| Error Scenario | Odoo Error Type / Exception | HTTP Code | Mobile App Recovery Strategy |
|----------------|----------------------------|-----------|------------------------------|
| Invalid Credentials | `odoo.exceptions.AccessDenied` | 200 (JSON-RPC Error) | Display "Invalid login credentials. Please re-enter password." |
| Session Expired | `Session Expired` / Null result | 200 | Trigger automatic re-auth with stored encrypted credentials. |
| Session Closed on Server / Missing | `odoo.exceptions.MissingError` / `UserError("This session is already closed.")` | 200 (JSON-RPC Error) | Sync manager queries `pos.config.search_read` for `current_session_id`. If active session found, automatically re-binds order `session_id` in SQLite and payload, then resubmits. If closed, alerts cashier to open session. |
| Invoicing Attempted in Book Fair | Suppressed by `pos_order.py` | 200 | App forces `to_invoice: false`. No error raised. |
| Partner Mobile Field | `ValueError: Invalid field 'mobile'` | 200 (JSON-RPC Error) | App must only query and write to `phone`. |
| Network Timeout / Drop | `SocketException` / `TimeoutException` | Client | Store order in SQLite offline queue with status `pending`. |
| Barcode Not Found | No matching product in local cache | Client | Provide audio error beep and prompt manual search. |
