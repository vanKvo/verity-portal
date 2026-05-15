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
- `backend/src/verity_portal/personnel/` **[NEW]** → Foundational Data Hub
  - `models.py` → Database schemas for Master HR Data
  - `service.py` → Ingestion and Normalization Engine
  - `router.py` → S3 Webhook triggers and HR manual upload APIs
- `backend/src/verity_portal/itar/` **[MODIFY]** → Operational Domain
  - `models.py` → Project Assignments, Violations
  - `service.py` → ITAR business logic & Reconciliation engine (Reads from `personnel`)
  - `router.py` → PM Roster uploads, violations management
  - `s3_worker.py` **[DELETE]** → (Moved to personnel module)
- `frontend/src/app/features/data-hub/` **[NEW]** → Shared Data Hub UI
- `frontend/src/app/features/itar-audit/` **[MODIFY]** → Operational UI

### Boundaries
- **Always do:** Rely on strict ENUMs for citizenship validation.
- **Always do:** Use `require_role("ROLE_EXPORT_CONTROL")` (or `ROLE_ECO`) for ITAR violations management. **[MODIFY]**
- **Always do:** Perform citizenship normalization in the `PersonnelService` to maintain a strict internal ENUM. **[MODIFY]**
- **Never do:** Store AWS Credentials in the source code or database. Use IAM Roles.
- **Never do:** Allow a `ROLE_PM` to modify `personnel` master data or resolve compliance violations. **[NEW]**

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
*Note: Utilize the Stubbed RBAC dependency `Depends(require_role("..."))`*
- **`POST /api/v1/hr/webhooks/s3-ingest`** **[NEW]** (S3 event trigger)
  - **Requires Role:** Internal/IAM Auth
- **`POST /api/v1/hr/roster/upload`** **[NEW]** (Uploads Master HR Data)
  - **Requires Role:** `ROLE_HR`
- **`POST /api/v1/itar/roster/upload`** **[MODIFY]** (Uploads Program Management CSV)
  - **Requires Role:** `ROLE_PM`
- **`GET /api/v1/itar/violations`**
  - **Requires Role:** `ROLE_ECO` or `ROLE_PM`
- **`PUT /api/v1/itar/violations/{id}/resolve`** **[MODIFY]** (Resolve violation)
  - **Requires Role:** `ROLE_ECO`
- **`POST /api/v1/itar/reconcile`** (Manually triggers the engine)
  - **Requires Role:** `ROLE_PM` or `ROLE_ECO`

### Event Interfaces (Asynchronous)
- **Subscribes To:** AWS S3 Event `s3:ObjectCreated:Put` on bucket `verity-hr-secure-sync`. Triggers webhook. **[MODIFY]**
- **Publishes:** Internal application alerts (Violation Detected).

### Environment Variables & Configuration
- `AWS_S3_HR_BUCKET`: Name of the bucket for automated ingestion.
- `ITAR_ALERT_DISTRIBUTION_LIST`: Email address for critical compliance notifications.

### Error Handling Strategy
- Raise `ITARMappingError` (Mapped to 400 Bad Request) for invalid CSV schemas.
- Raise `S3IngestionError` (Triggers admin notification) for malformed background files.

---

## 3. Feature Implementation Breakdown
*Developers: Read the block specific to your Jira ticket/Feature ID.*

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

### Requirement ID: FR-6.2 - Master Data Hub (HR Ingestion)
**Architectural Rationale:** HR data is foundational and shared across the application. It must be decoupled from the ITAR module.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** 
  - `POST /api/v1/hr/webhooks/s3-ingest` **[NEW]** - Secure webhook triggered by AWS EventBridge.
  - `POST /api/v1/hr/roster/upload` **[NEW]** - Requires `ROLE_HR`.
- **Service Layer:** `PersonnelService.ingest_master_data()` **[NEW]**. Connects to S3 via `boto3`, downloads the CSV, and runs fuzzy matching to convert strings ("U.S.") to the `citizenship_status` ENUM.
- **Data Access:** UPSERT logic on the `personnel` table based on `employee_id`.
- **Deprecation:** **[DELETE]** `S3WorkerService` inside `src/verity_portal/itar/`.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** 
  - `DataIntegrationsComponent` **[NEW]**. A dedicated dashboard restricted to `ROLE_HR`.
  - `<app-hr-roster-upload>` **[NEW]**. Shared component for manual Master Data overrides.
- **Deprecation:** **[MODIFY]** Remove the "Last HR Sync" widget from the `ComplianceDashboard` if it implies PMs control the sync. Make it a read-only timestamp.

#### Implementation Tasks
- [ ] **[Backend]** **[NEW]** Provision `boto3` webhook logic to securely fetch from `AWS_S3_HR_BUCKET`.
- [ ] **[Backend]** **[NEW]** Implement citizenship fuzzy-matching dictionary in `PersonnelService`.
- [ ] **[Backend]** **[DELETE]** Remove deprecated `S3WorkerService` from `itar`.
- [ ] **[Frontend]** **[NEW]** Build `DataIntegrationsComponent`.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Worker correctly maps "USA" and "US Citizen" to `US_CITIZEN`.
- [ ] **[Backend]** Integration Test: Worker successfully reads a mock file from S3 (using `moto`).

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
