# MetaPOS: Edge Cases & Architectural Biases Reference

**Document Version:** 1.0.0  
**Target Backend:** Odoo 19.0 Community (`https://demostore.metaposbd.com`)  
**Regulatory Standards:** NBR Bangladesh Value Added Tax & Supplementary Duty Act 2012 (Mushak 6.3)  
**Peripheral Standards:** ESC/POS Thermal Receipt Printing Specification (58mm / 80mm)  

---

## 1. Master Edge Case & Error Diagnostic Matrix

The following 18 edge cases have been empirically probed, verified, and mapped to specific recovery workflows on Odoo 19 Community:

| # | Edge Case Category | Error Class / Code | Verbatim Server Output / Bengali String | Root Cause | Client Recovery Workflow |
|---|---|---|---|---|---|
| **1** | **Overpayment Pattern A** (Net Settlement) | None (Success) | HTTP 200 OK, Order created | Customer tendered overpayment; client settles net (`amount_paid == amount_total`, `amount_return: 0.0`). | Standard checkout path. Local receipt displays cash tendered and change returned. |
| **2** | **Overpayment Pattern B** (Balancing Line) | None (Success) | HTTP 200 OK, Order created with 2 `pos.payment` rows | Tender line (e.g. ৳500) paired with balancing negative change line (e.g. -৳390, `is_change: true, name: 'ফেরত'`). | Full accounting audit path. Records both gross cash received and cash paid out in drawer. |
| **3** | **Unbalanced Overpayment Tender** | `odoo.exceptions.UserError` (Code 200) | `অর্ডার /-এর মূল্য পুরোপুরি পরিশোধ হয়নি।`<br/>*(Order %s is not fully paid.)* | Order payload contained tender of ৳500 and top-level `amount_return: 390.0` without balancing change line. | **Fatal Error**. Client must reformat payload: force `amount_return: 0.0` and append negative change line. |
| **4** | **Imbalanced Change Line** | `odoo.exceptions.UserError` (Code 200) | `অর্ডার /-এর মূল্য পুরোপুরি পরিশোধ হয়নি।` | Net payment sum does not strictly equal `amount_total` (e.g. tendered 500, returned 380, net 120 vs total 110). | Re-calculate change line: `change = amount_total - tender`. Re-queue order. |
| **5** | **Order UUID Idempotency** (Sequential Retry) | None (Success) | HTTP 200 OK, returns existing order ID without duplicates | Client retried network request after connection drop. Odoo `sync_from_ui` detects existing `pos.order.uuid`. | Mark local order as `'synced'`. No duplicate rows inserted into database. |
| **6** | **Order UUID Race Condition** (Concurrent Threads) | `odoo.exceptions.ValidationError` (Code 200) | `The operation cannot be completed: এই uuid-এর একটি অর্ডার আগে থেকেই আছে` | Two sync workers submitted the same order UUID simultaneously. PostgreSQL unique index `pos_order_unique_uuid` tripped. | Catch `ValidationError`, query `pos.order.search_read([["uuid", "=", order.uuid]])`, and mark local order `'synced'`. |
| **7** | **Line UUID Collision** | `odoo.exceptions.ValidationError` (Code 200) | `The operation cannot be completed: এই uuid-এর একটি অর্ডার লাইন আগে থেকেই আছে` | Duplicate line UUID reused across different orders. PostgreSQL index `pos_order_line_unique_uuid` tripped. | Client must always mint independent RFC 4122 v4 UUIDs for every line. Regenerate UUID and re-sync. |
| **8** | **Missing / Expired POS Session** | `odoo.exceptions.MissingError` (Code 200) | `Record does not exist or has been deleted. (Record: pos.session(X,), User: 2)` | Order submitted against a closed or non-existent session ID. | Trigger **Session Re-Binding Protocol**: query active opened session, rewrite payload `session_id`, and re-sync. |
| **9** | **Session Cookie Expiration** | `odoo.http.SessionExpiredException` (Code 100) | `Session expired` | Cookie `session_id` exceeded 7-day TTL or was invalidated by server restart. | Re-authenticate via `/web/session/authenticate`, capture new `session_id` cookie, and retry request. |
| **10** | **Unauthenticated Access** | `odoo.http.SessionExpiredException` (Code 100) | `Session expired` | Request sent without `Cookie: session_id=...` header. | Redirect user to PIN / Login screen or refresh stored credentials. |
| **11** | **Invalid Credentials** | `odoo.exceptions.AccessDenied` (Code 200) | `Access Denied` | Incorrect password or unauthorized username. | Prompt user with localized Bengali message: `"ব্যবহারকারীর নাম বা পাসওয়ার্ড সঠিক নয়।"`. |
| **12** | **Invalid Database** | Odoo Server Error (Code 200) | `Database not found.` | Invalid `db` parameter passed in JSON-RPC payload. | Verify backend configuration; default to `demostore`. |
| **13** | **Partner Query by `mobile`** | `builtins.ValueError` (Code 200) | `Invalid field 'mobile' on 'res.partner'` | Client projected `fields: ['mobile']`. Field was removed in Odoo 19 core. | **Code defect**. Replace all instances of `mobile` with `phone`. |
| **14** | **Partner Domain by `mobile`** | `builtins.ValueError` (Code 200) | `Invalid field res.partner.mobile in condition ('mobile', '=', '...')` | Client filtered partners using domain `[['mobile', '=', '...']]`. | **Code defect**. Update search domain to `[['phone', '=', '...']]`. |
| **15** | **Duplicate Customer Phone** | None (Allowed) | HTTP 200 OK, Partner created | Creating two customer records with the same phone number. Odoo does not enforce SQL uniqueness on phone. | Client should query `res.partner` by phone first. If existing partner found, reuse partner ID rather than creating duplicates. |
| **16** | **MRP Price Inflation** | Architectural Invariant | Total inflated from ৳100 to ৳110 if raw price submitted | Additive VAT (`price_include: false`) applied on top of printed gross cover price. | Apply **Reverse-Net Tax Math**: $\text{price\_unit} = \text{MRP} / 1.10$. |
| **17** | **Bengali Unicode Encoding** | None (Success) | Correct Unicode strings returned in JSON-RPC | Odoo PostgreSQL database supports full UTF-8 encoding. | Ensure HTTP client headers include `Content-Type: application/json; charset=utf-8`. |
| **18** | **Worker Saturation & Latency** | Network Latency Spike | p99 latency escalates from 312 ms to 918 ms | Concurrency exceeds 5 prefork workers; requests queue in Nginx backlog. | Throttling: Pause background catalog sync during active checkout bursts. |

---

## 2. Bangladesh Tax & NBR Mushak 6.3 Compliance

### 2.1 The Bangladeshi Retail MRP Tax Paradox

In Bangladesh, under the **Value Added Tax and Supplementary Duty Act 2012**, retail consumer goods (such as published books, stationery, and packaged goods) are sold at a statutory Maximum Retail Price (MRP) printed directly on the book cover or packaging. The printed MRP is legally inclusive of all applicable taxes.

However, standard ERP installations (including Odoo 19 `account.tax`) are configured by default in **Additive Mode** (`price_include: false`):
$$\text{Tax Amount} = \text{price\_unit} \times \text{tax\_rate}$$
$$\text{Total Invoice Amount} = \text{price\_unit} + \text{Tax Amount}$$

If a cashier scans a book with a printed cover price of ৳ 100.00 and submits `price_unit: 100.0`, Odoo computes:
$$\text{Tax} = 100.00 \times 10\% = ৳ 10.00$$
$$\text{Total Payable} = 100.00 + 10.00 = ৳ 110.00$$
**This violates Bangladesh consumer law**, as the customer is charged ৳ 110.00 for a product marked ৳ 100.00.

---

### 2.2 Reverse-Net Price & Penny-Balancing Formulas

To guarantee that the final checkout total matches the printed cover price to the exact paisa (৳ 0.01) with zero rounding drift, MetaPOS applies the **Reverse-Net Tax Engine**:

$$\text{Gross Shelf MRP} = \text{mrp}$$
$$\text{Applicable VAT Rate} = r \quad (\text{e.g., } 0.10 \text{ for } 10\%)$$

#### Step 1: Compute Net Unit Price (rounded to 4 decimal places)
$$\text{price\_unit} = \text{round}\left(\frac{\text{mrp}}{1 + r}, 4\right)$$
*Example:* $\frac{100.00}{1.10} = 90.909090\dots \xrightarrow{\text{round } 4} 90.9091$

#### Step 2: Compute Net Subtotal (rounded to 2 decimal places)
$$\text{price\_subtotal} = \text{round}(\text{price\_unit} \times \text{qty}, 2)$$
*Example:* $\text{round}(90.9091 \times 1.0, 2) = ৳ 90.91$

#### Step 3: Compute VAT Amount by Subtraction
$$\text{amount\_tax} = \text{round}(\text{mrp} \times \text{qty} - \text{price\_subtotal}, 2)$$
*Example:* $100.00 - 90.91 = ৳ 9.09$

#### Step 4: Reconciled Total
$$\text{amount\_total} = \text{price\_subtotal} + \text{amount\_tax} = 90.91 + 9.09 = ৳ 100.00$$

This mathematical invariant holds across arbitrary fractional amounts, preventing penny reconciliation errors in Odoo's financial journals.

---

### 2.3 Statutory NBR Mushak 6.3 Invoice Requirements

Under National Board of Revenue regulations, every retail invoice issued at the point of sale must contain the following statutory data elements:

```
==================================================
           গণপ্রজাতন্ত্রী বাংলাদেশ সরকার
               জাতীয় রাজস্ব বোর্ড
           কর চালানপত্র (মূসক - ৬.৩)
          [বিধি ৪০ এর উপ-বিধি (১) দ্রষ্টব্য]
==================================================
নিবন্ধিত ব্যক্তির নাম : মেটাপজ বুক স্টোর
নিবন্ধিত ব্যক্তির বিআইএন : ০০১২৩৪৫৬৭-০১০১
চালানপত্র নম্বর       : LIVE-264-1-32009
ইস্যুর তারিখ ও সময়   : ২১/১১/২০২৬ ১৩:৪৫:৪১
বিক্রয়ের কেন্দ্র       : বুক ফেয়ার প্যাভিলিয়ন (Config 1)
--------------------------------------------------
ক্রেতার নাম          : মুহিব্বুল্লাহ টেস্ট কাস্টমার
ক্রেতার মোবাইল       : ০১৭০০২৪৭১৪০
ক্রেতার বিআইএন/এনআইডি : (প্রযোজ্য ক্ষেত্রে)
--------------------------------------------------
আইটেমের বিবরণ       পরিমাণ   একক মূল্য     মোট মূল্য
--------------------------------------------------
ব্ল্যাকবার্ড এডিশন        ১     ৯০.৯১        ৯০.৯১
--------------------------------------------------
মোট মূল্য (কর ব্যতীত) :                    ৳ ৯০.৯১
মূল্য সংযোজন কর (১০%) :                    ৳ ৯.০৯
--------------------------------------------------
সর্বমোট প্রদেয় টাকা   :                   ৳ ১০০.০০
নগদ গ্রহণ (Tender)    :                   ৳ ৫০০.০০
ফেরত দেওয়া হয়েছে (Change):                 ৳ ৪০০.০০
==================================================
        ধন্যবাদ, আবার আসবেন! মেটাপজ দ্বারা পরিচালিত
==================================================
```

---

## 3. Hardware ESC/POS Thermal Printing Biases

### 3.1 The Bengali Unicode Font Rendering Problem

Standard 58mm and 80mm ESC/POS thermal receipt printers (Epson, Xprinter, Rongta, Star Micronics) ship with onboard hardware ROM character tables limited to ASCII, Katakana, and European codepages (CP437, CP850, CP1252). They contain **zero native support for Brahmic complex scripts like Bengali**:
- Bengali features complex conjuncts (*juktakkhor* যেমন: ক্ষ, জ্ঞ, ত্ত, ক্ত).
- Dependent vowel signs (*kar* যেমন: ি, ী, ু, ূ, ো) are reordered before or wrapped around base consonants.
- Transmitting raw UTF-8 bytes to an ESC/POS printer results in complete garbage text (mojibake).

---

### 3.2 The Solution: 1-Bit Monochrome Bitmap Rasterization

MetaPOS resolves this hardware constraint by treating the entire receipt—or all Bengali text sections—as a **graphical canvas** rendered on the client device before transmission:

```
[Flutter / Canvas Drawing Surface]
          │
          │ Renders Bengali Text using Noto Sans Bengali TTF font
          ▼
[High-Resolution ARGB8888 Image]
          │
          │ Thresholding & Floyd-Steinberg Dithering
          ▼
[1-Bit Monochrome Bit-Array (Width: 384 dots for 58mm / 576 dots for 80mm)]
          │
          │ Packs 8 horizontal pixels per byte (MSB first)
          ▼
[ESC/POS Command: GS v 0 (Raster Bit Image)]
          │
          ▼
[Transmitted via Bluetooth RFCOMM / USB POS / WiFi TCP Socket Port 9100]
```

#### ESC/POS Raster Command Structure (`GS v 0`):
$$\text{Bytes: } \texttt{0x1D} \quad \texttt{0x76} \quad \texttt{0x30} \quad m \quad x_L \quad x_H \quad y_L \quad y_H \quad [d_1 \dots d_k]$$
- $m = 0$: Normal density mode (203 DPI).
- $x_L + x_H \times 256$: Width of bitmap in bytes (e.g. $384 \text{ dots} / 8 = 48\text{ bytes} \implies x_L = 48, x_H = 0$).
- $y_L + y_H \times 256$: Height of bitmap in dots.
- $[d_1 \dots d_k]$: Raw bitstream where bit `1` = thermal heat pulse (black dot) and bit `0` = paper white.

---

### 3.3 Printer Hardware Recommendations & Parameters

| Parameter | 58mm Thermal Printer | 80mm Thermal Printer |
|---|---|---|
| **Effective Print Width** | 48 mm (384 dots) | 72 mm (576 dots) |
| **Line Pitch** | 203 DPI (8 dots/mm) | 203 DPI (8 dots/mm) |
| **Serial / Bluetooth Baud Rate** | 9600 / 115200 bps | 115200 bps |
| **WiFi Port** | TCP 9100 (RAW) | TCP 9100 (RAW) |
| **Feed & Cut Command** | `0x1D 0x56 0x42 0x00` | `0x1D 0x56 0x42 0x00` (Full/Partial Cut) |
| **Drawer Kick Pulse** | `0x1B 0x70 0x00 0x19 0xFA` | `0x1B 0x70 0x00 0x19 0xFA` |
