# MetaPOS Mobile - Stitch & Flutter Screen Design Specification

> **Target App:** MetaPOS Mobile Sales & Register Client  
> **Platform:** Flutter (iOS & Android)  
> **Backend:** Odoo 19.0 Community (`demostore.metaposbd.com` / `185.7.81.172`)  
> **Industry Specialty:** Book Publishing, Book Fair & Bookstore POS (`book_fair_pos`, `book_fair_stock`)  
> **Brand Palette:** Emerald (`#0BC279`), Deep Slate (`#131926`), Surface Light (`#F8FAFC`), Pure White (`#FFFFFF`)  
> **Typography:** Plus Jakarta Sans (English) + Hind Siliguri (Bangla)  
> **Currency:** Bangladeshi Taka (BDT `৳`)

---

## 1. Design System & Stitch Visual Prompt Token Guide

Use these global design tokens in all Google Stitch screen generation prompts to maintain strict visual consistency:

```yaml
Design System:
  Brand Name: "MetaPOS"
  Theme: "Modern sleek point-of-sale interface with high-density, tactile controls"
  Colors:
    Primary: "#0BC279" # MetaPOS Emerald
    Primary Dark: "#089E62"
    Primary Light: "#E6F9F1"
    Background Light: "#F8FAFC"
    Background Dark / Accent: "#131926" # Deep Slate Navy
    Surface: "#FFFFFF"
    Surface Card: "#FFFFFF"
    Border: "#E2E8F0"
    Text Primary: "#0F172A"
    Text Secondary: "#64748B"
    Success: "#10B981"
    Warning: "#F59E0B"
    Error: "#EF4444"
    Cash Accent: "#059669"
    Digital / bKash Accent: "#E2136E"
  Radii:
    Card: "16px"
    Button: "12px"
    Badge: "8px"
    Pill: "9999px"
  Shadows:
    Card: "0px 2px 8px rgba(19, 25, 38, 0.06)"
    Modal / Sheet: "0px -4px 20px rgba(19, 25, 38, 0.12)"
  Typography:
    Font Family: "Plus Jakarta Sans, sans-serif"
    Bangla Font: "Hind Siliguri, sans-serif"
    Title Large: "24px / SemiBold"
    Title Medium: "18px / SemiBold"
    Body Regular: "14px / Regular"
    Caption: "12px / Medium"
    Price Tag: "16px / Bold / Monospace Numerals"
```

---

## 2. Screen Specifications & Stitch Prompts

---

### Screen 1: Session Login & Register Selection (`/login`)

#### Stitch Prompt (Copy & Paste into Stitch)
```text
A sleek, modern mobile login and POS register selection screen for a bookstore POS app called "MetaPOS".
Top area features the emerald MetaPOS logo squircle and title "MetaPOS Mobile".
Form container with clean rounded white card on a light slate #F8FAFC background:
- Domain/Host display: "demostore.metaposbd.com" (pill badge with lock icon).
- Username text input field with person icon (filled with "admin").
- Password input field with eye toggle icon.
- "Select POS Terminal / Register" dropdown selector showing "Book Fair (ID: 1) - Session Open" and "Nilkhet (ID: 2) - Closed".
- "Opening Cash Balance (Float)" input field with "৳" prefix icon.
- Large emerald green primary action button "#0BC279": "Open Terminal & Start Selling" with arrow right icon.
- Bottom footer: "Connected to Odoo 19 • Book Fair Mode Active".
Clean, ultra-crisp mobile UI, Material 3 with Plus Jakarta Sans typography.
```

#### Key Functional Behaviors & Bindings
- **API Authenticate:** `POST /web/session/authenticate` with `db: "demostore"`, `login`, `password`.
- **Register Query:** `pos.config.search_read` with fields `['id', 'name', 'book_fair_mode', 'payment_method_ids', 'current_session_id']`.
- **Session Check:** If `current_session_id` has state `opened`, resume directly into Screen 2.

---

### Screen 2: Book Catalog & Fast Scan POS (`/pos/catalog`)

#### Stitch Prompt (Copy & Paste into Stitch)
```text
A sleek mobile POS catalog and fast-checkout screen for a book fair / publishing house bookstore.
Top Header Bar:
- Left: App brand "MetaPOS" with active session badge "Book Fair #00004" (emerald dot).
- Center/Right: Network online status indicator (green cloud icon) and sync status.
- Right: Barcode scanner button with camera icon and search filter icon.

Search & Barcode Bar:
- Prominent search input with barcode prefix icon: "Scan ISBN or search title, author, publisher...".
- Right side has a quick camera-scan button.

Genre / Category Carousel:
- Horizontal scrolling pill tabs: "All Books (76)", "উপন্যাস" (Fiction), "কবিতা ও ছড়া" (Poetry), "থ্রিলার ও রহস্য" (Thriller), "বিজ্ঞান কল্পকাহিনী" (Sci-Fi), "ইতিহাস ও মুক্তিযুদ্ধ" (History), "কিশোর সাহিত্য" (Young Adult).
- Active tab has solid deep slate #131926 background with white text; inactive tabs have white cards with subtle borders.

Product Grid View (2 Columns):
- Each card shows:
  - Book cover portrait aspect ratio (3:4) with clean shadow.
  - Stock badge overlay top-right: "80 left" in soft green pill (or "Out of stock" in soft red).
  - Book Title in bold text (supports Bengali script e.g. "পদ্মা নদীর মাঝি").
  - Author name in subtle gray e.g. "মানিক বন্দ্যোপাধ্যায়".
  - Publisher subtitle e.g. "স্বাধ্যায় প্রকাশনী".
  - Bottom row: Bold price "৳ 180.00" on the left, and an emerald circular "+" button on the right with tactile tap effect.

Sticky Bottom Floating Cart Bar:
- Floating bottom pill dock in #131926 dark slate:
  - Left: Cart icon with bright emerald notification badge "3 items".
  - Center: Subtotal "Total: ৳ 540.00 (Incl. 10% VAT)".
  - Right: Emerald button "#0BC279": "View Cart →".
```

#### Key Functional Behaviors & Bindings
- **Model:** `product.product`
- **Fields:** `['id', 'name', 'display_name', 'barcode', 'isbn', 'book_authors_display', 'book_publisher_name', 'book_genre_name', 'list_price', 'book_qty_on_hand', 'pos_categ_ids']`
- **Thumbnail Image URL:** `https://demostore.metaposbd.com/web/image?model=product.product&id={id}&field=image_128`
- **Stock Counter:** `book_qty_on_hand` (updated dynamically by `book_fair_stock` on order completion).
- **Offline Cache:** Stored locally in SQLite for full offline browsing.

---

### Screen 3: Cart Drawer & Order Management (`/pos/cart`)

#### Stitch Prompt (Copy & Paste into Stitch)
```text
A sleek mobile slide-over cart drawer / sheet for bookstore point of sale.
Top Header:
- "Current Order" title with order number reference "#264-1-000005".
- "Clear Cart" text button in muted red.
- Customer indicator strip: "Walk-in Customer / সাধারণ ক্রেতা" with "Change Customer" link button.

Cart Items List:
- Item row 1: Book thumbnail (60x80px), Title "Blackbird Classic", Author "Black", Unit Price "৳ 100.00".
  - Right side: Stepper controls: Minus button, quantity number ("2"), Plus button.
  - Sub-actions below row: "Discount (0%)" tag button, "Note" icon button, swipe-left reveals red delete trash bin.
- Item row 2: Book thumbnail, Title "দীপু নাম্বার টু", Author "মুহম্মদ জাফর ইকবাল", Unit Price "৳ 220.00", Qty "1".

Discount & Promotion Strip:
- Quick discount chips: "No Disc", "5%", "10% Fair Disc", "15%", "Custom %".

Financial Breakdown Card:
- Subtotal: "৳ 420.00"
- Fair Discount (-10%): "-৳ 42.00"
- VAT (10%): "৳ 37.80"
- Divider line
- Grand Total in large bold typography: "৳ 415.80" (BDT).

Bottom Action Bar:
- Secondary button: "Hold Order" (save draft).
- Primary CTA in vibrant emerald #0BC279: "Proceed to Payment (৳ 415.80) →".
```

#### Key Functional Behaviors & Bindings
- **Tax Calculation:** Default 10% VAT (`account.tax` id 1, `amount: 10.0`).
- **Discounts:** Applied on line-level `discount` (0-100 float).
- **Line UUID:** Each line assigned a persistent UUID v4 (`uuid`) for Odoo 19 sync deduplication.

---

### Screen 4: Customer Selector & Quick Onboarding Modal (`/pos/customer`)

#### Stitch Prompt (Copy & Paste into Stitch)
```text
A clean mobile customer selection and quick-creation sheet for a retail POS app.
Top Area:
- Title: "Customer / ক্রেতা নির্বাচন".
- Search input: "Search by phone number or customer name...".
- "Walk-in Customer / সাধারণ গেস্ট" quick selection pill button (selected by default).

Customer List View:
- Recent / frequent customers:
  - Avatar circle with initials.
  - Name: "Tanvir Ahmed" • Phone: "+880 1712-345678".
  - Address tag: "Dhanmondi, Dhaka".
  - Right chevron / select checkmark.

Floating Action Button / Top Action:
- "+ Add New Customer" button in emerald green.

Quick Add Customer Form (Modal / Bottom Sheet):
- Full Name (required) text field.
- Mobile Phone number (required for SMS receipt) with Bangladesh +880 flag icon.
- Email address (optional).
- Delivery / Billing address area.
- "Save & Attach to Current Order" full-width emerald CTA button.
```

#### Key Functional Behaviors & Bindings
- **Search:** `res.partner.search_read` with domain `['|', ('name', 'ilike', query), ('phone', 'ilike', query)]`
- **Fields:** `['id', 'name', 'phone', 'email', 'street', 'city']` *(Note: In Odoo 19 `phone` is used, not `mobile`)*.
- **Quick Create:** `res.partner.create` with args `[{'name': name, 'phone': phone, ...}]`.

---

### Screen 5: Checkout & Tender Settlement (`/pos/checkout`)

#### Stitch Prompt (Copy & Paste into Stitch)
```text
A high-converting, tactile mobile checkout payment screen for a retail POS terminal.
Top Banner:
- Large amount due card in dark slate #131926 background:
  - "Total Amount Due" in soft gray.
  - Grand total in huge white bold numbers: "৳ 1,978.90".

Payment Methods Segmented Tabs:
- Tab 1 (Selected): "Cash / নগদ" with cash note icon.
- Tab 2: "Card / কার্ড" with POS terminal icon.
- Tab 3: "bKash / বিকাশ" with bKash pink accent badge.
- Tab 4: "Nagad / নগদ ডিজিটাল" with orange accent badge.

Cash Tender Interactive Interface:
- Tendered amount display box: "৳ 2,000.00".
- Fast Denomination Quick-Tender Pills:
  - "Exact ৳ 1,978.90", "+৳ 500", "+৳ 1,000", "+৳ 2,000", "+৳ 5,000".
- Tactile on-screen numeric keypad (0-9, 00, Clear, Backspace).

Change / Refund Highlight Card:
- Dynamic calculation banner in light emerald #E6F9F1:
  - "Change to Return / ফেরত": "৳ 21.10" in bold dark emerald #089E62.

Digital Reference Input (when Card / bKash selected):
- Transaction ID / bKash TrxID input field: "e.g. 9B84XXL89P".

Bottom Action Button:
- Large sticky button in emerald #0BC279: "Validate & Complete Sale (৳ 1,978.90)" with checkmark icon.
```

#### Key Functional Behaviors & Bindings
- **Tender Math:** `amount_return = max(0, amount_tendered - amount_total)`
- **Payment Lines Data:**
  - Method ID 1 (Cash): `{'payment_method_id': 1, 'amount': tendered, 'is_change': false, 'uuid': ...}`
  - If change exists: Server automatically creates `is_change: true` with label `"ফেরত"`.
  - Method ID 2 (Card / Mobile Banking): `{'payment_method_id': 2, 'amount': total, 'transaction_id': trx_id, ...}`

---

### Screen 6: Order Receipt & Success / Offline Queue (`/pos/receipt`)

#### Stitch Prompt (Copy & Paste into Stitch)
```text
A celebratory order success and digital thermal receipt screen for a mobile bookstore POS.
Top Section:
- Success celebration icon: Emerald green checkmark in animated circle.
- "Order Paid Successfully!" headline.
- Order Reference: "Book Fair - #264-1-000005" • Ticket Code: "k8x9m".

Digital Thermal Receipt Card (styled like 80mm thermal paper with jagged cut edge top/bottom):
- Header: "Demo Store • মেটাপস বুক কর্নার".
- Subtitle: "Dhaka International Book Fair • Stall 42".
- Date: "19 Nov 2026, 03:45 PM" • Cashier: "Administrator".
- Divider line.
- Itemized Table:
  - 2x Blackbird Classic @ ৳ 100.00 = ৳ 200.00
  - 1x দীপু নাম্বার টু @ ৳ 220.00 = ৳ 220.00
- Divider line.
- Subtotal: ৳ 420.00
- 10% VAT: ৳ 37.80
- Total Paid: ৳ 415.80 (Cash: ৳ 500.00 | Change: ৳ 84.20).
- QR code at bottom for digital verification.

Action Buttons:
- Primary button: "Print Receipt" (Bluetooth thermal printer icon) in emerald #0BC279.
- Secondary outline button: "Share via WhatsApp / SMS" (messaging icon).
- Tertiary button in slate #131926: "Start New Sale →".

Offline Mode Sync Banner (shown when offline):
- Soft yellow alert pill: "Offline Mode: Order saved in local queue. Will sync automatically once online."
```

#### Key Functional Behaviors & Bindings
- **Odoo 19 Sync Endpoint:** `POST /web/dataset/call_kw/pos.order/sync_from_ui`
- **Thermal Printing:** Formatted ESC/POS raw bytes sent over Bluetooth SPP / BLE (58mm or 80mm).
- **Bangla Rendering:** Converts UTF-8 Bangla text to raster bitmaps before sending to thermal printer so Bangla fonts render without printer ROM limitations.

---

## 3. Flutter Client Architecture & State Flow

```
                      +-----------------------------+
                      |     Flutter Presentation    |
                      |  (Screens 1 - 6 via Stitch) |
                      +--------------+--------------+
                                     |
                                     v
                      +-----------------------------+
                      |     Riverpod / BLoC State   |
                      |  (Cart, Catalog, Auth, POS) |
                      +--------------+--------------+
                                     |
                     +---------------+---------------+
                     |                               |
                     v                               v
       +----------------------------+  +----------------------------+
       |     Odoo 19 JSON-RPC       |  |     Local SQLite Engine    |
       |     (Dio / CookieJar)      |  |     (Drift / Isar / Hive)  |
       +-------------+--------------+  +-------------+--------------+
                     |                               |
                     | Online Order Sync             | Offline Queue / Cache
                     v                               v
       +----------------------------+  +----------------------------+
       |   Odoo 19 Backend Server   |  |   Background Sync Worker   |
       |    (185.7.81.172:443)      |  |  (sync_from_ui retry loop) |
       +----------------------------+  +----------------------------+
```

### Essential Flutter Packages
- `dio`: HTTP client with persistent cookie management (`dio_cookie_manager`).
- `flutter_riverpod`: Reactive UI state management for Cart, Catalog, and POS Session.
- `drift` / `sqlite3_flutter_libs`: ACID local database for offline book catalog & pending order queue.
- `mobile_scanner`: Fast camera barcode/ISBN scanning.
- `esc_pos_utils_plus` & `flutter_bluetooth_serial`: ESC/POS Bluetooth thermal printing.
- `google_fonts`: Automatic loading of `Plus Jakarta Sans` and `Hind Siliguri`.

---

## 4. Odoo 19 Backend Contract Mapping

### Crucial Odoo 19 Evolution Notes (Must Follow)
1. **Never call `create_from_ui`:** In Odoo 19, this method was removed. You must use `pos.order.sync_from_ui`.
2. **Never call `load_pos_data`:** In Odoo 19, you call `pos.session.load_data([[session_id], []])` or targeted `search_read` calls.
3. **Always pass `uuid` on every record:** Every order, order line, and payment record must contain a client-generated UUID v4 string.
4. **Book Fair Mode (`book_fair_mode: True`):** 
   - Stock pickings and warehouse moves are bypassed.
   - Closing accounting entries are bypassed.
   - `to_invoice` must always be `false`.
   - Real-time stock is tracked on `product.template.book_qty_on_hand` via `book_fair_stock`.
