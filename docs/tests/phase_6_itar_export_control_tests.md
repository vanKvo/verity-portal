# Phase 6: ITAR & Export Control - Test Specification

## Objective
To ensure strict ITAR compliance by verifying the accurate ingestion of project rosters, the automated event-driven ingestion of HR citizenship data from S3, and the flawless execution of the Reconciliation Engine to detect export control violations.

---

## Incremental Test Plan

### FR-6.1: Manual Roster Ingestion
*Ensures that Program Management data can be uploaded and mapped to personnel correctly via the UI.*

**Test 1: Successful Roster Upload (Backend)**
- **Purpose:** Verify valid CSVs create database relationships.
- **Test name:** `test_ingest_roster_success` 
- **Target Route:** `POST /api/v1/itar/roster/upload` (`src/verity_portal/itar/router.py`)
- **Setup:** Seed database with Personnel ID '101' and Project ID '500'. Mock an uploaded CSV containing these IDs. Authenticate with `ROLE_EXPORT_CONTROL`.
- **Action:** Call the upload endpoint.
- **Assertion 1:** HTTP status is 200 OK.
- **Assertion 2:** `project_assignments` table contains the link between 101 and 500.

**Test 1.1: RBAC Enforcement (Backend)**
- **Purpose:** Ensure the endpoint rejects requests without the `ROLE_EXPORT_CONTROL` role.
- **Test name:** `test_ingest_roster_unauthorized`
- **Target Route:** `POST /api/v1/itar/roster/upload` (`src/verity_portal/itar/router.py`)
- **Setup:** Generate a mock JWT that lacks the `ROLE_EXPORT_CONTROL` claim (e.g., standard user).
- **Action:** Call the upload endpoint with the mock token.
- **Assertion 1:** HTTP status is 403 Forbidden.

**Test 2: Unrecognized Employee Handling (Backend)**
- **Purpose:** Ensure system does not crash on bad data but safely flags it.
- **Test name:** `test_ingest_roster_invalid_employee` 
- **Target Route:** `POST /api/v1/itar/roster/upload` (`src/verity_portal/itar/router.py`)
- **Setup:** Mock an uploaded CSV containing an Employee ID that does not exist in the DB.
- **Action:** Call the upload endpoint.
- **Assertion 1:** System raises an `ITARMappingError`.
- **Assertion 2:** Valid rows are inserted; invalid rows are returned in an error response object.

**Test 3: File Upload UI Rendering (Frontend)**
- **Purpose:** Verify the user can interact with the upload workflow.
- **Test name:** `should display upload success or mapping error table` 
- **Target Component:** `RosterUploadViewComponent` (`src/app/itar/roster-upload.component.ts`)
- **Setup:** Mock the Angular `ItarService` to return a `MappingError` response.
- **Action:** Trigger the file upload submit button.
- **Assertion 1:** The error `MatTable` renders showing the specific rows that failed.

---

### FR-6.2: S3 Automated HR Data Ingestion
*Ensures the background worker securely pulls HR data from AWS S3 and enforces the Custom ENUM.*

**Test 4: S3 Ingestion and Fuzzy Matching (Backend)**
- **Purpose:** Verify the worker correctly normalizes messy string data.
- **Test name:** `test_s3_worker_normalizes_citizenship` 
- **Target Service:** `S3WorkerService` (`src/verity_portal/itar/s3_worker.py`)
- **Setup:** Use the `moto` library to mock an S3 bucket. Upload a mock CSV to the bucket containing citizenship strings like "USA", "U.S.", and "Permanent Resident".
- **Action:** Execute `sync_hr_data()`.
- **Assertion 1:** "USA" maps to the `US_CITIZEN` enum in the database.
- **Assertion 2:** "Permanent Resident" maps to `PERMANENT_RESIDENT`.

**Test 5: Unrecognized Citizenship Fallback (Backend)**
- **Purpose:** Verify the worker safely halts on unknown statuses rather than guessing.
- **Test name:** `test_s3_worker_unknown_status` 
- **Target Service:** `S3WorkerService` (`src/verity_portal/itar/s3_worker.py`)
- **Setup:** Mock an S3 CSV with citizenship status "Unknown".
- **Action:** Execute `sync_hr_data()`.
- **Assertion 1:** The worker logs an exception for that record.
- **Assertion 2:** The record is queued for manual administrative review.

---

### FR-6.3: ITAR Reconciliation Engine
*Ensures the core compliance engine correctly identifies restricted access mismatches.*

**Test 6: Safe Access Scenario (Backend)**
- **Purpose:** Ensure the engine does not generate false positives.
- **Test name:** `test_reconciliation_engine_safe_access` 
- **Target Service:** `ItarReconciliationEngine` (`src/verity_portal/itar/service.py`)
- **Setup:** Seed DB with a `US_CITIZEN` assigned to an `ITAR_RESTRICTED` project.
- **Action:** Execute `run_audit()`.
- **Assertion 1:** No violations are created in the `compliance_violations` table.

**Test 7: Violation Detection Scenario (Backend)**
- **Purpose:** Ensure the engine flags illegal assignments immediately.
- **Test name:** `test_reconciliation_engine_violation_detected` 
- **Target Service:** `ItarReconciliationEngine` (`src/verity_portal/itar/service.py`)
- **Setup:** Seed DB with a `FOREIGN_NATIONAL` assigned to an `ITAR_RESTRICTED` project.
- **Action:** Execute `run_audit()`.
- **Assertion 1:** A high-priority record is inserted into `compliance_violations`.

**Test 8: Violations Dashboard Rendering (Frontend)**
- **Purpose:** Verify the Export Control Officer can view actionable alerts.
- **Test name:** `should fetch and display active compliance violations` 
- **Target Component:** `ViolationsDashboardComponent` (`src/app/itar/dashboard.component.ts`)
- **Setup:** Mock the API to return one OPEN violation.
- **Action:** Initialize the component.
- **Assertion 1:** The `MatTable` renders one row containing the employee's name, project, and date detected.
- **Assertion 2:** The "Resolve" button is visible and active on the row.
