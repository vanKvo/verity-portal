# Technical Design Document: Phase 6 - ITAR & Export Control
---
App Version: 1.1.0
---

## Document History / Changelog
> [!WARNING]
> **ATTENTION DEVELOPERS:** Version 1.1.0 introduces significant architectural changes to previously implemented logic (v1.0.0). Please review carefully. This document outlines exactly what must be refactored, removed, and built new.

| Version | Date | Changes |
| :--- | :--- | :--- |
| **1.1.0** | 2026-05-14 | - **Architectural Pivot:** Transitioned from siloed HR ingestion to a centralized "Data Hub" model.<br>- **RBAC Update:** Introduced strict separation of duties (`ROLE_HR`, `ROLE_CONTRACTS`, `ROLE_PM`, `ROLE_ECO`).<br>- **Feature Add:** Added Auto-Resolution logic with audit trails for ITAR violations.<br>- **Integration:** Added requirements for S3 Event Webhook ingestion. |
| **1.0.0** | Previous | Initial Phase 6 specification (Basic ITAR Reconciliation). |

---

## 1. System Architecture

### Tech Stack
- **Base Stack:** See [tech_stack.md](tech_stack.md)
- **Module Specific:** 
  - `pandas` (Fast CSV/Excel processing)
  - `thefuzz` (Fuzzy logic matching for citizenship normalization)
  - `boto3` (AWS SDK for S3 integration)
  - `moto` (S3 mocking for unit/integration tests)

### Project Structure (Feature-Based Layout)
- `backend/src/verity_portal/core/utils/file_utils.py` **[NEW]** → Centralized parsing utility
  - `parse_file_to_df` → Seekable buffer parser for `.csv`, `.xlsx`, `.xls`, and `.numbers` formats (using temp file buffer cleanup).
  - `extract_headers_from_file` → Low-overhead header parsing.
- `backend/src/verity_portal/data_hub/` **[NEW]** → Centralized Master Data Hub Feature Slice
  - `core/engine.py` → Centralized transactional bulk upsert engine (`MasterDataIngestor`).
  - `core/retrieval.py` → Dynamic file retrieval strategies (`ManualUploadStrategy`, `S3EventStrategy` with threadpool offloading).
  - `core/ingestion.py` → Coordination service (`DataHubOrchestrationService`) handling parsing, manual uploads, S3 webhooks, and routing.
  - `personnel/` → HR master records model, schemas, and fuzzy validation service.
  - `projects/` → Project master records model, schemas, and validation service.
  - `router.py` → REST and Webhook coordinates (/data-hub).
  - `exceptions.py` → Dedicated Data Hub exceptions.
  - `schemas.py` → Data transfer objects.
- `backend/src/verity_portal/itar/` **[MODIFY]** → Operational Compliance Module
  - `models.py` → Operational project assignments and compliance violation logs.
  - `service.py` → ITAR validation rules & reconciliation engine (reconciles operational assignments against the `data_hub` tables).
- `frontend/src/app/features/data-hub/` **[NEW]** → Centralized Shared Data Hub UI (personnel/projects tabs, dynamic mapper, and polling sync status).

### Boundaries
- **Always do:** Rely on strict ENUMs for citizenship (`US_CITIZEN`, `PERMANENT_RESIDENT`, `FOREIGN_NATIONAL`) and project sensitivity (`ITAR_RESTRICTED`, `EAR99`, `UNCLASSIFIED`).
- **Always do:** Protect master HR uploads with `require_role("ROLE_HR")` and master project uploads with `require_role("ROLE_ECO")`.
- **Always do:** Execute S3 downloads asynchronously offloaded to a thread pool (`run_in_executor`) to avoid event-loop blocking.
- **Never do:** Direct file format parsing inside feature business services. Always delegate to the centralized `file_utils` parsing module.
- **Never do:** Access environment variables directly from feature code. Always inject environment-specific configuration via the `ConfigService` (frontend) or `get_settings()` (backend).

---

## 2. Global Technical Context (The Contracts)
*Developers: Read this section to understand the module-wide infrastructure and boundaries before starting any specific feature.*

### Data Model & Storage
- **`projects` Table:**
  - `id` (UUID, PK)
  - `name` (String)
  - `sensitivity` (Enum: `ITAR_RESTRICTED`, `EAR99`, `UNCLASSIFIED`)
- **`personnel` Table:**
  - `id` (UUID, PK)
  - `employee_id` (String, Unique)
  - `citizenship_status` (Enum: `US_CITIZEN`, `PERMANENT_RESIDENT`, `FOREIGN_NATIONAL`)
- **`project_assignments` (Bridging Table):**
  - `project_id` (UUID, FK)
  - `personnel_id` (UUID, FK)
- **`compliance_violations` Table:**
  - `id` (UUID, PK)
  - `personnel_id` (UUID, FK)
  - `project_id` (UUID, FK)
  - `status` (Enum: `OPEN`, `RESOLVED`)
  - `resolution_reason` (String) **[NEW]**
  - `created_at` (Datetime)

### API Specifications & Security (RBAC)
- **`POST /data-hub/parse-headers`** (Extracts raw column headers)
  - **Requires Role:** Authenticated users
- **`POST /data-hub/personnel/upload`** (Manual overwrite/upsert HR Data)
  - **Requires Role:** `ROLE_HR`
- **`POST /data-hub/projects/upload`** (Manual overwrite/upsert Projects sensitivity)
  - **Requires Role:** `ROLE_ECO`
- **`POST /data-hub/webhooks/s3-ingest`** (AWS event webhook)
  - **Requires Role:** Internal system auth
- **`GET /data-hub/sync-status`** (Retrieve synchronization status dates)
  - **Requires Role:** Authenticated users
- **`POST /api/v1/itar/roster/upload`** (Uploads PM project roster assignments)
  - **Requires Role:** `ROLE_PM`
- **`GET /api/v1/itar/violations`**
  - **Requires Role:** `ROLE_ECO` or `ROLE_PM`
- **`PUT /api/v1/itar/violations/{id}/resolve`** (ECO resolve violation with explanation)
  - **Requires Role:** `ROLE_ECO`
- **`POST /api/v1/itar/reconcile`** (Manually executes audit)
  - **Requires Role:** `ROLE_PM` or `ROLE_ECO`

### Event Interfaces (Asynchronous)
- **Subscribes To:** AWS S3 Event `s3:ObjectCreated:Put` payload matching configured `S3_HR_BUCKET_NAME` or prefix. Defer parsing to FastAPI BackgroundTasks to avoid execution timeouts.
- **Publishes:** Email notifications via `SnsEmailService` on background worker failures.

### Environment Variables & Configuration
- `S3_HR_BUCKET_NAME`: Bucket configured for background S3 events (e.g. `verity-portal`).
- `S3_ENDPOINT_URL`: Endpoint URL for secure S3 object retrieval (e.g. MinIO/S3 URL).
- `AWS_SNS_TOPIC_ARN`: Target topic ARN to publish failed background worker alert emails.

### Error Handling Strategy
- Raise `MappingParseError` (HTTP 400) for unmappable column mappings or malformed JSON payloads.
- Raise `DataHubRetrievalError` (HTTP 400) for S3 download issues or connection failures.
- Raise `IngestionRoutingError` (HTTP 400) for webhook object keys not matching master data patterns.

---

## 3. Feature Implementation Breakdown

### Requirement ID: FR-6.1 - Program Management Data Ingestion & Mapping
**Architectural Rationale:** PMs trigger temporary operational assignments, which are mapped against the foundational HR database.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** `POST /api/v1/itar/roster/upload` **[MODIFY]** - Require `ROLE_PM`.
- **Service Layer:** `ItarService.ingest_roster(file)` **[MODIFY]**. Parse the CSV, validate `employee_id` against the new `personnel` schema located in the foundational module, and bulk insert into `project_assignments`.
- **Data Access:** SQLAlchemy `session.bulk_save_objects()`.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** `RosterUploadViewComponent` **[MODIFY]**. Ensure UI verbage specifies "Project Assignment Upload" to differentiate from the HR Master upload.
- **State & Service:** `ItarService` (Angular) will handle the HTTP POST and map the response to a `RosterUploadResult` interface.
- **Error Handling:** Catch HTTP 400s and display `MappingErrors`.

#### Implementation Tasks
- [ ] **[Backend]** **[MODIFY]** Update CSV parsing to validate against new `personnel` module logic.
- [ ] **[Frontend]** **[MODIFY]** Update `RosterUploadViewComponent` UI text and logic.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Ingesting a CSV with valid IDs creates relationships.
- [ ] **[Backend]** Unit Test: Ingesting a CSV with invalid IDs raises `ITARMappingError`.
- [ ] **[Frontend]** Component Test: File upload progress bar and error table render correctly.

---

### Requirement ID: FR-6.2 - Centralized Data Hub (HR & Project Master Ingestion)
**Architectural Rationale:** Foundational Master HR (Citizenship) and Project Sensitivity records are structurally decoupled from operational modules (e.g. ITAR reconciliations or leaver checklists) to prevent data drift and enforce robust separation of duties.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** 
  - `POST /data-hub/webhooks/s3-ingest` **[NEW]** - Secure AWS S3 webhook trigger.
  - `POST /data-hub/personnel/upload` **[NEW]** - Requires `ROLE_HR` for manual HR overrides.
  - `POST /data-hub/projects/upload` **[NEW]** - Requires `ROLE_ECO` for manual Project overrides.
  - `GET /data-hub/sync-status` **[NEW]** - Open to authenticated users to query latest update times.
- **Service Layer:** `DataHubOrchestrationService` **[NEW]**. Orchestrates manual file mappings and dynamically routes background S3 event uploads to `PersonnelService` or `ProjectService` based on file keys.
- **Data Access:** Dynamic Pydantic schema validation (`MasterDataIngestor` engine) executing transactional bulk UPSERTs with isolated database sub-transactions (nested savepoints).
- **Deprecation:** **[DELETE]** `S3WorkerService` inside `src/verity_portal/itar/`.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** 
  - `DataHubComponent` **[NEW]**. A unified dashboard offering segregated tabs for "Personnel & HR Records" (restricted to `ROLE_HR`) and "Project Governance" (restricted to `ROLE_ECO`).
  - `ShareMapperComponent` **[NEW]**. A reusable column mapping UI helper enabling dynamic Excel/Numbers header configuration.
- **Polling & Refresh:** The frontend component polls `/data-hub/sync-status` every 10 seconds and displays a manual `refresh` action next to the last sync status.

#### Implementation Tasks
- [ ] **[Backend]** **[NEW]** Setup the centralized `DataHubOrchestrationService` and bulk upsert engine.
- [ ] **[Backend]** **[NEW]** Provision the shared file parser (`file_utils.py`) to support thread-safe `.numbers` buffering.
- [ ] **[Backend]** **[DELETE]** Remove deprecated `S3WorkerService` from `itar`.
- [ ] **[Frontend]** **[NEW]** Build the vertical `DataHubComponent` containing dual role-restricted tabs and polling.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Ingestion correctly maps raw strings to ENUMs.
- [ ] **[Backend]** Integration Test: Webhook dynamically routes files based on name matches.
- [ ] **[Frontend]** Component Test: Last sync badge polls and refreshes properly.

---

### Requirement ID: FR-6.3 - Automated ITAR Reconciliation & Auto-Resolution
**Architectural Rationale:** The core business value. Enforce separation of duties (`ROLE_ECO` resolves) and handle eventual consistency (Auto-Resolution).

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** `PUT /api/v1/itar/violations/{id}/resolve` **[MODIFY]** - Strictly require `ROLE_ECO`.
- **Service Layer:** `ItarReconciliationEngine.run_audit()` **[MODIFY]**. 
  - *Auto-Resolution Logic:* Before creating new violations, query `OPEN` violations. Check current `personnel` and `projects` tables. If the relationship is no longer a violation, update the violation status to `RESOLVED` with the reason `SYSTEM_AUTO_RESOLVED`. Do not delete the record.
- **Alerting:** If a NEW violation is inserted, trigger `EmailService` to notify the Export Control Officer.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** `ViolationsDashboardComponent` **[MODIFY]**.
  - Conditionally render the "Resolve" button: `*ngIf="authService.hasRole('ROLE_ECO')"`.
  - Display the resolution reason in the table (e.g., distinguishing between "DSP-5 License" vs "System Auto-Resolved").
- **State & Service:** `ItarService.getViolations()` mapped to `ComplianceViolation[]` interface.

#### Implementation Tasks
- [ ] **[Backend]** **[MODIFY]** Update the SQLAlchemy join query to detect mismatches and process Auto-Resolutions.
- [ ] **[Backend]** **[MODIFY]** Update `PUT /api/v1/itar/violations/{id}/resolve` endpoint to verify `ROLE_ECO`.
- [ ] **[Frontend]** **[MODIFY]** Update `ViolationsDashboardComponent` template to conditionally hide the resolve button.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Engine catches a foreign national on a restricted project.
- [ ] **[Backend]** Unit Test: Engine ignores a US Citizen on a restricted project.
- [ ] **[Frontend]** E2E Test: Dashboard correctly fetches and displays a red alert for a new violation.
