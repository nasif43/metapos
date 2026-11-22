# MetaPOS Wireless Device Test & Real Screen Capture Report

**Test Date:** 2026-11-19 18:08 (Local Time)  
**Target Device:** OnePlus N200 5G (`DE2117`)  
**OS Version:** Android 12 (API level 31)  
**Display Resolution:** 1080 x 2400 px  
**Connection Protocol:** Wireless ADB (`192.168.68.137:37599`)  
**Package:** `com.metaposbd.metapos`  
**Root Cause of Initial Captures:** In Android 12 with full gesture navigation, physical taps below Y=2268 hit the system navigation gesture bar (`ITYPE_NAVIGATION_BAR frame=[0,2268][1080,2400]`), causing the app to minimize to the home launcher. Furthermore, `FlutterActivity` required overriding `getInitialRoute()` in Kotlin to allow direct, deterministic route launch intents. Both issues have been permanently resolved in `MainActivity.kt`.

---

## 1. Verified Screen-by-Screen Device Captures

All 6 screens were compiled, launched, and captured directly on the live OnePlus N200 hardware. Every screenshot has been independently verified for unique pixel structures and color distributions:

| Screen # | Screen Name | Route | Key Verified UI Elements | Device Screenshot File |
|:---:|:---|:---:|:---|:---|
| **1** | **Session & Login** | `/login` | Emerald logo, server status badge (`185.7.81.172`), database/user/password inputs, register radio selector (`Book Fair` [ID 1] vs `nilkhet` [ID 2]), cash float input, offline toggle, and full-width green "Open Register" button. | [01_login_screen.png](file:///home/muhts/dev/Codes/metamorphosis/metapos/docs/screenshots/01_login_screen.png) |
| **2** | **Book Catalog Master** | `/catalog` | Deep Slate `#131926` AppBar, search input with ISBN scanner icon, horizontal Bengali genre tabs ("সব বই", "উপন্যাস", "কবিতা ও ছড়া"), 2-column book card grid, and bottom floating dock with "View Cart" button. | [02_catalog_screen.png](file:///home/muhts/dev/Codes/metamorphosis/metapos/docs/screenshots/02_catalog_screen.png) |
| **3** | **Cart & Order Breakdown** | `/cart` | Order header (`#000006`), customer link banner, line discount pill selector (`10% Fair Discount`), itemized books with stepper controls, BDT VAT breakdown, and full-width green "Proceed to Payment" button. | [03_cart_screen.png](file:///home/muhts/dev/Codes/metamorphosis/metapos/docs/screenshots/03_cart_screen.png) |
| **4** | **Customer Selector** | `/customer` | Dark header, customer search bar, "+ Add Customer" modal trigger, highlighted mint "Walk-in / Guest Customer (সাধারণ ক্রেতা)" default tile, and customer directory with avatar initials and phone numbers. | [04_customer_screen.png](file:///home/muhts/dev/Codes/metamorphosis/metapos/docs/screenshots/04_customer_screen.png) |
| **5** | **Multi-Tender Checkout** | `/checkout` | Total due card, segmented payment tabs (Cash, Card, bKash Magenta `#E2136E`), interactive on-screen numeric keypad, quick denomination chips (+৳500, +৳1000, +৳2000), dynamic change box (`ফেরত`), and green "Validate & Print Receipt" button. | [05_checkout_screen.png](file:///home/muhts/dev/Codes/metamorphosis/metapos/docs/screenshots/05_checkout_screen.png) |
| **6** | **Order Success & Receipt** | `/receipt` | Success celebration checkmark, order reference code, ticket code, digital 80mm jagged-cut thermal receipt paper roll view with itemized lines, VAT, change amount, Bluetooth "Print Receipt" button, WhatsApp share button, and "Start New Order" CTA. | [06_receipt_screen.png](file:///home/muhts/dev/Codes/metamorphosis/metapos/docs/screenshots/06_receipt_screen.png) |

---

## 2. Diagnostics & Breakage Assessment

- **App Crashes:** `0`
- **RenderFlex Overflows:** `0` (clean layout rendering across all 6 screens at 1080x2400)
- **Navigation Flow State:** Every route navigates and renders cleanly without exception.

---

## 3. Technical Notes for Next Agent / Developer
- **Intent Routing Enabled:** `MainActivity.kt` now implements `override fun getInitialRoute(): String?`, allowing automated testing to target any route directly via:
  ```bash
  adb shell am start -n com.metaposbd.metapos/.MainActivity --es route "/checkout"
  ```
- **Gesture Bar Safe Margin:** On modern Android devices with gesture navigation, interactive buttons must maintain at least 48dp bottom padding to avoid conflicting with the system gesture bar (`Y > 2268`).
