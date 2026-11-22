# MetaPOS Technical Reconnaissance & Infrastructure Audit Report

**Document Version:** 1.0.0  
**Target Host:** `185.7.81.172` (`metapos`)  
**Production Tenant / Demo Instance:** `https://demostore.metaposbd.com`  
**Database Name:** `demostore`  
**Odoo Engine:** Odoo 19.0 Community Edition (Final)  
**Operating Environment:** Ubuntu 24.04.5 LTS (Noble Numbat) on LXC container  
**Auditor / Reconnaissance Team:** Teamwork Specialist & Spec Miner  
**Date of Audit:** November 19, 2026  

---

## Executive Summary

A comprehensive technical reconnaissance was conducted on the production host server `185.7.81.172` and the live web demo instance `https://demostore.metaposbd.com`. The inspection covered:
1. Low-level system hardware, kernel, Linux container virtualization, and filesystem mounts.
2. Systemd service management, processes, security boundaries, and listening network ports.
3. PostgreSQL 16 database clustering, role privileges, authentication, and multi-tenant cloning mechanics.
4. Nginx reverse proxy architecture, wildcard tenant routing, SSL/TLS configuration, HTTP/2, and WebSocket proxying.
5. In-depth code analysis of the custom Odoo 19 module suite tailored specifically for the **Book Publishing, Book Fair (Amar Ekushey Boi Mela), and Bookstore retail industry in Bangladesh**.
6. Specialized POS mechanics including "Book Fair Mode" (bypassing warehouse pickings and closing journal entries), standalone `book_qty_on_hand` stock tracking, ISBN-10/13 normalization & barcode sync, Open Library metadata integration, author/publisher/genre registries, and SaaS terminal caps.

This document serves as the authoritative backend and infrastructure blueprint for building the **MetaPOS Flutter Mobile Sales Companion**.

---

## 1. Host Infrastructure & System Architecture

### 1.1 Hardware Specifications & Virtualization Environment
- **Hostname**: `metapos`
- **Virtualization Type**: Linux Containers (LXC / Incus runtime, chassis: `container`, mounts: `/dev/.incus-mounts`)
- **Host Distribution**: Ubuntu 24.04.5 LTS (Noble Numbat)
- **Kernel Release**: `Linux metapos 7.0.0-42-generic #42~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Oct 19 14:43:01 UTC 2026 x86_64`
- **CPU Topology**: Intel(R) Xeon(R) CPU E5-2667 v4 @ 3.20GHz
  - Allocated Virtual CPUs: 4 cores (`cores 1, 2, 19, 22`) assigned to container cgroup from 32 physical host threads.
  - Typical system load average: `< 0.10` (healthy, idle).
- **Memory (RAM)**:
  - Total Available to Container: `6.0 GiB`
  - Active Utilization: `~2.8 GiB`
  - Free & Available: `~3.2 GiB`
  - Shared Memory / Buffers: `1.6 GiB` shared / `3.5 GiB` buffers & cache
  - Swap: `0 B` (no swap configured inside LXC container; kernel memory limit managed by host)
- **Filesystem & Storage Allocations**:
  - Root Mount (`/`): `/dev/dm-62` (LVM logical volume), `30 GB` total capacity, `6.4 GB` used (22%), `23 GB` available.
  - Modules Mount (`/usr/lib/modules`): `/dev/sda2`, `196 GB` ext4 host filesystem.
  - Ephemeral Mounts: `tmpfs` mounted on `/dev/shm` (250 GB shared limit) and `/run` (100 GB).

### 1.2 Disk Footprint & Key Directory Structure
| Directory Path | Size | Description / Role |
|----------------|------|--------------------|
| `/opt/metapos/odoo` | 1.1 GB | Upstream Odoo 19.0 Community source tree |
| `/opt/metapos/venv` | 600 MB | Python 3.12.3 virtual environment with compiled wheels |
| `/opt/metapos/repos/odoo19-book-fair-addons` | 2.8 MB | Custom Book Fair POS Git repository (`HEAD 407e58d`) |
| `/opt/metapos/addons` | 120 KB | Proprietary SaaS add-ons (`metapos_saas`) |
| `/var/lib/postgresql/16/main` | 1.7 GB | PostgreSQL 16 database cluster data directory |
| `/var/lib/metapos` | 39 MB | Odoo filestore (`/filestore/<db_name>`) and active sessions |
| `/var/www/metapos` | 162 MB | Node.js Express API & React marketing landing SPA |
| `/var/backups/metapos` | 76 MB | Automated daily logical tenant backup archives (`.sql.gz` + filestore) |
| `/etc/metapos` | 16 KB | Core Odoo configuration (`odoo.conf`) |

---

## 2. Systemd Service Management & Security Model

The server orchestrates four core production systemd services:

### 2.1 Odoo Service: `metapos-odoo.service`
- **Unit Configuration Path**: `/etc/systemd/system/metapos-odoo.service`
- **Execution Command**: `/opt/metapos/venv/bin/python /opt/metapos/odoo/odoo-bin -c /etc/metapos/odoo.conf`
- **Execution Identity**: Dedicated unprivileged user `odoo`, group `odoo`.
- **Pre-forking Model**: 5 HTTP prefork worker processes (`127.0.0.1:8069`), 1 Gevent worker (`127.0.0.1:8072`), 1 Cron runner.
- **Security & Sandboxing Hardening**:
  - `NoNewPrivileges=true`
  - `PrivateTmp=true`
  - `PrivateDevices=true`
  - `ProtectSystem=strict` (mounts `/usr`, `/boot`, `/etc` as read-only)
  - `ProtectHome=true` (inaccessible `/home`, `/root`)
  - `ProtectKernelTunables=true`, `ProtectControlGroups=true`
  - `RestrictSUIDSGID=true`
  - `CapabilityBoundingSet=` (drops all kernel POSIX capabilities)
  - `ReadWritePaths=/var/lib/metapos /var/backups/metapos`
  - `MemoryMax=4300M` (cgroup memory kill ceiling to prevent out-of-memory container crashes)
  - `LimitNOFILE=65536`

### 2.2 PostgreSQL Service: `postgresql@16-main.service`
- **Unit Configuration**: Multi-instance systemd unit managing cluster `16/main`.
- **Process**: Postmaster (`/usr/lib/postgresql/16/bin/postgres -D /var/lib/postgresql/16/main -c config_file=/etc/postgresql/16/main/postgresql.conf`).
- **Startup Order**: Must be active before `metapos-odoo.service` starts (`Requires=postgresql.service`).

### 2.3 Nginx Reverse Proxy: `nginx.service`
- **Unit Path**: `/usr/lib/systemd/system/nginx.service`
- **Process**: Master process running as `root`, 4 worker processes running as `www-data`.
- **Termination**: Terminates HTTPS/TLS on port `443`, proxies WebSocket traffic to port `8072`, and proxies HTTP/RPC traffic to port `8069`.

### 2.4 Marketing & SaaS Admin API: `metapos-api.service`
- **Unit Configuration Path**: `/etc/systemd/system/metapos-api.service`
- **Execution Command**: `/usr/bin/node /var/www/metapos/server/index.ts --production`
- **Port**: `127.0.0.1:3001` (proxied via apex Nginx `metaposbd.com/api/`).
- **Purpose**: Express backend handling new tenant registration, lead captures, and Zoho transactional mail.

---

## 3. Network Topology & Listening Ports

The host maintains tight firewall boundaries, binding core database and application services exclusively to `localhost` (`127.0.0.1`):

```
+-----------------------------------------------------------------------------------------+
|                                    INTERNET (WAN)                                       |
+-----------------------------------------------------------------------------------------+
       |                                      |                                  |
   Port 22 (SSH)                        Port 80 (HTTP)                    Port 443 (HTTPS)
   rootuser / OpenSSH                   301 Redirect                      Let's Encrypt SSL
       |                                      |                                  |
       v                                      +----------------------------------+
+-----------------------------------------------------------------------------------------+
|                                 NGINX REVERSE PROXY                                     |
|                                                                                         |
|   Apex Domain (metaposbd.com)             Subdomain Tenants (*.metaposbd.com)          |
|   - Static SPA (/var/www/metapos/dist)    - Proxy / -> 127.0.0.1:8069 (Odoo HTTP)       |
|   - Proxy /api/ -> 127.0.0.1:3001         - Proxy /websocket -> 127.0.0.1:8072 (Gevent) |
|                                           - Edge 404 on /web/database/*                |
+-----------------------------------------------------------------------------------------+
       |                                             |
       | (Port 3001)                                 +-----------------------+
       v                                             v                       v
+-----------------------+                 +---------------------+  +--------------------+
|  Node.js Express API  |                 | Odoo HTTP Workers   |  | Odoo Gevent WS     |
|  127.0.0.1:3001       |                 | 127.0.0.1:8069      |  | 127.0.0.1:8072     |
+-----------------------+                 +---------------------+  +--------------------+
                                                     |                       |
                                                     +-----------+-----------+
                                                                 | (Unix Socket / Port 5432)
                                                                 v
                                                  +------------------------------+
                                                  |   PostgreSQL 16.15 Cluster   |
                                                  |   127.0.0.1:5432 / Socket    |
                                                  |   Databases: demostore, ...  |
                                                  +------------------------------+
```

### Verified Open Ports (`ss -tulpn`)
| Protocol | Address:Port | Service | Notes |
|----------|--------------|---------|-------|
| TCP | `0.0.0.0:22` | `sshd` | OpenSSH daemon |
| TCP | `0.0.0.0:80` | `nginx` | Port 80 redirect to HTTPS |
| TCP | `0.0.0.0:443` | `nginx` | HTTPS / HTTP/2 reverse proxy |
| TCP | `127.0.0.1:8069` | `python3` (Odoo) | Odoo HTTP workers (prefork) |
| TCP | `127.0.0.1:8072` | `python3` (Odoo) | Odoo Gevent longpolling / WebSocket |
| TCP | `127.0.0.1:5432` | `postgres` | PostgreSQL 16 cluster |
| TCP | `127.0.0.1:3001` | `node` | MetaPOS marketing backend |

---

## 4. Odoo 19 Configuration & Multi-Tenancy Architecture

### 4.1 Odoo Configuration (`/etc/metapos/odoo.conf`)
```ini
[options]
addons_path = /opt/metapos/odoo/addons,/opt/metapos/addons,/opt/metapos/repos/odoo19-book-fair-addons
data_dir = /var/lib/metapos
admin_passwd = aI4mSCOz85L4iRk7wqE30R7oG9OccCEnszv07JypC78
db_user = odoo
dbfilter = ^%d$
list_db = False
proxy_mode = True
http_interface = 127.0.0.1
http_port = 8069
gevent_port = 8072
workers = 5
max_cron_threads = 1
db_maxconn = 16
limit_memory_soft = 671088640
limit_memory_hard = 1073741824
limit_time_cpu = 120
limit_time_real = 240
limit_time_real_cron = 300
limit_request = 8192
server_wide_modules = base,web
```

### 4.2 Multi-Tenant Subdomain Routing Mechanics
1. **Dynamic Database Filtering**:
   The setting `dbfilter = ^%d$` instructs Odoo's HTTP dispatcher to evaluate the first segment of the incoming HTTP `Host` header.
2. **Nginx Integration**:
   - The Nginx server block `/etc/nginx/sites-available/metapos-tenants` matches:
     `server_name "~^[a-z0-9][a-z0-9-]{1,29}\.metaposbd\.com$";`
   - Passes upstream headers via `/etc/nginx/snippets/metapos-proxy.conf`:
     ```nginx
     proxy_set_header Host $host;
     proxy_set_header X-Forwarded-Host $host;
     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     proxy_set_header X-Forwarded-Proto $scheme;
     proxy_set_header X-Real-IP $remote_addr;
     ```
3. **Database Selection Resolution**:
   - When the mobile app or browser requests `https://demostore.metaposbd.com`, Nginx sends `Host: demostore.metaposbd.com`.
   - Odoo extracts `%d = demostore`.
   - The regex `^demostore$` matches the PostgreSQL database named `demostore`.
   - This provides total tenant database isolation without hardcoding database names in the Odoo configuration.

### 4.3 Tenant Provisioning Automation (`/usr/local/sbin/metapos-tenant`)
New bookshops and fair stalls are provisioned instantaneously using a CLI utility:
- Command: `metapos-tenant create <subdomain>`
- Behind the scenes:
  1. Executes `createdb -O odoo -T metapos_tpl <subdomain>`.
  2. Copies pre-configured filestore from `/var/lib/metapos/filestore/metapos_tpl` to `/var/lib/metapos/filestore/<subdomain>`.
  3. Updates company name, default user password, and sets SaaS tier limits.
- Nightly backups run via `/etc/cron.d/metapos-backup` at `02:30 UTC`, backing up each database and its filestore into `/var/backups/metapos/YYYY-MM-DD` with a 14-day rolling pruning policy.

---

## 5. PostgreSQL 16 Database Configuration

- **Database Server**: PostgreSQL 16.15 on x86_64-pc-linux-gnu.
- **Active Databases**:
  1. `demostore` (59 MB, owner: `odoo`) — Target demo store.
  2. `metapos_tpl` (55 MB, owner: `odoo`) — Golden template database.
  3. `bftest` (53 MB, owner: `odoo`) — Internal testing database.
  4. `postgres` (7.5 MB) — Administrative database.
- **Client Authentication (`pg_hba.conf`)**:
  - `local all all peer`: Unix domain socket peer authentication for `odoo` and `postgres` local system users.
  - `host all all 127.0.0.1/32 scram-sha-256`: SCRAM-SHA-256 password authentication for localhost TCP.
- **Memory & Resource Tuning**:
  - `shared_buffers = 1536MB` (25% of container RAM)
  - `work_mem = 8MB`
  - `max_connections = 200`
- **Installed Modules in `demostore`**:
  Total of 64 installed modules, including core Odoo POS (`point_of_sale`, `pos_online_payment`, `product`, `barcodes`) and five custom extensions.

---

## 6. Custom Module Suite Analysis

The server hosts a specialized suite of custom modules located in `/opt/metapos/repos/odoo19-book-fair-addons` and `/opt/metapos/addons`:

### 6.1 `book_fair_pos` (v19.0.1.0.0)
- **Primary Objective**: Transform generic Odoo 19 POS into an ultra-fast retail terminal for book fairs and bookstores.
- **Key Capabilities**:
  1. **Book Fair Mode (`pos.config.book_fair_mode = True`)**:
     - Strips out traditional enterprise logistics.
     - Automatically suppresses `_create_order_picking()` — no warehouse delivery orders or `stock.move` records are generated.
     - Automatically resets `order['to_invoice'] = False` — disables account invoicing during rapid fair checkouts.
     - Eliminates closing journal entries: `_cannot_close_session()` clears `bank_payment_method_diffs`, logging cash differences to session chatter instead of generating accounting loss/profit journal entries.
     - Blocks cash in/out operations (`try_cash_in_out` raises `UserError`).
  2. **ISBN Validation & Normalization (`models/isbn.py`)**:
     - Validates both ISBN-10 and ISBN-13 strings.
     - Automatically strips hyphens and spaces (`"978-0-385-47454-2"` -> `"9780385474542"`).
     - Validates modulo-10 and modulo-11 check digits.
     - Converts valid ISBN-10 to standard 13-digit EAN-13 ISBN (`978...`).
     - Enforces uniqueness per company (`UNIQUE(isbn, company_id)`).
     - Automatically synchronizes `barcode = isbn` if barcode is empty or previously matched the old ISBN.
  3. **Open Library Metadata Integration (`models/product_template.py`)**:
     - Action button `action_fetch_isbn_details` calls REST API `https://openlibrary.org/api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data`.
     - Automatically fetches book title, subtitle, authors, publisher, number of pages, publication year, and downloads the book cover image directly into `image_1920`.
  4. **Master Data Registries**:
     - `book.author`: Author catalog with trigram search, nationality, birth year, photo, biography, and book count.
     - `book.publisher`: Publisher catalog with website, contact partner, logo, and book count.
     - `book.genre`: Hierarchical genre tree with recursive protection, color codes, and full name (e.g., `"গল্প / রহস্য"`).
  5. **Management Dashboard & Sales Analysis**:
     - Model `book.fair.dashboard`: RPC endpoint `get_dashboard_data` returning live sales metrics, top titles, top authors, and hourly cashflow.
     - Model `book.sale.report`: Analytical SQL view (`_auto = False`) joining POS lines with author and publisher dimensions for reporting.

### 6.2 `book_fair_stock` (v19.0.1.0.0)
- **Primary Objective**: Lightweight, instant stock on hand tracking without the overhead of Odoo's standard `stock.quant` / `stock.picking` warehouse engine.
- **Mechanics**:
  - Adds an integer field `book_qty_on_hand` directly to `product.template`.
  - When a POS order reaches `paid` or `done` state, `pos_order.py` invokes `ProductTemplate._book_add_qty(delta)`.
  - Sales decrement the counter (`delta = -line.qty`).
  - Returns/refunds increment the counter (`delta = -(-line.qty) = +line.qty`).
  - **Negative Stock Allowed**: Overselling below zero is explicitly permitted to prevent counter stalls if physical deliveries have arrived at the fair but haven't been counted in the system yet.
  - Idempotency is strictly enforced by a boolean flag `order.book_stock_applied` on `pos.order`.

### 6.3 `bangla_translations` (v19.0.1.0.0)
- **Primary Objective**: Provide native Bengali (`bn_IN`) translation across all POS screens, receipts, and product taxonomy.
- **Mechanics**:
  - Employs a dynamic translation hook (`po_paths.py`) that intercepts Odoo's PO loader and merges translation terms for core modules (`point_of_sale`, `product`, `account`, `stock`).
  - Provides Bangla receipts with terminology like `"ফেরত"` (Change Return), `"মোট"` (Total), and `"ভ্যাট"` (VAT).

### 6.4 `metamorphosis_backend_theme` (v19.0.1.0.0)
- **Primary Objective**: Professional slate-navy backend theme with Plus Jakarta Sans typography and customizable branding.
- **Mechanics**:
  - Custom SCSS compiler dynamically updates `$mm-accent` in `ir.asset` to support custom brand colors without patching CSS on disk.

### 6.5 `metapos_saas` (v1.0.0)
- **Primary Objective**: Multi-tenant subscription protection.
- **Mechanics**:
  - Hooks `pos.config.create()`.
  - Compares existing terminals against system parameter `metapos.max_pos_config` (default `2`).
  - Throws `UserError` if a tenant attempts to spin up more registers than their plan allows.

---

## 7. Master Data Models & Custom Fields

### 7.1 Custom Models Reference
```
+---------------------------------------------------------------------------------------------+
|                                    CUSTOM DATA MODELS                                       |
+---------------------------------------------------------------------------------------------+
| Model Name            | Description             | Key Fields                                |
+-----------------------+-------------------------+-------------------------------------------+
| `book.author`         | Author Master Registry  | name, biography, birth_year, book_count,  |
|                       |                         | country_id, photo, book_ids               |
| `book.publisher`      | Publisher Master Data   | name, website, partner_id, logo,          |
|                       |                         | book_count, book_ids                      |
| `book.genre`          | Hierarchical Book Genre | name, complete_name, parent_id,           |
|                       |                         | child_ids, color, book_count              |
| `book.sale.report`    | Sales Analysis SQL View | date, order_id, product_id, author_id,    |
|                       |                         | publisher_id, genre_id, qty, price_total  |
| `book.fair.dashboard` | Fast KPI RPC Generator  | get_dashboard_data(date_from, date_to)    |
+-----------------------+-------------------------+-------------------------------------------+
```

### 7.2 Extensions to Core Models
#### `product.template` & `product.product`:
- `is_book` (Boolean): Identifies the item as a book. Defaults `type='consu'`, `is_storable=False`.
- `isbn` (Char): 13-digit canonical ISBN string (e.g., `"9789849512345"`).
- `isbn10` (Char): Computed 10-digit ISBN representation.
- `book_subtitle` (Char): Secondary title / volume descriptor.
- `author_ids` (Many2many -> `book.author`): Linked book authors.
- `main_author_id` (Many2one -> `book.author`): Primary author for quick sorting.
- `book_authors_display` (Char, stored): Comma-separated author string (e.g., `"সেলিম সোলায়মান, সুরেশ কুণ্ডু"`).
- `publisher_id` (Many2one -> `book.publisher`): Publishing house.
- `book_publisher_name` (Char, stored): Publisher name.
- `genre_id` (Many2one -> `book.genre`): Primary genre.
- `book_genre_name` (Char, stored): Complete genre name (e.g., `"উপন্যাস / থ্রিলার"`).
- `book_qty_on_hand` (Integer, stored): Live on-hand quantity counter.
- `book_sold_qty` (Float, stored): Cumulative units sold.
- `book_series` (Char), `book_edition` (Char), `book_publication_year` (Integer), `book_pages` (Integer).
- `book_format` (Selection: `paperback`, `hardcover`, `pocket`, `comic`, `ebook`).

#### `pos.config`:
- `book_fair_mode` (Boolean): Enables Book Fair operational mode.
- `book_fair_hide_cash_in_out` (Boolean): Blocks cash in/out controls.
- `book_fair_simplify_session_close` (Boolean): Bypasses profit/loss balancing accounts.

---

## 8. Live Demonstration Database State (`demostore`)

Direct inspection of `demostore` on `185.7.81.172` revealed the following active live configuration:
- **Active Registers**:
  - `ID 1: "Book Fair"`: `book_fair_mode: True`, `current_session_id: 7` (`"Book Fair/00004"`, State: `"opened"`), `payment_method_ids: [1, 2]`.
  - `ID 2: "nilkhet"`: `book_fair_mode: True`, `current_session_id: False` (Closed), `payment_method_ids: [2]`.
- **Active Payment Methods**:
  - `ID 1: "Cash"`: `is_cash_count: True`, journal code `CSH1`.
  - `ID 2: "Card"`: `is_cash_count: False`, journal code `BNK1`.
  - `ID 3: "Customer Account"`: Store credit / account receivables.
- **Taxation Structure**:
  - Sales Tax `ID 1`: `"10%"` VAT (`amount: 10.0`, `price_include: False`).
- **Currency**:
  - Currency `ID 55`: Bangladeshi Taka (`BDT`), Symbol: `৳`, Position: `"after"`, Rounding: `0.01`.
- **Catalog Dataset**:
  - 76 live book products loaded with Bengali literature titles, ISBN-13 barcodes, author relations, and initial stock quantities (`book_qty_on_hand`).
  - 10 POS categories mapped to Bengali literary genres (উপন্যাস, কবিতা ও ছড়া, থ্রিলার ও রহস্য, ইতিহাস ও মুক্তিযুদ্ধ, ইত্যাদি).

---

## 9. Verification & Audit Sign-Off

The technical reconnaissance has verified that:
1. All server infrastructure components (LXC, systemd, Odoo 19, PostgreSQL 16, Nginx SSL) are functioning normally and stably.
2. The custom book fair POS and stock modules eliminate ERP logistics complexity, making the backend ideal for lightweight mobile sales.
3. The server environment is fully prepared to receive order submissions from the upcoming Flutter mobile client via JSON-RPC.
