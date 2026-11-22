# MetaPOS: Offline Synchronization Protocol & State Machine Specifications

**Document Version:** 1.0.0  
**Target Backend:** Odoo 19.0 Community Edition (`pos.order`, `pos.session`, `pos.config`)  
**Specification Scope:** Offline Queue Persistence, Idempotency, Session Re-Binding & FIFO Replay  

---

## 1. Protocol Overview

At high-traffic retail venues, network connectivity is volatile: cellular networks experience congestion, Wi-Fi access points disconnect, and remote servers experience temporary latency spikes. MetaPOS implements an **Offline-First Zero-Data-Loss Architecture**:

1. **Instant Offline Checkout**: All checkout transactions are completed, validated, committed to local SQLite storage, and printed on the thermal receipt printer in $<500\text{ ms}$, entirely independent of network availability.
2. **Deterministic FIFO Queue Replay**: Outbound orders are enqueued in SQLite table `local_orders` and processed in strict creation order ($FIFO$) by a background synchronization engine.
3. **Multi-Level RFC 4122 v4 UUID Idempotency**: Unique UUIDs are stamped on the Order, each Order Line, and each Payment Line. Network retries never duplicate transactions.
4. **Automated Session Re-Binding**: If an order was captured under a POS session that is subsequently closed on the server before synchronization, MetaPOS intercepts the error, identifies the active session, updates the queue payload, and re-submits without operator intervention.

---

## 2. State Machines

### 2.1 Offline Order Queue State Machine

Every order transitions through a deterministic series of states managed within the local SQLite storage (`local_orders.sync_status`).

```mermaid
stateDiagram-v2
    [*] --> DRAFT: Cashier scans items / builds cart

    DRAFT --> PENDING: Payment confirmed & receipt printed (committed to SQLite)
    
    PENDING --> SYNCING: Background Sync Worker picks head of FIFO queue
    
    SYNCING --> SYNCED: HTTP 200 OK & matching UUID confirmed by Odoo
    
    SYNCING --> FAILED: Network timeout / 5xx server error / connection dropped
    FAILED --> PENDING: Exponential backoff timer fires (1s, 2s, 4s, 8s... max 60s)
    
    SYNCING --> SESSION_REBIND: Server returns MissingError (Record: pos.session(X,) deleted/closed)
    SESSION_REBIND --> PENDING: New active session discovered & payload session_id rewritten
    
    SYNCING --> DEAD_LETTER: ValidationError / Permanent schema violation (max_retries >= 10)
    
    DEAD_LETTER --> PENDING: Manual supervisor payload audit & re-queue
    SYNCED --> [*]: Order permanently marked synced (retained for offline analytics)
```

#### State Definitions & Transition Triggers:
- **`DRAFT`**: Order is actively modified in memory. Local stock reservations may be held.
- **`PENDING`**: Cashier presses "Complete Order". Order payload is written to `local_orders` with status `'pending'`. ESC/POS receipt prints immediately.
- **`SYNCING`**: Sync worker acquires queue lock, changes status to `'syncing'`, and dispatches `pos.order.sync_from_ui` JSON-RPC request.
- **`SYNCED`**: Odoo returns success (`id` and matching `uuid`). Status updated to `'synced'`, `odoo_id` recorded, and local on-hand stock count permanently decremented.
- **`FAILED`**: Network error (e.g. `SocketException`, `TimeoutException`, HTTP 502/504). Retry counter incremented; order returns to `PENDING` after exponential backoff.
- **`SESSION_REBIND`**: Server rejects order with `odoo.exceptions.MissingError` because the session was closed remotely. The automated re-binding protocol runs.
- **`DEAD_LETTER`**: Order failed 10+ times due to fatal validation errors (e.g. malformed data). Requires manual inspection via supervisor dashboard.

---

### 2.2 POS Register Session Lifecycle State Machine

Odoo 19 POS registers (`pos.config`) enforce a strict session lifecycle (`pos.session`). Orders can only be synchronized when the target session is in state `'opened'`.

```mermaid
stateDiagram-v2
    [*] --> CLOSED: Initial state / Register idle

    CLOSED --> OPENING_CONTROL: Cashier initiates opening shift via pos.config.open_ui
    
    OPENING_CONTROL --> OPENED: Opening cash float entered via pos.session.set_opening_control
    
    OPENED --> CLOSING_CONTROL: Cashier ends shift & counts cash drawer
    
    CLOSING_CONTROL --> CLOSED: Closing balance verified & journal entries posted
    
    CLOSED --> [*]
```

#### Session Synchronization Rule:
If MetaPOS attempts to submit an order targeting a session that is in `'closing_control'` or `'closed'`, Odoo rejects the submission with `MissingError`. MetaPOS must either wait for the new session to open or query the newly opened replacement session.

---

## 3. Sequence Diagrams

### 3.1 Bootstrapping & Register Discovery

Workflow executed when a cashier logs into MetaPOS, captures the session cookie, discovers the register configuration, and caches the catalog.

```mermaid
sequenceDiagram
    autonumber
    actor Cashier
    participant App as MetaPOS Client
    participant SQLite as Local SQLite DB
    participant Odoo as Odoo 19 Server (https://demostore.metaposbd.com)

    Cashier->>App: Enter Credentials (db: demostore, user: admin)
    App->>Odoo: POST /web/session/authenticate
    Note over App,Odoo: Payload: {db, login, password}
    Odoo-->>App: Set-Cookie: session_id=r_xr...; UID=2, Currency=55 (BDT)
    App->>SQLite: Persist session cookie & user context

    App->>Odoo: POST /web/dataset/call_kw (pos.config, search_read)
    Odoo-->>App: [{id: 1, name: "Book Fair", current_session_state: "opened"}]
    
    App->>Odoo: POST /web/dataset/call_kw (pos.session, search_read, [["state","=","opened"]])
    Odoo-->>App: [{id: 23, name: "Book Fair/00014", config_id: [1, "Book Fair"]}]
    App->>SQLite: Save active_session_id = 23

    par Catalog & Category Fetch
        App->>Odoo: POST /web/dataset/call_kw (product.product, search_read)
        Odoo-->>App: 128 Products (81 books with ISBN, Author, Base64 image)
        App->>SQLite: Upsert into local_products
    and Category Hierarchy
        App->>Odoo: POST /web/dataset/call_kw (pos.category, search_read)
        Odoo-->>App: 23 Categories (including Bengali Unicode)
        App->>SQLite: Upsert into local_categories
    end

    App-->>Cashier: Display Catalog Screen (Ready for Offline Checkout)
```

---

### 3.2 High-Speed Offline Checkout (<500 ms)

Execution path when processing a customer purchase with cash over-tender and receipt printing, operating 100% locally.

```mermaid
sequenceDiagram
    autonumber
    actor Customer
    actor Cashier
    participant UI as MetaPOS UI
    participant TaxEngine as Reverse-Net Tax Engine
    participant Repo as Order Repository
    participant SQLite as Local SQLite DB
    participant Printer as Thermal ESC/POS Printer

    Customer->>Cashier: Purchases 1 Book (Printed MRP ৳ 100.00) & Tenders ৳ 500.00 Cash
    Cashier->>UI: Scan Barcode / Add Book (Template 62) to Cart
    UI->>TaxEngine: Calculate Reverse-Net VAT (MRP ৳ 100, Rate 10%)
    TaxEngine-->>UI: Net Unit = 90.9091, Subtotal = ৳ 90.91, VAT = ৳ 9.09, Total = ৳ 100.00
    
    Cashier->>UI: Enter Tender ৳ 500.00 -> Change due: ৳ 400.00
    Cashier->>UI: Tap "Complete Checkout"
    
    UI->>Repo: Create Order (Order UUID, Line UUID, Tender UUID, Change UUID)
    Note over Repo: Statically pairs tender (৳500) with change line (-৳400, 'ফেরত')<br/>Sets amount_paid = 100.0, amount_return = 0.0
    
    Repo->>SQLite: INSERT INTO local_orders (uuid, payload_json, sync_status='pending')
    SQLite-->>Repo: Commit OK (Elapsed: ~15 ms)
    
    par Immediate UI Feedback
        Repo-->>UI: Checkout Completed Successfully
        UI-->>Cashier: Show Success Screen & Drawer Open
    and Hardware Printing
        Repo->>Printer: Transmit ESC/POS 1-bit Monochrome Bitmap (Bengali Mushak 6.3)
        Printer-->>Customer: Dispense Printed Receipt
    end
    Note over Customer,Printer: Total Checkout Elapsed Time: < 350 ms
```

---

### 3.3 Asynchronous FIFO Queue Replay & Idempotency

Background process that syncs pending orders to Odoo when connectivity is available.

```mermaid
sequenceDiagram
    autonumber
    participant Worker as SyncQueueWorker
    participant SQLite as Local SQLite DB
    participant Odoo as Odoo 19 Server
    participant Postgres as PostgreSQL 16 DB

    loop Every 5 Seconds (when online)
        Worker->>SQLite: SELECT * FROM local_orders WHERE sync_status='pending' ORDER BY id ASC LIMIT 1
        SQLite-->>Worker: Order #144 (uuid: 878aa87d..., session_id: 23)
        
        Worker->>SQLite: UPDATE local_orders SET sync_status='syncing' WHERE id=144
        
        Worker->>Odoo: POST /web/dataset/call_kw (pos.order, sync_from_ui, [[payload]])
        Note over Worker,Odoo: Deterministically sorted lines: [0, 0, Line]<br/>Balanced payments: Tender (৳500) + Change (-৳400, 'ফেরত')<br/>amount_return: 0.0, amount_paid: 100.0
        
        Odoo->>Postgres: BEGIN TRANSACTION
        Odoo->>Postgres: SELECT id FROM pos_order WHERE uuid = '878aa87d...'
        
        alt First Submission (Normal Path)
            Postgres-->>Odoo: None (Record does not exist)
            Odoo->>Postgres: INSERT INTO pos_order (id=144, uuid='878aa87d...', ...)
            Odoo->>Postgres: INSERT INTO pos_order_line (uuid='1f9d719e...', ...)
            Odoo->>Postgres: INSERT INTO pos_payment (uuid='c7b4e871...', amount=500.0)
            Odoo->>Postgres: INSERT INTO pos_payment (uuid='ba4fc540...', amount=-400.0, name='ফেরত')
            Odoo->>Postgres: UPDATE product_template SET book_qty_on_hand = book_qty_on_hand - 1 WHERE id=62
            Postgres-->>Odoo: COMMIT OK
            Odoo-->>Worker: HTTP 200 {result: {pos.order: [{id: 144, uuid: '878aa87d...'}]}}
            Worker->>SQLite: UPDATE local_orders SET sync_status='synced', odoo_id=144
        else Resubmission / Network Retry (Idempotency Path)
            Postgres-->>Odoo: Found existing row (id: 144)
            Note over Odoo: Idempotency bypass: Returns existing order record without duplicating rows
            Odoo-->>Worker: HTTP 200 {result: {pos.order: [{id: 144, uuid: '878aa87d...'}]}}
            Worker->>SQLite: UPDATE local_orders SET sync_status='synced', odoo_id=144
        end
    end
```

---

### 3.4 Expired Session Detection & Automated Re-binding

Workflow when an order captured during offline operation references an expired or closed session.

```mermaid
sequenceDiagram
    autonumber
    participant Worker as SyncQueueWorker
    participant Rebind as SessionRebindHandler
    participant SQLite as Local SQLite DB
    participant Odoo as Odoo 19 Server

    Worker->>Odoo: POST /web/dataset/call_kw (pos.order, sync_from_ui, [[Order #145]])
    Note over Worker,Odoo: Order #145 references stale session_id: 22
    
    Odoo-->>Worker: HTTP 200 JSON-RPC Error: odoo.exceptions.MissingError<br/>"Record does not exist or has been deleted. (Record: pos.session(22,), User: 2)"
    
    Worker->>Rebind: Handle Stale Session Error (session_id: 22)
    Rebind->>SQLite: UPDATE local_orders SET sync_status='session_rebind' WHERE id=145
    
    Rebind->>Odoo: POST /web/dataset/call_kw (pos.session, search_read, [["config_id","=",1],["state","=","opened"]])
    Odoo-->>Rebind: [{id: 23, name: "Book Fair/00014", state: "opened"}]
    
    alt New Active Session Found (ID 23)
        Rebind->>SQLite: UPDATE active_session SET session_id=23
        Rebind->>SQLite: Read payload_json for Order #145, rewrite session_id = 23, set sync_status='pending'
        SQLite-->>Rebind: Payload updated
        Rebind-->>Worker: Trigger immediate FIFO queue drain
        Worker->>Odoo: POST /web/dataset/call_kw (pos.order, sync_from_ui, [[Order #145 with session_id: 23]])
        Odoo-->>Worker: HTTP 200 Success (Order ID 145 created)
        Worker->>SQLite: UPDATE local_orders SET sync_status='synced', odoo_id=145
    else No Open Session on Register
        Rebind->>Odoo: POST /web/dataset/call_kw (pos.config, open_ui, [1])
        Odoo-->>Rebind: Created new session ID 24
        Rebind->>Odoo: POST /web/dataset/call_kw (pos.session, set_opening_control, [24, 0.0])
        Rebind->>SQLite: Rewrite pending orders to session_id=24 & re-sync
    end
```

---

## 4. Idempotency & UUID Generation Architecture

### 4.1 Multi-Level RFC 4122 v4 UUID Hierarchy

Every synchronized transaction consists of a three-tier tree of universally unique identifiers:

```
[Order Level] pos.order.uuid
     ├── [Line 1] pos.order.line.uuid (Product 44)
     ├── [Line 2] pos.order.line.uuid (Product 62)
     ├── [Payment 1] pos.payment.uuid (Tender ৳500.0)
     └── [Payment 2] pos.payment.uuid (Change -৳390.0, 'ফেরত')
```

1. **`pos.order.uuid`**:
   - Stamped by the client at transaction initialization.
   - Enforces transaction-level deduplication.
   - Database constraint: `pos_order_unique_uuid`.
2. **`pos.order.line.uuid`**:
   - Every individual line item MUST generate its own distinct RFC 4122 v4 UUID.
   - **CRITICAL**: Reusing line UUIDs across separate orders OR within the same order causes immediate database failure: `psycopg2.errors.UniqueViolation: duplicate key value violates unique constraint "pos_order_line_unique_uuid"`.
3. **`pos.payment.uuid`**:
   - Generated independently for both the tender line and the balancing change line.

---

### 4.2 Concurrency Race Resolution

If two client worker threads accidentally submit the same order payload concurrently (e.g. during a network stutter):
- Thread A reaches PostgreSQL first: inserts row and commits.
- Thread B reaches PostgreSQL seconds later: PostgreSQL triggers `UniqueViolation` on `pos_order_unique_uuid`.
- Odoo 19 wraps this as:
  ```
  odoo.exceptions.ValidationError: The operation cannot be completed: এই uuid-এর একটি অর্ডার আগে থেকেই আছে
  ```
- **Client Handling**: The MetaPOS queue worker catches `ValidationError` with message containing `uuid` and queries Odoo `pos.order.search_read([["uuid", "=", order.uuid]])`. Finding the confirmed order, it marks the local order as `'synced'` with zero error alerts, treating the race condition as an idempotent success.
