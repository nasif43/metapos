# Changelog

All notable changes to MetaPOS are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-11-22

### Added
- **Multi-Cart Walk-in Concurrency**:
  - Cashiers can maintain multiple active customer carts simultaneously without losing state.
  - Horizontal scrolling tab bar with active badges, item counters, cart switching, custom renaming via long-press, and discard guards.
- **Hardware Camera Barcode & QR Scanner**:
  - Integrated `mobile_scanner` with native camera feed for scanning physical book barcodes, ISBNs, and customer receipt tickets.
  - Hardware controls: real-time flash/torch toggle and rear/front camera switching.
  - Added dedicated Order & Receipt camera scanner for the returns/refunds workflow.
- **Full Returns & Refunds (Odoo 19 Connected)**:
  - SQLite schema v4 persistence for local and queued returns.
  - Order history screen (`/orders` & `/history`) with search, filter chips (`সব`, `ফেরতযোগ্য`, `রিফান্ড`), and barcode lookup.
  - Order details screen (`/orders/detail`) with per-line refundable quantity bounding (`max(0, qty - refunded_qty)`).
  - Bottom sheet return flow with quantity steppers and payout tender selection (Cash, Bank, bKash).
  - Reverse stock synchronization and Odoo 19 `pos.order` refund payload compliance.
- **Interactive Dashboard with Live Drill-Downs**:
  - Dynamic KPI cards displaying real-time session telemetry.
  - Modal drill-downs for payments breakdown, top-selling titles, genre distribution, and cashier telemetry.
  - Hourly sales and order volume histograms.
- **High-Resolution Book Covers**:
  - Switched catalog image ingestion to 256px resolution with `BoxFit.contain` canvas rendering, eliminating blurry and cropped covers.

### Changed
- **Branding & White-Labeling**:
  - Removed all third-party ERP/Odoo branding across headers, footers, receipts, and login screens.
  - Updated branding to **MetaPOS • Smart Retail POS**.
  - Server status updated to "Server Online • Connected" and sync pill updated to "Synced with Cloud".
- **Number & Currency Formatting**:
  - Replaced abbreviated "K" notation with full localized integer digit display (e.g. `৳ 1,500`, `৳ 5,000`).
- **Checkout Keypad Ergonomics**:
  - When tapping "Exact" (`সঠিক পরিমাণ`), entering any digit now immediately replaces the total instead of appending to it.
- **Bangla Localization Refinements**:
  - Changed KPI title from `মোট বিক্রয়` to `দৈনিক আয়` (Daily Sales).
  - Changed histogram section title from `ঘণ্টাওয়ারী পরিসংখ্যান` to `ঘণ্টা প্রতি পরিসংখ্যান`.
  - Updated chart labels to `ঘণ্টা প্রতি বিক্রয়` and `ঘণ্টা প্রতি অর্ডার`.
  - Updated order history scanner button to `Icons.barcode_reader`.
- **Dashboard Cleanup**:
  - Removed the duplicate Point of Sale banner button in the dashboard hero header; POS is cleanly launched via the floating action button.
- **Tester Credentials**:
  - Pre-filled login credentials updated to `admin` / `admin` for human testing ease.

---

### Releases & Artifacts
Versioned release builds are archived in `dist/releases/`:
- `dist/releases/v1.0.0/metapos-v1.0.0-arm64-v8a-release.apk` (28 MB)
- `dist/releases/v1.0.0/metapos-v1.0.0-universal-release.apk` (77 MB)
