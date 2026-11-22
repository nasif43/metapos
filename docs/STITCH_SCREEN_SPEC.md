# MetaPOS Mobile - Stitch AI & Flutter Screen Generation Specification

**Document Version:** 1.0.0  
**Target Platform:** Flutter (Mobile Android & iOS, Handheld POS Terminals)  
**Backend:** Odoo 19.0 Community (`https://demostore.metaposbd.com` on `185.7.81.172`)  
**Target Tool:** Google Stitch AI / Flutter UI Generator  
**Author:** Teamwork Senior Flutter Specialist & UI/UX Architect  
**Date:** November 19, 2026  

---

## 1. Executive Overview & Purpose

This document is the **definitive, copy-paste ready specification for Stitch AI** to generate production-quality, modular Flutter screens for the **MetaPOS Mobile Sales App**. 

The backend (Odoo 19 Community with custom `book_fair_pos` and `book_fair_stock` modules) is already fully deployed on the server. The mobile app's role is to provide a lightning-fast, tactile, offline-resilient sales companion for retail book fairs (e.g. Amar Ekushey Boi Mela) and bookstore counters.

---

## 2. Design System, Tokens & UI Guidelines

All Stitch prompts below reference this unified design system to ensure visual consistency across all screens.

### 2.1 Color Palette
```yaml
Colors:
  Brand Primary: "#0BC279"         # MetaPOS Emerald Green
  Brand Primary Dark: "#089E62"    # Darker shade for active/pressed states
  Brand Primary Light: "#E6F9F1"   # Soft mint background for badges
  Accent Indigo: "#4F46E5"        # Secondary action / sync accent
  Surface Dark: "#131926"         # Slate Navy (Sidebar / Headers / Keypad bg)
  Surface Light: "#F8FAFC"        # Background canvas
  Surface Card: "#FFFFFF"         # Card & sheet surfaces
  Border Default: "#E2E8F0"       # Subtle divider lines
  Border Focus: "#0BC279"         # Focused input stroke
  Text Primary: "#0F172A"         # High-contrast charcoal/black
  Text Secondary: "#64748B"       # Medium slate for subtitles and metadata
  Text Muted: "#94A3B8"           # Light slate for placeholders
  Status InStock: "#10B981"       # Emerald green badge
  Status LowStock: "#F59E0B"      # Amber warning badge
  Status OutOfStock: "#EF4444"    # Crimson red badge
  Cash Tender Accent: "#059669"   # Money green
  Digital bKash: "#E2136E"        # Authentic bKash Magenta
```

### 2.2 Typography
- **Primary Font**: `Plus Jakarta Sans` (Latin numbers, codes, labels)
- **Bengali Font**: `Hind Siliguri` / `Noto Sans Bengali` (Book titles, author names, genres, Bangla receipts)
- **Currency Symbol**: Bangladeshi Taka `৳` (Unicode `\u09F3`, code `BDT`)
- **Type Scale**:
  - `Display / Total Due`: 32sp, SemiBold, height 1.2
  - `Heading 1`: 22sp, Bold, height 1.3
  - `Heading 2`: 18sp, SemiBold, height 1.3
  - `Body Regular`: 14sp, Regular, height 1.4
  - `Body Medium`: 14sp, Medium, height 1.4
  - `Caption`: 12sp, Medium, height 1.2
  - `Keypad Digit`: 24sp, SemiBold, height 1.0

### 2.3 Component Geometry & Spacing
- **Base Grid Unit**: 8dp (padding: 8, 16, 24, 32dp)
- **Touch Target Minimum**: `48dp x 48dp` (optimized for rapid thumb tapping on mobile and rugged POS handhelds)
- **Corner Radii**:
  - Cards & Containers: `16dp`
  - Action Buttons: `12dp`
  - Badges & Pills: `8dp`
  - Modal Bottom Sheets: `24dp` top radius
- **Elevation**:
  - Floating Scanner / Sticky Bottom Bar: Elevation 4 (`BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))`)
  - Product Cards: Subtle outline (`Border.all(color: Color(0xFFE2E8F0))`) or Elevation 1

---

## 3. Screen 1: Login, Instance Configuration & Register Setup

### 3.1 Screen Specifications
- **Name**: `SessionLoginScreen`
- **Route**: `/login`
- **Purpose**: Authenticate sales operator, verify connection to `https://demostore.metaposbd.com`, select active POS terminal (`Book Fair` [ID 1] or `nilkhet` [ID 2]), verify active session status (`opened` vs `closed`), and enter opening cash float if starting a new shift.
- **Key State Variables**:
  - `serverUrlController` (default: `https://demostore.metaposbd.com`)
  - `databaseController` (default: `demostore`)
  - `usernameController` (default: `admin`)
  - `passwordController`
  - `selectedConfigId` (1 for Book Fair, 2 for nilkhet)
  - `activeSession` (`Book Fair/00004` [ID 7], State: `opened`)
  - `openingFloatController` (e.g. `5000.00 ৳`)

### 3.2 Stitch AI Generation Prompt
```markdown
Generate a high-fidelity Flutter screen widget named `SessionLoginScreen` for the MetaPOS Mobile Sales application.

Design Style & Palette:
- Brand colors: Primary Emerald (#0BC279), Deep Slate Navy (#131926), Canvas (#F8FAFC), Card Surface (#FFFFFF).
- Fonts: Plus Jakarta Sans with support for Bengali text (Hind Siliguri).
- Layout: Modern single-column login card with responsive vertical centering, clean elevation, and smooth status banners.

Screen Structure:
1. Header Section:
   - Centered MetaPOS branded logo or icon container (emerald green rounded square with white geometric register/book mark).
   - App title: "MetaPOS Boi Mela" in 24sp Bold (#0F172A).
   - Subtitle: "Handheld Sales & Register Terminal" in 14sp (#64748B).
2. Server & Tenant Accordion (Collapsible):
   - Defaults to "https://demostore.metaposbd.com" (Server) and "demostore" (Database).
   - Shows a green dot indicator with "Server Online (Odoo 19.0)".
3. Credentials Form:
   - Login / Username input with prefix icon `Icons.person_outline` (default mock: "admin").
   - Password input with obscure text toggle and prefix icon `Icons.lock_outline`.
   - "Remember register login" checkbox.
4. POS Register Selector:
   - Dropdown or Segmented Card selector for POS Configs:
     * Option A: "Book Fair (স্টল ১)" [Config ID 1] — Badge: "Active Session #7 Open" in emerald green.
     * Option B: "Nilkhet Store (নীলক্ষেত)" [Config ID 2] — Badge: "Closed" in amber.
5. Opening Cash Float (conditional if starting a new session):
   - Number field: "Opening Cash Float (ক্যাশ ড্রয়ার ব্যালেন্স)" with prefix "৳ " (e.g. 5,000.00).
6. Action Button:
   - Primary full-width button: "Open Register & Sync Catalog" (height 54dp, color #0BC279, text white 16sp Bold).
   - Loading indicator state when authenticating.
7. Footer:
   - Offline Mode toggle switch: "Work Offline (Offline Cache Available)".
   - Small copyright: "Powered by Metamorphosis Ltd • Odoo 19 Community".

State & Code Requirements:
- Write clean, modular Flutter code using `StatefulWidget` or Riverpod `ConsumerStatefulWidget`.
- Include form validation, text controllers, and mock authentication handler returning success for admin/CaEYjbVrDuk8JtD9qykXifeKsmqQZ.
- Use explicit SizedBox padding (8/16/24dp) and proper SafeArea wrapping.
```

---

## 4. Screen 2: Catalog Master & Barcode/ISBN Scanner

### 4.1 Screen Specifications
- **Name**: `BookCatalogScreen`
- **Route**: `/catalog`
- **Purpose**: Fast, high-density book discovery and rapid barcode scanning. Support for camera-based ISBN scanner, hardware HID laser scanner, multi-field search (title, author, publisher, ISBN), Bangla genre filtering tabs, live stock badges (`book_qty_on_hand`), and quick quantity additions.
- **Mock Catalog Records from `demostore`**:
  1. *Blackbrid Classic* — Author: Black, Publisher: black publisher, Price: `100.00 ৳`, Stock: `80`, ISBN: `9796869458274`, Barcode: `5556666`.
  2. *জোছনা ও জননীর গল্প* — Author: হুমায়ূন আহমেদ, Publisher: অন্যপ্রকাশ, Price: `850.00 ৳`, Stock: `45`, ISBN: `9789845021234` (Valid EAN-13 check digit 4).
  3. *পদ্মানদীর মাঝি* — Author: মানিক বন্দ্যোপাধ্যায়, Publisher: সময় প্রকাশন, Price: `320.00 ৳`, Stock: `12`, ISBN: `9789844580121` (Corrected EAN-13 modulo-10 check digit 1).
  4. *হিমু সমগ্র* — Author: হুমায়ূন আহমেদ, Publisher: পার্ল পাবলিকেশন্স, Price: `1,200.00 ৳`, Stock: `3`, ISBN: `9789848970010` (Corrected EAN-13 modulo-10 check digit 0).
  5. *দীপু নাম্বার টু* — Author: জাফর ইকবাল, Publisher: সময় প্রকাশন, Price: `280.00 ৳`, Stock: `0` (Out of stock), ISBN: `9789844580459` (Corrected EAN-13 modulo-10 check digit 9).
- **Genre Tabs**:
  - `সব বই (All)`
  - `উপন্যাস` (ID 59)
  - `কবিতা ও ছড়া` (ID 61)
  - `থ্রিলার ও রহস্য` (ID 62)
  - `বিজ্ঞান কল্পকাহিনী` (ID 63)
  - `ইতিহাস ও মুক্তিযুদ্ধ` (ID 64)

### 4.2 Stitch AI Generation Prompt
```markdown
Generate a high-performance, polished Flutter catalog screen named `BookCatalogScreen` for MetaPOS Mobile.

Design Style & Palette:
- Primary: #0BC279 (Emerald), Deep Slate Navy: #131926, Canvas: #F8FAFC, Card Surface: #FFFFFF.
- Typography: Plus Jakarta Sans for numbers & English UI, Hind Siliguri for Bengali titles and authors.
- Layout: Sticky top search bar, horizontal category pills, 2-column Grid of book cards, floating camera scanner action button, and sticky bottom mini-cart banner.

Screen Structure:
1. App Bar & Status:
   - Left: Cashier avatar and title "Book Fair Stall #1" with green "Online" pulse dot.
   - Right: Bluetooth Printer status icon (green connected) and Sync status icon.
2. Search & Filter Bar:
   - Search TextField with rounded borders (12dp), prefix `Icons.search`, hint "Search by Title, Author, or ISBN (বই, লেখক, আইএসবিএন খুঁজুন)...".
   - Suffix: Quick barcode scan icon button.
3. Category / Genre Horizontal Scroll:
   - Filter chips/pills: "সব বই (All)", "উপন্যাস", "কবিতা ও ছড়া", "থ্রিলার ও রহস্য", "ইতিহাস ও মুক্তিযুদ্ধ", "বিজ্ঞান কল্পকাহিনী".
   - Selected chip: #0BC279 fill with white text; unselected: white fill with #64748B text and #E2E8F0 border.
4. Book Grid (2 Columns, GridView.builder):
   - Card dimensions: Aspect ratio ~0.65 (book proportions).
   - Top 55%: Book cover thumbnail container with placeholder book jacket graphic, or network image with cached fallback.
   - Author badge / Genre chip overlay on image: e.g. "হুমায়ূন আহমেদ" or "অন্যপ্রকাশ".
   - Bottom 45%:
     * Title: 14sp SemiBold in 2 max lines with ellipsis (e.g. "জোছনা ও জননীর গল্প").
     * Author & Publisher: 12sp Regular in #64748B (e.g. "মানিক বন্দ্যোপাধ্যায় • সময়").
     * Price: 16sp Bold in #0F172A: "৳ 850.00".
     * Stock Badge:
       - If stock > 10: Pill with text "45 in stock", bg #E6F9F1, text #10B981.
       - If stock 1-5: Pill with text "3 left", bg #FEF3C7, text #D97706.
       - If stock <= 0: Pill with text "Out of stock (০ টি)", bg #FEE2E2, text #EF4444.
     * Tactile "+" Add Button: Circular 36dp emerald button to immediately add 1 copy to cart.
5. Floating Scanner Action Button (FAB):
   - Floating circular or extended pill FAB in bottom right: `Icons.qr_code_scanner` with label "Scan ISBN".
   - Tapping simulates or opens barcode camera viewfinder sheet.
6. Sticky Bottom Mini-Cart Bar (appears when cart has >= 1 item):
   - Dark Slate Navy background (#131926), height 64dp, rounded top corners 16dp.
   - Left: Cart icon with yellow badge count (e.g. "3 items") and Total: "৳ 1,970.00".
   - Right: "View Cart / অর্ডার দেখুন" button in emerald green (#0BC279) with right chevron.

State & Code Requirements:
- Build with clean Flutter code, supporting search filtering by text and category selection.
- Include mock data list with at least 5 realistic Bangladeshi book items matching the specification.
- Provide smooth micro-interactions on tapping "+" button with animated bounce or snackbar feedback.
```

---

## 5. Screen 3: Cart & Order Management

### 5.1 Screen Specifications
- **Name**: `CartScreen`
- **Route**: `/cart`
- **Purpose**: Review selected books, adjust quantities with steppers, apply book fair discounts (e.g. 5%, 10%, 20% or custom percentage), enter customer notes, assign a customer, inspect the 10% VAT calculation, and proceed to payment.
- **Financial Math Rules & Dual Tax Pricing Models**:
  The mobile app must support both retail pricing workflows depending on backend tax configuration:
  - **Mode A: MRP Tax-Inclusive Mode (Bangladeshi Retail Book Publishing Standard)**:
    Book printed cover prices (MRP) are gross customer totals. For an order of ৳ 1,700.00 with 10% Fair Discount:
    - Gross Item Subtotal (মোট বই মূল্য): $\sum (\text{Price} \times \text{Qty}) = \text{৳ } 1,700.00$
    - Fair Discount (-10% ছাড়): $- \text{৳ } 170.00$
    - Gross Payable Total (MRP প্রদেয়): $\text{৳ } 1,530.00$
    - Net Amount (করবিহীন ভিত্তি): $\text{Gross Payable} / 1.10 = \text{৳ } 1,390.91$
    - 10% VAT (১০% ভ্যাট অংশ): $\text{Net Amount} \times 0.10 = \text{৳ } 139.09$
    - Grand Total (সর্বমোট প্রদেয়): $\text{Net Amount} + \text{VAT} = \text{৳ } 1,530.00$
  - **Mode B: Additive Tax Mode (Odoo Server Default - `account.tax` ID 1 `price_include: false`)**:
    Shelf prices represent net taxable base; tax is added on top:
    - Base Item Subtotal: ৳ 1,700.00
    - Fair Discount (-10%): - ৳ 170.00
    - Price Subtotal (Net Base): ৳ 1,530.00
    - 10% VAT (১০% ভ্যাট যোগ): $\text{Subtotal} \times 0.10 = \text{৳ } 153.00$
    - Grand Total (সর্বমোট প্রদেয়): $\text{Subtotal} + \text{VAT} = \text{৳ } 1,683.00$
  - **Critical Developer Sync Note (`pos.order.sync_from_ui`)**:
    If the backend `account.tax` ID 1 has `price_include: false` (server default) while the bookstore operates in Mode A (MRP-Inclusive), the Flutter app **must reverse-calculate the pre-tax base unit price**:
    $$\text{price\_unit} = \frac{\text{list\_price}}{1.10} \quad (\text{e.g. } \frac{৳ 850.00}{1.10} = ৳ 772.73)$$
    This ensures that when Odoo applies 10% additive tax, `price_subtotal_incl` equals the customer's gross MRP (৳ 850.00), preventing underpayment or cash register reconciliation errors. If the backend is configured with `price_include: true`, `price_unit` is sent as full MRP (৳ 850.00).

### 5.2 Stitch AI Generation Prompt
```markdown
Generate a modern, highly functional Flutter screen named `CartScreen` for the MetaPOS Mobile app.

Design Style & Palette:
- Brand colors: Primary Emerald (#0BC279), Deep Slate Navy (#131926), Canvas (#F8FAFC), Card Surface (#FFFFFF).
- Typography: Plus Jakarta Sans with Hind Siliguri for Bengali text.
- Layout: Top customer attachment banner, scrollable itemized cart list with swipe-to-delete, discount pill selector, order notes, financial summary card, and sticky checkout button.

Screen Structure:
1. Custom App Bar:
   - Title: "Current Order (বর্তমান অর্ডার)" with order sequence tag "#000006".
   - Actions: "Clear All" red text button with confirmation dialog.
2. Customer Tag Banner:
   - Card at top with #F1F5F9 background and 12dp border radius.
   - Left: User avatar icon. If assigned, show "Customer: Kazi Nazrul (01711000000)". If guest, show "Walk-in Customer / গেস্ট ক্রেতা".
   - Right: "Change / Add" text button in emerald green that navigates to Customer Selection.
3. Cart Items List (ListView.separated):
   - Each item card:
     * Left: Small 48x64dp book thumbnail.
     * Center:
       - Book Title: 15sp SemiBold (e.g. "জোছনা ও জননীর গল্প").
       - Author & ISBN: 12sp in #64748B (e.g. "হুমায়ূন আহমেদ • 9789845021234").
       - Unit Price: "৳ 850.00 each".
       - Line Note button: Small icon `Icons.edit_note` to attach a gift inscription or note.
     * Right:
       - Quantity Stepper: Compact pill container with `[-]`, `[ 2 ]`, `[+]` buttons.
       - Line Total: 16sp Bold "৳ 1,700.00".
       - Discount tag if applied: "-10% (Fair Discount)" in emerald green text.
     * Swipe-to-delete background with red trash icon.
4. Fair Discount Quick Bar:
   - Horizontal label: "Fair Discount (মেলার বিশেষ ছাড়):"
   - Quick selectable pills: `[ None ]`, `[ 5% ]`, `[ 10% ]`, `[ 15% ]`, `[ 20% ]`, `[ Custom ]`.
   - Applying a percentage applies to all eligible lines.
5. Order Summary Card:
   - Clean white card with subtle 1dp border (#E2E8F0):
     * Pricing Model Badge: "MRP Inclusive / এমআরপি অন্তর্ভুক্ত (10% VAT included)" [Configurable: MRP Inclusive vs Additive Tax]
     * In MRP-Inclusive Mode:
       - "Subtotal (মোট বই মূল্য)": "৳ 1,700.00"
       - "Fair Discount (ছাড়)": "- ৳ 170.00"
       - "Net Amount (করবিহীন ভিত্তি)": "৳ 1,390.91"
       - "VAT / ভ্যাট (10%)": "৳ 139.09"
       - Divider line.
       - "Grand Total (সর্বমোট প্রদেয়)": 20sp Bold in #0F172A: "৳ 1,530.00".
     * In Additive Tax Mode (Server Default):
       - "Price Subtotal (করবিহীন মূল্য)": "৳ 1,530.00"
       - "10% VAT (ভ্যাট যোগ)": "৳ 153.00"
       - Divider line.
       - "Grand Total (সর্বমোট প্রদেয়)": 20sp Bold: "৳ 1,683.00".
6. Sticky Bottom Action Bar:
   - Padding 16dp, elevated with top shadow.
   - Primary Full-Width Button: "Proceed to Payment • ৳ 1,530.00 (পেমেন্ট করুন)" in #0BC279, height 54dp, 16sp Bold with trailing arrow (or ৳ 1,683.00 in Additive Mode).

State & Code Requirements:
- Build complete state handling with `setState` or Riverpod state provider.
- Implement reactive quantity increment/decrement, discount calculation, and line removal.
- Ensure all numbers format properly with commas (e.g. 1,530.00 ৳).
```

---

## 6. Screen 4: Customer Selector & Quick Onboarding

### 6.1 Screen Specifications
- **Name**: `CustomerSelectScreen`
- **Route**: `/customer-select`
- **Purpose**: Search existing customers in the Odoo database by name, phone number, or barcode, toggle Walk-in / Guest mode, or pop open a "Quick Add Customer" modal to register a new patron in seconds.
- **Backend Schema Constraints**: In Odoo 19, the partner phone field is strictly `phone` (not `mobile`).

### 6.2 Stitch AI Generation Prompt
```markdown
Generate a high-productivity Flutter screen named `CustomerSelectScreen` with an embedded Quick-Create bottom sheet for MetaPOS Mobile.

Design Style & Palette:
- Primary: #0BC279 (Emerald), Deep Slate: #131926, Surface Light: #F8FAFC, Card: #FFFFFF.
- Typography: Plus Jakarta Sans and Hind Siliguri.
- Layout: Search bar, quick "Guest / Walk-in" tile, scrollable registered customer list with phone numbers, and a floating or sticky "Create New Customer" button.

Screen Structure:
1. App Bar:
   - Title: "Select Customer (গ্রাহক নির্বাচন)".
   - Back button returning to Cart.
2. Search Input:
   - Large TextField with rounded corners: "Search by Name or Phone (নাম বা মোবাইল নম্বর লিখুন)...".
   - Prefix search icon, suffix clear icon.
3. Default Option: "Walk-in / Guest Customer (সাধারণ ক্রেতা)":
   - Card tile with user silhouette, subtitle "No customer info attached to receipt".
   - Radio / Select button that sets customer to null and pops back to cart.
4. Recent & Registered Customer List (ListView.builder):
   - List tile with customer initials avatar circle (#E6F9F1 with #089E62 text).
   - Customer Name: 16sp SemiBold (e.g. "Kazi Nazrul", "Rahim Ahmed", "Hello grahok").
   - Phone Number: 14sp Regular in #64748B with phone icon (e.g. "01711000000").
   - City / Address tag: "Dhanmondi, Dhaka".
   - Trailing: Select checkmark or tap tile to assign.
5. Quick Add Floating Button or Header Action:
   - Prominent button "+ New Customer (নতুন গ্রাহক)".
   - Tapping slides up a Modal Bottom Sheet:
     * Sheet Title: "Quick Add Customer (নতুন গ্রাহক নিবন্ধন)".
     * Full Name field (Required, textCapitalization: words).
     * Phone Number field (Required, keyboardType: phone, prefix "+880").
     * Email field (Optional).
     * Address / City field (Optional).
     * Action Button: "Save & Attach to Order (সংরক্ষণ করুন)" in #0BC279.

State & Code Requirements:
- Build stateful search filtering that updates list as user types phone or name.
- Provide form validation in the quick create modal (validates phone has at least 11 digits).
- Include realistic mock Bangladeshi customer entries matching live demostore data.
```

---

## 7. Screen 5: Multi-Tender Checkout & Payment

### 7.1 Screen Specifications
- **Name**: `CheckoutPaymentScreen`
- **Route**: `/checkout`
- **Purpose**: Rapid counter tender settlement. Support for Cash with numeric keypad and quick denomination chips (+500, +1000, +2000), real-time dynamic change calculation (`ফেরত`), Card/POS machine payment, bKash / Nagad digital payment with Transaction ID entry, and multi-tender split payments (e.g. 500 Cash + 1,030 bKash).
- **Backend Sync Mapping & Payment Constraints**:
  - `Cash`: `payment_method_id = 1` (Odoo `demostore` Cash method). Over-tender permitted; change return calculated automatically.
  - `Card`: `payment_method_id = 2` (Odoo `demostore` Card method). Capped at remaining balance due; no over-tender or change return.
  - `bKash / Nagad`: Maps to Bank/Card method with TrxID in payment reference. Capped at remaining balance due; no over-tender or change return.
  - **Dynamic Formulas**:
    - If $\text{Tendered} < \text{Total Due}$: $\text{Remaining Balance} = \text{Total Due} - \text{Tendered}$
    - If $\text{Tendered} \ge \text{Total Due}$: $\text{Change to Return} = \text{Tendered} - \text{Total Due}$
  - Change calculation: `amount_return = Tendered - Grand Total` (Cash only).

### 7.2 Stitch AI Generation Prompt
```markdown
Generate a high-efficiency Flutter checkout screen named `CheckoutPaymentScreen` for MetaPOS Mobile.

Design Style & Palette:
- Brand colors: Primary Emerald (#0BC279), Deep Slate Navy (#131926), Cash Accent (#059669), bKash Magenta (#E2136E), Canvas (#F8FAFC), Card (#FFFFFF).
- Typography: Plus Jakarta Sans for large numerical totals and keypad, Hind Siliguri for Bangla labels.
- Layout: Prominent Total Due header, Tender method tabs (Cash, Card, bKash), interactive on-screen numeric keypad for cash tender, quick cash buttons (+500, +1000, +2000, Exact), real-time change return display, and finalize button.

Screen Structure:
1. Total Due Header Banner:
   - Deep Slate Navy card (#131926) with rounded bottom:
     * Label: "Total Amount Due (মোট প্রদেয় বিল)" in 13sp white/slate.
     * Big bold amount: "৳ 1,530.00" in 32sp Bold white (or "৳ 1,683.00" in Additive Mode).
     * Customer tag: "Kazi Nazrul (01711000000)" with invoice sequence #000006.
2. Tender Method Selector Tabs:
   - Horizontal pill bar:
     * Tab 1: "Cash (নগদ)" with cash icon [Selected].
     * Tab 2: "Card / POS (কার্ড)" with credit card icon.
     * Tab 3: "bKash / Nagad (বিকাশ)" with smartphone icon.
3. If Cash Selected (Primary Counter Flow):
   - Tendered Display Box:
     * "Tendered Cash (গৃহীত টাকা)": Large input display showing entered amount (e.g. "৳ 2,000.00" or typed digits).
   - Dynamic Change Return / Balance Box (High Visibility, Reactive):
     * **Reactive Calculation Rules**:
       - When Tendered < Total Due:
         Label: "Remaining Balance (বাকি):"
         Calculation: `Remaining Balance = Total Due - Tendered` (e.g. Total ৳ 1,530.00, Tendered ৳ 1,000.00 -> displays "৳ 530.00" in 20sp Bold #DC2626).
       - When Tendered >= Total Due:
         Label: "Change to Return (ফেরত দিন):"
         Calculation: `Change to Return = Tendered - Total Due` (e.g. Total ৳ 1,530.00, Tendered ৳ 2,000.00 -> displays "৳ 470.00" in 24sp Bold #059669 on #E6F9F1 card).
   - Quick Cash Denomination Chips:
     * Horizontal row: `[ Exact (৳1,530) ]`, `[ +500 ৳ ]`, `[ +1000 ৳ ]`, `[ +2000 ৳ ]`.
     * Tapping adds to current tender amount.
   - Integrated Numeric Touch Keypad:
     * 4x3 grid: `[1] [2] [3]`, `[4] [5] [6]`, `[7] [8] [9]`, `[C] [0] [⌫]`.
     * Tactile buttons, 52dp height, soft slate hover states.
4. If Card / bKash Selected (Digital Payment Constraints):
   - **Tender Restriction Constraint**: "Over-tender and Change Return are strictly restricted to Cash payments. Card and bKash inputs are capped at the remaining balance due and cannot accept over-tender or return change."
   - Card: Pre-filled with exact remaining balance due, Last 4 digits input, Approval code.
   - bKash: Pre-filled with exact remaining balance due, TrxID input (e.g. "BLA789XYZ12") with authentic magenta accent button.
5. Split Payment Section (Collapsible):
   - Shows added payment lines: e.g. "Line 1: Cash ৳ 500.00", "Line 2: bKash ৳ 1,030.00".
6. Finalize Sale Button:
   - Full-width button at bottom: "Validate & Print Receipt (অর্ডার সম্পন্ন করুন)" in #0BC279.
   - Disabled if remaining balance > 0.
   - Tapping shows brief circular progress, calls mock Odoo sync, and transitions to Screen 6.

State & Code Requirements:
- Manage tender input buffer string ("2000") and compute change dynamically using reactive formulas:
  `remainingBalance = max(0.0, totalDue - tenderedCash);`
  `changeReturn = max(0.0, tenderedCash - totalDue);`
- Enforce business logic: over-tender is allowed ONLY for Cash payments; digital/card tenders are capped at `remainingBalance`.
- Implement sound or haptic feedback on keypad button presses.
- Support seamless split tender recording in local state.
```

---

## 8. Screen 6: Order Success, Thermal Receipt & Offline Queue

### 8.1 Screen Specifications
- **Name**: `OrderReceiptScreen`
- **Route**: `/receipt`
- **Purpose**: Order completion confirmation, receipt preview formatted for 58mm (32-column standard) and 80mm (48-column) thermal ESC/POS Bluetooth printers, high-fidelity Bengali text rasterization, WhatsApp / SMS receipt sharing, and offline queue status indicator if transaction was saved locally during network disconnection.
- **Receipt Fields**:
  - Store Header: `Demo Store` (স্টোর ১ - একুশে বইমেলা)
  - Address: `বাংলা একাডেমি প্রাঙ্গণ, ঢাকা`
  - POS Reference: `264-1-000006`
  - Cashier: `Administrator`
  - Ticket Code: `m5z7p`
  - Itemized Lines with Bengali titles, quantity, and line price
  - Pricing Breakdown:
    - In MRP Tax-Inclusive Mode: Net Subtotal (৳ 1,048.18), 10% VAT (৳ 104.82), Total (৳ 1,153.00)
    - In Additive Tax Mode (Server Default): Price Subtotal (৳ 1,153.00), 10% VAT (৳ 115.30), Total (৳ 1,268.30)
  - Tendered and Change (`ফেরত`)
  - QR Code containing receipt validation URL

### 8.2 Stitch AI Generation Prompt
```markdown
Generate a complete, photorealistic Flutter receipt confirmation screen named `OrderReceiptScreen` for MetaPOS Mobile.

Design Style & Palette:
- Brand colors: Primary Emerald (#0BC279), Slate Navy (#131926), Receipt Paper (#FAFAFA), Canvas (#F1F5F9).
- Typography: Courier / Monospace for thermal receipt preview, Plus Jakarta Sans for UI controls, Hind Siliguri for Bengali items.
- Layout: Animated green checkmark success badge, paper receipt card with jagged/serrated edge visual effect, printer connection indicator, action button cluster, and "Next Sale" footer.

Screen Structure:
1. Top Success Badge:
   - Circular animated green checkmark container (#E6F9F1 bg, #10B981 icon).
   - "Order Completed Successfully! (অর্ডার সম্পন্ন হয়েছে)" in 20sp Bold.
   - Order Reference: "POS Ref: 264-1-000006" • Ticket: "m5z7p".
   - Offline Indicator (Conditional):
     * If synced: Green badge "Synced with Odoo Server (লাইভ সিংক্রোনাইজড)".
     * If offline: Amber badge "Saved to Offline Queue (#Q-0012) • Auto-sync pending".
2. Thermal Receipt Preview Card:
   - Styled as a realistic white thermal paper roll receipt with subtle drop shadow:
     * Header: "DEMO STORE (বইমেলা স্টল)" centered bold.
     * Subheader: "Amar Ekushey Boi Mela, Bangla Academy, Dhaka".
     * Metadata: Date & Time, Cashier: Administrator, Register: Book Fair.
     * Separator line: "--------------------------------" (32 characters for 58mm mobile printer standard).
     * Table columns: "আইটেম (Item)         মূল্য (Tk)"
     * Item Line 1: "জোছনা ও জননীর গল্প"
       Subline: " 1 x 850.00 (-10%)       765.00"
     * Item Line 2: "পদ্মানদীর মাঝি"
       Subline: " 1 x 320.00 (-10%)       288.00"
     * Item Line 3: "Blackbrid Classic"
       Subline: " 1 x 100.00              100.00"
     * Separator line: "--------------------------------".
     * Dual Pricing Display (Default: MRP Tax-Inclusive Mode):
       - "উপমোট ভিত্তি (Net):     1,048.18 ৳"
       - "১০% ভ্যাট (10% VAT):      104.82 ৳"
       - "সর্বমোট (TOTAL):        1,153.00 ৳"
       - [Note: If in Additive Tax Mode: Subtotal: 1,153.00 ৳, 10% VAT: 115.30 ৳, TOTAL: 1,268.30 ৳]
     * Separator line: "--------------------------------".
     * "নগদ গৃহীত (Tendered):   1,500.00 ৳"
     * "ফেরত (Change Returned):   347.00 ৳"
     * Separator line: "--------------------------------".
     * Centered QR Code graphic (contains receipt UUID).
     * Footer: "বই কিনুন, জ্ঞান বাড়ান • ধন্যবাদ আবার আসবেন!"
3. Printer Connection Status:
   - Status bar: Bluetooth icon with "Printer: POS-58BT (Connected)" with 58mm / 80mm width toggle.
4. Action Buttons:
   - Button 1: "Print Receipt (রসিদ প্রিন্ট)" in emerald green (#0BC279), full width, height 50dp, with print icon.
   - Row with 2 secondary buttons:
     * "Share WhatsApp" (#25D366 icon button).
     * "Send SMS Receipt" (#4F46E5 icon button).
5. Next Sale CTA:
   - Sticky bottom button: "Start New Order (নতুন অর্ডার)" in deep slate navy (#131926), height 54dp, with reset icon. Tapping clears cart and returns to Catalog.

State & Code Requirements:
- **Thermal Printer ESC/POS Rasterization Requirement (MANDATORY)**:
  "Bengali text (`যুক্তবর্ণ`) must be rendered to bitmap via Flutter `RepaintBoundary` -> `toImage()` and transmitted as monochrome raster bit-image bytes (`imageRaster` / `GS v 0`) to ESC/POS thermal printers because printer hardware font ROMs lack Bengali Unicode code pages."
  Sending raw UTF-8 text bytes to ESC/POS printer hardware will cause character corruption (e.g. CP437/CP850 decoding errors). Developers must wrap the receipt layout in a `RepaintBoundary`, capture it as a 1-bit monochrome raster image, and print using `esc_pos_utils` / `blue_thermal_printer` `printCustomImage` or `imageRaster`.
- **Printer Width Specifications**:
  Specify standard 32-column separator lines (`--------------------------------`) for 58mm mobile Bluetooth thermal printers (384 dots @ 203 DPI, dominant format at Boi Mela stalls), with optional 48-column mode (`------------------------------------------------`, 576 dots) for 80mm desktop thermal printers.
- Include simulated printing dialog animation.
- Ensure proper character rendering for Bangla characters and the Taka symbol (৳).
```

---

## 9. Stitch Execution Instructions for Frontend Developers

When generating screens in Stitch AI, follow this 4-step sequence:

1. **Step 1 - Global Design Tokens**:
   Paste Section 2 (Design System, Tokens & UI Guidelines) into Stitch's system instructions or project prompt to establish colors, typography, and geometry.
2. **Step 2 - Sequential Screen Generation**:
   Prompt Stitch one screen at a time using the exact prompts in Sections 3, 4, 5, 6, 7, and 8.
3. **Step 3 - Component Assembly**:
   Organize the generated Flutter widgets into the following project structure:
   ```
   lib/
   ├── core/
   │   ├── constants/
   │   │   ├── app_colors.dart
   │   │   ├── app_typography.dart
   │   │   └── api_endpoints.dart
   │   └── utils/
   │       └── bangla_currency_formatter.dart
   ├── data/
   │   ├── models/
   │   │   ├── book_product.dart
   │   │   ├── pos_order_payload.dart
   │   │   └── customer_partner.dart
   │   ├── repositories/
   │   │   ├── odoo_pos_repository.dart
   │   │   └── offline_queue_repository.dart
   │   └── local/
   │       └── app_database.dart (Drift / Sqflite)
   └── presentation/
       ├── screens/
       │   ├── session_login_screen.dart       # Screen 1
       │   ├── book_catalog_screen.dart        # Screen 2
       │   ├── cart_screen.dart                # Screen 3
       │   ├── customer_select_screen.dart     # Screen 4
       │   ├── checkout_payment_screen.dart    # Screen 5
       │   └── order_receipt_screen.dart       # Screen 6
       └── widgets/
           ├── book_card.dart
           ├── thermal_receipt_view.dart
           └── cash_keypad.dart
   ```
4. **Step 4 - Wire Backend JSON-RPC Endpoints**:
   Connect each screen's callbacks to the corresponding Odoo 19 endpoints detailed in `MOBILE_POS_TECHNICAL_SPEC.md`:
   - `SessionLoginScreen` -> `/web/session/authenticate`
   - `BookCatalogScreen` -> `pos.session.load_data` & `product.product/search_read`
   - `CustomerSelectScreen` -> `res.partner/search_read` & `res.partner/create`
   - `CheckoutPaymentScreen` -> `pos.order/sync_from_ui`
   - `OrderReceiptScreen` -> ESC/POS thermal printing & background sync queue.
