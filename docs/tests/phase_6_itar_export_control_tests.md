# Phase 6: ITAR & Export Control - Test Specification
---
App Version: 1.1.0
---

## Document History / Changelog
> [!WARNING]
> **ATTENTION DEVELOPERS:** Version 1.1.0 introduces significant architectural changes. Tests marked with **[NEW]** or **[MODIFY]** must be written/updated before implementing the corresponding feature code (TDD). Tests marked with **[DELETE]** should be removed as the underlying architecture has been deprecated.

## Objective
To ensure strict ITAR compliance by verifying the accurate ingestion of project rosters, the automated event-driven ingestion of HR citizenship data from S3, and the flawless execution of the Reconciliation Engine to detect export control violations.

---

## Incremental Test Plan

### FR-6.1: Manual Roster Ingestion
*Ensures that Program Management data can be uploaded and mapped to personnel correctly via the UI.*

**Test 1: Successful Roster Upload (Backend)** **[MODIFY]**
- **Purpose:** Verify valid CSVs create database relationships.
- **Test name:** `test_ingest_roster_success` 
- **Target Route:** `POST /api/v1/itar/roster/upload` (`src/verity_portal/itar/router.py`)
- **Setup:** Seed database with Personnel ID '101' and Project ID '500' (via new `PersonnelService`). Mock an uploaded CSV containing these IDs. Authenticate with `ROLE_PM`. *(Modified: Now requires ROLE_PM instead of ROLE_EXPORT_CONTROL)*
- **Action:** Call the upload endpoint.
- **Assertion 1:** HTTP status is 200 OK.
- **Assertion 2:** `project_assignments` table contains the link between 101 and 500.

**Test 1.1: RBAC Enforcement (Backend)** **[MODIFY]**
- **Purpose:** Ensure the endpoint rejects requests without the `ROLE_PM` role.
- **Test name:** `test_ingest_roster_unauthorized`
- **Target Route:** `POST /api/v1/itar/roster/upload` (`src/verity_portal/itar/router.py`)
- **Setup:** Generate a mock JWT that lacks the `ROLE_PM` claim.
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

### FR-6.2: Master Data Hub (HR Ingestion)
*Ensures foundational data is correctly ingested via webhooks and manual overrides.*

**Test 4: S3 Webhook Trigger (Backend)** **[NEW]**
- **Purpose:** Verify the webhook endpoint securely receives payload and triggers ingestion.
- **Target Route:** `POST /api/v1/hr/webhooks/s3-ingest` (`src/verity_portal/personnel/router.py`)
- **Setup:** Mock an AWS EventBridge S3 payload. 
- **Action:** POST the payload to the endpoint.
- **Assertion:** Endpoint returns 202 Accepted and correctly invokes `PersonnelService.ingest_master_data`.

**Test 5: HR Manual Override (Backend)** **[NEW]**
- **Purpose:** Ensure only `ROLE_HR` can manually upload Master Data.
- **Target Route:** `POST /api/v1/hr/roster/upload`
- **Assertion 1:** User with `ROLE_PM` receives 403 Forbidden.
- **Assertion 2:** User with `ROLE_HR` receives 200 OK and data is upserted.

**Test 6: S3 Ingestion and Fuzzy Matching (Backend)** **[DELETE]**
- **Test name:** `test_s3_worker_normalizes_citizenship` 
- **Reason:** The standalone `s3_worker.py` inside the `itar` module is deprecated. Normalization testing is moved to the `PersonnelService` unit tests.

**Test 7: Unrecognized Citizenship Fallback (Backend)** **[DELETE]**
- **Test name:** `test_s3_worker_unknown_status` 
- **Reason:** Moved to `PersonnelService` unit tests.

---

### FR-6.3: ITAR Reconciliation Engine
*Ensures the core compliance engine correctly identifies restricted access mismatches and enforces Separation of Duties.*

**Test 8: Safe Access Scenario (Backend)**
- **Purpose:** Ensure the engine does not generate false positives.
- **Test name:** `test_reconciliation_engine_safe_access` 
- **Target Service:** `ItarReconciliationEngine` (`src/verity_portal/itar/service.py`)
- **Setup:** Seed DB with a `US_CITIZEN` assigned to an `ITAR_RESTRICTED` project.
- **Action:** Execute `run_audit()`.
- **Assertion 1:** No violations are created in the `compliance_violations` table.

**Test 9: Violation Detection Scenario (Backend)**
- **Purpose:** Ensure the engine flags illegal assignments immediately.
- **Test name:** `test_reconciliation_engine_violation_detected` 
- **Target Service:** `ItarReconciliationEngine` (`src/verity_portal/itar/service.py`)
- **Setup:** Seed DB with a `FOREIGN_NATIONAL` assigned to an `ITAR_RESTRICTED` project.
- **Action:** Execute `run_audit()`.
- **Assertion 1:** A high-priority record is inserted into `compliance_violations`.

**Test 10: System Auto-Resolution (Backend)** **[NEW]**
- **Purpose:** Verify that updated Master Data automatically resolves stale ITAR violations without deleting the historical record.
- **Target Service:** `ItarReconciliationEngine.run_audit()`
- **Setup:** 
  1. Seed DB with `OPEN` violation for Employee A (Foreign National).
  2. Modify Employee A in `personnel` DB to `US_CITIZEN` (simulating an HR Master Data update).
- **Action:** Execute `run_audit()`.
- **Assertion 1:** The `OPEN` violation transitions to `RESOLVED`.
- **Assertion 2:** The resolution reason is strictly set to `SYSTEM_AUTO_RESOLVED`.

**Test 11: Violations Dashboard Rendering (Frontend)**
- **Purpose:** Verify the Export Control Officer can view actionable alerts.
- **Test name:** `should fetch and display active compliance violations` 
- **Target Component:** `ViolationsDashboardComponent` (`src/app/itar/dashboard.component.ts`)
- **Setup:** Mock the API to return one OPEN violation.
- **Action:** Initialize the component.
- **Assertion 1:** The `MatTable` renders one row containing the employee's name, project, and date detected.

**Test 12: ECO Resolution Enforcement (Frontend)** **[MODIFY]**
- **Purpose:** Verify Program Managers cannot dismiss compliance alerts.
- **Target Component:** `ViolationsDashboardComponent`
- **Setup 1:** Render component with mock user having `ROLE_PM`.
- **Assertion 1:** The "Resolve Violation" button is NOT present in the DOM.
- **Setup 2:** Render component with mock user having `ROLE_ECO`.
- **Assertion 2:** The "Resolve Violation" button IS present and active.
