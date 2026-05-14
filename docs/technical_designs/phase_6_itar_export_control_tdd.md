# Technical Design Document: Phase 6 - ITAR & Export Control
---
App Version: 1.0.0
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
- `backend/src/verity_portal/itar/` → Backend domain for export control
  - `models.py` → Database schemas (Project, Personnel, Violations)
  - `service.py` → ITAR business logic & Reconciliation engine
  - `router.py` → API endpoints (Audit trigger, violations management)
  - `s3_worker.py` → Background worker for HR citizenship synchronization
- `frontend/src/app/features/itar-audit/` → Frontend domain
  - `components/itar-dashboard.component.ts` → Main compliance dashboard
  - `services/itar.service.ts` → API client for ITAR endpoints

### Boundaries
- **Always do:** Rely on strict ENUMs for citizenship validation.
- **Always do:** Use `require_role("ROLE_EXPORT_CONTROL")` for all ITAR-specific endpoints.
- **Always do:** Perform citizenship normalization in the `S3WorkerService` to maintain a strict internal ENUM.
- **Never do:** Store AWS Credentials in the source code or database. The S3 worker must use IAM Roles.
- **Never do:** Import `ItarRepository` or `ProjectModel` directly into other features (e.g., Identity); use services for inter-module communication.

---

## 2. Global Technical Context (The Contracts)

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
  - `created_at` (Datetime)

### API Specifications & Security (RBAC)
*Note: Utilize the Stubbed RBAC dependency `Depends(require_role("..."))` from Phase 2. Implement phase 2 for FR-2.4 to create a robust RBAC implementation.*
- **`POST /api/v1/itar/roster/upload`** (Uploads Program Management CSV)
  - **Requires Role:** `ROLE_EXPORT_CONTROL`
- **`GET /api/v1/itar/violations`** (Fetches active alerts)
  - **Requires Role:** `ROLE_EXPORT_CONTROL`
- **`POST /api/v1/itar/reconcile`** (Manually triggers the engine)
  - **Requires Role:** `ROLE_EXPORT_CONTROL`

### Event Interfaces (Asynchronous)
- **Subscribes To:** AWS S3 Event `s3:ObjectCreated:Put` on bucket `verity-hr-secure-sync`.
- **Publishes:** Internal application alerts (Violation Detected).

### Environment Variables & Configuration
- `AWS_S3_HR_BUCKET`: Name of the bucket for automated ingestion.
- `ITAR_ALERT_DISTRIBUTION_LIST`: Email address for critical compliance notifications.

### Error Handling Strategy
- Raise `ITARMappingError` (Mapped to 400 Bad Request) for invalid CSV schemas.
- Raise `S3IngestionError` (Triggers admin notification) for malformed background files.

---

## 3. Feature Implementation Breakdown

### Requirement ID: FR-6.1 - Program Management Data Ingestion & Mapping
**Architectural Rationale:** We use manual UI mapping here because the Export Control Officer owns this process and must verify external project rosters.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** `POST /api/v1/itar/roster/upload` utilizing `UploadFile`.
- **Service Layer:** `ItarService.ingest_roster(file)`. Parse the CSV, lookup `personnel` by Employee ID, and bulk insert into `project_assignments`.
- **Data Access:** SQLAlchemy `session.bulk_save_objects()`.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** Re-use the existing `FileUploadComponent` but configure the upload URL specifically for the ITAR roster endpoint.
- **State & Service:** `ItarService` (Angular) will handle the HTTP POST and map the response to a `RosterUploadResult` interface.
- **Error Handling:** Catch HTTP 400s and display `MappingErrors` (e.g., "Unknown Project") in a `MatTable` for the user to review.

#### Implementation Tasks
- [ ] **[Backend]** Create `ProjectAssignment` SQLAlchemy model.
- [ ] **[Backend]** Implement CSV parsing and bulk insert in `ItarService`.
- [ ] **[Frontend]** Create `RosterUploadViewComponent`.
- [ ] **[Frontend]** Wire `ItarService.uploadRoster()` to backend.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Ingesting a CSV with valid IDs creates relationships.
- [ ] **[Backend]** Unit Test: Ingesting a CSV with invalid IDs raises `ITARMappingError`.
- [ ] **[Frontend]** Component Test: File upload progress bar and error table render correctly.

---

### Requirement ID: FR-6.2 - HR Citizenship Data Standardization
**Architectural Rationale:** Event-Driven S3 ingestion prevents the compliance team from manually handling highly sensitive HR/PII data.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Routing:** None (Triggered by S3 Event or Cron job).
- **Service Layer:** `S3WorkerService.sync_hr_data()`. Connects to S3 via `boto3`, downloads the CSV, and runs fuzzy matching to convert strings ("U.S.") to the `citizenship_status` ENUM.
- **Data Access:** UPSERT logic on the `personnel` table based on `employee_id`.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** No UI needed for the ingestion itself. However, the `ComplianceDashboard` should have a small widget displaying: "Last HR Sync: [Timestamp]".

#### Implementation Tasks
- [ ] **[Backend]** Provision `boto3` logic to securely fetch from `AWS_S3_HR_BUCKET`.
- [ ] **[Backend]** Implement citizenship fuzzy-matching dictionary in `ItarService`.
- [ ] **[Backend]** Set up FastAPI BackgroundTask or Celery worker to run the sync.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Worker correctly maps "USA" and "US Citizen" to `US_CITIZEN`.
- [ ] **[Backend]** Integration Test: Worker successfully reads a mock file from S3 (using `moto`).

---

### Requirement ID: FR-6.3 - Automated ITAR Reconciliation Engine
**Architectural Rationale:** The core business value. Runs fully automated post-ingestion to eliminate Excel lookups.

#### Backend Implementation Specification (FastAPI)
*For Backend Developers*
- **Service Layer:** `ItarReconciliationEngine.run_audit()`. 
- **Algorithm:** 
  1. Fetch all active `project_assignments`.
  2. Join `personnel` and `projects`.
  3. Filter where `personnel.citizenship == FOREIGN_NATIONAL` AND `projects.sensitivity == ITAR_RESTRICTED`.
  4. For each result, insert into `compliance_violations`.
- **Alerting:** If a violation is inserted, trigger `EmailService` to notify the Export Control Officer.

#### Frontend Implementation Specification (Angular)
*For Frontend Developers*
- **Component UI:** `ViolationsDashboardComponent`. A high-visibility `MatTable` showing Open Violations (Employee, Project, Date Detected).
- **State & Service:** `ItarService.getViolations()` mapped to `ComplianceViolation[]` interface.
- **Action:** Allow user to click a violation and mark it as `RESOLVED` (e.g., if a DSP-5 license is provided).

#### Implementation Tasks
- [ ] **[Backend]** Write the SQLAlchemy join query to detect mismatches.
- [ ] **[Backend]** Create `GET /api/v1/itar/violations` endpoint.
- [ ] **[Frontend]** Build `ViolationsDashboardComponent`.
- [ ] **[Frontend]** Implement the "Resolve Violation" modal and HTTP PUT request.

#### Verification Plan
- [ ] **[Backend]** Unit Test: Engine catches a foreign national on a restricted project.
- [ ] **[Backend]** Unit Test: Engine ignores a US Citizen on a restricted project.
- [ ] **[Frontend]** E2E Test: Dashboard correctly fetches and displays a red alert for a new violation.
