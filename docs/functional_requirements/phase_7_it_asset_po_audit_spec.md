# Functional Specification: Phase 7 - IT Asset & PO Audit

## Objective
To reconcile Procurement (Finance) data against physical IT Inventory to identify discrepancies, such as "Ghost Assets," unused software licenses, and unapproved hardware purchases. This phase establishes Procurement data as the System of Record and utilizes the Hybrid Data Hub pattern for automated and manual master data ingestion.

## Requirement ID: FR-7.1 – Procurement & Inventory Master Data Hub (Centralized Ingestion)
### Business Context & Rationale (The "Why")
Discrepancies between what a company pays for (Procurement) and what is actually deployed (IT Inventory) lead to massive financial waste. By establishing Procurement as the financial System of Record and treating both data streams as centralized Master Data within our Data Hub, we can decouple data ingestion from the audit logic and rely on automated S3 webhooks for up-to-date reporting.

### User Story
**As a** Finance Auditor or IT Asset Manager,
**I want** the system to automatically ingest and normalize Procurement and IT Inventory records via secure manual mapping or background S3 webhooks,
**So that** I have an accurate, daily foundation of data to run financial reconciliation audits without manually managing Excel imports.

### Functional Requirements
- **FR-7.1.1: Standard Schema Enforcement.** The system shall enforce standardized data models for Procurement (e.g., `po_number`, `purchase_date`, `asset_category`, `cost`) and IT Inventory (e.g., `asset_tag`, `status`, `assigned_user`).
- **FR-7.1.2: Dynamic Mapping Engine.** The system shall reuse the Shared Column Mapper to allow users to map custom JSON columns during manual UI uploads of PO or Inventory spreadsheets.
- **FR-7.1.3: Automated S3 Webhook Routing.** The S3 webhook router (`/data-hub/webhooks/s3-ingest`) shall dynamically route execution based on file keys:
  - If the key contains `"procurement"` or `"finance"`, route to the **Procurement Ingestor**.
  - If the key contains `"inventory"` or `"asset"`, route to the **Inventory Ingestor**.
- **FR-7.1.4: Sync Status Polling.** The Data Hub UI shall display and actively poll the `updated_at` synchronization timestamps for Procurement and Inventory tables.

### User Interaction & Workflow
#### Path 1: Basic Flow (Automated S3 Webhook Ingestion)
Focus: Event-driven background ingestion of Procurement and Inventory Data.
- An external ERP (e.g., SAP Ariba) drops the weekly PO export (`procurement_weekly_v2.csv`) or an IT Asset system drops an inventory export into the secure S3 bucket.
- An S3 event triggers a POST request to the backend webhook (`/data-hub/webhooks/s3-ingest`).
- FastAPI receives the payload, schedules a Background Task, and returns a `200 OK`.
- The background worker securely downloads the file, parses the data via the centralized parsing utility, and routes it to `ProcurementService`.
- System executes transactional upserts and updates the max `updated_at` timestamp.
- The user's active browser reloads or polls to display the updated "Last Sync" timestamp.

#### Path 2: Exception Flows (Errors & Edge Cases)
Focus: Malformed Data Drops.
- **Exc-A: Routing Failure:** System receives a webhook payload for `unknown_report.xlsx`. The router detects no matching keywords, raises `IngestionRoutingError`, and halts processing.

#### Path 3: Alternative Flows
Focus: Manual File Uploads.
- **Alt-A: Manual Procurement Upload:** A Finance Manager uploads a manual PO file. The frontend extracts headers, presents the Shared Column Mapper UI, and posts the mapping payload to `/data-hub/procurement/upload`.
- **Alt-B: Manual IT Inventory Upload:** An IT Asset Manager uploads an IT Inventory export (e.g. from ServiceNow or Snipe-IT). The frontend extracts headers, presents the Shared Column Mapper UI, and posts the mapping payload to `/data-hub/inventory/upload`.

### Non-Functional Requirements (Constraints)
- **NFR-7.1.1: Security (RBAC).** Manual Procurement uploads must require `ROLE_FINANCE` authorization. Manual Inventory uploads must require `ROLE_IT` authorization.
- **NFR-7.1.2: Thread Safety.** File parsing must utilize the thread-safe seekable buffer patterns established in Phase 6 to prevent event loop blocking.

### Verification Plan (Acceptance Criteria)
- **AC-7.1.1:** Verify that S3 webhook event triggers dynamically route to the correct service based on the presence of "procurement", "finance", "inventory", or "asset" in the file key.
- **AC-7.1.2:** Verify that the manual upload endpoints successfully reject requests from unauthorized roles.

---

## Requirement ID: FR-7.2 – Asset Reconciliation Engine
### Business Context & Rationale (The "Why")
Once the data is ingested, the system must identify financial leaks. A "Ghost Asset" is a physical device or software license that is physically active or deployed but lacks a valid procurement record (compliance risk), or conversely, a PO exists for maintenance but the asset is retired (financial waste).

### User Story
**As a** Finance Auditor,
**I want** the system to automatically cross-reference PO records against IT asset tags,
**So that** I can instantly view a dashboard of discrepancies, ghost assets, and unapproved purchases to take corrective action.

### Functional Requirements
- **FR-7.2.1: Automated Audit Execution.** The reconciliation engine shall compare `po_number` mappings between the Procurement and Inventory tables.
- **FR-7.2.2: Ghost Asset Detection.** The system shall flag IT assets marked as `IN_USE` that cannot be linked to an approved Procurement record.
- **FR-7.2.3: Wasted Spend Detection.** The system shall flag active Procurement maintenance/subscription records linked to IT assets marked as `RETIRED` or `LOST`.
- **FR-7.2.4: Resolution Tracking.** The system shall allow `ROLE_FINANCE` users to dismiss or resolve detected anomalies by providing a resolution reason.

### Role Capabilities & Notifications
#### Role: `ROLE_FINANCE`
- **Capabilities:** Can manually upload Procurement data via the Shared Mapper UI. Has full read-write access to the Asset Audit Dashboard to view all anomalies. Can financially "resolve" anomalies by either acknowledging a cancelled PO or marking a Ghost Asset as approved post-facto.
- **Notifications:** Receives automated email/in-app notifications for **Wasted Spend** violations (e.g., paying a maintenance contract on an asset that IT has marked as `RETIRED`).

#### Role: `ROLE_IT`
- **Capabilities:** Can manually upload IT Inventory data via the Shared Mapper UI. Has read-only access to the Asset Audit Dashboard. Cannot financially "resolve" a violation, but can view Ghost Assets to investigate them physically or in the ITAM system.
- **Notifications:** Receives automated email/in-app notifications for **Ghost Asset** violations (e.g., an active hardware device connected to the network that Finance has no record of purchasing).

### User Interaction & Workflow
#### Path 1: Basic Flow (Audit Dashboard)
Focus: Identifying and resolving a discrepancy.
- User with `ROLE_FINANCE` navigates to the "Asset Audit Dashboard".
- System displays a table of detected discrepancies (e.g., "Ghost Asset Found: Laptop-XYZ123").
- User investigates, updates the source system, and clicks "Resolve" in Verity Portal, entering a required reason.
- System updates the violation status to `RESOLVED` and records the audit trail.

### Non-Functional Requirements (Constraints)
- **NFR-7.2.1: Read Optimization.** The reconciliation query must utilize optimized SQL joins and indexes on `po_number` and `asset_tag` to return audit results in under 2 seconds.

### Verification Plan (Acceptance Criteria)
- **AC-7.2.1:** Verify that an IT Asset in `IN_USE` status without a matching Procurement record generates a high-priority "Ghost Asset" violation.
- **AC-7.2.2:** Verify that `ROLE_IT` users can view the dashboard but cannot resolve financial violations (restricted to `ROLE_FINANCE`).
