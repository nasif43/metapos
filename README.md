# MetaPOS

<div align="center">

**Smart Retail & Book Fair Mobile Point of Sale (POS)**  
*Engineered for Amar Ekushey Boi Mela & High-Throughput Retail*

[![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.1+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![State](https://img.shields.io/badge/State-Riverpod%202.6-black)](https://riverpod.dev)
[![Release](https://img.shields.io/badge/Release-v1.0.0-emerald)](#releases)
[![License](https://img.shields.io/badge/License-Proprietary-red)](#)

</div>

---

## 📖 Overview

**MetaPOS** is a high-performance, offline-first mobile Point of Sale system built with Flutter and Riverpod. Tailored specifically for book fairs, pop-up events, and retail environments, it integrates seamlessly with cloud backend services via standard JSON-RPC protocols while preserving flawless offline operability through local SQLite caching.

The application features full bilingual localization (**Bengali & English**), compliant with Bangladeshi retail standards (whole-BDT integer currency formatting, 10% MRP-inclusive tax handling, and bKash/MFS settlement).

---

## ✨ Key Features

### 🛒 Multi-Cart Walk-in Concurrency
- Maintain multiple active customer carts simultaneously without losing state.
- Horizontal scrolling pill tabs with active badges, item counters, cart switching, long-press renaming, and accidental discard guards.

### 📷 Live Hardware Barcode & QR Scanner
- Real-time physical camera scanning powered by `mobile_scanner`.
- Instant detection for ISBNs, barcodes, and receipt voucher codes.
- Hardware controls: real-time flash/torch toggle and rear/front camera switching.
- Dedicated return order ticket scanner for instantaneous return lookup.

### 🔄 End-to-End Returns & Refunds
- Search past orders with debounced querying, status filters (`সব`, `ফেরতযোগ্য`, `রিফান্ড`), or barcode scanning.
- Per-line refundable quantity bounding (`refundable_qty = max(0, qty - refunded_qty)`).
- Modal return bottom sheet with quantity steppers and payout tender selection (Cash, Bank, bKash).
- Synchronous reverse stock moves and cloud refund voucher generation (`OrderSuccessReceiptScreen`).

### 📊 Live Interactive Dashboard
- 8 tappable KPI cards with drill-down bottom sheets for payment breakdowns, top-selling titles, genre analytics, and session telemetry.
- Hourly sales and order volume histograms.
- Real-time session monitoring with active cashier and float tracking.

### 🖨️ Thermal Printing & Receipts
- Thermal receipt preview (32-column roll) with custom Bengali typography.
- ESC/POS print support for 58mm and 80mm wireless Bluetooth/network receipt printers.

### ⚡ Offline-First Architecture
- SQLite schema v4 persistence for orders, order lines, catalog, categories, and sync queues.
- Automatic background replay with re-entrancy protection when connectivity is restored.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter 3.x / Dart 3.x
- **State Management**: Riverpod 2.6 (StateNotifier, AsyncNotifier, Ref-driven dependency injection)
- **Local Persistence**: `sqflite` (Schema v4) with transactional queue flush
- **Networking**: `dio` & `http` JSON-RPC client with cookie session capture
- **Scanner**: `mobile_scanner` 7.5.0
- **Typography & UI**: Material 3 with Shadcn-inspired tokens, `HindSiliguri` for Bengali, and `PlusJakartaSans` for Latin scripts

```
lib/
├── core/
│   ├── localization/      # Bilingual strings (BN/EN) & Locale provider
│   ├── routing/           # Declarative named routes (AppRouter)
│   ├── theme/             # AppColors, AppTypography, Shadcn tokens
│   └── utils/             # CurrencyFormatter (whole-BDT), helpers
├── data/
│   ├── local/             # DatabaseHelper (SQLite v4), offline queues
│   ├── models/            # ProductModel, OrderModel, DashboardModel
│   ├── remote/            # JSON-RPC client, catalog, session & order services
│   └── repositories/      # OrderRepository, CatalogRepository, SyncQueue
├── presentation/
│   ├── screens/
│   │   ├── login/         # SessionLoginScreen
│   │   ├── dashboard/     # DashboardScreen & drill-down bottom sheets
│   │   ├── catalog/       # CatalogMasterScreen & book grid
│   │   ├── cart/          # CartOrderScreen & multi-cart controls
│   │   ├── customer/      # CustomerSelectorScreen
│   │   ├── checkout/      # CheckoutPaymentScreen & keypad
│   │   ├── orders/        # OrderHistoryScreen & OrderDetailScreen
│   │   └── receipt/       # OrderSuccessReceiptScreen
│   └── widgets/           # BarcodeScannerSheet, MultiCartTabBar, BrandLogo
└── providers/             # Riverpod state notifiers & business logic
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.13.7`
- Android SDK (API 21+)
- Java 17

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/nasif43/metapos.git
   cd metapos
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run code analysis:**
   ```bash
   flutter analyze
   ```

4. **Execute test suite:**
   ```bash
   flutter test test/unit/
   ```

5. **Run the application:**
   ```bash
   flutter run
   ```

---

## 📦 Building Releases

To compile versioned production APKs:

```bash
# Per-ABI split APK (recommended for arm64 mobile devices)
flutter build apk --release --split-per-abi

# Universal fat binary
flutter build apk --release
```

Compiled binaries are archived under `dist/releases/`:
- `dist/releases/v1.0.0/metapos-v1.0.0-arm64-v8a-release.apk`
- `dist/releases/v1.0.0/metapos-v1.0.0-universal-release.apk`

---

## 📄 License & Documentation

- Detailed changelog: [CHANGELOG.md](CHANGELOG.md)
- Returns & refunds architecture: [docs/returns_and_refunds_architecture.md](docs/returns_and_refunds_architecture.md)

---
<div align="center">
Developed by <b>Metamorphosis</b> for MetaPOS Bangladesh
</div>
