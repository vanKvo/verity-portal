# Phase 7: IT Asset & PO Audit - Test Specification

## Objective
Verify the secure ingestion of Procurement and IT Inventory master data via the Hybrid Data Hub pattern, and ensure the Asset Reconciliation Engine accurately detects financial anomalies (Ghost Assets and Wasted Spend) while strictly enforcing role-based resolution access.

---

## Incremental Test Plan by Functional Requirements

### FR-7.1: Procurement & Inventory Master Data Hub (Centralized Ingestion)
*[Ensures foundational data is correctly ingested via automated S3 webhooks and manual overrides, respecting strict RBAC boundaries.]*

**Test 1: S3 Webhook Dynamic Routing (Backend)**
- **Purpose:** Verify the webhook endpoint securely receives payload, correctly identifies file types based on keywords, and routes to the appropriate ingestor.
- **Test name:** `test_s3_webhook_routes_procurement_and_inventory` 
- **Target Route:** `POST /data-hub/webhooks/s3-ingest` (`src/verity_portal/data_hub/router.py`)
- **Setup:** Mock an AWS EventBridge S3 payload containing `weekly_finance_report.csv` and another containing `monthly_inventory_dump.xlsx`.
- **Action:** POST the payloads to the endpoint.
- **Assertion 1:** The `finance` file triggers `ProcurementService.ingest_master_data`.
- **Assertion 2:** The `inventory` file triggers `InventoryService.ingest_master_data`.

**Test 2: Manual Upload Authorization (Backend)**
- **Purpose:** Ensure role-based access control prevents cross-departmental data pollution.
- **Test name:** `test_manual_upload_rbac_enforcement` 
- **Target Route:** `POST /data-hub/procurement/upload` and `POST /data-hub/inventory/upload`
- **Setup:** Create test users with `ROLE_FINANCE`, `ROLE_IT`, and `ROLE_PM`.
- **Action:** Attempt to upload files to both endpoints using each role.
- **Assertion 1:** `ROLE_PM` receives 403 Forbidden on both endpoints.
- **Assertion 2:** `ROLE_IT` receives 200 OK on Inventory upload but 403 Forbidden on Procurement upload.

**Test 3: Thread-Safe .numbers File Parsing (Backend)**
- **Purpose:** Verify physical inventory `.numbers` spreadsheets are extracted via temp buffers without blocking the event loop.
- **Test name:** `test_inventory_numbers_extraction_cleanup` 
- **Target Service:** `parse_file_to_df` (`src/verity_portal/core/file_parser.py`)
- **Setup:** Mock a binary `.numbers` stream payload.
- **Action:** Execute parsing function.
- **Assertion 1:** Returns a valid Pandas DataFrame representing the inventory data.
- **Assertion 2:** Temp file on disk is successfully deleted.

---

### FR-7.2: Asset Reconciliation Engine
*[Ensures the core compliance engine correctly identifies missing or stale records between financial POs and physical asset states.]*

**Test 4: Ghost Asset Detection (Backend)**
- **Purpose:** Verify the engine identifies active hardware lacking financial procurement records.
- **Test name:** `test_reconciliation_detects_ghost_asset` 
- **Target Service:** `AssetReconciliationEngine.run_audit()` (`src/verity_portal/data_hub/audit/engine.py`)
- **Setup:** Seed database with an IT Asset (`asset_tag: MAC-123`, `status: IN_USE`) that has no matching `po_number` in the Procurement table.
- **Action:** Execute the audit engine.
- **Assertion 1:** A new `AssetViolationModel` is created with `violation_type: GHOST_ASSET`.
- **Assertion 2:** An automated notification task is dispatched to `ROLE_IT`.

**Test 5: Wasted Spend Detection (Backend)**
- **Purpose:** Verify the engine identifies active financial contracts for retired physical hardware.
- **Test name:** `test_reconciliation_detects_wasted_spend` 
- **Target Service:** `AssetReconciliationEngine.run_audit()`
- **Setup:** Seed database with an IT Asset (`status: RETIRED`) linked to a Procurement record (`status: ACTIVE`).
- **Action:** Execute the audit engine.
- **Assertion 1:** A new `AssetViolationModel` is created with `violation_type: WASTED_SPEND`.
- **Assertion 2:** An automated notification task is dispatched to `ROLE_FINANCE`.

**Test 6: Anomaly Resolution Authorization (Backend)**
- **Purpose:** Ensure only Finance can legally dismiss or resolve a financial discrepancy.
- **Test name:** `test_anomaly_resolution_restricted_to_finance` 
- **Target Route:** `POST /data-hub/audit/violations/{id}/resolve`
- **Setup:** Create an unresolved `AssetViolationModel`. Authenticate as `ROLE_IT` and `ROLE_FINANCE`.
- **Action:** Send a resolution payload (`{"resolution_reason": "Approved"}`).
- **Assertion 1:** `ROLE_IT` receives 403 Forbidden.
- **Assertion 2:** `ROLE_FINANCE` receives 200 OK and violation status changes to `RESOLVED`.
