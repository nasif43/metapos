# Developer & AI Coding Agent Onboarding Blueprint

**Document Version:** 1.0.0  
**Target Systems:** MetaPOS Mobile/Desktop/Web & Odoo 19.0 Community Backend  
**Audience:** Human Software Engineers, Forensic Auditors, and Autonomous AI Coding Agents  

---

## 1. Welcome & Architecture Principles

Welcome to the **MetaPOS** core engineering blueprint. This guide is written so that ANY developer or autonomous AI coding agent (working in Flutter/Dart, React Native/TypeScript, Swift/iOS, Kotlin/Android, Go, Rust, or Python) can immediately understand the architecture, respect system invariants, and safely extend the platform without breaking production systems.

### Core Architectural Pillars
1. **Offline-First Resilience**: All checkout actions must complete, store in local persistence (SQLite/IndexedDB), and print receipts locally in $<500\text{ ms}$ without waiting for network round-trips.
2. **Zero Data Loss Guarantee**: Orders are enqueued in a strictly ordered FIFO queue. The synchronization worker handles transient disconnections, server restarts, and session closures gracefully.
3. **Strict Invariant Enforcement**: All orders must balance tender and change lines, preserve printed MRP cover prices via reverse-net tax math, and stamp unique RFC 4122 v4 UUIDs across headers and lines.
4. **Platform & Framework Agnosticism**: The API specification is published as OpenAPI 3.1.0 (`docs/openapi.yaml`, `docs/openapi.json`), supporting both generic REST clients (`/api/v1/...`) and native Odoo JSON-RPC 2.0 clients (`/web/...`).

---

## 2. Live Backend Environment & Credentials

The production-mirrored test environment is actively maintained and available for automated integration tests:

| Parameter | Value | Notes |
|---|---|---|
| **Base URL** | `https://demostore.metaposbd.com` | HTTPS TLS 1.3, Nginx 1.24 reverse proxy |
| **Server Engine** | Odoo 19.0 Community Edition | Running on Ubuntu 24.04 LTS |
| **Worker Concurrency** | 5 Prefork Workers (`workers = 5`) | WSGI gevent worker pool |
| **Database Name** | `demostore` | PostgreSQL 16.15 relational engine |
| **Admin Login** | `admin` | Full POS Manager / System Administrator |
| **Admin Password** | `CaEYjbVrDuk8JtD9qykXifeKsmqQZ` | Read/write API access |
| **Default Register** | Config ID `1` (`"Book Fair"`) | `book_fair_mode: True` |
| **Active Session** | Session ID `23` (`"Book Fair/00014"`) | Status: `'opened'` |
| **Currency** | BDT (`৳`, Currency ID `55`) | Bangladesh Taka |
| **Installed Custom Addons** | `book_fair_pos`<br/>`book_fair_stock`<br/>`bangla_translations`<br/>`metapos_saas` | Direct on-hand stock decrement on `product_template`<br/>Bengali localized error strings<br/>Tenant limits |

---

## 3. Database Schema Notes & Field Mapping

When interacting with Odoo 19 ORM via `call_kw` or database queries, use the following field structures:

### 3.1 `product.product` & `product.template` (Catalog & Books)
- `id` (int): Product variant ID.
- `product_tmpl_id` (many2one): Product template ID.
- `name` (char): Product title (e.g. `Blackbird Classic Edition`).
- `lst_price` (float): Base catalog price in BDT.
- `taxes_id` (many2many): Tax relation IDs (e.g. `[1]` for 10% VAT).
- `pos_categ_ids` (many2many): Assigned POS category IDs.
- `image_128` (binary): Base64-encoded thumbnail image (stored as string in JSON-RPC).
- **Custom Book Fair Fields**:
  - `isbn` (char): Standard 10 or 13-digit ISBN.
  - `book_authors_display` (char): Formatted author name (e.g. `মুহম্মদ জাফর ইকবাল`).
  - `book_publisher_name` (char): Publishing house name (e.g. `তাম্রলিপি প্রকাশনী`).
  - `book_edition` (char): Edition details (e.g. `১ম সংস্করণ, ২০২৪`).
  - `book_qty_on_hand` (float, on `product.template`): Direct physical stock count. Query via `product.template.book_read_qty_on_hand`.

### 3.2 `res.partner` (Customer Records)
- `id` (int): Customer partner ID.
- `name` (char): Customer name (supports Bengali Unicode characters).
- `phone` (char): Primary contact number.
- `email` (char): Optional customer email.
- `street` (char): Street address.
- `vat` (char): Customer Tax ID / Business BIN for NBR Mushak 6.3 invoices.

### 3.3 `pos.order` (Order Header)
- `name` (char): Order name / reference (e.g. `Order - 000144`).
- `pos_reference` (char): Workstation reference sequence (e.g. `LIVE-264-1-32009`).
- `session_id` (many2one): Target open POS session ID (must be in state `'opened'`).
- `config_id` (many2one): POS register config ID.
- `amount_total` (float): Gross total payable.
- `amount_tax` (float): Total VAT.
- `amount_paid` (float): Reconciled total paid. **Must equal `amount_total`**.
- `amount_return` (float): **Must be `0.0` in Odoo sync payload**.
- `uuid` (char): RFC 4122 v4 unique identifier (indexed with unique constraint `pos_order_unique_uuid`).

### 3.4 `pos.order.line` (Order Line Items)
- `product_id` (many2one): Relates to `product.product`.
- `qty` (float): Quantity purchased.
- `price_unit` (float): Net unit price before tax.
- `price_subtotal` (float): Net subtotal before tax (`price_unit * qty`).
- `price_subtotal_incl` (float): Gross subtotal including VAT.
- `tax_ids` (many2many): Odoo command tuple `[[6, 0, [tax_id]]]`.
- `uuid` (char): RFC 4122 v4 unique identifier (indexed with unique constraint `pos_order_line_unique_uuid`).

### 3.5 `pos.payment` (Payment Lines)
- `payment_method_id` (many2one): `1` for Cash, `2` for Bank/Card/MFS.
- `amount` (float): Positive tender amount, or negative change amount.
- `is_change` (boolean): `true` if representing change returned to customer.
- `name` (char): Label, e.g. `'ফেরত'` for change lines.
- `uuid` (char): RFC 4122 v4 unique identifier.

---

## 4. Critical Pitfalls & Anti-Patterns

### ❌ PITFALL 1: Querying or Searching `mobile` on `res.partner`
- **What happens**: Odoo 19 core **completely removed the `mobile` field from `res.partner`**.
- **The error**:
  ```python
  builtins.ValueError: Invalid field 'mobile' on 'res.partner'
  ```
- **The rule**: **NEVER** mention `mobile` in field lists, projections, or search domains (`[["mobile", "=", "..."]]`). **ALWAYS** use `phone`.

### ❌ PITFALL 2: Submitting Top-Level `amount_return > 0` in `pos.order.sync_from_ui`
- **What happens**: When cash over-tender occurs (e.g. customer gives ৳500 for a ৳110 order), passing `amount_return: 390.0` at the order header level causes Odoo's `_process_order` to fail payment reconciliation.
- **The error**:
  ```
  odoo.exceptions.UserError: অর্ডার /-এর মূল্য পুরোপুরি পরিশোধ হয়নি।
  (Order %s is not fully paid.)
  ```
- **The rule**:
  1. Top-level `'amount_return'` **MUST ALWAYS BE `0.0`**.
  2. Top-level `'amount_paid'` **MUST ALWAYS EQUAL `'amount_total'`**.
  3. Change must be recorded by adding a balancing negative payment line in `payment_ids`:
     ```json
     [0, 0, {"payment_method_id": 1, "amount": -390.0, "is_change": true, "name": "ফেরত", "uuid": "<uuid>"}]
     ```
  4. Client applications may keep `amountReturn = 390.0` in their local SQLite models and print it on receipts, but serialize `0.0` when sending to Odoo.

### ❌ PITFALL 3: Failing to Apply Reverse-Net Tax on Printed MRP Cover Prices
- **What happens**: Bangladeshi retail goods (books, packaged goods) display printed statutory Maximum Retail Prices (MRP) that include VAT. However, standard Odoo taxes are often configured as **Additive** (`price_include: false`). Submitting a printed ৳100 book as `price_unit: 100.0` causes Odoo to add 10% VAT, inflating the checkout price to ৳110.00 and violating consumer protection laws.
- **The rule**: Always reverse-calculate the net unit price before tax:
  $$\text{price\_unit} = \text{round}\left(\frac{\text{MRP}}{1 + r}, 4\right) = \text{round}\left(\frac{100.0}{1.10}, 4\right) = 90.9091$$
  $$\text{price\_subtotal} = \text{round}(90.9091 \times \text{qty}, 2) = 90.91$$
  $$\text{amount\_tax} = \text{round}(\text{MRP} - \text{price\_subtotal}, 2) = 9.09$$
  $$\text{amount\_total} = 90.91 + 9.09 = 100.00$$

### ❌ PITFALL 4: Reusing Line UUIDs
- **What happens**: While Odoo 19 `sync_from_ui` provides application-level idempotency for duplicate *order* UUIDs, it enforces a strict database uniqueness constraint on *line* UUIDs: `pos_order_line_unique_uuid`.
- **The error**:
  ```
  odoo.exceptions.ValidationError: The operation cannot be completed: এই uuid-এর একটি অর্ডার লাইন আগে থেকেই আছে
  ```
- **The rule**: Every single order line must generate its own fresh RFC 4122 v4 UUID. Never clone or reuse line UUIDs.

### ❌ PITFALL 5: Submitting Unsorted Line Items (Deadlock Hazard)
- **What happens**: Under high concurrency (5–10 simultaneous cashiers), two orders containing the same products in different orders will acquire row-level locks on `product_template.book_qty_on_hand` in opposing sequence, triggering PostgreSQL `40P01 deadlock_detected`.
- **The rule**: **Always sort `lines` ascending by `product_id`** before transmitting the JSON-RPC payload.

---

## 5. Development Setup & Verification Commands

### 5.1 Workspace Environment
- **Workspace Directory**: `/home/muhts/dev/Codes/metamorphosis/metapos`
- **SDK**: Dart ^3.13.7 / Flutter 3.x
- **Python**: Python 3.12+ with `requests`

### 5.2 Test Execution Commands

#### 1. Full Flutter Test Suite (175 Tests)
Runs all unit, widget, responsive viewport, and live integration tests:
```bash
cd /home/muhts/dev/Codes/metamorphosis/metapos
flutter test
```
*Expected Result*: `All tests passed!`, 175 tests, exit code `0`.

#### 2. Live Odoo 19 Interface & Concurrency Benchmark
Executes all 25 live checks and concurrency sweeps against `https://demostore.metaposbd.com`:
```bash
cd /home/muhts/dev/Codes/metamorphosis/metapos
python3 test/integration/live_odoo_stress_test.py
```
*Expected Result*: Completes 8 sections with `25/25 checks PASSED`, exit code `0`, and updates `docs/LIVE_STRESS_TEST_REPORT.json`.

#### 3. OpenAPI 3.1 Specification Validation
Validates that `docs/openapi.yaml` and `docs/openapi.json` are syntactically and structurally sound:
```bash
python3 -c "
import yaml, json
with open('docs/openapi.yaml', 'r') as f:
    y = yaml.safe_load(f)
with open('docs/openapi.json', 'r') as f:
    j = json.load(f)
assert y['openapi'] == '3.1.0'
assert len(y['paths']) == len(j['paths'])
print('OpenAPI 3.1 Spec Validated Successfully: 17 Paths, 25 Components')
"
```
